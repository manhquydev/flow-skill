#!/usr/bin/env python3
"""Deterministic lifecycle regression suite for Windows process containment in Flow context adapter.
(ADR-0001 Addendum 2026-10-13 / Windows Job Object & launch gate contract).

Covers:
1. Job Object creation failure injection (FLOW_TEST_INJECT_WIN_JOB_FAIL=1):
   Proves target bash runner was NEVER spawned, handler warns and fails open (exit 0).
   Uses positive healthy baseline confirming runner CAN write marker before testing refusal.
2. Job Object assignment failure injection (FLOW_TEST_INJECT_WIN_ASSIGN_FAIL=1):
   Proves launch gate child was terminated before GO, target NEVER ran (sentinel absent),
   handler warns and fails open (exit 0).
3. Silent held-open stdin producer:
   Bounded by STDIN_DEADLINE, fails open (exit 0) with empty stdout and deadline warning.
4. Oversized stdin payload (>64KiB):
   Rejected in full, fails open (exit 0) with empty stdout and oversize warning.
5. Surplus output drain:
   Target emitting large output (>cap) is drained without stalling, output contains
   fresh handoff content, and is capped <= MAX_BYTES.
6. Root-exit descendant-held pipe:
   Root exits while background child holds pipes; deadline terminates descendants,
   exit 0 fail-open.
"""

import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)
HANDLER_PY = os.path.join(REPO_ROOT, "skills", "flow", "adapter-hooks", "context_handler.py")
REAL_SKILL = os.path.join(REPO_ROOT, "skills", "flow")

passed = 0
failed = 0
skipped = 0

def check(name, cond, details=""):
    global passed, failed
    if cond:
        print("  ok   %s" % name)
        passed += 1
    else:
        print("  FAIL %s %s" % (name, details))
        failed += 1

def skip(name, reason="requires Windows host / CI"):
    global skipped
    print("  skip [%s: %s]" % (name, reason))
    skipped += 1

def mk_proj(tmp, name):
    d = os.path.join(tmp, name)
    os.makedirs(os.path.join(d, "flow"), exist_ok=True)
    os.makedirs(os.path.join(d, ".flow"), exist_ok=True)
    with open(os.path.join(d, "flow", "00-idea.md"), "w") as f:
        f.write("# idea\n")
    return d

def test_job_creation_failure_aborts_spawn():
    if os.name != 'nt':
        skip("job creation failure test")
        return
    tmp = tempfile.mkdtemp(prefix="flow_win_test_")
    try:
        proj = mk_proj(tmp, "p_job_fail")
        marker = os.path.join(tmp, "TARGET_RAN.marker")
        # Runner creates marker via sys.executable to be path/argv safe on both Windows and POSIX
        runner_dir = os.path.join(tmp, "fake_runner", "runner")
        os.makedirs(runner_dir, exist_ok=True)
        runner_sh = os.path.join(runner_dir, "flow.sh")
        py_bin = sys.executable.replace('\\', '/')
        marker_path = marker.replace('\\', '/')
        with open(runner_sh, "w") as f:
            f.write('#!/bin/sh\n%s -c "import sys; open(sys.argv[1], \'w\').write(\'RAN\')" %s\nexit 0\n' %
                    (shlex.quote(py_bin), shlex.quote(marker_path)))
        os.chmod(runner_sh, 0o755)

        # 1. Positive healthy baseline: confirm runner CAN write marker normally
        base_env = dict(os.environ)
        base_env["FLOW_SKILL_DIR"] = os.path.join(tmp, "fake_runner")
        payload = json.dumps({"hook_event_name": "SessionStart", "cwd": proj}).encode("utf-8")
        p_base = subprocess.run([sys.executable, HANDLER_PY],
                                input=payload, capture_output=True, env=base_env, timeout=10)
        diag = ("(rc=%d stderr=%s)" % (p_base.returncode, p_base.stderr[:200])) if not os.path.exists(marker) else ""
        check("healthy baseline creates marker", os.path.exists(marker), details=diag)
        if os.path.exists(marker):
            os.remove(marker)

        # 2. Injected failure: creation returns None -> abort BEFORE spawn
        fail_env = dict(base_env)
        fail_env["FLOW_TEST_INJECT_WIN_JOB_FAIL"] = "1"
        proc = subprocess.run([sys.executable, HANDLER_PY],
                              input=payload, capture_output=True, env=fail_env, timeout=10)
        check("job creation failure: exit 0 (fail-open)", proc.returncode == 0)
        check("job creation failure: target NEVER ran (marker absent)", not os.path.exists(marker))
        check("job creation failure: warning emitted", b"Windows Job Object creation failed" in proc.stderr)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

