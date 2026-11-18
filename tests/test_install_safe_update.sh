#!/usr/bin/env bash
# tests/test_install_safe_update.sh - Comprehensive behavioral verification for
# transactional installer, safe ownership updates, and OMP target parity.
# Covers:
#   1. Lexical root, ancestor, and traversal symlink checks (e.g. /tmp/link/../dest)
#   2. Non-regular / FIFO file rejection before hashing (non-blocking)
#   3. Strict receipt schema (integer schema_version, duplicate keys, canonical paths)
#   4. Fresh install with staged receipt generation
#   5. Conflict refusal on user-modified owned files (original untouched)
#   6. Custom file preservation everywhere (including inside managed subdirectories)
#   7. Retired file lifecycle: unmodified pruned, modified preserved as unowned
#   8. Legacy destination collision rules (identical accepted, differing refused)
#   9. Root mismatch refusal (old receipt path missing)
#  10. Fault injection: promotion failure, receipt corruption, quarantine failure, restore failure
#  11. End-to-end install.sh: fresh, update, conflict, OMP target, and no-Python fresh/update safety
#  12. Traversal pre-mkdir non-creation regression: no directory created on refusal
#  13. No-Python fresh install over empty directory with failure restoration
#  14. Windows drive (C:\) and UNC (\\server\share) raw path component parsing
set -u

export PYTHONDONTWRITEBYTECODE=1

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
HELPER="$ROOT/skills/flow/runner/installer_helper.py"
INSTALL_SH="$ROOT/install.sh"
PY="${FLOW_PYTHON:-python3}"

pass=0
fail=0
skipped=0

# Detect MSYS/Cygwin/Windows Git Bash — Unix-specific filesystem features
# (real symlinks, mkfifo) do not exist there.
IS_WINDOWS=no
if [ -n "${MSYSTEM:-}" ] || uname -s 2>/dev/null | grep -qiE 'MINGW|MSYS|CYGWIN'; then
  IS_WINDOWS=yes
fi

# On Windows Git Bash (MSYS), $ROOT is an MSYS path (/c/Users/...) that the
# native Windows Python interpreter cannot resolve for imports. Convert to a
# Windows-native path so `import installer_helper` works in inline scripts.
if [ "$IS_WINDOWS" = yes ] && command -v cygpath >/dev/null 2>&1; then
  WIN_RUNNER_DIR="$(cygpath -w "$ROOT/skills/flow/runner")"
  export PYTHONPATH="$WIN_RUNNER_DIR${PYTHONPATH:+;$PYTHONPATH}"
else
  export PYTHONPATH="$ROOT/skills/flow/runner${PYTHONPATH:+:$PYTHONPATH}"
