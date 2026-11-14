#!/usr/bin/env bash
# Tests for flow resume --card C-NNN --json handoff envelope (card.handoff/v1).
# Verifies:
#   1. Argument parsing: --card C-NNN --json and --json --card C-NNN in any order
#   2. Single line valid JSON output conforming to closed card.handoff/v1 schema
#   3. Correct fields: schema_version, kind, card_id, title, status, scope,
#      allowed_files, verify_commands, linked_decisions, git_baseline, risk
#   4. Secret redaction in scope, verify_commands, allowed_files
#   5. Exact prose output preserved when --json is omitted
#   6. Project-level resume --json (flow_context/v1) preserved
#   7. Done cards emit valid card.handoff JSON with status: done
#   8. Non-existent cards exit 1
#   9. Invalid card IDs exit 2
# Run: bash tests/test_flow_card_handoff_json.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
RUN="$ROOT/skills/flow/runner/flow.sh"
unset FLOW_HARNESS_DISABLE
export FLOW_LOG_DISABLE=1
py="$(command -v python3 2>/dev/null || command -v python 2>/dev/null)"

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

SB=""
clean() {
  if [ -n "$SB" ] && [ -d "$SB" ]; then
    rm -rf "$SB"
  fi
}
trap clean EXIT

newsb() {
  clean
  SB="$(mktemp -d)"
  export FLOW_PROJECT_ROOT="$SB"
  mkdir -p "$SB/flow" "$SB/cards"
}

echo "=== 1. Basic active card handoff JSON schema & fields ==="
newsb
cat << 'EOC' > "$SB/cards/C-001.md"
# C-001 — Add debt-simplification nudge to the household expense app

status: in_progress
deps: none
implements: FR3
risk: standard
risk-reason: non-security

## Scope

Compute minimum set with API_KEY=secret_api_key_12345.

## Allowed files

src/balance/simplify.ts, src/balance/simplify.test.ts

## Verify (run these before calling the card done)

- [x] npm test src/balance/simplify.test.ts
- [ ] curl AKIA1234567890ABCDEF

## Done-evidence
live

## Evidence
none
EOC

out1="$(bash "$RUN" resume --card C-001 --json 2>&1)"; rc1=$?
ck 0 "$rc1" "resume --card C-001 --json exits 0"
ck 1 "$(printf '%s\n' "$out1" | wc -l | tr -d ' ')" "resume --card C-001 --json emits exactly 1 line"

py_check1="$("$py" -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
    assert d["schema_version"] == 1, "bad schema_version"
    assert d["kind"] == "card.handoff", "bad kind"
    assert d["card_id"] == "C-001", "bad card_id"
    assert d["title"] == "Add debt-simplification nudge to the household expense app", "bad title"
    assert d["status"] == "in_progress", "bad status"
    assert "[REDACTED:credential]" in d["scope"], "secret in scope not redacted"
    assert "secret_api_key_12345" not in d["scope"], "raw secret leaked in scope"
    assert d["allowed_files"] == ["src/balance/simplify.ts", "src/balance/simplify.test.ts"], "bad allowed_files"
    assert len(d["verify_commands"]) == 2, "bad verify_commands count"
    assert d["verify_commands"][0] == "npm test src/balance/simplify.test.ts", "bad verify 0"
    assert "[REDACTED:aws-key-id]" in d["verify_commands"][1], "secret in verify not redacted"
    assert "AKIA1234567890ABCDEF" not in d["verify_commands"][1], "raw secret leaked in verify"
    assert isinstance(d["linked_decisions"], list), "linked_decisions not list"
    assert isinstance(d["git_baseline"], dict), "git_baseline not dict"
    assert "commit" in d["git_baseline"], "git_baseline missing commit"
    assert isinstance(d["git_baseline"]["clean"], bool), "git_baseline clean not bool"
    assert d["risk"] == "standard", "bad risk"
    print("PASS")
except Exception as e:
    print(f"FAIL: {e}")
' "$out1")"
ck "PASS" "$py_check1" "python validation of card.handoff/v1 schema on C-001"

echo "=== 2. Argument order independence: --json before --card and --card= form ==="
out2="$(bash "$RUN" resume --json --card C-001 2>&1)"; rc2=$?
ck 0 "$rc2" "resume --json --card C-001 exits 0"
ck "$out1" "$out2" "resume --json --card C-001 produces identical output to --card C-001 --json"

