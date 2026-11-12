#!/usr/bin/env bash
# tests/test_flow_doctor.sh - Behavioral contract test suite for flow doctor:
# registry discovery, flag filtering, schema invariants, tamper/symlink boundary detection,
# isolated HOME/environment, and valid JSON error envelopes without incidental prose pinning.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
RUN="$ROOT/skills/flow/runner/flow.sh"
PY="${FLOW_PYTHON:-python3}"

pass=0
fail=0

ck() {
  if [ "$1" = "$2" ]; then
    echo "  ok   [$3]"
    pass=$((pass + 1))
  else
    echo "  FAIL [$3] expected='$1' got='$2'"
    fail=$((fail + 1))
  fi
}

# Isolate HOME and user environment for all test runs with complete trap cleanup
TEST_HOME="$(mktemp -d)"
TMP_DIR=""
cleanup() { rm -rf "$TEST_HOME" "${TMP_DIR:-}"; }
trap cleanup EXIT
export HOME="$TEST_HOME"

echo "A) Registry discovery (--list)"
out="$(bash "$RUN" doctor --list 2>&1)"; rc=$?
ck 0 "$rc" "doctor --list exits 0"

# Verify structured registry output
out_json="$(bash "$RUN" doctor --list --json 2>/dev/null)"; rc=$?
ck 0 "$rc" "doctor --list --json exits 0"
is_valid_list="$("$PY" -c '
import sys, json
try:
    d = json.loads(sys.stdin.read())
    assert d.get("schema_version") == 1
    assert d.get("kind") == "doctor.list"
    checks = d.get("checks", [])
    names = [c["name"] for c in checks if "name" in c and "category" in c]
    assert len(names) == len(set(names)), "duplicate check names found"
    assert "os" in names and "bash" in names and "bundled_tree_integrity" in names
    print("VALID")
except Exception as e:
    print("INVALID: " + str(e))
' <<< "$out_json" 2>/dev/null || echo "FAIL")"
ck "VALID" "$is_valid_list" "doctor --list --json provides deduplicated registry with required checks"

echo "B) Incompatible flags rejection"
out="$(bash "$RUN" doctor --list --check os 2>&1)"; rc=$?
ck 1 "$rc" "doctor --list --check exits 1"

out="$(bash "$RUN" doctor --list --check os --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "doctor --list --check --json exits 1"
is_valid_err="$("$PY" -c '
import sys, json
try:
    d = json.loads(sys.stdin.read())
    assert d.get("schema_version") == 1
    assert d.get("healthy") is False
    assert d.get("summary", {}).get("total") == 1
    assert d.get("summary", {}).get("fail") == 1
    assert "error" in d and len(d["error"]) > 0
    print("VALID")
except Exception as e:
    print("INVALID: " + str(e))
' <<< "$out" 2>/dev/null || echo "FAIL")"
ck "VALID" "$is_valid_err" "incompatible flags emit valid error envelope"

echo "C) --check subset filtering and canonicalization"
out="$(bash "$RUN" doctor --check os,bash --json 2>/dev/null)"; rc=$?
ck 0 "$rc" "doctor --check os,bash exits 0"
ck_filter="$("$PY" -c '
import sys, json
d = json.loads(sys.stdin.read())
names = [c["name"] for c in d.get("checks", [])]
assert set(names) == {"os", "bash"}
print("FILTER_OK")
' <<< "$out" 2>/dev/null || echo "FAIL")"
ck "FILTER_OK" "$ck_filter" "only requested checks run"

# Whitespace and deduplication
out="$(bash "$RUN" doctor --check " os , bash , os " --json 2>/dev/null)"; rc=$?
ck 0 "$rc" "doctor --check with whitespace/dedupe exits 0"
ck_count="$("$PY" -c '
import sys, json
d = json.loads(sys.stdin.read())
print(len(d.get("checks", [])))
' <<< "$out" 2>/dev/null || echo 0)"
ck 2 "$ck_count" "whitespace and duplicates canonicalized to exactly 2 checks"

# Empty check input rejected
out="$(bash "$RUN" doctor --check "" 2>&1)"; rc=$?
ck 1 "$rc" "empty --check exits 1"

out="$(bash "$RUN" doctor --check " ,,, " 2>&1)"; rc=$?
ck 1 "$rc" "commas-only --check exits 1"

# Unknown check name rejected
out="$(bash "$RUN" doctor --check unknown_check_foo 2>&1)"; rc=$?
ck 1 "$rc" "unknown check name exits 1"

