#!/usr/bin/env python3
"""flow host-context adapter core (opt-in, host-invoked, advisory only).

Boundary: ADR-0001 Addendum "Host-fired lifecycle context adapters" (2026-10-13).
Runs because the HOST fired a lifecycle event; terminates when this handler returns.
No tool interposition, no security enforcement, no gate-bearing behavior, no daemon.
The operator installs it; flow never registers it. Docs:
skills/flow/references/host-hooks.md

Contract:
  PreCompact   -> capture `flow.sh status` into the PRIVATE snapshot
                  <project>/.flow/context-handoff/snapshot.json (existing .flow only:
                  never created or chmodded; private subdir 0700; atomic os.replace by
                  dir_fd; symlink/owner-checked; serialized size capped). STDOUT STAYS
                  EMPTY on every branch. Snapshot failure -> warn + skip (fail-open).
  SessionStart -> ALWAYS recompute fresh authoritative `flow.sh status`, labeled by
                  source. The snapshot is validated through O_NOFOLLOW|O_DIRECTORY
                  dir_fd traversal (symlink/owner/type/mode checks at every component),
                  strict JSON with the recorded project matching this project, and used
                  only as a staleness reference - or as an explicitly STALE-labeled
                  fallback when fresh computation fails. Labels + body together never
                  exceed the configured byte cap; truncation respects UTF-8 boundaries.
  Project root -> preserve local marker acceptance (flow/, cards/, .flow/, or MODE).
                  Otherwise inspect at most 24 physical ancestors, nearest first,
                  for flow/00-idea.md, flow/00-inspect.md, .flow/, or cards/C-*.md
                  files. Bare ancestor flow/ or cards/ directories never qualify.
                  No match -> skip, never auto-init. Inherited FLOW_PROJECT_ROOT
                  cannot redirect the validated project used by the runner.

Hardening: strict JSON parse (duplicate keys rejected) of a 64 KiB-capped stdin with a
total deadline; strict UTF-8 (invalid/oversize input fully rejected); numeric env bounds
length-checked before int() with a floor on the output cap; subprocess in its own
session, output drained through capped buffers, killed by process group and reaped even
if its pipes close early; any unexpected error is fail-open (exit 0) with a warning that
never echoes raw payload values, cwd, event class, or runner stderr.

Env: FLOW_SKILL_DIR, FLOW_HOOK_TIMEOUT (1..120 s, default 10), FLOW_HOOK_MAX_BYTES
(1024..1048576, default 4000), FLOW_HOOK_SNAPSHOT=0 disables the snapshot write.
Requires python3 (stdlib only, already an optional flow dependency).
"""
import errno, json, os, queue, re, secrets, select, signal, stat as stat_mod, subprocess, sys, threading, time

TIMEOUT_DEF, TIMEOUT_MAX = 10, 120
BYTES_DEF, BYTES_MIN, BYTES_MAX = 4000, 1024, 1048576
STDIN_MAX = 65536
STDIN_DEADLINE = 5.0
try:
    _env_dl = float(os.environ.get("FLOW_HOOK_STDIN_DEADLINE", "5.0"))
    if 0.1 <= _env_dl <= 30.0:
        STDIN_DEADLINE = _env_dl
except (TypeError, ValueError):
    pass
LABEL_BUDGET = 512
MAGIC = "flow-compact-handoff/v1"
FLOW_DIR = ".flow"
PRIV_NAME = "context-handoff"
SNAP_NAME = "snapshot.json"

def note(msg):
    sys.stderr.write("flow-context: %s\n" % msg)

def fail_open(msg):
    note(msg)
    sys.exit(0)

def _uncaught(exc_type, value, tb):
    note("WARNING adapter error (%s); handoff skipped (fail-open)" % exc_type.__name__)
    os._exit(0)

sys.excepthook = _uncaught  # any unexpected error still exits 0 with a safe warning

def env_int(name, default, hard_min, hard_max):
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return default
    raw = raw.strip()
    if len(raw) > 9 or not re.match(r"^[0-9]+$", raw):
        note("WARNING %s rejected (not a bounded positive decimal); using default %d"
             % (name, default))
        return default
    val = int(raw)
    if val < hard_min or val > hard_max:
        note("WARNING %s=%d out of range %d..%d; using default %d"
             % (name, val, hard_min, hard_max, default))
        return default
    return val

TIMEOUT = env_int("FLOW_HOOK_TIMEOUT", TIMEOUT_DEF, 1, TIMEOUT_MAX)
MAX_OUT = env_int("FLOW_HOOK_MAX_BYTES", BYTES_DEF, BYTES_MIN, BYTES_MAX)
# Snapshot features need O_NOFOLLOW (symlink refusal at open) and O_DIRECTORY dir_fd
# walking. On a platform without them the snapshot is refused on BOTH read and write
# (fail-open: fresh-only handoff still works, with a warning).
HAS_NOFOLLOW = hasattr(os, "O_NOFOLLOW") and hasattr(os, "O_DIRECTORY")