out3="$(bash "$RUN" resume --card=C-001 --json 2>&1)"; rc3=$?
ck 0 "$rc3" "resume --card=C-001 --json exits 0"
ck "$out1" "$out3" "resume --card=C-001 --json produces identical output"

out4="$(bash "$RUN" resume --json --card=C-001 2>&1)"; rc4=$?
ck 0 "$rc4" "resume --json --card=C-001 exits 0"
ck "$out1" "$out4" "resume --json --card=C-001 produces identical output"

echo "=== 3. Done card handling in JSON mode ==="
cat << 'EOC' > "$SB/cards/C-002.md"
# C-002: Completed card task

status: done
deps: none
implements: none
risk: security-class

## Scope
Completed work.

## Allowed files
none

## Verify
- [x] npm test
EOC

out_done_json="$(bash "$RUN" resume --card C-002 --json 2>&1)"; rc_done_json=$?
ck 0 "$rc_done_json" "resume --card C-002 --json on done card exits 0"
ck 1 "$(printf '%s\n' "$out_done_json" | wc -l | tr -d ' ')" "done card in JSON mode emits single line"

py_check_done="$("$py" -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
    assert d["schema_version"] == 1
    assert d["kind"] == "card.handoff"
    assert d["card_id"] == "C-002"
    assert d["title"] == "Completed card task"
    assert d["status"] == "done"
    assert d["risk"] == "security-class"
    assert d["allowed_files"] == ["none"]
    assert d["verify_commands"] == ["npm test"]
    print("PASS")
except Exception as e:
    print(f"FAIL: {e}")
' "$out_done_json")"
ck "PASS" "$py_check_done" "done card JSON schema valid with status done"

echo "=== 4. 100% prose output preservation when --json is omitted ==="
out_prose_done="$(bash "$RUN" resume --card C-002 2>&1)"; rc_prose_done=$?
ck 0 "$rc_prose_done" "resume --card C-002 prose exits 0"
ck "yes" "$([ "$out_prose_done" != "$out_done_json" ] && echo yes || echo no)" "prose output differs from JSON output"
printf '%s\n' "$out_prose_done" | grep -q "card C-002 is already done - see 'flow recall'"
ck 0 "$?" "prose output preserves 'already done' message"
printf '%s\n' "$out_prose_done" | grep -q "NEXT_VERB=card"
ck 0 "$?" "prose output preserves NEXT_VERB=card"

out_prose_active="$(bash "$RUN" resume --card C-001 2>&1)"; rc_prose_active=$?
ck 0 "$rc_prose_active" "resume --card C-001 prose exits 0"
# Line-anchored full-surface check: every prose line the pre-change surface emitted.
printf '%s\n' "$out_prose_active" | grep -qxF "flow resume card: C-001"
ck 0 "$?" "prose preserves header line"
printf '%s\n' "$out_prose_active" | grep -qE '^  project: .+'
ck 0 "$?" "prose preserves project line"
printf '%s\n' "$out_prose_active" | grep -qxF "  status:  in_progress"
ck 0 "$?" "prose preserves status line"
printf '%s\n' "$out_prose_active" | grep -qxF "scope:"
ck 0 "$?" "prose preserves scope section header"
printf '%s\n' "$out_prose_active" | grep -qxF "  Compute minimum set with API_KEY=[REDACTED:credential]"
ck 0 "$?" "prose preserves scope body line"
printf '%s\n' "$out_prose_active" | grep -qxF "allowed files:"
ck 0 "$?" "prose preserves allowed files section header"
printf '%s\n' "$out_prose_active" | grep -qxF "  src/balance/simplify.ts, src/balance/simplify.test.ts"
ck 0 "$?" "prose preserves allowed files body line"
printf '%s\n' "$out_prose_active" | grep -qxF "verify:"
ck 0 "$?" "prose preserves verify section header"
printf '%s\n' "$out_prose_active" | grep -qxF "  - [x] npm test src/balance/simplify.test.ts"
ck 0 "$?" "prose preserves verify body line 1"
printf '%s\n' "$out_prose_active" | grep -qxF "  - [ ] curl [REDACTED:aws-key-id]"
ck 0 "$?" "prose preserves verify body line 2"
printf '%s\n' "$out_prose_active" | grep -qxF "linked decisions:"
ck 0 "$?" "prose preserves linked decisions section header"
printf '%s\n' "$out_prose_active" | grep -qxF "  none recorded in harness"
ck 0 "$?" "prose preserves linked decisions empty body"
printf '%s\n' "$out_prose_active" | grep -qxF "git status:"
ck 0 "$?" "prose preserves git status section header"
printf '%s\n' "$out_prose_active" | grep -qE '^  (Not captured in this session|[^ ].*)$'
ck 0 "$?" "prose preserves git status body line"
printf '%s\n' "$out_prose_active" | grep -qxF "NEXT_VERB=card"
ck 0 "$?" "prose preserves NEXT_VERB line"
printf '%s\n' "$out_prose_active" | grep -qxF "**First safe step**: review Scope and run Verify commands before editing"
ck 0 "$?" "prose preserves First safe step line"
prose_lines="$(printf '%s\n' "$out_prose_active" | wc -l | tr -d '[:space:]')"
ck "22" "$prose_lines" "prose output keeps the exact 22-line surface"