# Unknown check name with quotes under --json
out="$(bash "$RUN" doctor --check 'bad_name"' --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "unknown check with quotes under --json exits 1"
is_valid_quote_err="$("$PY" -c '
import sys, json
try:
    d = json.loads(sys.stdin.read())
    assert d.get("healthy") is False
    assert "bad_name\"" in d.get("error", "")
    print("VALID")
except Exception as e:
    print("INVALID: " + str(e))
' <<< "$out" 2>/dev/null || echo "FAIL")"
ck "VALID" "$is_valid_quote_err" "quoted unknown check name escapes cleanly into valid JSON envelope"

echo "D) JSON report summary agreement contract"
out="$(bash "$RUN" doctor --check os,bash,bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 0 "$rc" "subset doctor --json exits 0"
json_contract="$("$PY" -c '
import sys, json
try:
    d = json.loads(sys.stdin.read())
    assert d.get("schema_version") == 1
    assert d.get("kind") == "doctor.report"
    summary = d.get("summary", {})
    checks = d.get("checks", [])
    assert summary.get("total") == len(checks)
    assert summary.get("ok") + summary.get("warn") + summary.get("fail") + summary.get("skip") == summary.get("total")
    assert d.get("healthy") == (summary.get("fail") == 0)
    print("CONTRACT_OK")
except Exception as e:
    print("CONTRACT_FAIL: " + str(e))
' <<< "$out" 2>/dev/null || echo "FAIL")"
ck "CONTRACT_OK" "$json_contract" "doctor --json summary total agrees with checks length and health status"

echo "E) Bundled tree receipt verification scenarios"
TMP_DIR="$(mktemp -d)"
mkdir -p "$TMP_DIR/src"
cp -R "$ROOT/skills/flow/"* "$TMP_DIR/src/"
RUN_T="$TMP_DIR/src/runner/flow.sh"
rm -f "$TMP_DIR/src/manifest-hashes.json"

# E1. Dev checkout (no receipt) -> skipped
out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 0 "$rc" "no receipt exits 0"
ck_status="$("$PY" -c '
import sys, json
d = json.loads(sys.stdin.read())
print(d["checks"][0]["status"])
' <<< "$out" 2>/dev/null || echo "FAIL")"
ck "skip" "$ck_status" "absent receipt produces skip status"

# E2. Pristine synthetic install
HASH_RUNNER="$("$PY" -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$RUN_T")"
HASH_HELPER="$("$PY" -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$TMP_DIR/src/runner/doctor_helper.py")"
HASH_CARD="$("$PY" -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$TMP_DIR/src/_templates/card.md")"

cat <<EOF > "$TMP_DIR/src/manifest-hashes.json"
{
  "schema_version": 1,
  "files": {
    "runner/flow.sh": "$HASH_RUNNER",
    "runner/doctor_helper.py": "$HASH_HELPER",
    "_templates/card.md": "$HASH_CARD"
  }
}
EOF

out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 0 "$rc" "pristine receipt verification exits 0"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "ok" "$ck_status" "pristine receipt produces ok status"

# Extra unmanaged files in project are ignored
touch "$TMP_DIR/src/user_extra_file.txt"
out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 0 "$rc" "unmanaged user file does not cause failure"

# E3. Tampered file
echo "tampered" >> "$TMP_DIR/src/_templates/card.md"
out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "tampered file exits 1"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "fail" "$ck_status" "tampered file produces fail status"
git checkout "$TMP_DIR/src/_templates/card.md" 2>/dev/null || touch "$TMP_DIR/src/_templates/card.md"

# E4. Missing file
rm -f "$TMP_DIR/src/_templates/card.md"
out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "missing file exits 1"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "fail" "$ck_status" "missing file produces fail status"
touch "$TMP_DIR/src/_templates/card.md"

# E5. Malformed JSON
echo "not json" > "$TMP_DIR/src/manifest-hashes.json"
out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "malformed JSON receipt exits 1"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "fail" "$ck_status" "malformed JSON produces fail status"

# E6. Duplicate keys in receipt
cat <<EOF > "$TMP_DIR/src/manifest-hashes.json"
{
  "schema_version": 1,
  "files": {
    "runner/flow.sh": "$HASH_RUNNER",
    "runner/flow.sh": "$HASH_RUNNER"
  }
}
EOF
out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "duplicate keys in receipt exits 1"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "fail" "$ck_status" "duplicate keys produce fail status"

# E7. Invalid digest format (65 chars / newline)
cat <<EOF > "$TMP_DIR/src/manifest-hashes.json"
{
  "schema_version": 1,
  "files": {
    "runner/flow.sh": "${HASH_RUNNER}a"
  }
}
EOF
out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "invalid digest format exits 1"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "fail" "$ck_status" "invalid digest format produces fail status"