if os.name == 'nt':
    import ctypes, msvcrt
    from ctypes import wintypes, c_void_p, c_int, c_wchar_p, POINTER, byref, sizeof

    ERROR_BROKEN_PIPE = 109
    ERROR_NO_DATA = 232
    ERROR_PIPE_NOT_CONNECTED = 233

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

    kernel32.CreateJobObjectW.restype = wintypes.HANDLE
    kernel32.CreateJobObjectW.argtypes = [c_void_p, c_wchar_p]

    kernel32.SetInformationJobObject.restype = wintypes.BOOL
    kernel32.SetInformationJobObject.argtypes = [wintypes.HANDLE, c_int, c_void_p, wintypes.DWORD]

    kernel32.AssignProcessToJobObject.restype = wintypes.BOOL
    kernel32.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]

    kernel32.CloseHandle.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]

    kernel32.TerminateJobObject.restype = wintypes.BOOL
    kernel32.TerminateJobObject.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel32.PeekNamedPipe.restype = wintypes.BOOL
    kernel32.PeekNamedPipe.argtypes = [
        wintypes.HANDLE,
        c_void_p,
        wintypes.DWORD,
        POINTER(wintypes.DWORD),
        POINTER(wintypes.DWORD),
        POINTER(wintypes.DWORD),
    ]

    def _win_peek_pipe(h_pipe):
        """Peek an open Windows named pipe handle without blocking.
        Returns (avail_bytes, is_eof, err_code)."""
        try:
            h_val = int(h_pipe) & 0xFFFFFFFFFFFFFFFF
            h = wintypes.HANDLE(h_val)
        except (ValueError, TypeError, OverflowError):
            return 0, False, 6  # ERROR_INVALID_HANDLE
        avail = wintypes.DWORD(0)
        res = kernel32.PeekNamedPipe(h, None, 0, None, byref(avail), None)
        if not res:
            err = ctypes.get_last_error()
            if err in (ERROR_BROKEN_PIPE, ERROR_NO_DATA, ERROR_PIPE_NOT_CONNECTED, 38):
                return 0, True, 0
            return 0, False, err
        return avail.value, False, 0
def utf8_cut(data, cap):
    """Byte cap that never splits a UTF-8 sequence."""
    if len(data) <= cap:
        return data
    cut = cap
    while cut > 0 and (data[cut] & 0xC0) == 0x80:
        cut -= 1
    return data[:cut]

def read_event():
    """Bounded stdin: byte cap AND total deadline. Strict UTF-8, duplicate JSON keys
    rejected, oversize rejected in full. Returns (payload, None) or (None, reason)."""
    try:
        if os.name != 'nt':
            fd = sys.stdin.fileno()
            if os.isatty(fd):
                return None, "interactive stdin (no piped event)"
            start, chunks, total = time.monotonic(), [], 0
            while True:
                left = STDIN_DEADLINE - (time.monotonic() - start)
                if left <= 0:
                    return None, "stdin deadline exceeded before a complete event"
                ready, _, _ = select.select([fd], [], [], min(left, 0.5))
                if not ready:
                    continue
                chunk = os.read(fd, 65536)
                if not chunk:
                    break
                total += len(chunk)
                if total > STDIN_MAX + 1:
                    return None, "event payload oversize (rejected in full)"
                chunks.append(chunk)
            data = b"".join(chunks)
        else:
            # Windows: select() raises WinError 10038 on pipes. Bounded synchronous polling via PeekNamedPipe.
            fd = sys.stdin.fileno()
            if os.isatty(fd):
                return None, "interactive stdin (no piped event)"
            try:
                h_pipe = msvcrt.get_osfhandle(fd)
            except (OSError, ValueError) as ex:
                return None, "invalid stdin handle (%s)" % type(ex).__name__

            start, chunks, total = time.monotonic(), [], 0
            while True:
                left = STDIN_DEADLINE - (time.monotonic() - start)
                if left <= 0:
                    return None, "stdin deadline exceeded before a complete event"
                avail, is_eof, err = _win_peek_pipe(h_pipe)
                if is_eof:
                    try:
                        while total <= STDIN_MAX + 1:
                            chunk = os.read(fd, min(65536, STDIN_MAX + 1 - total))
                            if not chunk:
                                break
                            chunks.append(chunk)
                            total += len(chunk)
                    except OSError:
                        pass
                    break
                if err != 0:
                    # NEVER fallback to blocking os.read; report safe error code
                    return None, "stdin pipe peek failed (OS error %d)" % err
                if avail > 0:
                    to_read = min(avail, min(65536, STDIN_MAX + 1 - total))
                    try:
                        chunk = os.read(fd, to_read)
                    except OSError as ex:
                        return None, "stdin read failed (%s)" % type(ex).__name__
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > STDIN_MAX + 1:
                        return None, "event payload oversize (rejected in full)"
                    chunks.append(chunk)
                else:
                    time.sleep(0.01)
            data = b"".join(chunks)
        if len(data) > STDIN_MAX:
            return None, "event payload oversize (rejected in full)"
        try:
            text = data.decode("utf-8", "strict")
        except UnicodeDecodeError:
            return None, "event payload is not valid UTF-8 (rejected)"
        if not text.strip():
            return None, "empty event payload"

        def no_dupes(pairs):
            keys = [k for k, _ in pairs]
            if len(keys) != len(set(keys)):
                raise ValueError("duplicate keys")
            return dict(pairs)

        try:
            payload = json.loads(text, object_pairs_hook=no_dupes)
        except ValueError:
            return None, "malformed event payload (invalid or duplicate-key JSON)"
        if not isinstance(payload, dict):
            return None, "event payload is not a JSON object"
        return payload, None
    except Exception as exc:
        return None, "stdin read failed (%s)" % type(exc).__name__