echo "=== 5. Project-level resume --json preservation (flow_context/v1) ==="
out_proj_json="$(bash "$RUN" resume --json 2>&1)"; rc_proj_json=$?
ck 0 "$rc_proj_json" "project-level resume --json exits 0"
py_check_proj="$("$py" -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
    assert d["v"] == "flow_context/v1", "expected flow_context/v1"
    assert "stage" in d
    assert "gate" in d
    assert "next_verb" in d
    print("PASS")
except Exception as e:
    print(f"FAIL: {e}")
' "$out_proj_json")"
ck "PASS" "$py_check_proj" "project-level resume --json preserves flow_context/v1 schema"

echo "=== 6. Error handling: non-existent card and invalid card ID ==="
out_missing="$(bash "$RUN" resume --card C-999 --json 2>&1)"; rc_missing=$?
ck 1 "$rc_missing" "resume --card C-999 --json exits 1 on missing card"
printf '%s\n' "$out_missing" | grep -q "card C-999 not found"
ck 0 "$?" "missing card error message preserved"

out_invalid="$(bash "$RUN" resume --card invalid-card --json 2>&1)"; rc_invalid=$?
ck 2 "$rc_invalid" "resume --card invalid-card --json exits 2 on invalid card ID"
printf '%s\n' "$out_invalid" | grep -q "invalid card id"
ck 0 "$?" "invalid card ID error message preserved"

echo "=== 7. Incompatible flags: --budget with --json or --card ==="
bash "$RUN" resume --budget --json >/dev/null 2>&1; rc_b1=$?
ck 2 "$rc_b1" "resume --budget --json exits 2"

bash "$RUN" resume --budget --card C-001 >/dev/null 2>&1; rc_b2=$?
ck 2 "$rc_b2" "resume --budget --card C-001 exits 2"

echo "=== 8. Semantic linked decisions in JSON and prose modes ==="
newsb
cat << 'EOC' > "$SB/cards/C-001.md"
# C-001 — Active card with linked decisions

status: in_progress
deps: none
implements: FR1
risk: standard

## Scope
Card with decision test.

## Allowed files
src/a.ts

## Verify
- [ ] npm test
EOC

# Initialize harness and record decision 0001
py="$(which python3 2>/dev/null || which python 2>/dev/null)"
HARNESS="$ROOT/skills/flow/harness/flow_harness.py"
if command -v cygpath >/dev/null 2>&1; then
  NATIVE_SB="$(cygpath -m "$SB")"
  NATIVE_HARNESS="$(cygpath -m "$HARNESS")"
else
  NATIVE_SB="$SB"
  NATIVE_HARNESS="$HARNESS"
fi
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" init >/dev/null 2>&1
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" decision add --id 0001 --title "Use SQLite WAL mode for C-001" >/dev/null 2>&1

# (a) Verify linked_decisions contains decision 0001 in JSON mode
out_dec_json="$(bash "$RUN" resume --card C-001 --json 2>&1)"; rc_dec_json=$?
ck 0 "$rc_dec_json" "resume --card C-001 --json exits 0 with harness decisions"
py_dec_check="$("$py" -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
    decisions = d.get("linked_decisions", [])
    assert len(decisions) >= 1, "linked_decisions is empty"
    assert any("0001" in item for item in decisions), "decision 0001 not in linked_decisions"
    assert any("SQLite WAL" in item for item in decisions), "decision title not in linked_decisions"
    print("PASS")