# E8. Path traversal in receipt
cat <<EOF > "$TMP_DIR/src/manifest-hashes.json"
{
  "schema_version": 1,
  "files": {
    "../../etc/passwd": "$HASH_RUNNER"
  }
}
EOF
out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "path traversal in receipt exits 1"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "fail" "$ck_status" "path traversal produces fail status"

# E9. Backslash in path
cat <<EOF > "$TMP_DIR/src/manifest-hashes.json"
{
  "schema_version": 1,
  "files": {
    "runner\\\\flow.sh": "$HASH_RUNNER"
  }
}
EOF
out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "backslash in path exits 1"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "fail" "$ck_status" "backslash in path produces fail status"

# E10. Ancestor symlink or leaf symlink
mkdir -p "$TMP_DIR/outside"
touch "$TMP_DIR/outside/ext.txt"
ln -s "$TMP_DIR/outside" "$TMP_DIR/src/sym_dir"
cat <<EOF > "$TMP_DIR/src/manifest-hashes.json"
{
  "schema_version": 1,
  "files": {
    "sym_dir/ext.txt": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  }
}
EOF
out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "ancestor symlink exits 1"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "fail" "$ck_status" "ancestor symlink produces fail status"

# E11. Manifest receipt itself is a symlink
rm -f "$TMP_DIR/src/manifest-hashes.json"
ln -s "$TMP_DIR/outside/ext.txt" "$TMP_DIR/src/manifest-hashes.json"
out="$(bash "$RUN_T" doctor --check bundled_tree_integrity --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "symlinked receipt file exits 1"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "fail" "$ck_status" "symlinked receipt file produces fail status"

rm -rf "$TMP_DIR"
echo "F) Bounded JSON and context-handoff directory integrity"
SB_DOC="$(mktemp -d)"
export FLOW_PROJECT_ROOT="$SB_DOC"
mkdir -p "$SB_DOC/flow"

# F1. Absent directory -> skip status, doctor exit 0
out="$(bash "$RUN" doctor --check bounded_json --json 2>/dev/null)"; rc=$?
ck 0 "$rc" "doctor --check bounded_json on absent directory exits 0"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "skip" "$ck_status" "absent context-handoff produces skip status"

# F2. Valid private directory (0700) + valid snapshot (0600) -> ok status, doctor exit 0
mkdir -p "$SB_DOC/.flow/context-handoff"
chmod 0700 "$SB_DOC/.flow/context-handoff"
printf '{"magic":"flow-compact-handoff/v1","project":"%s","status":"ok"}\n' "$SB_DOC" > "$SB_DOC/.flow/context-handoff/snapshot.json"
chmod 0600 "$SB_DOC/.flow/context-handoff/snapshot.json"
out="$(bash "$RUN" doctor --check bounded_json --json 2>/dev/null)"; rc=$?
ck 0 "$rc" "doctor --check bounded_json on valid directory exits 0"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "ok" "$ck_status" "valid context-handoff produces ok status"

# F3. Symlinked context-handoff directory -> fail status, doctor exit 1 (POSIX symlink check)
IS_WIN=0
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) IS_WIN=1 ;;
esac
if [ "$IS_WIN" -eq 0 ]; then
  rm -rf "$SB_DOC/.flow/context-handoff"
  mkdir -p "$SB_DOC/fake-handoff"
  ln -s "$SB_DOC/fake-handoff" "$SB_DOC/.flow/context-handoff"
  out="$(bash "$RUN" doctor --check bounded_json --json 2>/dev/null)"; rc=$?
  ck 1 "$rc" "doctor --check bounded_json on symlink directory exits 1"
  ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
  ck "fail" "$ck_status" "symlinked context-handoff produces fail status"

  # F4. Unsafe permissions (0777) on directory -> fail status, doctor exit 1
  rm -rf "$SB_DOC/.flow/context-handoff" "$SB_DOC/fake-handoff"
  mkdir -p "$SB_DOC/.flow/context-handoff"
  chmod 0777 "$SB_DOC/.flow/context-handoff"
  out="$(bash "$RUN" doctor --check bounded_json --json 2>/dev/null)"; rc=$?
  ck 1 "$rc" "doctor --check bounded_json on unsafe permissions exits 1"
  ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
  ck "fail" "$ck_status" "unsafe directory mode produces fail status"
else
  echo "  ok   [Windows/NT: symlink & POSIX mode tests skipped]"
  pass=$((pass + 4))