payload, reason = read_event()
if payload is None:
    fail_open("no usable event (%s) - ignoring" % reason)
def _normalize_win_path(p):
    if isinstance(p, str) and os.name == 'nt' and len(p) >= 3 and p.startswith('/') and p[1].isalpha() and p[2] == '/':
        return p[1].upper() + ':' + p[2:]
    return p

kind = payload.get("hook_event_name")
if kind not in ("SessionStart", "PreCompact"):
    fail_open("unsupported or missing event class - handles SessionStart and PreCompact "
              "only; ignoring")

def _has_flow_signature(root):
    """Use the runner's ancestor signatures, not bare planning/card directories."""
    if (os.path.isfile(os.path.join(root, "flow", "00-idea.md"))
            or os.path.isfile(os.path.join(root, "flow", "00-inspect.md"))
            or os.path.isdir(os.path.join(root, ".flow"))):
        return True
    cards = os.path.join(root, "cards")
    if os.path.isdir(cards):
        with os.scandir(cards) as entries:
            return any(entry.name.startswith("C-") and entry.name.endswith(".md")
                       and entry.is_file() for entry in entries)
    return False

proj = _normalize_win_path(payload.get("cwd"))
try:
    real = os.path.realpath(proj) if isinstance(proj, str) and proj else ""
    has_marker = bool(real) and os.path.isdir(real) and (
        os.path.isdir(os.path.join(real, "flow"))
        or os.path.isdir(os.path.join(real, "cards"))
        or os.path.isdir(os.path.join(real, ".flow"))
        or os.path.isfile(os.path.join(real, "MODE"))
    )
    if real and os.path.isdir(real) and not has_marker:
        # Walk only the resolved physical ancestry: a symlink alias cannot redirect
        # discovery to its lexical parents. Check exactly 24 parents, root at most once.
        for _ in range(24):
            parent = os.path.dirname(real)
            if parent == real:
                break
            real = parent
            if _has_flow_signature(real):
                has_marker = True
                break
except (OSError, ValueError):
    has_marker = False
if not has_marker:
    fail_open("event cwd is not a flow project (missing markers after resolution) - "
              "skipping (no fallback directory, no auto-init)")

PROJECT = real

base = _normalize_win_path(os.environ.get("FLOW_SKILL_DIR") or "")
if not base:
    home = _normalize_win_path(os.environ.get("HOME") or os.path.expanduser("~"))
    for cand in (os.path.join(home, ".claude", "skills", "flow"),
                 os.path.join(home, ".codex", "skills", "flow"),
                 os.path.join(home, ".agents", "skills", "flow"),
                 os.path.join(home, ".omp", "agent", "skills", "flow"),
                 os.path.join(home, ".cursor", "skills", "flow"),
                 os.path.join(home, ".gemini", "antigravity-cli", "skills", "flow"),
                 os.path.join(home, ".gemini", "config", "skills", "flow")):
        if os.path.isfile(os.path.join(cand, "runner", "flow.sh")):
            base = cand
            break
RUNNER = os.path.join(base, "runner", "flow.sh") if base else ""
if not RUNNER or not os.path.isfile(RUNNER):
    fail_open("WARNING flow skill home not found (set FLOW_SKILL_DIR); handoff skipped - "
              "run the flow verb manually")

def dirfd_checked(rel_parts, base_fd, last_exact_private=False):
    """Walk rel_parts below base_fd with O_NOFOLLOW|O_DIRECTORY. Every component must be
    a real directory (no symlink), owned by the current user, and not group/world-
    writable; the FINAL component (the private snapshot dir) must be exactly 0700.
    Returns the final fd or None."""
    fd = base_fd
    try:
        for index, part in enumerate(rel_parts):
            nxt = os.open(part, os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY, dir_fd=fd)
            if fd != base_fd:
                os.close(fd)
            fd = nxt
            st = os.fstat(fd)
            if st.st_uid != os.getuid():
                os.close(fd)
                return None
            if index == len(rel_parts) - 1 and last_exact_private:
                if (st.st_mode & 0o7777) != 0o700:
                    os.close(fd)
                    return None  # unsafe private dir is rejected, never chmodded on read
            elif st.st_mode & 0o022:
                os.close(fd)
                return None  # group/world-writable parent: refused, never chmodded
        return fd
    except OSError:
        if fd != base_fd:
            try:
                os.close(fd)
            except OSError:
                pass
        return None

