#!/usr/bin/env bash
# Verify the Research (01) and Contract (05) gate templates are project-type aware
# (findings #1, #4) WITHOUT weakening the web/market-product path. Run: bash tests/test_flow_gate_wording.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../skills/flow/_templates"
G01="$HERE/../skills/flow/references/gate-01.md"
G05="$HERE/../skills/flow/references/gate-05.md"
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

echo "Semantic layer applies the lens by project type + guards web abuse"
has "$G01" "Apply the lens by project type" "stage 01 challenge keys on project type"
has "$G05" "Do NOT let a web product blank the access column" "stage 05 guards web abuse of non-web framing"
has "$G01" "Reject the soft" "stage 01 refuses a web product hiding behind soft framing"

echo "Stage 00 & Card templates guide beginners without breaking scan_gate"
structok "$T/00-idea.md" "00-idea"
has "$T/00-idea.md" "How to complete:" "00-idea includes beginner completion tip"
has "$T/00-idea.md" '\- \[x\]' "00-idea explains - [x] checkbox completion syntax"
idea_fills="$(awk '{ s=$0; while ((i=index(s, "[FILL")) > 0) { c++; s=substr(s, i+5) } } END { print c+0 }' "$T/00-idea.md" 2>/dev/null)"
if [ "$idea_fills" = "4" ]; then
  echo "  ok   [00-idea has exact expected [FILL count (4)]"; pass=$((pass+1))
else
  echo "  FAIL [00-idea [FILL count expected 4, got $idea_fills]"; fail=$((fail+1))
fi
idea_boxes="$(grep -cE '^[[:space:]]*- \[ \]' "$T/00-idea.md" 2>/dev/null | tr -d '[:space:]')"
if [ "$idea_boxes" = "3" ]; then
  echo "  ok   [00-idea has exact expected gate checkbox count (3)]"; pass=$((pass+1))
else
  echo "  FAIL [00-idea gate checkbox count expected 3, got $idea_boxes]"; fail=$((fail+1))
fi
has "$T/card.md" "(empty until done)" "card.md preserves (empty until done) sentinel"
has "$T/card.md" "Example of >=2 real world-state signals" "card.md explains world-state proof examples"
has "$T/card.md" "exit 0" "card.md proof example shows command output & exit code"
card_ev_fills="$(awk '/^## Evidence/{flag=1; next} /^## /{flag=0} flag{ s=$0; while ((i=index(s, "[FILL")) > 0) { c++; s=substr(s, i+5) } } END { print c+0 }' "$T/card.md" 2>/dev/null)"
if [ "$card_ev_fills" = "0" ]; then
  echo "  ok   [card.md introduces 0 [FILL substrings under ## Evidence]"; pass=$((pass+1))
else
  echo "  FAIL [card.md has $card_ev_fills unexpected [FILL substrings under ## Evidence]"; fail=$((fail+1))
fi

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]