fi
# F5. Duplicate keys in snapshot.json -> fail status, doctor exit 1
chmod 0700 "$SB_DOC/.flow/context-handoff"
printf '{"magic":"flow-compact-handoff/v1","a":1,"a":2}\n' > "$SB_DOC/.flow/context-handoff/snapshot.json"
chmod 0600 "$SB_DOC/.flow/context-handoff/snapshot.json"
out="$(bash "$RUN" doctor --check bounded_json --json 2>/dev/null)"; rc=$?
ck 1 "$rc" "doctor --check bounded_json on duplicate JSON keys exits 1"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out")"
ck "fail" "$ck_status" "duplicate JSON keys produce fail status"

rm -rf "$SB_DOC"
unset FLOW_PROJECT_ROOT
echo "G) Privacy guard and scout bounds checks"
SB_G="$(mktemp -d)"
export FLOW_PROJECT_ROOT="$SB_G"
mkdir -p "$SB_G/flow"

# G1: privacy_guard on repo without unignored secrets -> ok
out_g1="$(bash "$RUN" doctor --check privacy_guard --json 2>/dev/null)"; rc_g1=$?
ck 0 "$rc_g1" "doctor --check privacy_guard on clean repo exits 0"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out_g1")"
ck "ok" "$ck_status" "clean repo produces ok status"

# G2: privacy_guard when an unignored .env is created -> warn
echo "SECRET=123" > "$SB_G/.env"
out_g2="$(bash "$RUN" doctor --check privacy_guard --json 2>/dev/null)"; rc_g2=$?
ck 0 "$rc_g2" "doctor --check privacy_guard with unignored .env exits 0 (warn is non-blocking)"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out_g2")"
ck "warn" "$ck_status" "unignored .env produces warn status"

# G3: privacy_guard when .env is covered by .gitignore -> ok
echo ".env" > "$SB_G/.gitignore"
out_g3="$(bash "$RUN" doctor --check privacy_guard --json 2>/dev/null)"; rc_g3=$?
ck 0 "$rc_g3" "doctor --check privacy_guard with ignored .env exits 0"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out_g3")"
ck "ok" "$ck_status" "ignored .env produces ok status"

# G4: privacy_guard with .env.example -> ok (safe template exempt)
rm -f "$SB_G/.env" "$SB_G/.gitignore"
echo "SECRET=example" > "$SB_G/.env.example"
echo "SAMPLE=1" > "$SB_G/.env.sample"
out_g4="$(bash "$RUN" doctor --check privacy_guard --json 2>/dev/null)"; rc_g4=$?
ck 0 "$rc_g4" "doctor --check privacy_guard with .env.example/.env.sample exits 0"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out_g4")"
ck "ok" "$ck_status" "safe templates produce ok status"

# G5: scout_bounds on clean repo -> ok
out_g5="$(bash "$RUN" doctor --check scout_bounds --json 2>/dev/null)"; rc_g5=$?
ck 0 "$rc_g5" "doctor --check scout_bounds on clean repo exits 0"
ck_status="$("$PY" -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["checks"][0]["status"])' <<< "$out_g5")"
ck "ok" "$ck_status" "clean repo produces ok scout_bounds status"

# G6: install_homes detects cursor target when ~/.cursor/skills/flow exists
FAKE_DOC_HOME="$(mktemp -d)"
mkdir -p "$FAKE_DOC_HOME/.cursor/skills/flow/runner"
touch "$FAKE_DOC_HOME/.cursor/skills/flow/runner/flow.sh"
out_g6="$(HOME="$FAKE_DOC_HOME" bash "$RUN" doctor --check install_homes --json 2>/dev/null)"; rc_g6=$?
ck 0 "$rc_g6" "doctor --check install_homes with fake cursor home exits 0"
case "$out_g6" in
  *"cursor ($FAKE_DOC_HOME/.cursor/skills/flow)"*) ck 0 0 "install_homes output includes cursor target" ;;
  *) ck 0 1 "install_homes output includes cursor target" ;;
esac
rm -rf "$FAKE_DOC_HOME"