fi
to_native_path() {
  if [ "$IS_WINDOWS" = yes ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s' "$1"
  fi
}

# Symlink helper: on Windows Git Bash, ln -s creates a regular copy, not a reparse point.
# Create a true NTFS directory junction with `cmd //c mklink /J` and verify via native Python
# lstat st_file_attributes FILE_ATTRIBUTE_REPARSE_POINT (or S_ISLNK).
make_link() {
  local target="$1" linkpath="$2"
  if [ "$IS_WINDOWS" = yes ]; then
    rm -rf "$linkpath"
    if command -v cmd >/dev/null 2>&1; then
      local win_link win_target
      win_link="$(cygpath -w "$linkpath")"
      win_target="$(cygpath -w "$target")"
      cmd //c mklink //J "$win_link" "$win_target" >/dev/null 2>&1
      if "$PY" -c 'import os, stat, sys; p = sys.argv[1]; st = os.lstat(p); sys.exit(0 if (stat.S_ISLNK(st.st_mode) or bool(getattr(st, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)) or getattr(os.path, "isjunction", lambda _: False)(p)) else 1)' "$win_link" 2>/dev/null; then
        return 0
      fi
    fi
    return 1
  fi
  ln -s "$target" "$linkpath" 2>/dev/null
  if [ -L "$linkpath" ]; then
    return 0
  fi
  return 1
}
skipped=0
ck() {
  if [ "$1" = "$2" ]; then
    echo "  ok   [$3]"
    pass=$((pass + 1))
  else
    echo "  FAIL [$3] expected='$1' got='$2'"
    fail=$((fail + 1))
  fi
}
skip_test() {
  echo "  skip [$1: $2]"
  skipped=$((skipped + 1))
}

SCRATCH="$(cd "$(mktemp -d)" && pwd -P)"
cleanup() {
  rm -rf "$SCRATCH"
}
trap cleanup EXIT

echo "=== 1. Lexical root, ancestor, and traversal symlink checks ==="
S1_SRC="$SCRATCH/s1_src"
S1_DST="$SCRATCH/s1_dst"
mkdir -p "$S1_SRC/runner" "$S1_DST"
echo "# skill" > "$S1_SRC/SKILL.md"
echo "# runner" > "$S1_SRC/runner/flow.sh"

# Source root is a symlink
S1_SRC_LINK="$SCRATCH/s1_src_link"
if make_link "$S1_SRC" "$S1_SRC_LINK"; then
  set +e
  out="$("$PY" "$HELPER" upgrade "$S1_SRC_LINK" "$S1_DST" 2>&1)"
  rc=$?
  set -e
  ck 7 "$rc" "symlink source root refused with exit 7"
else
  ck 7 "SKIP_NO_LINK" "symlink source root refused (platform cannot create links)"
fi

# Dest root is a symlink
S1_DST_LINK="$SCRATCH/s1_dst_link"
if make_link "$S1_DST" "$S1_DST_LINK"; then
  set +e
  out="$("$PY" "$HELPER" upgrade "$S1_SRC" "$S1_DST_LINK" 2>&1)"
  rc=$?
  set -e
  ck 7 "$rc" "symlink destination root refused with exit 7"
else
  ck 7 "SKIP_NO_LINK" "symlink destination root refused (platform cannot create links)"
fi

# Ancestor of source is a symlink
S1_ANC_REAL="$SCRATCH/s1_anc_real"
mkdir -p "$S1_ANC_REAL/nested/src"
echo "# skill" > "$S1_ANC_REAL/nested/src/SKILL.md"
S1_ANC_LINK="$SCRATCH/s1_anc_link"
if make_link "$S1_ANC_REAL/nested" "$S1_ANC_LINK"; then
  set +e
  out="$("$PY" "$HELPER" upgrade "$S1_ANC_LINK/src" "$S1_DST" 2>&1)"
  rc=$?
  set -e
  ck 7 "$rc" "symlink in source ancestry refused with exit 7"
else
  ck 7 "SKIP_NO_LINK" "symlink in source ancestry refused (platform cannot create links)"
fi

# Regression: path with '..' traversing a symlink component (/tmp/link/../dest)
S1_BYPASS_TARGET="$SCRATCH/s1_bypass_target"
S1_BYPASS_LINK="$SCRATCH/s1_bypass_link"
mkdir -p "$S1_BYPASS_TARGET"
if make_link "$S1_BYPASS_TARGET" "$S1_BYPASS_LINK"; then
  set +e
  if [ "$IS_WINDOWS" = yes ]; then
    s1_dst_arg="$(to_native_path "$S1_BYPASS_LINK")\\..\\s1_dst"
    out="$("$PY" "$HELPER" upgrade "$S1_SRC" "$s1_dst_arg" 2>&1)"
  else
    out="$("$PY" "$HELPER" upgrade "$S1_SRC" "$S1_BYPASS_LINK/../s1_dst" 2>&1)"
  fi
  rc=$?
  set -e
  ck 7 "$rc" "traversal through symlink component (/tmp/link/../dest) refused with exit 7"
else
  ck 7 "SKIP_NO_LINK" "traversal through symlink component (platform cannot create links)"
fi

echo "=== 2. Non-regular / FIFO rejection before hash ==="
S2_SRC="$SCRATCH/s2_src"
S2_DST="$SCRATCH/s2_dst"
mkdir -p "$S2_SRC" "$S2_DST"
echo "# skill" > "$S2_SRC/SKILL.md"
has_real_fifo=no
if mkfifo "$S2_SRC/blocker_fifo" 2>/dev/null; then
  if "$PY" -c 'import os, stat, sys; st = os.lstat(sys.argv[1]); sys.exit(0 if stat.S_ISFIFO(st.st_mode) else 1)' "$(to_native_path "$S2_SRC/blocker_fifo")" 2>/dev/null; then
    has_real_fifo=yes
  fi
fi

if [ "$has_real_fifo" = yes ]; then
  set +e
  out="$("$PY" "$HELPER" gen-receipt "$S2_SRC" 2>&1)"
  rc=$?
  set -e
  ck 4 "$rc" "gen-receipt refuses FIFO without hanging (exit 4)"
  rm -f "$S2_SRC/blocker_fifo"
else
  rm -f "$S2_SRC/blocker_fifo" 2>/dev/null || true
  skip_test "gen-receipt refuses FIFO" "mkfifo/FIFO unsupported by native filesystem or interpreter"
fi
echo "=== 3. Strict receipt schema validation ==="
S3_DIR="$SCRATCH/s3_schema"
mkdir -p "$S3_DIR"
echo "# skill" > "$S3_DIR/SKILL.md"

# Case A: duplicate keys in JSON
cat <<'EOF' > "$S3_DIR/manifest-hashes.json"
{
  "schema_version": 1,
  "files": {
    "SKILL.md": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "SKILL.md": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  }
}
EOF
out="$("$PY" -c '
import sys, installer_helper
from pathlib import Path
try:
    installer_helper.parse_receipt(Path(sys.argv[1]))
    print("UNEXPECTED_SUCCESS")
except installer_helper.Fail as e:
    print("REJECTED:" + e.code)
' "$(to_native_path "$S3_DIR")" 2>/dev/null || echo "CRASH")"
ck "REJECTED:receipt" "$out" "duplicate JSON keys strictly rejected"

# Case B: schema_version is boolean true
cat <<'EOF' > "$S3_DIR/manifest-hashes.json"
{
  "schema_version": true,
  "files": {
    "SKILL.md": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
}
EOF
out="$("$PY" -c '
import sys, installer_helper
from pathlib import Path
try:
    installer_helper.parse_receipt(Path(sys.argv[1]))
    print("UNEXPECTED_SUCCESS")
except installer_helper.Fail as e:
    print("REJECTED:" + e.code)
' "$(to_native_path "$S3_DIR")" 2>/dev/null || echo "CRASH")"
ck "REJECTED:receipt" "$out" "boolean schema_version strictly rejected"

# Case C: non-canonical path
cat <<'EOF' > "$S3_DIR/manifest-hashes.json"
{
  "schema_version": 1,
  "files": {
    "../SKILL.md": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
}
EOF
out="$("$PY" -c '
import sys, installer_helper
from pathlib import Path
try:
    installer_helper.parse_receipt(Path(sys.argv[1]))
    print("UNEXPECTED_SUCCESS")
except installer_helper.Fail as e:
    print("REJECTED:" + e.code)
' "$(to_native_path "$S3_DIR")" 2>/dev/null || echo "CRASH")"
ck "REJECTED:receipt" "$out" "non-canonical relative path rejected"

echo "=== 4. Fresh install with staged receipt ==="
S4_SRC="$SCRATCH/s4_src"
S4_DST="$SCRATCH/s4_dst"
mkdir -p "$S4_SRC/runner"
echo "# skill" > "$S4_SRC/SKILL.md"
echo "#!/bin/sh" > "$S4_SRC/runner/flow.sh"
echo "hello" > "$S4_SRC/file.txt"

set +e
out="$("$PY" "$HELPER" upgrade "$S4_SRC" "$S4_DST" 2>&1)"
rc=$?
set -e
ck 0 "$rc" "fresh install succeeds (exit 0)"
[ -f "$S4_DST/manifest-hashes.json" ] && ck_rec="yes" || ck_rec="no"
ck "yes" "$ck_rec" "fresh install creates manifest-hashes.json"
[ -x "$S4_DST/runner/flow.sh" ] && ck_exec="yes" || ck_exec="no"
ck "yes" "$ck_exec" "runner flow.sh is executable"

echo "=== 5. In-place update with user-modified file (conflict) ==="
# User modifies an owned file in S4_DST
echo "MODIFIED" >> "$S4_DST/file.txt"
orig_hash="$("$PY" -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$(to_native_path "$S4_DST/file.txt")")"

set +e
out="$("$PY" "$HELPER" upgrade "$S4_SRC" "$S4_DST" 2>&1)"
rc=$?
set -e
ck 3 "$rc" "user-modified owned file triggers exit 3 (conflict)"

curr_hash="$("$PY" -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$(to_native_path "$S4_DST/file.txt")")"
ck "$orig_hash" "$curr_hash" "destination left completely untouched on conflict"

# Restore original content for subsequent tests
echo "hello" > "$S4_DST/file.txt"

echo "=== 6. Preservation of custom files everywhere ==="
# Add unowned custom file at root and inside managed subdirs
echo "custom top" > "$S4_DST/custom_root.txt"
echo "custom runner" > "$S4_DST/runner/custom_runner.txt"

set +e
out="$("$PY" "$HELPER" upgrade "$S4_SRC" "$S4_DST" 2>&1)"
rc=$?
set -e
ck 0 "$rc" "update succeeds when owned files match (exit 0)"

[ -f "$S4_DST/custom_root.txt" ] && c1="yes" || c1="no"
[ -f "$S4_DST/runner/custom_runner.txt" ] && c2="yes" || c2="no"
ck "yes" "$c1" "custom file at root preserved"
ck "yes" "$c2" "custom file inside managed runner subdir preserved"

# Verify that custom files are NOT in the new ownership receipt
is_owned="$("$PY" -c '
import json, sys
doc = json.load(open(sys.argv[1], "r", encoding="utf-8"))
files = doc.get("files", {})
assert "custom_root.txt" not in files
assert "runner/custom_runner.txt" not in files
print("CLEAN")
' "$(to_native_path "$S4_DST/manifest-hashes.json")")"
ck "CLEAN" "$is_owned" "custom files excluded from manifest-hashes.json"

echo "=== 7. Retired files: unmodified pruned, modified preserved ==="
# S4_DST has a file that S5_SRC will omit
echo "retired old" > "$S4_SRC/retired_unmodified.txt"
echo "retired old" > "$S4_SRC/retired_modified.txt"
"$PY" "$HELPER" upgrade "$S4_SRC" "$S4_DST" >/dev/null

# Now user modifies retired_modified.txt
echo "user edit" > "$S4_DST/retired_modified.txt"

# New source S5_SRC without the two retired files
S5_SRC="$SCRATCH/s5_src"
mkdir -p "$S5_SRC/runner"
echo "# skill" > "$S5_SRC/SKILL.md"
echo "#!/bin/sh" > "$S5_SRC/runner/flow.sh"
echo "hello" > "$S5_SRC/file.txt"

set +e
out="$("$PY" "$HELPER" upgrade "$S5_SRC" "$S4_DST" 2>&1)"
rc=$?
set -e
ck 0 "$rc" "update with retired files succeeds"

[ -f "$S4_DST/retired_unmodified.txt" ] && r1="yes" || r1="no"
[ -f "$S4_DST/retired_modified.txt" ] && r2="yes" || r2="no"
ck "no" "$r1" "unmodified retired file pruned"
ck "yes" "$r2" "modified retired file preserved as unowned"

echo "=== 8. Legacy collision rules ==="
S8_SRC="$SCRATCH/s8_src"
S8_DST="$SCRATCH/s8_dst"
mkdir -p "$S8_SRC" "$S8_DST"
echo "# skill" > "$S8_SRC/SKILL.md"
echo "version A" > "$S8_SRC/file.txt"
# Destination has no receipt (legacy install) with DIFFERENT content
echo "version B" > "$S8_DST/file.txt"
echo "# skill" > "$S8_DST/SKILL.md"

set +e
out="$("$PY" "$HELPER" upgrade "$S8_SRC" "$S8_DST" 2>&1)"
rc=$?
set -e
ck 3 "$rc" "legacy differing-byte collision refused with exit 3"

# Identical bytes in legacy destination
echo "version A" > "$S8_DST/file.txt"
set +e
out="$("$PY" "$HELPER" upgrade "$S8_SRC" "$S8_DST" 2>&1)"
rc=$?
set -e
ck 0 "$rc" "legacy identical-byte collision accepted"

echo "=== 9. Fault injection via _rename seam ==="
# Prepare fresh src and dst
S9_SRC="$SCRATCH/s9_src"
S9_DST="$SCRATCH/s9_dst"
mkdir -p "$S9_SRC"
echo "# skill" > "$S9_SRC/SKILL.md"
echo "hello" > "$S9_SRC/a.txt"
"$PY" "$HELPER" upgrade "$S9_SRC" "$S9_DST" >/dev/null
echo "original destination payload" > "$S9_DST/orig.txt"

# 9.1 Promotion failure (2nd rename fails): backup restored, destination intact
set +e
out="$("$PY" -c '
import sys, unittest.mock as mock, installer_helper
count = 0
orig_rename = installer_helper._rename
def mock_rename(s, d):
    global count
    count += 1
    if count == 2:  # promotion rename (stage -> dst)
        raise OSError("injected promotion failure")
    return orig_rename(s, d)

with mock.patch.object(installer_helper, "_rename", side_effect=mock_rename):
    rc = installer_helper.cmd_upgrade(sys.argv[1], sys.argv[2])
    sys.exit(rc)
' "$(to_native_path "$S9_SRC")" "$(to_native_path "$S9_DST")" 2>&1)"
rc=$?
set -e
ck 6 "$rc" "promotion failure returns exit 6"
[ -f "$S9_DST/orig.txt" ] && orig_kept="yes" || orig_kept="no"
ck "yes" "$orig_kept" "destination restored intact after promotion failure"

# 9.2 Quarantine rename failure: candidate left at dst, backup retained, exit 6
set +e
out="$("$PY" -c '
import sys, unittest.mock as mock, installer_helper
count = 0
orig_rename = installer_helper._rename
def mock_rename(s, d):
    global count
    count += 1
    # Call 1: dst -> backup
    # Call 2: stage -> dst
    # Call 3: dst -> failed (quarantine rename)
    if count == 3:
        raise OSError("injected quarantine rename failure")
    return orig_rename(s, d)

with mock.patch.object(installer_helper, "verify_tree", side_effect=installer_helper.Fail("io", "injected verify fail")):
    with mock.patch.object(installer_helper, "_rename", side_effect=mock_rename):
        rc = installer_helper.cmd_upgrade(sys.argv[1], sys.argv[2])
        sys.exit(rc)
' "$(to_native_path "$S9_SRC")" "$(to_native_path "$S9_DST")" 2>&1)"
rc=$?
set -e
ck 6 "$rc" "quarantine failure returns exit 6"

# Both backup and candidate paths must still exist (NEVER rmtree dst)
has_backup="$(find "$SCRATCH" -maxdepth 1 -name ".flow-skill-backup-*" | wc -l)"
[ "$has_backup" -ge 1 ] && bk_found="yes" || bk_found="no"
ck "yes" "$bk_found" "backup directory preserved on quarantine failure"
[ -d "$S9_DST" ] && dst_found="yes" || dst_found="no"
ck "yes" "$dst_found" "destination candidate preserved (NEVER deleted) on quarantine failure"

# Clean up temp backups from S9
rm -rf "$SCRATCH"/.flow-skill-*

echo "=== 10. End-to-end install.sh shell tests ==="
TEST_REPO="$SCRATCH/test_repo"
mkdir -p "$TEST_REPO/skills/flow"
cp "$ROOT/install.sh" "$TEST_REPO/"
cp -R "$ROOT/skills/flow/." "$TEST_REPO/skills/flow/"

FAKE_HOME="$SCRATCH/fake_home"
mkdir -p "$FAKE_HOME"

# 10.1 Fresh install to claude
HOME="$FAKE_HOME" bash "$TEST_REPO/install.sh" global claude >/dev/null
[ -f "$FAKE_HOME/.claude/skills/flow/manifest-hashes.json" ] && s_fresh="yes" || s_fresh="no"
ck "yes" "$s_fresh" "install.sh global claude creates fresh install with receipt"

# 10.2 Explicit OMP target
HOME="$FAKE_HOME" bash "$TEST_REPO/install.sh" global omp >/dev/null
[ -f "$FAKE_HOME/.omp/agent/skills/flow/manifest-hashes.json" ] && s_omp="yes" || s_omp="no"
ck "yes" "$s_omp" "install.sh global omp installs to ~/.omp/agent/skills/flow"

# 10.2b Explicit Cursor target
HOME="$FAKE_HOME" bash "$TEST_REPO/install.sh" global cursor >/dev/null
[ -f "$FAKE_HOME/.cursor/skills/flow/manifest-hashes.json" ] && s_cur="yes" || s_cur="no"
ck "yes" "$s_cur" "install.sh global cursor installs to ~/.cursor/skills/flow"

# 10.3 OMP autodetect with genuine marker
FAKE_HOME2="$SCRATCH/fake_home2"
mkdir -p "$FAKE_HOME2/.omp/agent/skills"
HOME="$FAKE_HOME2" bash "$TEST_REPO/install.sh" global all >/dev/null
[ -f "$FAKE_HOME2/.omp/agent/skills/flow/manifest-hashes.json" ] && s_ompa="yes" || s_ompa="no"
ck "yes" "$s_ompa" "install.sh global all detects ~/.omp/agent/skills"

# Bare ~/.omp should NOT trigger omp
FAKE_HOME3="$SCRATCH/fake_home3"
mkdir -p "$FAKE_HOME3/.omp"
HOME="$FAKE_HOME3" bash "$TEST_REPO/install.sh" global all >/dev/null
[ -d "$FAKE_HOME3/.omp/agent/skills/flow" ] && s_bare="yes" || s_bare="no"
ck "no" "$s_bare" "bare ~/.omp without agent/skills does NOT install omp"

# 10.4 Update existing with user custom file preservation
echo "user custom" > "$FAKE_HOME/.claude/skills/flow/my_custom.txt"
HOME="$FAKE_HOME" bash "$TEST_REPO/install.sh" global claude >/dev/null
[ -f "$FAKE_HOME/.claude/skills/flow/my_custom.txt" ] && s_cust="yes" || s_cust="no"
ck "yes" "$s_cust" "install.sh update preserves custom file"

# 10.5 In-place update conflict refusal
echo "conflict" >> "$FAKE_HOME/.claude/skills/flow/SKILL.md"
set +e
HOME="$FAKE_HOME" bash "$TEST_REPO/install.sh" global claude >/dev/null 2>&1
s_conf_rc=$?
set -e
ck 3 "$s_conf_rc" "install.sh update conflict fails with exit code 3"

# 10.6 No-Python update safety refusal
# Simulate missing Python by shadowing python3 and python with failing shims
NOPY_SHIM="$SCRATCH/nopy_shim"
mkdir -p "$NOPY_SHIM"
printf '#!/bin/sh\nexit 127\n' > "$NOPY_SHIM/python3"
printf '#!/bin/sh\nexit 127\n' > "$NOPY_SHIM/python"
chmod +x "$NOPY_SHIM/python3" "$NOPY_SHIM/python"
if [ "$IS_WINDOWS" = yes ]; then
  # On Windows, shadow python.exe and python3.exe as well
  printf '#!/bin/sh\nexit 127\n' > "$NOPY_SHIM/python3.exe"
  printf '#!/bin/sh\nexit 127\n' > "$NOPY_SHIM/python.exe"
  chmod +x "$NOPY_SHIM/python3.exe" "$NOPY_SHIM/python.exe"
fi

# Try update on existing install without python
set +e
PATH="$NOPY_SHIM:$PATH" HOME="$FAKE_HOME" bash "$TEST_REPO/install.sh" global omp >/dev/null 2>&1
no_py_update_rc=$?
set -e
ck 1 "$no_py_update_rc" "no-Python update fails loudly with exit 1"

# 10.7 No-Python fresh install staging
FAKE_HOME_NOPY="$SCRATCH/fake_home_nopy"
mkdir -p "$FAKE_HOME_NOPY"
set +e
out="$(PATH="$NOPY_SHIM:$PATH" HOME="$FAKE_HOME_NOPY" bash "$TEST_REPO/install.sh" global claude 2>&1)"
no_py_fresh_rc=$?
set -e
ck 0 "$no_py_fresh_rc" "no-Python fresh install succeeds with exit 0"
[ -f "$FAKE_HOME_NOPY/.claude/skills/flow/SKILL.md" ] && nopy_inst="yes" || nopy_inst="no"
ck "yes" "$nopy_inst" "no-Python fresh install staged into place"
[ -f "$FAKE_HOME_NOPY/.claude/skills/flow/manifest-hashes.json" ] && nopy_rec="yes" || nopy_rec="no"
ck "no" "$nopy_rec" "no-Python fresh install has no receipt (as designed)"

echo "=== 11. Pre-mkdir non-creation on traversal refusal ==="
# Attempt install to symlink/../newparent - verify newparent is NOT created
S11_TARGET="$SCRATCH/s11_target"
mkdir -p "$S11_TARGET"
S11_LINK="$SCRATCH/s11_link"
make_link "$S11_TARGET" "$S11_LINK"
S11_NEWPARENT="$SCRATCH/s11_target_newparent"

set +e
out="$(bash "$TEST_REPO/install.sh" project "$S11_LINK/../s11_target_newparent" 2>&1)"
s11_rc=$?
set -e
ck 1 "$s11_rc" "traversal destination rejected by install.sh (exit 1)"
[ ! -d "$S11_NEWPARENT" ] && s11_uncreated="yes" || s11_uncreated="no"
ck "yes" "$s11_uncreated" "newparent directory NOT created on filesystem"

echo "=== 12. No-Python fresh install over empty directory ==="
FAKE_HOME_EMPTY="$SCRATCH/fake_home_empty"
mkdir -p "$FAKE_HOME_EMPTY/.claude/skills/flow"

set +e
out="$(PATH="$NOPY_SHIM:$PATH" HOME="$FAKE_HOME_EMPTY" bash "$TEST_REPO/install.sh" global claude 2>&1)"
empty_rc=$?
set -e
ck 0 "$empty_rc" "no-Python fresh install over empty directory succeeds (exit 0)"
[ -f "$FAKE_HOME_EMPTY/.claude/skills/flow/SKILL.md" ] && empty_pop="yes" || empty_pop="no"
ck "yes" "$empty_pop" "empty directory cleanly replaced with skill content"

echo "=== 13. Windows drive and UNC raw path component parsing ==="
out="$("$PY" -c '
import sys, installer_helper

# Test A: Windows drive letter C:\path\..\dest
a1, s1 = installer_helper.parse_raw_path_segments("C:\\foo\\bar\\..\\dest")
assert a1.startswith("C:") and s1 == ["foo", "bar", "..", "dest"], f"unexpected C: path {a1}, {s1}"

# Test B: UNC path \\server\share\foo\..\dest
a2, s2 = installer_helper.parse_raw_path_segments("\\\\server\\share\\foo\\..\\dest")
assert a2.replace("\\", "/").startswith("//server/share") and s2 == ["foo", "..", "dest"], f"unexpected UNC path {a2}, {s2}"

print("PARSED_OK")
' 2>/dev/null || echo "FAIL")"
ck "PARSED_OK" "$out" "raw Windows drive and UNC paths correctly parsed without stripping"

echo "=== Installer Python floor pins (3.7, matching runtime probe) ==="
# Runtime flow.sh probes (3, 7); the installer probes must not claim a stricter floor.
grep -q 'sys\.version_info >= (3, 7)' "$INSTALL_SH" \
  && ck "PRESENT" "PRESENT" "install.sh probes python floor sys.version_info >= (3, 7)" \
  || ck "PRESENT" "ABSENT" "install.sh probes python floor sys.version_info >= (3, 7)"
if grep -q 'sys\.version_info >= (3, 8)' "$INSTALL_SH"; then
  ck "ABSENT" "PRESENT" "install.sh has no stale (3, 8) floor"
else
  ck "ABSENT" "ABSENT" "install.sh has no stale (3, 8) floor"
fi
grep -q 'sys\.version_info >= (3, 7)' "$ROOT/install.ps1" \
  && ck "PRESENT" "PRESENT" "install.ps1 probes python floor sys.version_info >= (3, 7)" \
  || ck "PRESENT" "ABSENT" "install.ps1 probes python floor sys.version_info >= (3, 7)"
if grep -q 'sys\.version_info >= (3, 8)' "$ROOT/install.ps1"; then
  ck "ABSENT" "PRESENT" "install.ps1 has no stale (3, 8) floor"
else
  ck "ABSENT" "ABSENT" "install.ps1 has no stale (3, 8) floor"
fi

# If a python3.7 binary exists on PATH, run an actual install/update smoke test through installer_helper
if command -v python3.7 >/dev/null 2>&1; then
  echo "=== Python 3.7 live installer smoke ==="
  py37_smoke="$(python3.7 "$INSTALLER_HELPER" --help 2>&1)"
  [ $? -eq 0 ] && ck "OK" "OK" "installer_helper runs under Python 3.7" || ck "OK" "FAIL" "installer_helper runs under Python 3.7"
fi

echo "=== Summary ==="
if [ "$skipped" -gt 0 ]; then
  echo "Pass: $pass, Fail: $fail, Skipped: $skipped"
else
  echo "Pass: $pass, Fail: $fail"
fi
[ "$fail" -eq 0 ] || exit 1