def snapshot_fds():
    """Validated dir fds for the private snapshot dir on READ. None if anything along
    .flow -> context-handoff is missing, a symlink, foreign, or not a directory.
    Read-only: nothing is created, chmodded, or mutated."""
    try:
        proj_fd = os.open(PROJECT, os.O_RDONLY | os.O_DIRECTORY)
    except OSError:
        return None
    try:
        if os.lstat(os.path.join(PROJECT, FLOW_DIR)).st_uid != os.getuid():
            return None
        return dirfd_checked([FLOW_DIR, PRIV_NAME], proj_fd, last_exact_private=True)
    except OSError:
        return None
    finally:
        try:
            os.close(proj_fd)
        except OSError:
            pass

def load_snapshot():
    """O_NOFOLLOW open + fstat (regular, owner, private mode), strict JSON with magic,
    recorded project must equal this project. Returns (status_body, verdict)."""
    if not HAS_NOFOLLOW:
        return "", "platform lacks O_NOFOLLOW (refused)"
    priv_fd = snapshot_fds()
    if priv_fd is None:
        return "", "absent-or-untrusted"
    try:
        try:
            fd = os.open(SNAP_NAME, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=priv_fd)
        except OSError as exc:
            if exc.errno == errno.ENOENT:
                return "", "absent"
            if exc.errno == errno.ELOOP:
                return "", "symlink (refused)"
            return "", "unreadable (ignored)"
        try:
            st = os.fstat(fd)
            if not stat_mod.S_ISREG(st.st_mode):
                return "", "not a regular file (refused)"
            if st.st_uid != os.getuid():
                return "", "foreign owner (refused)"
            if st.st_mode & 0o177:
                return "", "unsafe mode (refused)"
            if st.st_size > BYTES_MAX:
                return "", "oversize (ignored)"
            data = b""
            while len(data) <= BYTES_MAX:
                chunk = os.read(fd, 65536)
                if not chunk:
                    break
                data += chunk
            if len(data) > BYTES_MAX:
                return "", "oversize (ignored)"
            try:
                doc = json.loads(data.decode("utf-8", "strict"))
            except (UnicodeDecodeError, ValueError):
                return "", "malformed (ignored)"
            if not isinstance(doc, dict) or doc.get("magic") != MAGIC:
                return "", "malformed (unrecognized magic; ignored)"
            snap_project = doc.get("project")
            if not isinstance(snap_project, str):
                return "", "malformed (missing project; ignored)"
            try:
                real_snap_project = os.path.realpath(snap_project)
            except (OSError, ValueError):
                real_snap_project = snap_project
            if snap_project != PROJECT and real_snap_project != PROJECT:
                return "", "cross-project (refused)"
            body = doc.get("status_body")
            if not isinstance(body, str):
                return "", "malformed (missing status_body; ignored)"
            return body, "valid"
        finally:
            os.close(fd)
    finally:
        os.close(priv_fd)

class JobHolder:
    def __init__(self, handle):
        self.handle = handle

    def close(self):
        if self.handle:
            if os.name == 'nt':
                try:
                    res = kernel32.CloseHandle(self.handle)
                    if not res:
                        err = ctypes.get_last_error()
                        note("WARNING CloseHandle on Job Object returned error %d; terminating job" % err)
                        try:
                            kernel32.TerminateJobObject(self.handle, 124)
                        except Exception:
                            pass
                        return False
                    self.handle = None
                    return True
                except Exception as ex:
                    note("WARNING CloseHandle failed (%s)" % type(ex).__name__)
                    return False
            else:
                self.handle = None
                return True
        return True