# G7: project install homes are independent, additive, and exact (isolated HOME).
check_install_homes() {
  local expected_status="$1" expected_evidence="$2" label="$3" report rc parsed
  report="$(bash "$RUN" doctor --check install_homes --json 2>/dev/null)"; rc=$?
  ck 0 "$rc" "$label exits 0"
  parsed="$("$PY" -c '
import json, sys
d = json.load(sys.stdin)
assert d["kind"] == "doctor.report"
expected = {"name": "install_homes", "category": "install",
            "status": sys.argv[1], "evidence": sys.argv[2]}
if sys.argv[1] == "skip":
    expected["remedy"] = "install via npx @manhquy/flow-skill@latest --yes (or flow rules agent-skills for project scope)"
assert d["checks"] == [expected], d["checks"]
assert d["summary"] == {"total": 1, "ok": int(sys.argv[1] == "ok"),
                        "warn": 0, "fail": 0, "skip": int(sys.argv[1] == "skip")}
print("VALID")
' "$expected_status" "$expected_evidence" <<< "$report" 2>&1)"
  ck "VALID" "$parsed" "$label exact JSON status and evidence"
}
check_install_homes skip "none detected (local project or custom path)" "no user or project install"
human="$(bash "$RUN" doctor --check install_homes 2>&1)"
case "$human" in
  *"  install homes: none detected (local project or custom path)"$'\n'"  remedy: install via npx @manhquy/flow-skill@latest --yes (or flow rules agent-skills for project scope)"*) ck 0 0 "human remedy follows check line" ;;
  *) ck 0 1 "human remedy follows check line" ;;
esac
mkdir -p "$SB_G/.agents/skills/not-flow" "$SB_G/.agents/flow" "$SB_G/.claude/skills/not-flow"
check_install_homes skip "none detected (local project or custom path)" "near-miss project paths"
mkdir -p "$SB_G/.agents/skills/flow"
check_install_homes ok "project ($SB_G/.agents/skills/flow)" "project agents only"
rm -rf "$SB_G/.agents/skills/flow"
mkdir -p "$SB_G/.claude/skills/flow"
check_install_homes ok "project ($SB_G/.claude/skills/flow)" "project claude only"
mkdir -p "$SB_G/.agents/skills/flow"
check_install_homes ok "project ($SB_G/.claude/skills/flow), project ($SB_G/.agents/skills/flow)" "both project homes without precedence masking"
mkdir -p "$TEST_HOME/.agents/skills/flow"
check_install_homes ok "agents ($TEST_HOME/.agents/skills/flow), project ($SB_G/.claude/skills/flow), project ($SB_G/.agents/skills/flow)" "user and project homes without precedence masking"
rm -rf "$TEST_HOME/.agents/skills/flow"
rm -rf "$SB_G"
unset FLOW_PROJECT_ROOT

# Extract only the pure lookup function; do not source the runner dispatch or mock uname.
lookup_source="$("$PY" -c '
import pathlib, sys
s = pathlib.Path(sys.argv[1]).read_text()
start = s.index("doctor_remedy_for() {")
print(s[start:s.index("\n}\n", start) + 3])
' "$RUN")"
eval "$lookup_source"
ck 'brew install coreutils (provides gtimeout)' "$(doctor_remedy_for timeout Darwin)" "Darwin timeout remedy"
ck 'brew install grep' "$(doctor_remedy_for grep_p Darwin)" "Darwin grep remedy"
ck 'install via npx @manhquy/flow-skill@latest --yes (or flow rules agent-skills for project scope)' "$(doctor_remedy_for install_homes Linux)" "install homes remedy"
ck 'install working Python >=3.7 with stdlib sqlite3 (python.org or brew install python); replace old/Store-stub launchers' "$(doctor_remedy_for python Linux)" "missing Python remedy"
ck 'brew install sqlite' "$(doctor_remedy_for sqlite3 Darwin)" "Darwin sqlite remedy"
ck 'install sqlite3 via your package manager' "$(doctor_remedy_for sqlite3 Linux)" "other platform sqlite remedy"
ck '' "$(doctor_remedy_for timeout Linux)" "Linux timeout has no remedy"
ck '' "$(doctor_remedy_for os Darwin)" "unmapped check has no remedy"

transport="$(printf 'os\0environment\0ok\0Linux\0install_homes\0install\0skip\0none\0remedy:install advice\0python\0runtime\0warn\0missing\0remedy:python advice\0sqlite3\0runtime\0fail\0missing\0remedy:sqlite advice\0' | "$PY" "$ROOT/skills/flow/runner/doctor_helper.py" format-report 0)"
parsed="$("$PY" -c '
import json, sys
d = json.load(sys.stdin)
assert d["checks"][0] == {"name":"os", "category":"environment", "status":"ok", "evidence":"Linux"}
assert [c.get("remedy") for c in d["checks"]] == [None, "install advice", "python advice", "sqlite advice"]
assert d["summary"] == {"total":4, "ok":1, "warn":1, "skip":1, "fail":1}
assert d["healthy"] is False
print("VALID")
' <<< "$transport" 2>&1)"
ck VALID "$parsed" "mixed legacy and remedy records preserve summaries"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
