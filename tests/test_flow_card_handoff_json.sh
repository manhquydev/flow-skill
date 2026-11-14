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

py_check1="$(python3 -c '
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

py_check_done="$(python3 -c '
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
printf '%s\n' "$out_prose_active" | grep -q "flow resume card: C-001"
ck 0 "$?" "prose output preserves header"
printf '%s\n' "$out_prose_active" | grep -q "status:  in_progress"
ck 0 "$?" "prose output preserves status"
printf '%s\n' "$out_prose_active" | grep -q "scope:"
ck 0 "$?" "prose output preserves scope section"
printf '%s\n' "$out_prose_active" | grep -q "allowed files:"
ck 0 "$?" "prose output preserves allowed files section"
printf '%s\n' "$out_prose_active" | grep -q "verify:"
ck 0 "$?" "prose output preserves verify section"
printf '%s\n' "$out_prose_active" | grep -q "\*\*First safe step\*\*"
ck 0 "$?" "prose output preserves First safe step prompt"

echo "=== 5. Project-level resume --json preservation (flow_context/v1) ==="
out_proj_json="$(bash "$RUN" resume --json 2>&1)"; rc_proj_json=$?
ck 0 "$rc_proj_json" "project-level resume --json exits 0"
py_check_proj="$(python3 -c '
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
py="$("$RUN" __python__ 2>/dev/null || which python3)"
HARNESS="$ROOT/skills/flow/harness/flow_harness.py"
FLOW_PROJECT_ROOT="$SB" "$py" "$HARNESS" init >/dev/null 2>&1
FLOW_PROJECT_ROOT="$SB" "$py" "$HARNESS" decision add --id 0001 --title "Use SQLite WAL mode for C-001" >/dev/null 2>&1

# (a) Verify linked_decisions contains decision 0001 in JSON mode
out_dec_json="$(bash "$RUN" resume --card C-001 --json 2>&1)"; rc_dec_json=$?
ck 0 "$rc_dec_json" "resume --card C-001 --json exits 0 with harness decisions"
py_dec_check="$(python3 -c '
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

clean

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
