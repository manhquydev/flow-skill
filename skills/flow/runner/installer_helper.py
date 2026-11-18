#!/usr/bin/env python3
"""installer_helper.py — flow skill ownership-receipt installer helper (stdlib only).

Single-process full-transaction helper used by install.sh / install.ps1:
  gen-receipt <root>
      Write an ownership receipt (manifest-hashes.json document) for every regular file
      under <root> (excluding the receipt itself, __pycache__, and .pyc/.pyo files) to stdout.
      Refuses symlinks and non-regular files (FIFOs, sockets, etc.) before hashing.

  upgrade <source_root> <dest_dir>
      Entire transactional update of an existing destination in ONE process (single walk,
      no preflight/build split):
        raw input validation component-by-component BEFORE normalization (rejecting
        symlink components even when '..' traverses them, e.g. /tmp/link/../dest,
        properly supporting POSIX, Windows drives, and UNC paths) →
        Python 3.7 compatible containment check (disjoint source/dest) →
        exclusive process lock (.flow-skill.installing.lock) compatible with Node installer →
        non-regular files (FIFOs, symlinks) refused before any hashing →
        dest survey (conflicts / root mismatch / legacy collisions collected up front;
        ANY hit aborts before the original is touched) →
        staged candidate in dest parent (receipted source files + preserved user customs
        including inside managed subdirs + preserved retired-modified files − pruned
        retired-unmodified files; fresh receipt generated from the staged bytes owning
        ONLY the new source files) →
        backup via rename dest→backup, promote candidate→dest →
        verify promoted tree against the IMMUTABLE staged expectation →
        clean up backup only after verified promotion.
        Promotion or verification failure triggers rename-only quarantine and restore;
        quarantine failure NEVER recursively deletes dst; restore runs ONLY if dest is
        vacant; if restore fails or dest is occupied, BOTH backup and candidate paths
        are preserved and reported in structured EROLLBACK JSON (exit 6).

Exit codes: 0 ok · 2 usage · 3 ownership conflict · 4 invalid receipt · 5 legacy collision ·
6 swap/rollback failure with backup retained · 7 environment / lock / symlink error.
Guarantees hold for returned failures only (no crash/SIGKILL atomicity claimed).
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import shutil
import stat
import sys
import tempfile
from pathlib import Path

# Enforce no bytecode generation to prevent .pyc clutter in source/dest trees
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

RECEIPT_NAME = "manifest-hashes.json"
LOCK_NAME = ".flow-skill.installing.lock"


def _rename(src: str | Path, dst: str | Path) -> None:
    """Atomic swap primitive seam. Tests may patch installer_helper._rename."""
    os.replace(str(src), str(dst))


class Fail(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message

def is_symlink_or_reparse(path: Path | str, st: os.stat_result | None = None) -> bool:
    """Return True if path/stat is a symbolic link or Windows reparse point (e.g. junction)."""
    try:
        if st is None:
            st = os.lstat(str(path))
        if stat.S_ISLNK(st.st_mode):
            return True
        if bool(getattr(st, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)):
            return True
        if getattr(os.path, "isjunction", lambda _: False)(str(path)):
            return True
        return False
    except OSError:
        return False


def parse_raw_path_segments(raw_path_str: str) -> tuple[str, list[str]]:
    """Parse raw path into (anchor, segments) preserving components and relative traversals."""
    if not raw_path_str:
        return "", []
    # Windows drive letter: C:\ or C:/
    if len(raw_path_str) >= 2 and raw_path_str[1] == ":" and raw_path_str[0].isalpha():
        drive = raw_path_str[:2]
        rest = raw_path_str[2:].lstrip("/\\")
        anchor = drive + ("\\" if "\\" in raw_path_str else "/")
        segments = [s for s in rest.replace("\\", "/").split("/") if s]
        return anchor, segments

    # MSYS / Git Bash POSIX drive path: /c/... or /d/...
    if len(raw_path_str) >= 2 and raw_path_str[0] == "/" and raw_path_str[1].isalpha() and (len(raw_path_str) == 2 or raw_path_str[2] in ("/")):
        if os.name == "nt" or "WINDIR" in os.environ or "SYSTEMROOT" in os.environ:
            drive = raw_path_str[1].upper() + ":"
            rest = raw_path_str[2:].lstrip("/")
            anchor = drive + "/"
            segments = [s for s in rest.split("/") if s]
            return anchor, segments

    # UNC path: \\server\share\...
    if raw_path_str.startswith(("\\\\", "//")):
        clean = raw_path_str[2:].replace("\\", "/")
        parts = clean.split("/", 2)
        if len(parts) >= 2:
            unc_anchor = raw_path_str[:2] + parts[0] + ("\\" if "\\" in raw_path_str else "/") + parts[1]
            rest = parts[2] if len(parts) > 2 else ""
            segments = [s for s in rest.replace("\\", "/").split("/") if s]
            return unc_anchor, segments

    drive, rest = os.path.splitdrive(raw_path_str)
    if drive or raw_path_str.startswith(("/", "\\")):
        anchor = (drive + os.sep) if drive else ("\\" if raw_path_str.startswith("\\") else "/")
        rest_clean = rest.lstrip("/\\")
        segments = [s for s in rest_clean.replace("\\", "/").split("/") if s]
        return anchor, segments

    return "", [s for s in raw_path_str.replace("\\", "/").split("/") if s]

def validate_raw_path_no_symlinks(raw_path_str: str, label: str, must_exist: bool = True) -> Path:
    """Validate path component-by-component BEFORE any normalization or abspath resolve.

    Traverses the raw spelling preserving '.' and '..' segments.
    Properly handles POSIX roots, Windows drive letters (C:\\), and UNC paths (\\\\server\\share).
    Checks each existing prefix with lstat so that any symlink component is rejected immediately.
    Returns canonicalized Path once validated.
    """
    if not raw_path_str:
        raise Fail("env", f"{label} path is empty")

    anchor, segments = parse_raw_path_segments(raw_path_str)
    if anchor:
        curr = Path(anchor)
    else:
        cwd = Path(os.getcwd())
        # Validate cwd ancestry first
        for parent in list(reversed(cwd.parents)) + [cwd]:
            try:
                st = parent.lstat()
                if is_symlink_or_reparse(parent, st):
                    raise Fail("env", f"current working directory component is a symlink: {parent}")
            except OSError as e:
                raise Fail("env", f"cannot stat cwd component {parent}: {e}")
        curr = cwd

    for idx, seg in enumerate(segments):
        if seg == ".":
            continue
        if seg == "..":
            # Before going to parent, curr was already lstat-verified
            curr = curr.parent
            continue

        curr = curr / seg

        try:
            st = curr.lstat()
        except FileNotFoundError:
            if not must_exist:
                remaining = segments[idx + 1 :]
                if ".." in remaining:
                    raise Fail("symlink", f"{label} cannot traverse '..' through nonexistent component: {curr}")
                for rem in remaining:
                    if rem and rem != ".":
                        curr = curr / rem
                break
            raise Fail("symlink" if ".." in segments else "env", f"{label} path component does not exist: {curr}")
        except OSError as e:
            raise Fail("env", f"{label} path error on {curr}: {e}")

        if is_symlink_or_reparse(curr, st):
            raise Fail("symlink", f"{label} symlink component refused: {curr}")

    try:
        st = curr.lstat()
        if is_symlink_or_reparse(curr, st):
            raise Fail("symlink", f"{label} root is a symlink: {curr}")
    except FileNotFoundError:
        if must_exist:
            raise Fail("env", f"{label} path does not exist: {curr}")
    return curr


def is_within(child: Path, parent: Path) -> bool:
    """Python 3.7-compatible containment check without following symlinks."""
    child_str = os.path.normpath(str(child))
    parent_str = os.path.normpath(str(parent))
    if child_str == parent_str:
        return True
    try:
        common = os.path.commonpath([child_str, parent_str])
        return common == parent_str
    except (ValueError, OSError):
        return False


def acquire_lock(lock_path: Path) -> bool:
    """Acquire exclusive installer lock compatible with Node installer.mjs."""
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    my_pid = str(os.getpid())
    try:
        with open(lock_path, "x") as f:
            f.write(my_pid + "\n")
        return True
    except FileExistsError:
        pass
    except OSError as e:
        raise Fail("env", f"cannot create lock file {lock_path}: {e}")

    # Lock exists — check if holding process is alive
    pid = None
    try:
        pid_text = lock_path.read_text(encoding="utf-8").strip()
        pid = int(pid_text)
    except (ValueError, OSError):
        pass  # Corrupt lock content -> treat as stale

    if pid is not None and pid > 0:
        try:
            os.kill(pid, 0)
            raise Fail("lock", f"destination locked by installer process {pid}")
        except ProcessLookupError:
            pass  # Stale lock
        except PermissionError:
            raise Fail("lock", f"destination locked by installer process {pid}")

    # Remove stale lock and retry once
    try:
        lock_path.unlink()
    except OSError:
        pass

    try:
        with open(lock_path, "x") as f:
            f.write(my_pid + "\n")
        return True
    except FileExistsError:
        raise Fail("lock", f"destination locked concurrently at {lock_path}")
    except OSError as e:
        raise Fail("env", f"cannot create lock file {lock_path}: {e}")


def release_lock(lock_path: Path) -> None:
    try:
        lock_path.unlink()
    except OSError:
        pass


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def is_canonical_rel(p: str) -> bool:
    if not p or p.startswith("/") or p.startswith("~") or "\\" in p or ":" in p:
        return False
    for seg in p.split("/"):
        if seg in ("", ".", ".."):
            return False
    return True


def special_files(root: Path) -> list[str]:
    """Return all relative paths that are non-regular files or symlinks.

    Walks strictly without following symlinks. Skips __pycache__ and bytecode.
    Never opens FIFOs or devices.
    """
    out: list[str] = []
    if is_symlink_or_reparse(root):
        out.append(".")
        return out
    for dirpath, dirnames, filenames in os.walk(str(root), followlinks=False):
        dir_entries = list(dirnames)
        file_entries = list(filenames)
        keep_dirs = []
        for d in dir_entries:
            if d == "__pycache__":
                continue
            dp = Path(dirpath) / d
            if is_symlink_or_reparse(dp):
                out.append(dp.relative_to(root).as_posix())
            else:
                keep_dirs.append(d)
        dirnames[:] = keep_dirs

        for name in file_entries:
            if name.endswith(".pyc") or name.endswith(".pyo"):
                continue
            p = Path(dirpath) / name
            rel = p.relative_to(root).as_posix()
            try:
                st = p.lstat()
            except OSError as e:
                out.append(f"{rel} (inaccessible: {e})")
                continue
            if is_symlink_or_reparse(p, st):
                out.append(rel)
            elif not stat.S_ISREG(st.st_mode) and not stat.S_ISDIR(st.st_mode):
                out.append(rel)
    return sorted(out)


def assert_no_symlinks(root: Path, label: str) -> None:
    if is_symlink_or_reparse(root):
        raise Fail("symlink", f"{label} root symlink refused: {root}")
    for dirpath, dirnames, filenames in os.walk(str(root), followlinks=False):
        dir_entries = list(dirnames)
        file_entries = list(filenames)
        keep_dirs = []
        for d in dir_entries:
            if d == "__pycache__":
                continue
            dp = Path(dirpath) / d
            if is_symlink_or_reparse(dp):
                raise Fail("symlink", f"{label} symlink refused: {dp.relative_to(root).as_posix()}")
            keep_dirs.append(d)
        dirnames[:] = keep_dirs

        for name in file_entries:
            p = Path(dirpath) / name
            rel = p.relative_to(root).as_posix()
            if is_symlink_or_reparse(p):
                raise Fail("symlink", f"{label} symlink refused: {rel}")


def manifest_from_tree(root: Path) -> dict[str, str]:
    """Hash every regular file under root (excluding the receipt itself, pycache, .pyc)."""
    if is_symlink_or_reparse(root):
        raise Fail("source", f"symlink/reparse root refused before hashing: {root}")
    files: dict[str, str] = {}
    for dirpath, dirnames, filenames in os.walk(str(root), followlinks=False):
        dir_entries = list(dirnames)
        keep_dirs = []
        for d in dir_entries:
            if d == "__pycache__":
                continue
            dp = Path(dirpath) / d
            if is_symlink_or_reparse(dp):
                raise Fail("source", f"symlink/reparse directory refused before hashing: {dp.relative_to(root).as_posix()}")
            keep_dirs.append(d)
        dirnames[:] = keep_dirs

        for name in sorted(filenames):
            if name.endswith(".pyc") or name.endswith(".pyo"):
                continue
            p = Path(dirpath) / name
            rel = p.relative_to(root).as_posix()
            if rel == RECEIPT_NAME:
                continue
            st = p.lstat()
            if is_symlink_or_reparse(p, st) or not stat.S_ISREG(st.st_mode):
                raise Fail("source", f"non-regular source file refused before hashing: {rel}")
            files[rel] = sha256_file(p)
    return files


def parse_receipt(root: Path) -> dict[str, str]:
    rp = root / RECEIPT_NAME
    try:
        st = rp.lstat()
    except FileNotFoundError:
        raise Fail("receipt", f"ownership receipt missing: {rp}")
    except OSError as e:
        raise Fail("receipt", f"cannot stat ownership receipt: {e}")

    if is_symlink_or_reparse(rp, st):
        raise Fail("receipt", f"ownership receipt must not be a symlink: {rp}")
    if not stat.S_ISREG(st.st_mode):
        raise Fail("receipt", f"ownership receipt is not a regular file: {rp}")
    text = rp.read_text(encoding="utf-8")

    def reject_dups(pairs: list[tuple[str, object]]) -> dict[str, object]:
        keys = [k for k, _ in pairs]
        if len(keys) != len(set(keys)):
            dup = next(k for k in keys if keys.count(k) > 1)
            raise Fail("receipt", f"duplicate key in receipt JSON: {dup}")
        return dict(pairs)

    try:
        strict = json.loads(text, object_pairs_hook=reject_dups)
    except Fail:
        raise
    except ValueError as e:
        raise Fail("receipt", f"ownership receipt is not valid JSON: {e}")

    if not isinstance(strict, dict):
        raise Fail("receipt", "receipt root must be a JSON object")

    sv = strict.get("schema_version")
    if type(sv) is not int or sv != 1:
        raise Fail("receipt", "receipt schema_version must be integer 1")

    files = strict.get("files")
    if not isinstance(files, dict) or not files:
        raise Fail("receipt", 'receipt "files" map missing')

    out: dict[str, str] = {}
    for rel, digest in files.items():
        if not is_canonical_rel(rel):
            raise Fail("receipt", f"receipt path {rel}: not canonical")
        if not isinstance(digest, str) or len(digest) != 64:
            raise Fail("receipt", f"receipt digest for {rel} is not 64-hex")
        if any(c not in "0123456789abcdef" for c in digest):
            raise Fail("receipt", f"receipt digest for {rel} is not 64-hex lowercase")
        if rel == RECEIPT_NAME:
            raise Fail("receipt", "receipt must not list itself")
        out[rel] = digest
    return out


def verify_tree(root: Path, files: dict[str, str], label: str) -> None:
    for rel, digest in files.items():
        p = root / rel
        try:
            st = p.lstat()
        except FileNotFoundError:
            raise Fail("tree", f"{label}: receipted path missing: {rel}")
        except OSError as e:
            raise Fail("tree", f"{label}: receipted path error for {rel}: {e}")

        if is_symlink_or_reparse(p, st) or not stat.S_ISREG(st.st_mode):
            raise Fail("tree", f"{label}: receipted path is not a regular file: {rel}")
        if sha256_file(p) != digest:
            raise Fail("tree", f"{label}: digest mismatch for {rel}")


def rel_files(root: Path) -> list[str]:
    out: list[str] = []
    for dirpath, dirnames, filenames in os.walk(str(root), followlinks=False):
        dir_entries = list(dirnames)
        keep_dirs = []
        for d in dir_entries:
            if d == "__pycache__":
                continue
            dp = Path(dirpath) / d
            if not is_symlink_or_reparse(dp):
                keep_dirs.append(d)
        dirnames[:] = keep_dirs

        for name in filenames:
            if name.endswith(".pyc") or name.endswith(".pyo"):
                continue
            p = Path(dirpath) / name
            rel = p.relative_to(root).as_posix()
            try:
                st = p.lstat()
                if stat.S_ISREG(st.st_mode) and not is_symlink_or_reparse(p, st):
                    out.append(rel)
            except OSError:
                continue
    return sorted(out)

def cmd_gen_receipt(root_str: str) -> int:
    r = validate_raw_path_no_symlinks(root_str, "source", must_exist=True)
    if not r.is_dir() or is_symlink_or_reparse(r):
        sys.stderr.write(f"FAIL: source root is not a real directory: {r}\n")
        return 7

    specials = special_files(r)
    if specials:
        sys.stderr.write(f"FAIL: non-regular source entries refused: {specials}\n")
        return 4

    assert_no_symlinks(r, "source")
    files = manifest_from_tree(r)
    sys.stdout.write(json.dumps({"schema_version": 1, "files": files}, indent=2) + "\n")
    return 0


def cmd_upgrade(source_str: str, dest_str: str) -> int:
    try:
        src = validate_raw_path_no_symlinks(source_str, "source", must_exist=True)
        dst = validate_raw_path_no_symlinks(dest_str, "destination", must_exist=False)
    except Fail as e:
        print(json.dumps({"success": False, "code": e.code, "error": e.message}))
        return {
            "conflict": 3,
            "receipt": 4,
            "collision": 5,
            "io": 6,
            "lock": 7,
            "symlink": 7,
            "source": 4,
            "tree": 4,
        }.get(e.code, 7)
    if src == dst or is_within(dst, src) or is_within(src, dst):
        raise Fail("env", "source and destination must be disjoint trees")
    if dst == Path(dst.anchor):
        raise Fail("env", "destination is the filesystem root")

    if not (src / "SKILL.md").is_file():
        raise Fail("env", f"SKILL.md missing in sourceDir={src}")

    dest_exists = dst.exists()
    if dest_exists and not dst.is_dir():
        raise Fail("env", f"destination is not a real directory: {dst}")

    dst_parent = dst.parent
    try:
        dst_parent.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        raise Fail("env", f"cannot create destination parent directory {dst_parent}: {e}")

    # 3. Acquire exclusive destination lock before any filesystem modification
    lock_path = dst_parent / LOCK_NAME
    lock_held = False
    try:
        lock_held = acquire_lock(lock_path)
    except Fail:
        raise
    except Exception as e:
        raise Fail("env", f"failed to acquire installer lock: {e}")

    try:
        # 4. Non-regular / symlink rejection before ANY hashing
        src_specials = special_files(src)
        if src_specials:
            raise Fail("source", f"non-regular source entries refused before hashing: {src_specials}")
        assert_no_symlinks(src, "source")

        # 5. Source receipt verification or tree hashing
        src_rp = src / RECEIPT_NAME
        has_src_receipt = False
        try:
            if is_symlink_or_reparse(src_rp):
                raise Fail("receipt", f"source receipt must not be a symlink: {src_rp}")
            if src_rp.exists():
                has_src_receipt = True
        except OSError as e:
            raise Fail("receipt", f"cannot stat source receipt: {e}")

        if has_src_receipt:
            source_files = parse_receipt(src)
            verify_tree(src, source_files, "source")
            disk = set(rel_files(src)) - {RECEIPT_NAME}
            if disk != set(source_files.keys()):
                raise Fail("receipt", "source receipt does not cover the source tree exactly")
        else:
            source_files = manifest_from_tree(src)

        # 6. Destination survey
        old_files: dict[str, str] | None = None
        legacy = False
        if dest_exists:
            dst_rp = dst / RECEIPT_NAME
            has_dst_receipt = False
            try:
                if is_symlink_or_reparse(dst_rp):
                    raise Fail("receipt", f"destination receipt must not be a symlink: {dst_rp}")
                if dst_rp.exists():
                    has_dst_receipt = True
            except OSError as e:
                raise Fail("receipt", f"cannot stat destination receipt: {e}")

            if has_dst_receipt:
                old_files = parse_receipt(dst)
                old_files.pop(RECEIPT_NAME, None)
            else:
                legacy = True

        conflicts: list[str] = []
        retired_removed: list[str] = []
        retired_preserved: list[str] = []
        preserved: list[str] = []
        new_set = set(source_files.keys()) - {RECEIPT_NAME}

        if dest_exists:
            for rel in special_files(dst):
                conflicts.append(f"destination non-regular entry or symlink refused: {rel}")

            for rel, old_digest in (old_files or {}).items():
                p = dst / rel
                try:
                    st = p.lstat()
                except FileNotFoundError:
                    conflicts.append(f"receipted path missing from destination (root mismatch): {rel}")
                    continue
                except OSError as e:
                    conflicts.append(f"cannot stat receipted path: {rel} ({e})")
                    continue

                if is_symlink_or_reparse(p, st) or not stat.S_ISREG(st.st_mode):
                    conflicts.append(f"owned file was replaced with non-regular entry: {rel}")
                    continue

                disk_digest = sha256_file(p)
                if disk_digest != old_digest:
                    if rel not in new_set:
                        retired_preserved.append(rel)
                    else:
                        conflicts.append(f"user-modified owned file: {rel}")
                elif rel not in new_set:
                    retired_removed.append(rel)

            for rel in sorted(new_set):
                if old_files is not None and rel in old_files:
                    continue
                p = dst / rel
                try:
                    st = p.lstat()
                except FileNotFoundError:
                    continue
                except OSError:
                    continue

                if not is_symlink_or_reparse(p, st) and stat.S_ISREG(st.st_mode) and sha256_file(p) != source_files[rel]:
                    kind = "legacy destination" if legacy else "unowned destination file"
                    conflicts.append(f"{kind} collision with differing bytes: {rel}")

        if conflicts:
            raise Fail(
                "conflict",
                f"install refused before touching {dst}:\n  - " + "\n  - ".join(conflicts),
            )

        # 7. Staging candidate in same parent directory
        stage = Path(tempfile.mkdtemp(prefix=".flow-skill-stage-", dir=str(dst_parent)))
        backup = dst_parent / f".flow-skill-backup-{secrets.token_hex(8)}"
        failed = dst_parent / f".flow-skill-failed-{secrets.token_hex(8)}"
        backup_path: Path | None = None

        try:
            staged_receipt: dict[str, str] = {}
            for rel in sorted(new_set):
                s = src / rel
                d = stage / rel
                d.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(s, d)
                digest = sha256_file(d)
                if digest != source_files[rel]:
                    raise Fail("io", f"staged copy of {rel} does not match verified source bytes")
                staged_receipt[rel] = digest

            if dest_exists:
                for rel in sorted(retired_preserved):
                    d = stage / rel
                    d.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(dst / rel, d)

                for rel in sorted(rel_files(dst)):
                    if (
                        rel == RECEIPT_NAME
                        or (old_files is not None and rel in old_files)
                        or rel in new_set
                        or rel in retired_preserved
                    ):
                        continue
                    d = stage / rel
                    d.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(dst / rel, d)
                    preserved.append(rel)

                for dirpath, dirnames, filenames in os.walk(str(dst), followlinks=False):
                    dirnames[:] = [d for d in dirnames if d != "__pycache__"]
                    if not dirnames and not filenames:
                        rel_dir = Path(dirpath).relative_to(dst).as_posix()
                        (stage / rel_dir).mkdir(parents=True, exist_ok=True)

            (stage / RECEIPT_NAME).write_text(
                json.dumps({"schema_version": 1, "files": staged_receipt}, indent=2) + "\n",
                encoding="utf-8",
            )
            runner = stage / "runner" / "flow.sh"
            if runner.is_file():
                try:
                    runner.chmod(runner.stat().st_mode | 0o111)
                except OSError:
                    pass

            # 8. Atomic swap and recovery region
            if dest_exists:
                _rename(dst, backup)
                backup_path = backup

            try:
                _rename(stage, dst)
                verify_tree(dst, staged_receipt, "installed")
                promoted = parse_receipt(dst)
                if set(promoted.keys()) != set(staged_receipt.keys()) or any(
                    promoted[k] != staged_receipt[k] for k in staged_receipt
                ):
                    raise Fail("io", "promoted receipt differs from staged expectation")
            except (Fail, OSError) as swap_err:
                swap_msg = swap_err.message if isinstance(swap_err, Fail) else str(swap_err)
                failed_candidate_path: str | None = None

                if dst.exists() or is_symlink_or_reparse(dst):
                    try:
                        _rename(dst, failed)
                        failed_candidate_path = str(failed)
                    except OSError:
                        # Quarantine failed: NEVER RECURSIVELY DELETE DST
                        failed_candidate_path = str(dst)

                restored = False
                dest_vacant = not (dst.exists() or is_symlink_or_reparse(dst))
                if backup_path and dest_vacant:
                    try:
                        _rename(backup_path, dst)
                        restored = True
                    except OSError:
                        restored = False

                shutil.rmtree(stage, ignore_errors=True)

                if backup_path and not restored:
                    print(
                        json.dumps(
                            {
                                "success": False,
                                "code": "EROLLBACK",
                                "recovery_path": str(backup_path),
                                "failed_candidate_path": failed_candidate_path,
                                "dest_occupied": not dest_vacant,
                                "error": (
                                    f"transaction failed ({swap_msg}); "
                                    f"{'dest occupied, restore aborted' if not dest_vacant else 'rollback rename failed'}; "
                                    f'ORIGINAL DESTINATION PRESERVED AT "{backup_path}"'
                                ),
                            }
                        )
                    )
                    return 6

                raise Fail(
                    "io",
                    f"transaction failed ({swap_msg}); "
                    + (
                        f"bad candidate preserved at {failed_candidate_path}; original destination restored"
                        if backup_path and restored
                        else f"bad candidate preserved at {failed_candidate_path}"
                    ),
                )

            if backup_path:
                shutil.rmtree(backup, ignore_errors=True)

            print(
                json.dumps(
                    {
                        "success": True,
                        "dest": str(dst),
                        "files": len(new_set),
                        "receipt_generated": True,
                        "preserved": sorted(preserved),
                        "retired_removed": sorted(retired_removed),
                        "retired_preserved": sorted(retired_preserved),
                    }
                )
            )
            return 0

        except Fail as e:
            shutil.rmtree(stage, ignore_errors=True)
            print(json.dumps({"success": False, "code": e.code, "error": e.message}))
            return {
                "conflict": 3,
                "receipt": 4,
                "collision": 5,
                "io": 6,
                "lock": 7,
                "symlink": 7,
                "source": 4,
                "tree": 4,
            }.get(e.code, 7)

    finally:
        if lock_held:
            release_lock(lock_path)


def main(argv: list[str]) -> int:
    if len(argv) >= 3 and argv[1] == "gen-receipt":
        return cmd_gen_receipt(argv[2])
    if len(argv) >= 4 and argv[1] == "upgrade":
        return cmd_upgrade(argv[2], argv[3])
    sys.stderr.write(
        "usage: installer_helper.py gen-receipt <root> | upgrade <source_root> <dest_dir>\n"
    )
    return 7 if any(".." in a for a in argv) else 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except Fail as e:
        print(json.dumps({"success": False, "code": e.code, "error": e.message}))
        sys.exit(
            {
                "conflict": 3,
                "receipt": 4,
                "collision": 5,
                "io": 6,
                "lock": 7,
                "symlink": 7,
                "source": 4,
                "tree": 4,
            }.get(e.code, 7)
        )
    except OSError as e:
        print(json.dumps({"success": False, "code": "env", "error": str(e)}))
        sys.exit(7)