def create_windows_job():
    """Create an anonymous Windows Job Object configured with JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE.
    Contains the trusted gate child and all spawned descendants."""
    if os.name != 'nt':
        return None
    if os.environ.get("FLOW_TEST_INJECT_WIN_JOB_FAIL") == "1":
        return None
    try:
        h_job = kernel32.CreateJobObjectW(None, None)
        if not h_job:
            return None

        class JOBOBJECT_BASIC_LIMIT_INFORMATION(ctypes.Structure):
            _fields_ = [
                ("PerProcessUserTimeLimit", ctypes.c_int64),
                ("PerJobUserTimeLimit", ctypes.c_int64),
                ("LimitFlags", wintypes.DWORD),
                ("MinimumWorkingSetSize", ctypes.c_size_t),
                ("MaximumWorkingSetSize", ctypes.c_size_t),
                ("ActiveProcessLimit", wintypes.DWORD),
                ("Affinity", ctypes.c_size_t),
                ("PriorityClass", wintypes.DWORD),
                ("SchedulingClass", wintypes.DWORD),
            ]

        class IO_COUNTERS(ctypes.Structure):
            _fields_ = [
                ("ReadOperationCount", ctypes.c_uint64),
                ("WriteOperationCount", ctypes.c_uint64),
                ("OtherOperationCount", ctypes.c_uint64),
                ("ReadTransferCount", ctypes.c_uint64),
                ("WriteTransferCount", ctypes.c_uint64),
                ("OtherTransferCount", ctypes.c_uint64),
            ]

        class JOBOBJECT_EXTENDED_LIMIT_INFORMATION(ctypes.Structure):
            _fields_ = [
                ("BasicLimitInformation", JOBOBJECT_BASIC_LIMIT_INFORMATION),
                ("IoInfo", IO_COUNTERS),
                ("ProcessMemoryLimit", ctypes.c_size_t),
                ("JobMemoryLimit", ctypes.c_size_t),
                ("PeakProcessMemoryLimit", ctypes.c_size_t),
                ("PeakJobMemoryLimit", ctypes.c_size_t),
            ]

        info = JOBOBJECT_EXTENDED_LIMIT_INFORMATION()
        info.BasicLimitInformation.LimitFlags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        res = kernel32.SetInformationJobObject(
            h_job,
            9,  # JobObjectExtendedLimitInformation
            byref(info),
            sizeof(info),
        )
        if not res:
            kernel32.CloseHandle(h_job)
            return None
        return JobHolder(h_job)
    except Exception:
        return None
def assign_process_to_job(job_holder, proc_handle):
    if not job_holder or not job_holder.handle or os.name != 'nt':
        return False
    if os.environ.get("FLOW_TEST_INJECT_WIN_ASSIGN_FAIL") == "1":
        return False
    try:
        raw_handle = int(proc_handle)
        if raw_handle <= 0:
            return False
        h_proc = wintypes.HANDLE(raw_handle)
        return bool(kernel32.AssignProcessToJobObject(job_holder.handle, h_proc))
    except Exception:
        return False

def drain_capped(proc, cap, pgid, job_holder=None):
    """Drain child stdout/stderr via select (POSIX) or synchronous PeekNamedPipe (Windows) into capped
    buffers (surplus discarded, nothing unbounded retained). On deadline, kill process group/job."""
    if os.name != 'nt':
        bufs = {proc.stdout.fileno(): bytearray(), proc.stderr.fileno(): bytearray()}
        open_fds = list(bufs)
        deadline = time.monotonic() + TIMEOUT
        while open_fds:
            left = deadline - time.monotonic()
            if left <= 0:
                break
            try:
                ready, _, _ = select.select(open_fds, [], [], min(left, 0.5))
            except (OSError, InterruptedError):
                ready = []
            for fd in ready:
                try:
                    chunk = os.read(fd, 65536)
                except OSError:
                    chunk = b""
                if not chunk:
                    open_fds.remove(fd)
                    continue
                buf = bufs[fd]
                if len(buf) < cap:
                    buf.extend(chunk[:cap - len(buf)])
        rc = None
        try:
            rc = proc.wait(timeout=max(deadline - time.monotonic(), 0.1))
        except subprocess.TimeoutExpired:
            pass
        timed_out = (time.monotonic() >= deadline) or bool(open_fds)
        if timed_out or rc is None or proc.poll() is None:
            killed = True
            if pgid is not None:
                try:
                    os.killpg(pgid, signal.SIGKILL)  # saved group: covers surviving descendants
                except OSError:
                    try:
                        proc.kill()
                    except Exception:
                        pass
            else:
                try:
                    proc.kill()
                except Exception:
                    pass
            try:
                rc = proc.wait(timeout=5)  # reap the root: no zombie
            except Exception:
                rc = 124
            if killed or timed_out:
                rc = 124  # content from a killed run is marked as a timeout
        elif pgid is not None:
            # Process exited cleanly within deadline, but clean up any background descendants
            try:
                os.killpg(pgid, signal.SIGKILL)
            except OSError:
                pass
        return rc, bytes(bufs[proc.stdout.fileno()]), bytes(bufs[proc.stderr.fileno()])
    else:
        # Windows: select() unsupported on process pipes. Synchronous polling via PeekNamedPipe.
        out_buf = bytearray()
        err_buf = bytearray()
        out_fd = proc.stdout.fileno()
        err_fd = proc.stderr.fileno()
        drain_failed = False
        try:
            h_out = msvcrt.get_osfhandle(out_fd)
            h_err = msvcrt.get_osfhandle(err_fd)
            streams = {out_fd: (h_out, out_buf), err_fd: (h_err, err_buf)}
        except (OSError, ValueError) as ex:
            note("WARNING get_osfhandle failed (%s)" % type(ex).__name__)
            streams = {}
            drain_failed = True

        deadline = time.monotonic() + TIMEOUT
        while streams and not drain_failed:
            left = deadline - time.monotonic()
            if left <= 0:
                break
            did_read = False
            for fd, (h, buf) in list(streams.items()):
                avail, is_eof, err = _win_peek_pipe(h)
                if is_eof:
                    try:
                        while True:
                            chunk = os.read(fd, 65536)
                            if not chunk:
                                break
                            if len(buf) < cap:
                                buf.extend(chunk[:cap - len(buf)])
                    except OSError:
                        pass
                    del streams[fd]
                    continue
                if err != 0:
                    note("WARNING _win_peek_pipe fd=%d failed (OS error %d)" % (fd, err))
                    drain_failed = True
                    del streams[fd]
                    break
                if avail > 0:
                    did_read = True
                    to_read = min(avail, 65536)
                    try:
                        chunk = os.read(fd, to_read)
                    except OSError as ex:
                        note("WARNING os.read fd=%d failed (%s)" % (fd, type(ex).__name__))
                        drain_failed = True
                        del streams[fd]
                        break
                    if not chunk:
                        note("WARNING os.read fd=%d returned empty with avail=%d" % (fd, avail))
                        drain_failed = True
                        del streams[fd]
                        break
                    if len(buf) < cap:
                        buf.extend(chunk[:cap - len(buf)])
                # Root-exit does NOT drop stream; keep polling until real is_eof (BROKEN_PIPE) or deadline!
            if not did_read and streams and not drain_failed:
                time.sleep(0.01)

        timed_out = (time.monotonic() >= deadline)
        rc = None
        try:
            rem = max(deadline - time.monotonic(), 0.1) if not timed_out else 0.1
            rc = proc.wait(timeout=rem)
        except subprocess.TimeoutExpired:
            pass

        if timed_out or rc is None or drain_failed:
            rc = 124 if (timed_out or rc is None) else 1
            if job_holder:
                job_holder.close()
            try:
                proc.kill()
                proc.wait(timeout=5)
            except Exception:
                pass
        else:
            if job_holder and not job_holder.close():
                rc = 124
        res_rc = rc if rc is not None else 1
        res_out = bytes(out_buf)
        res_err = bytes(err_buf)
        if res_rc != 0:
            note("DEBUG: run_flow exit %s, captured stdout=%d bytes, captured stderr=%d bytes" %
                 (res_rc, len(res_out), len(res_err)))
        return res_rc, res_out, res_err
