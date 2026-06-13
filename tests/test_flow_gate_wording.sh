#!/usr/bin/env bash
# Verify the Research (01) and Contract (05) gate templates are project-type aware
# (findings #1, #4) WITHOUT weakening the web/market-product path. Run: bash tests/test_flow_gate_wording.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../skills/flow/_templates"
G="$HERE/../skills/flow/references/gate-rules.md"
pass=0; fail=0
has() { if grep -q "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }
structok() { # file has a Gate section + at least one checkbox + at least one FILL slot
  if grep -q '## Gate' "$1" && grep -qE '^- \[ \]' "$1" && grep -q '\[FILL' "$1"; then
    echo "  ok   [$2 still a well-formed gate template]"; pass=$((pass+1))
  else echo "  FAIL [$2 lost gate structure]"; fail=$((fail+1)); fi
}

echo "Finding #1 - Research (01) gate is project-type aware, web path preserved"
has "$T/01-research.md" "non-web" "research gate adds a non-web framing"
has "$T/01-research.md" "first-party friction" "non-web uses first-party friction"
has "$T/01-research.md" "social media" "web path still rejects vague 'social media' channel"
has "$T/01-research.md" "KILL signal" "web path still keeps the no-channel KILL signal"
structok "$T/01-research.md" "01-research"

echo "Finding #4 - Contract (05) gate is interface-based, OpenAPI marked web-only"
has "$T/05-contract.md" "INTERFACE" "contract gate maps features to an interface (not just endpoint)"
has "$T/05-contract.md" "Access/effects" "auth column generalized to access/effects per type"
has "$T/05-contract.md" "web only" "OpenAPI/Swagger rule marked web-only"
has "$T/05-contract.md" "interface map" "feature->interface map"
structok "$T/05-contract.md" "05-contract"

echo "Semantic layer (gate-rules.md) applies the lens by project type + guards web abuse"
has "$G" "Apply the lens by project type" "stage 01 challenge keys on project type"
has "$G" "Do NOT let a web product blank the access column" "stage 05 guards web abuse of non-web framing"
has "$G" "Reject the soft" "stage 01 refuses a web product hiding behind soft framing"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]