def test_job_assignment_failure_terminates_gate():
    if os.name != 'nt':
        skip("job assignment failure test")
        return
    tmp = tempfile.mkdtemp(prefix="flow_win_test_")
    try:
        proj = mk_proj(tmp, "p_assign_fail")
        marker = os.path.join(tmp, "TARGET_RAN.marker")
        runner_dir = os.path.join(tmp, "fake_runner", "runner")
        os.makedirs(runner_dir, exist_ok=True)
        runner_sh = os.path.join(runner_dir, "flow.sh")
        py_bin = sys.executable.replace('\\', '/')
        marker_path = marker.replace('\\', '/')
        with open(runner_sh, "w") as f:
            f.write('#!/bin/sh\n%s -c "import sys; open(sys.argv[1], \'w\').write(\'RAN\')" %s\nexit 0\n' %
                    (shlex.quote(py_bin), shlex.quote(marker_path)))
        os.chmod(runner_sh, 0o755)
        base_env = dict(os.environ)
        base_env["FLOW_SKILL_DIR"] = os.path.join(tmp, "fake_runner")
        payload = json.dumps({"hook_event_name": "SessionStart", "cwd": proj}).encode("utf-8")
        p_base = subprocess.run([sys.executable, HANDLER_PY],
                                input=payload, capture_output=True, env=base_env, timeout=10)
        diag = ("(rc=%d stderr=%s)" % (p_base.returncode, p_base.stderr[:200])) if not os.path.exists(marker) else ""
        check("healthy baseline creates marker", os.path.exists(marker), details=diag)
        if os.path.exists(marker):
            os.remove(marker)
        fail_env = dict(base_env)
        fail_env["FLOW_TEST_INJECT_WIN_ASSIGN_FAIL"] = "1"
        proc = subprocess.run([sys.executable, HANDLER_PY],
                              input=payload, capture_output=True, env=fail_env, timeout=10)
        check("job assignment failure: exit 0 (fail-open)", proc.returncode == 0)
        check("job assignment failure: target NEVER ran (unblocked gate prevented)", not os.path.exists(marker))
        check("job assignment failure: warning emitted", b"Windows Job Object assignment failed" in proc.stderr)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

def test_silent_held_stdin():
    env = dict(os.environ)
    env["FLOW_HOOK_STDIN_DEADLINE"] = "1.0"
    t0 = time.monotonic()
    pipe_proc = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(3)"], stdout=subprocess.PIPE)
    try:
        proc = subprocess.run([sys.executable, HANDLER_PY],
                              stdin=pipe_proc.stdout, capture_output=True, env=env, timeout=10)
    finally:
        pipe_proc.kill()
        pipe_proc.wait(timeout=2)
    t1 = time.monotonic()
    elapsed = t1 - t0
    check("silent held-stdin: exit 0 (fail-open)", proc.returncode == 0)
    check("silent held-stdin: stdout empty", proc.stdout == b"")
    check("silent held-stdin: deadline warning emitted", b"stdin deadline exceeded" in proc.stderr)
    check("silent held-stdin: bounded by deadline (%.2fs <= 2.5s)" % elapsed, elapsed <= 2.5)

def test_oversized_stdin():
    big_payload = b" " + json.dumps({"hook_event_name": "SessionStart", "cwd": "/tmp", "padding": "x" * 70000}).encode("utf-8")
    proc = subprocess.run([sys.executable, HANDLER_PY],
                          input=big_payload, capture_output=True, timeout=10)
    check("oversized stdin (>64KiB): exit 0 (fail-open)", proc.returncode == 0)
    check("oversized stdin (>64KiB): stdout empty", proc.stdout == b"")
    check("oversized stdin (>64KiB): oversize warning emitted", b"event payload oversize" in proc.stderr)