WIN_GATE_SCRIPT = (
    "import sys, subprocess\n"
    "go = sys.stdin.buffer.read(1)\n"
    "if go != b'G':\n"
    "    sys.exit(125)\n"
    "try:\n"
    "    p = subprocess.Popen(sys.argv[1:], stdin=subprocess.DEVNULL)\n"
    "    sys.exit(p.wait())\n"
    "except FileNotFoundError:\n"
    "    sys.exit(127)\n"
    "except Exception as ex:\n"
    "    sys.stderr.write('GATE_ERROR: %s\\n' % ex)\n"
    "    sys.stderr.flush()\n"
    "    sys.exit(126)\n"
)
def get_bash_executable():
    cand = os.environ.get("FLOW_BASH")
    if cand and os.path.isfile(cand):
        return cand
    if os.name == 'nt':
        for git_bash in (
            os.path.join(os.environ.get("ProgramFiles", "C:\\Program Files"), "Git", "bin", "bash.exe"),
            os.path.join(os.environ.get("ProgramFiles", "C:\\Program Files"), "Git", "usr", "bin", "bash.exe"),
            os.path.join(os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)"), "Git", "bin", "bash.exe"),
        ):
            if os.path.isfile(git_bash):
                return git_bash
    return "bash"

def run_flow(args):
    proc = None
    job_holder = None
    try:
        # Documented invocation shape is `bash <skill>/runner/flow.sh <cmd>` (command-
        # dispatch.md); repo checkouts may lack the exec bit, so run through bash.
        # Env hygiene (accepted no-side-effect boundary): FLOW_PROJECT_ROOT always wins
        # over cwd inside the runner, so it is pinned to the validated payload project -
        # an inherited value from the host session must never redirect the handoff. Usage
        # telemetry is disabled via the runner's own FLOW_LOG_DISABLE flag, so a
        # hook-triggered read-only verb writes no events anywhere; the adapter's sole
        # permitted write remains its own private snapshot.
        env = dict(os.environ)
        env["FLOW_PROJECT_ROOT"] = PROJECT.replace("\\", "/") if os.name == 'nt' else PROJECT
        env["FLOW_LOG_DISABLE"] = "1"
        popen_kwargs = {
            "cwd": PROJECT,
            "env": env,
            "stdout": subprocess.PIPE,
            "stderr": subprocess.PIPE,
            "stdin": subprocess.DEVNULL,
        }
        if os.name != 'nt':
            popen_kwargs["start_new_session"] = True
            proc = subprocess.Popen(["bash", RUNNER] + args, **popen_kwargs)
        else:
            job_holder = create_windows_job()
            if job_holder is None:
                # Abort BEFORE spawn: no uncontained Windows fallback
                note("WARNING Windows Job Object creation failed; spawn aborted (fail-open)")
                return 127, b"", b""
            popen_kwargs["creationflags"] = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
            popen_kwargs["stdin"] = subprocess.PIPE
            runner_arg = RUNNER.replace("\\", "/")
            bash_bin = get_bash_executable()
            gate_cmd = [sys.executable, "-c", WIN_GATE_SCRIPT, bash_bin, runner_arg] + args
            proc = subprocess.Popen(gate_cmd, **popen_kwargs)
            proc_handle = getattr(proc, "_handle", None)
            if not proc_handle or not assign_process_to_job(job_holder, proc_handle):
                try:
                    proc.kill()
                    proc.wait(timeout=5)
                except Exception:
                    pass
                job_holder.close()
                note("WARNING Windows Job Object assignment failed; process terminated (fail-open)")
                return 127, b"", b""
            try:
                proc.stdin.write(b"G")
                proc.stdin.flush()
                proc.stdin.close()
            except Exception:
                try:
                    proc.kill()
                    proc.wait(timeout=5)
                except Exception:
                    pass
                job_holder.close()
                note("WARNING failed to unblock launch gate; process terminated (fail-open)")
                return 127, b"", b""
    except Exception as exc:
        if job_holder:
            job_holder.close()
        return 127, b"", ("spawn failed: %s" % type(exc).__name__).encode()
    pgid = None
    if os.name != 'nt' and hasattr(os, "getpgid") and proc:
        try:
            pgid = os.getpgid(proc.pid)  # saved at spawn: group-kill stays possible
        except OSError:
            pgid = None
    try:
        return drain_capped(proc, MAX_OUT, pgid, job_holder=job_holder)
    finally:
        if job_holder:
            job_holder.close()
        if proc:
            for stream in (proc.stdout, proc.stderr, proc.stdin):
                try:
                    if stream:
                        stream.close()
                except Exception:
                    pass