except Exception as e:
    print(f"FAIL: {e}")
' "$out_dec_json")"
ck "PASS" "$py_dec_check" "linked_decisions is non-empty array containing decision 0001"

# (b) Verify linked decisions appears in prose mode
out_dec_prose="$(bash "$RUN" resume --card C-001 2>&1)"; rc_dec_prose=$?
ck 0 "$rc_dec_prose" "resume --card C-001 prose exits 0 with harness decisions"
printf '%s
' "$out_dec_prose" | grep -q "0001"
ck 0 "$?" "prose output displays decision 0001"
printf '%s
' "$out_dec_prose" | grep -q "SQLite WAL"
ck 0 "$?" "prose output displays decision title"

echo "=== 9. Negative test: harness query error propagation (fail-closed) ==="
# Trigger harness query decisions error via test hook
bad_harness_out="$(FLOW_TEST_DECISIONS_ERROR=1 bash "$RUN" resume --card C-001 --json 2>&1)"; bad_rc=$?
ck 1 "$bad_rc" "harness query failure propagates as error (exit 1) in JSON mode"
printf '%s\n' "$bad_harness_out" | grep -q "FAIL: harness query decisions failed: simulated harness query error for testing"
ck 0 "$?" "harness query failure error message reported in JSON mode"

echo "=== 10. Story-scoped decisions query does not leak unrelated decisions ==="
py="$(command -v python3 2>/dev/null || command -v python 2>/dev/null)"

# (a) empty-unrelated: story-scoped query with only an unrelated decision returns NOTHING
newsb
if command -v cygpath >/dev/null 2>&1; then
  NATIVE_SB="$(cygpath -m "$SB")"
  NATIVE_HARNESS="$(cygpath -m "$HARNESS")"
else
  NATIVE_SB="$SB"
  NATIVE_HARNESS="$HARNESS"
fi
cat << 'EOC' > "$SB/cards/C-001.md"
# C-001 — Active card unrelated decisions probe

status: in_progress
deps: none
implements: FR1
risk: standard

## Scope
Probe card.

## Allowed files
src/a.ts

## Verify
- [ ] npm test
EOC
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" init >/dev/null 2>&1
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" decision add --id 9002 --title "Unrelated C-002 caching decision" >/dev/null 2>&1
leak_out="$(FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" query decisions --story C-001 2>&1)"
if printf '%s\n' "$leak_out" | grep -q "9002"; then
  ck 0 1 "empty-unrelated: story C-001 query leaks unrelated decision 9002"
else
  ck 0 0 "empty-unrelated: story C-001 query returns no unrelated decisions"
fi
printf '%s\n' "$leak_out" | grep -q "(no decisions)"
ck 0 "$?" "empty-unrelated: reports (no decisions)"

# (b) matching-linked: trace-linked decision IS returned for the scoped story
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" decision add --id 9001 --title "Use SQLite WAL mode for C-001" >/dev/null 2>&1
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" trace --summary "work C-001 storage layer" --story C-001 --decisions 9001 --outcome completed >/dev/null 2>&1
linked_out="$(FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" query decisions --story C-001 2>&1)"
printf '%s\n' "$linked_out" | grep -q "9001"
ck 0 "$?" "matching-linked: linked decision 9001 returned for C-001"
if printf '%s\n' "$linked_out" | grep -q "9002"; then
  ck 0 1 "matching-linked: unrelated decision 9002 leaked into C-001 query"
else
  ck 0 0 "matching-linked: unrelated decision 9002 NOT returned for C-001"
fi

# (c) no-story: unfiltered query still returns ALL decisions
all_out="$(FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" query decisions 2>&1)"
printf '%s\n' "$all_out" | grep -q "9001"
ck 0 "$?" "no-story: unfiltered query returns decision 9001"
printf '%s\n' "$all_out" | grep -q "9002"
ck 0 "$?" "no-story: unfiltered query returns decision 9002"