def test_surplus_output_drain():
    tmp = tempfile.mkdtemp(prefix="flow_win_test_")
    try:
        proj = mk_proj(tmp, "p_surplus")
        runner_dir = os.path.join(tmp, "fake_runner", "runner")
        os.makedirs(runner_dir, exist_ok=True)
        runner_sh = os.path.join(runner_dir, "flow.sh")
        # Emit 50,000 bytes with a identifiable status marker
        with open(runner_sh, "w") as f:
            f.write('#!/bin/sh\nprintf "SENTINEL_SURPLUS_DATA_%%050000d" 0\nexit 0\n')
        os.chmod(runner_sh, 0o755)

        env = dict(os.environ)
        env["FLOW_SKILL_DIR"] = os.path.join(tmp, "fake_runner")
        env["FLOW_HOOK_MAX_BYTES"] = "2048"
        payload = json.dumps({"hook_event_name": "SessionStart", "cwd": proj}).encode("utf-8")

        proc = subprocess.run([sys.executable, HANDLER_PY],
                              input=payload, capture_output=True, env=env, timeout=10)
        diag = ("(len=%d rc=%d stderr=%s)" % (len(proc.stdout), proc.returncode, proc.stderr[:200])) if b"SENTINEL_SURPLUS_DATA" not in proc.stdout else ""
        check("surplus output drain: exit 0", proc.returncode == 0)
        check("surplus output drain: output capped <= 2048 bytes (%d)" % len(proc.stdout), len(proc.stdout) <= 2048)
        check("surplus output drain: contains expected sentinel", b"SENTINEL_SURPLUS_DATA" in proc.stdout, details=diag)
        check("surplus output drain: no timeout diagnostic", b"timeout" not in proc.stderr.lower())
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

def test_nonzero_runner_diagnostics_do_not_echo_child_output():
    if os.name != 'nt':
        skip("nonzero runner diagnostic privacy test")
        return
    tmp = tempfile.mkdtemp(prefix="flow_win_test_")
    try:
        proj = mk_proj(tmp, "p_nonzero")
        runner_dir = os.path.join(tmp, "fake_runner", "runner")
        os.makedirs(runner_dir, exist_ok=True)
        runner_sh = os.path.join(runner_dir, "flow.sh")
        with open(runner_sh, "w") as f:
            f.write("#!/bin/sh\nprintf '%s\\n' 'FLOW_STDOUT_SENTINEL_6f283a'\n"
                    "printf '%s\\n' 'FLOW_STDERR_SENTINEL_b9501d' >&2\nexit 7\n")
        os.chmod(runner_sh, 0o755)
        env = dict(os.environ)
        env["FLOW_SKILL_DIR"] = os.path.join(tmp, "fake_runner")
        payload = json.dumps({"hook_event_name": "SessionStart", "cwd": proj}).encode("utf-8")
        proc = subprocess.run([sys.executable, HANDLER_PY], input=payload,
                              capture_output=True, env=env, timeout=10)
        check("nonzero runner diagnostic: handler fails open", proc.returncode == 0)
        check("nonzero runner diagnostic: runner exit and byte counts observed",
              b"run_flow exit 7, captured stdout=28 bytes, captured stderr=28 bytes" in proc.stderr)
        check("nonzero runner diagnostic: stdout sentinel suppressed",
              b"FLOW_STDOUT_SENTINEL_6f283a" not in proc.stdout + proc.stderr)
        check("nonzero runner diagnostic: stderr sentinel suppressed",
              b"FLOW_STDERR_SENTINEL_b9501d" not in proc.stdout + proc.stderr)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