def write_snapshot(doc, total_cap):
    """Write the snapshot entirely through validated dir fds: no path-based chmod (no
    symlink race), no .flow mutation, existing-unsafe private dir is REJECTED rather
    than repaired. Stage file: random secret name, O_CREAT|O_EXCL|O_NOFOLLOW, 0600,
    inside the private dir fd; atomic os.replace by dir_fd. The complete serialized
    document is capped at total_cap bytes. The private dir must be exactly 0700."""
    if not HAS_NOFOLLOW:
        note("WARNING platform lacks O_NOFOLLOW; snapshot refused (fresh-only handoff)")
        return False
    try:
        proj_fd = os.open(PROJECT, os.O_RDONLY | os.O_DIRECTORY)
    except OSError as exc:
        note("WARNING project dir open failed (%s); snapshot skipped" % exc.__class__.__name__)
        return False
    priv_fd = None
    staged_name = None
    try:
        # .flow: existing only, real dir, owner, not group/world-writable. Never created,
        # never chmodded.
        try:
            flow_fd = os.open(FLOW_DIR, os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY,
                              dir_fd=proj_fd)
        except FileNotFoundError:
            return False  # no durable state here: no snapshot, never create .flow
        except OSError as exc:
            note("WARNING %s refused (%s); snapshot skipped" % (FLOW_DIR, exc.__class__.__name__))
            return False
        try:
            st = os.fstat(flow_fd)
            if st.st_uid != os.getuid() or (st.st_mode & 0o022):
                note("WARNING existing %s failed safety checks (owner/mode); snapshot refused"
                     % FLOW_DIR)
                return False
            # context-handoff: open if present (no symlink, owner, exactly 0700), else
            # create 0700 under the validated .flow fd.
            try:
                priv_fd = os.open(PRIV_NAME, os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY,
                                  dir_fd=flow_fd)
            except FileNotFoundError:
                os.mkdir(PRIV_NAME, 0o700, dir_fd=flow_fd)
                priv_fd = os.open(PRIV_NAME, os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY,
                                  dir_fd=flow_fd)
            pst = os.fstat(priv_fd)
            if pst.st_uid != os.getuid() or (pst.st_mode & 0o7777) != 0o700:
                note("WARNING existing context-handoff unsafe (owner/mode); snapshot refused")
                return False
            # Refuse a symlink at the destination, then replace atomically by dir_fd.
            try:
                dst = os.stat(SNAP_NAME, dir_fd=priv_fd, follow_symlinks=False)
                if stat_mod.S_ISLNK(dst.st_mode):
                    note("WARNING existing snapshot is a symlink; refusing to write")
                    return False
            except FileNotFoundError:
                pass
            # Cap the complete serialized document: shrink status_body until it fits the
            # hard snapshot cap (BYTES_MAX, JSON overhead included). If even an empty
            # body cannot fit (oversized header/project), refuse instead of writing.
            body_cap = len(doc["status_body"])
            while True:
                doc["status_body"] = doc["status_body"][:body_cap]
                serialized = json.dumps(doc).encode("utf-8", "strict")
                if len(serialized) <= total_cap:
                    break
                if body_cap == 0:
                    note("WARNING snapshot exceeds the hard size cap even with an empty "
                         "body; refusing to write")
                    return False
                body_cap = max(int(body_cap * 0.8), 0)
            staged_name = ".stage-" + secrets.token_hex(8)  # unpredictable, no fallback path
            fd = os.open(staged_name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                         0o600, dir_fd=priv_fd)
            with os.fdopen(fd, "wb") as handle:  # buffered write: full flush on close
                handle.write(serialized)
            try:
                dst = os.stat(SNAP_NAME, dir_fd=priv_fd, follow_symlinks=False)
                if stat_mod.S_ISLNK(dst.st_mode):  # raced in between: refuse, clean stage
                    note("WARNING snapshot destination became a symlink; write refused")
                    return False
            except FileNotFoundError:
                pass
            os.replace(staged_name, SNAP_NAME, src_dir_fd=priv_fd, dst_dir_fd=priv_fd)
            staged_name = None  # replaced: nothing left to clean
            return True
        finally:
            os.close(flow_fd)
    except OSError as exc:
        note("WARNING snapshot write failed (%s); snapshot skipped" % exc.__class__.__name__)
        return False
    finally:
        if staged_name is not None and priv_fd is not None:
            try:
                os.unlink(staged_name, dir_fd=priv_fd)
            except OSError:
                pass
        if priv_fd is not None:
            try:
                os.close(priv_fd)
            except OSError:
                pass
        try:
            os.close(proj_fd)
        except OSError:
            pass