# (d) story-boundary: C-100 query must NOT return C-1000's decision (substring leak)
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" decision add --id 9100 --title "Chosen the C-100 batching design" >/dev/null 2>&1
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" decision add --id 91000 --title "Chosen the C-1000 batching design" >/dev/null 2>&1
b100_out="$(FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" query decisions --story C-100 2>&1)"
printf '%s\n' "$b100_out" | grep -q "9100"
ck 0 "$?" "story-boundary: C-100 query returns its own decision 9100"
if printf '%s\n' "$b100_out" | grep -q "91000"; then
  ck 0 1 "story-boundary: C-100 query leaks C-1000 decision 91000"
else
  ck 0 0 "story-boundary: C-100 query does NOT leak C-1000 decision 91000"
fi
b1000_out="$(FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" query decisions --story C-1000 2>&1)"
printf '%s\n' "$b1000_out" | grep -q "91000"
ck 0 "$?" "story-boundary: C-1000 query returns its own decision 91000"
if printf '%s\n' "$b1000_out" | grep -q "9100[^0]"; then
  ck 0 1 "story-boundary: C-1000 query leaks C-100 decision 9100"
else
  ck 0 0 "story-boundary: C-1000 query does NOT leak C-100 decision 9100"
fi

# (e) notes-only match: story ID mentioned ONLY in notes field is returned without leaking notes into public schema
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" decision add --id 9200 --title "Generic architecture choice" >/dev/null 2>&1
# Update decision 9200 notes column with C-200 reference
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" - "$NATIVE_SB" << 'PY'
import sys, sqlite3, os
db = os.path.join(sys.argv[1], ".flow", "harness.db")
con = sqlite3.connect(db)
con.execute("UPDATE decision SET notes=? WHERE id=?", ("Documented specifically for C-200", "9200"))
con.commit()
PY
notes_out="$(FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" query decisions --story C-200 2>&1)"
printf '%s\n' "$notes_out" | grep -q "9200"
ck 0 "$?" "notes-only: C-200 query returns decision 9200 matched via notes"

# JSON schema check: notes column must NOT leak into returned public schema
notes_json="$(FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" query decisions --story C-200 --json 2>&1)"
ck "PASS" "$("$py" -c '
import json, sys
data = json.loads(sys.argv[1])
assert len(data) == 1, f"expected 1 record, got {len(data)}"
actual_id = data[0].get("id")
assert actual_id == "9200", f"bad id: {actual_id}"
assert "notes" not in data[0], "notes column leaked into public schema"
expected_keys = {"id", "title", "status", "predicted_impact", "actual_outcome", "accessed_count"}
assert set(data[0].keys()) == expected_keys, f"keys mismatch: {set(data[0].keys())}"
print("PASS")
' "$notes_json")" "notes-only: notes column stripped and public schema preserved"

# (f) literal wildcard in story ID: C_300 and C%300 matching exact literal characters without wildcard expansion
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" decision add --id 9300 --title "Underline case for C_300" >/dev/null 2>&1
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" decision add --id 9301 --title "Different case for CX300" >/dev/null 2>&1
FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" decision add --id 9302 --title "Percent case for C%300" >/dev/null 2>&1
u300_out="$(FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" query decisions --story C_300 2>&1)"
printf '%s\n' "$u300_out" | grep -q "9300"
ck 0 "$?" "literal-wildcard: C_300 query returns exact literal decision 9300"
if printf '%s\n' "$u300_out" | grep -q "9301"; then
  ck 0 1 "literal-wildcard: C_300 query leaks wildcard-matched CX300"
else
  ck 0 0 "literal-wildcard: C_300 query does NOT match CX300 (underscore escaped)"
fi
p300_out="$(FLOW_PROJECT_ROOT="$NATIVE_SB" "$py" "$NATIVE_HARNESS" query decisions --story C%300 2>&1)"
printf '%s\n' "$p300_out" | grep -q "9302"
ck 0 "$?" "literal-wildcard: C%300 query returns exact literal decision 9302"
if printf '%s\n' "$p300_out" | grep -q "9300"; then
  ck 0 1 "literal-wildcard: C%300 query leaks C_300"
else
  ck 0 0 "literal-wildcard: C%300 query does NOT match C_300 (percent escaped)"
fi

echo "=== 11. Card handoff normalization regressions (paths, tabs, wrapped verify) ==="
newsb
cat << 'EOC' > "$SB/cards/C-003.md"
# C-003 — Complex formatting normalization card

status: in_progress
deps: none
implements: FR4
risk: standard

## Scope
Verification of normalization.