def test_root_exit_descendant_held_pipe():
    tmp = tempfile.mkdtemp(prefix="flow_win_test_")
    try:
        proj = mk_proj(tmp, "p_rootexit")
        runner_dir = os.path.join(tmp, "fake_runner", "runner")
        os.makedirs(runner_dir, exist_ok=True)
        runner_sh = os.path.join(runner_dir, "flow.sh")
        pidfile = os.path.join(tmp, "child.pid")
        started_marker = os.path.join(tmp, "child.started")

        # Launch a python child that writes pid and started marker, then sleeps while holding pipes
        py_bin = sys.executable.replace('\\', '/')
        pid_path = pidfile.replace('\\', '/')
        start_path = started_marker.replace('\\', '/')
        child_script = (
            'import sys, os, time; '
            'open(sys.argv[1], "w").write(str(os.getpid())); '
            'open(sys.argv[2], "w").write("STARTED"); '
            'time.sleep(30)'
        )
        with open(runner_sh, "w") as f:
            f.write(
                '#!/bin/sh\n'
                '%s -c %s %s %s &\n'
                'exit 0\n' %
                (shlex.quote(py_bin), shlex.quote(child_script), shlex.quote(pid_path), shlex.quote(start_path))
            )
        os.chmod(runner_sh, 0o755)

        env = dict(os.environ)
        env["FLOW_SKILL_DIR"] = os.path.join(tmp, "fake_runner")
        env["FLOW_HOOK_TIMEOUT"] = "2"
        payload = json.dumps({"hook_event_name": "SessionStart", "cwd": proj}).encode("utf-8")

        t0 = time.monotonic()
        proc = subprocess.run([sys.executable, HANDLER_PY],
                              input=payload, capture_output=True, env=env, timeout=10)
        elapsed = time.monotonic() - t0
        check("root-exit held-pipe: exit 0 (fail-open)", proc.returncode == 0)
        check("root-exit held-pipe: bounded by timeout (%.2fs <= 5s)" % elapsed, elapsed <= 5.0)
        check("root-exit held-pipe: child actually started", os.path.exists(started_marker))

        # Verify child was terminated by process group (POSIX) or Job Object (Windows)
        if os.path.exists(pidfile):
            try:
                with open(pidfile) as pf:
                    cpid = int(pf.read().strip())
                if os.name == 'nt':
                    import ctypes
                    from ctypes import wintypes
                    SYNCHRONIZE = 0x00100000
                    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
                    STILL_ACTIVE = 259
                    ERROR_INVALID_PARAMETER = 87

                    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
                    k32.OpenProcess.restype = wintypes.HANDLE
                    k32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
                    k32.WaitForSingleObject.restype = wintypes.DWORD
                    k32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
                    k32.GetExitCodeProcess.restype = wintypes.BOOL
                    k32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
                    k32.CloseHandle.restype = wintypes.BOOL
                    k32.CloseHandle.argtypes = [wintypes.HANDLE]

                    is_dead = False
                    diag = ""
                    h = k32.OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, False, cpid)
                    if not h:
                        err = ctypes.get_last_error()
                        if err == ERROR_INVALID_PARAMETER:
                            is_dead = True
                        else:
                            diag = "OpenProcess failed: OS error %d" % err
                    else:
                        try:
                            wait_res = k32.WaitForSingleObject(h, 0)
                            if wait_res == 0:
                                exit_code = wintypes.DWORD()
                                if k32.GetExitCodeProcess(h, ctypes.byref(exit_code)):
                                    if exit_code.value != STILL_ACTIVE:
                                        is_dead = True
                                    else:
                                        diag = "process is STILL_ACTIVE"
                                else:
                                    err = ctypes.get_last_error()
                                    diag = "GetExitCodeProcess failed: OS error %d" % err
                            else:
                                diag = "WaitForSingleObject returned %d (non-signaled)" % wait_res
                        finally:
                            k32.CloseHandle(h)
                    check("root-exit held-pipe: child was reaped by Job Object", is_dead, details=diag)
                else:
                    try:
                        os.kill(cpid, 0)
                        alive = True
                    except OSError:
                        alive = False
                    check("root-exit held-pipe: child was reaped by group kill", not alive)
            except Exception as ex:
                check("root-exit held-pipe: child pid check succeeded", False, details=str(ex))
        else:
            check("root-exit held-pipe: child pidfile recorded", False)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

def main():
    print("=== Windows Lifecycle Regression Tests ===")
    test_job_creation_failure_aborts_spawn()
    test_job_assignment_failure_terminates_gate()
    test_silent_held_stdin()
    test_oversized_stdin()
    test_surplus_output_drain()
    test_nonzero_runner_diagnostics_do_not_echo_child_output()
    test_root_exit_descendant_held_pipe()

    print("\nRESULT: %d passed, %d failed, %d skipped" % (passed, failed, skipped))
    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