snap_rel_display = os.path.join(FLOW_DIR, PRIV_NAME, SNAP_NAME)

if kind == "PreCompact":
    if os.environ.get("FLOW_HOOK_SNAPSHOT", "1") != "1":
        note("snapshot disabled (FLOW_HOOK_SNAPSHOT=0); pre-compact capture skipped")
        sys.exit(0)  # stdout stays empty on every PreCompact branch
    rc, out, err = run_flow(["status"])
    body = utf8_cut(out, MAX_OUT).decode("utf-8", "replace").strip()
    if rc != 0 or not body:
        note("WARNING flow.sh status failed pre-compact (exit %s, %d stderr bytes "
             "suppressed); NO snapshot written" % (rc, len(err)))
        sys.exit(0)  # stdout stays empty on every PreCompact branch
    doc = {"magic": MAGIC,
           "captured": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
           "project": PROJECT,
           "source": "flow.sh status at pre-compact time; stale by definition after compaction",
           "status_body": body}
    if write_snapshot(doc, BYTES_MAX):
        note("pre-compact snapshot captured to %s (advisory; SessionStart recomputes fresh "
             "state and treats this as stale)" % snap_rel_display)
    sys.exit(0)  # stdout stays empty on every PreCompact branch

# SessionStart: fresh state is the authority; labels + body share the byte cap (bytes,
# UTF-8-safe); no snapshot-dir side effects on this event.
rc, out, err = run_flow(["status"])
fresh_raw = out if rc == 0 else b""
fresh = utf8_cut(fresh_raw, max(MAX_OUT - LABEL_BUDGET, 0)).decode("utf-8", "replace").strip()
snap_body, snap_verdict = load_snapshot()
if fresh:
    source = payload.get("source")
    # Only fixed labels reach stdout; unknown/malformed host data stays fail-open.
    authority = "current session authoritative"
    if isinstance(source, str):
        authority = {
            "compact": "post-compaction authoritative",
            "startup": "session startup authoritative",
            "resume": "resumed session authoritative",
            "clear": "cleared session authoritative",
            "fork": "forked session authoritative",
        }.get(source, authority)
    lines = ["[flow context handoff - SessionStart - advisory, never a gate]",
             '[source: fresh "flow.sh status" recomputed now - %s]' % authority,
             fresh]
    if snap_verdict != "absent-or-untrusted" and snap_verdict != "absent":
        lines.append("[pre-compact snapshot: %s - reference only; the state above is current]"
                     % snap_verdict)
    sys.stdout.buffer.write(utf8_cut(("\n".join(lines) + "\n").encode("utf-8"), MAX_OUT))
    sys.stdout.buffer.flush()
    sys.exit(0)

note("WARNING fresh flow.sh status failed (exit %s, %d stderr bytes suppressed)"
     % (rc, len(err)))
if snap_verdict == "valid":
    stale = utf8_cut(snap_body.encode("utf-8"),
                     max(MAX_OUT - LABEL_BUDGET, 0)).decode("utf-8", "replace").strip()
    lines = ["[flow context handoff - SessionStart - STALE SOURCE]",
             "[source: PRE-COMPACT SNAPSHOT %s - fresh status unavailable; stale by "
             "definition - run /flow status to re-verify]" % snap_rel_display,
             stale]
    sys.stdout.buffer.write(utf8_cut(("\n".join(lines) + "\n").encode("utf-8"), MAX_OUT))
    sys.stdout.buffer.flush()
    sys.exit(0)
note("WARNING no usable pre-compact snapshot (%s); run /flow status or /flow resume manually"
     % snap_verdict)
sys.exit(0)