## Allowed files
- `lib/x.py`, lib/y.py
- src/a.ts, src/b.ts   src/c.ts
* `path/to/script.sh`
- secrets/password=supersecretpassword123, src/config.ts

## Verify
- [x] npm	test
  --runInBand
- [ ] curl AKIA1234567890ABCDEF
  -H "Authorization: Bearer token"
- pytest tests/unit
  --verbose
  -k "test_feature"
EOC

out_norm="$(bash "$RUN" resume --card C-003 --json 2>&1)"; rc_norm=$?
ck 0 "$rc_norm" "resume --card C-003 --json exits 0"
ck 1 "$(printf '%s\n' "$out_norm" | wc -l | tr -d ' ')" "resume --card C-003 --json emits exactly 1 line"

py_check_norm="$("$py" -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
    # 1. Allowed files normalization: bullets stripped, backticks stripped, comma/whitespace separated
    af = d.get("allowed_files", [])
    assert af == [
        "lib/x.py",
        "lib/y.py",
        "src/a.ts",
        "src/b.ts",
        "src/c.ts",
        "path/to/script.sh",
        "secrets/password=[REDACTED:credential]",
        "src/config.ts"
    ], f"bad normalized allowed_files: {af}"

    # Secret redaction verified
    assert "supersecretpassword123" not in json.dumps(af), "raw password leaked in allowed_files"
    assert any("[REDACTED:credential]" in f for f in af), "redaction marker missing in allowed_files"

    # 2. Verify commands normalization: tabs preserved, continuation lines joined, shell flags intact
    vc = d.get("verify_commands", [])
    assert len(vc) == 3, f"expected 3 verify commands, got {len(vc)}: {vc}"
    assert vc[0] == "npm\ttest --runInBand", f"bad verify[0]: {repr(vc[0])}"
    assert "\t" in vc[0], "literal tab missing in verify[0]"
    assert "--runInBand" in vc[0], "shell flag --runInBand corrupted in verify[0]"
    assert vc[1] == "curl [REDACTED:aws-key-id] -H \"Authorization: Bearer token\"", f"bad verify[1]: {repr(vc[1])}"
    assert "AKIA1234567890ABCDEF" not in vc[1], "raw aws key leaked in verify[1]"
    assert vc[2] == "pytest tests/unit --verbose -k \"test_feature\"", f"bad verify[2]: {repr(vc[2])}"
    print("PASS")
except Exception as e:
    print(f"FAIL: {e}")
' "$out_norm")"
ck "PASS" "$py_check_norm" "handoff JSON normalizes paths, preserves tabs and groups wrapped verify"

echo "=== 12. Empty --card= argument handling ==="
bash "$RUN" resume --card= --json >/dev/null 2>&1; rc_ec1=$?
ck 2 "$rc_ec1" "resume --card= --json exits 2"
bash "$RUN" resume --json --card= >/dev/null 2>&1; rc_ec2=$?
ck 2 "$rc_ec2" "resume --json --card= exits 2"
bash "$RUN" resume --budget --card= >/dev/null 2>&1; rc_ec3=$?
ck 2 "$rc_ec3" "resume --budget --card= exits 2"

echo "=== 13. Regression: BSD wc -l padded output numeric comparison (22 accepted, 21/23 rejected) ==="
# BSD wc -l on macOS prints leading spaces (e.g. "      22"). Normalizing with tr -d '[:space:]'
# and comparing numerically ensures exact-22-line validation works cross-platform without weakening.
_wc_exact_22() {
  local raw trimmed
  raw="$1"
  trimmed="$(printf '%s' "$raw" | tr -d '[:space:]')"
  [ -n "$trimmed" ] && [ "$trimmed" -eq 22 ] 2>/dev/null
}
_wc_exact_22 "      22"
ck 0 "$?" "padded BSD wc output '      22' accepted as exact 22"
_wc_exact_22 "      21"
ck 1 "$?" "padded BSD wc output '      21' rejected"
_wc_exact_22 "      23"
ck 1 "$?" "padded BSD wc output '      23' rejected"
_wc_exact_22 "22"
ck 0 "$?" "unpadded GNU wc output '22' accepted"
_wc_exact_22 "21"
ck 1 "$?" "unpadded '21' rejected"
_wc_exact_22 "23"
ck 1 "$?" "unpadded '23' rejected"

clean

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
