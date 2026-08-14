#!/usr/bin/env bash
# Regression suite for C-002: Independent test + quality boxes + artifact-lifecycle.
# FIXED vs graft B4: positive ban-line grep (no `no 'specs/'`); no `no flow.sh
# 'Independent test'` (§1.6 is cut). Portable — no `sed -i`.
# Run: bash tests/test_flow_slice_quality.sh
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
ROOT="$HERE/../skills/flow"
T="$ROOT/_templates"
G="$ROOT/references/gate-rules.md"
LIFE="$ROOT/references/artifact-lifecycle.md"
LAW="$ROOT/law/CLAUDE.md"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if grep -qE -- "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }

# H3 env. T13 seeds SIX SYNTHETIC clean stages — never copy real 03/05 templates.
newsb() {
  SB="$(mktemp -d)"
  mkdir -p "$SB/flow" "$SB/cards"
  export FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_DISABLE=1 FLOW_LOG_DISABLE=1
}
stage_clean() { printf '#%s\n## Gate\n- [x] honestly done\n\nreal content.\n' "$1" > "$2"; }

echo "T13 Independent test (template + law + semantic challenge)"
has "$T/card.md" '^## Independent test' "card template has ## Independent test heading"
# heading sits between Scope and Allowed files
sl=$(grep -n '^## Scope' "$T/card.md" | head -1 | cut -d: -f1)
il=$(grep -n '^## Independent test' "$T/card.md" | head -1 | cut -d: -f1)
al=$(grep -n '^## Allowed files' "$T/card.md" | head -1 | cut -d: -f1)
if [ -n "${sl:-}" ] && [ -n "${il:-}" ] && [ -n "${al:-}" ] && [ "$sl" -lt "$il" ] && [ "$il" -lt "$al" ]; then
  echo "  ok   [Independent test sits between Scope and Allowed files]"; pass=$((pass+1))
else
  echo "  FAIL [Independent test sits between Scope and Allowed files] (Scope=$sl IT=$il Allowed=$al)"; fail=$((fail+1))
fi
has "$T/card.md" 'infra' "card template allows infra/none"
has "$T/card.md" 'Unit tests pass' "card template FILL hint rejects unit-tests-pass"
has "$LAW" 'models-only' "law forbids models-only cards"
has "$G" 'Independent test' "gate-rules card challenge names Independent test"
has "$G" 'unit tests pass' "gate-rules splits on unit-tests-pass"
has "$G" 'heading remains' "gate-rules documents M5 (FILL-only while heading remains)"

echo "T12 requirements-quality boxes are real ^- [ ] lines (after phase-1 OD Gate line)"
has "$T/03-prd.md" '^- \[ \] No unquantified adjectives' "PRD quality box is a real unchecked line"
has "$T/03-prd.md" '^- \[ \] Every `FRn` names the failure or empty case' "PRD FRn failure/empty box is a real unchecked line"
has "$T/05-contract.md" '^- \[ \] Every write interface names the failure shape' "contract write-failure box is a real unchecked line"
has "$T/05-contract.md" '^- \[ \] Every interface that can return empty names the empty shape' "contract empty-shape box is a real unchecked line"
has "$T/05-contract.md" '^- \[ \] Access/effects is a concrete token' "contract access-token box is a real unchecked line"
has "$G" 'reviewer of English' "gate-rules 03/05 English-reviewer challenge"
# M3: boxes live inside ## Gate, after the open-decisions line, before next ## heading
od03=$(grep -n 'No unresolved open decisions' "$T/03-prd.md" | head -1 | cut -d: -f1)
adj=$(grep -n '^- \[ \] No unquantified adjectives' "$T/03-prd.md" | head -1 | cut -d: -f1)
ctx=$(grep -n '^## Context' "$T/03-prd.md" | head -1 | cut -d: -f1)
if [ -n "${od03:-}" ] && [ -n "${adj:-}" ] && [ -n "${ctx:-}" ] && [ "$od03" -lt "$adj" ] && [ "$adj" -lt "$ctx" ]; then
  echo "  ok   [PRD quality boxes sit after OD Gate line, before ## Context]"; pass=$((pass+1))
else
  echo "  FAIL [PRD quality boxes sit after OD Gate line, before ## Context] (od=$od03 adj=$adj ctx=$ctx)"; fail=$((fail+1))
fi
od05=$(grep -n 'No unresolved open decisions' "$T/05-contract.md" | head -1 | cut -d: -f1)
wf=$(grep -n '^- \[ \] Every write interface names the failure shape' "$T/05-contract.md" | head -1 | cut -d: -f1)
oa=$(grep -n '^## OpenAPI' "$T/05-contract.md" | head -1 | cut -d: -f1)
if [ -n "${od05:-}" ] && [ -n "${wf:-}" ] && [ -n "${oa:-}" ] && [ "$od05" -lt "$wf" ] && [ "$wf" -lt "$oa" ]; then
  echo "  ok   [contract quality boxes sit after OD Gate line, before ## OpenAPI]"; pass=$((pass+1))
else
  echo "  FAIL [contract quality boxes sit after OD Gate line, before ## OpenAPI] (od=$od05 wf=$wf oa=$oa)"; fail=$((fail+1))
fi

echo "T2 artifact-lifecycle (3 models + converge closer + positive ban-line)"
has "$LIFE" 'living' "names living plan"
has "$LIFE" 'cycle-forward' "names cycle-forward"
has "$LIFE" 'flow-back' "names flow-back"
has "$LIFE" 'append-only' "default is append-only cards"
has "$LIFE" 'converge' "points at converge as closer"
has "$LIFE" 'append-only' "artifact-lifecycle describes converge as the append-only flow-back closer"
has "$LIFE" 'Do not add' "positive ban-line (Do not add) — not a no-specs/ grep"

echo "T13 mechanical proof: /flow card + leftover FILL in Independent test fails check"
newsb
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
  stage_clean "$s" "$SB/flow/$s.md"
done
out="$(bash "$RUN" card 2>&1)"; ck 0 $? "card after six synthetic clean stages"
cardf="$SB/cards/C-001.md"
if [ -f "$cardf" ]; then
  echo "  ok   [card file created]"; pass=$((pass+1))
else
  echo "  FAIL [card file created]"; fail=$((fail+1))
  cardf=""
fi
if [ -n "$cardf" ]; then
  has "$cardf" '^## Independent test' "fresh /flow card copied Independent test heading"
  # Isolate leftover FILL to Independent test only (portable overwrite of the created card).
  cat > "$cardf" <<'EOF'
# C-001 — one thing
status: todo
deps: none
implements: FR1
risk: unknown
risk-reason:
risk-ack: none

## Scope
one thing

## Independent test
[FILL: leftover]

## Allowed files
app.py

## Verify (run these before calling the card done)
- [ ] curl 200

## Done-evidence (world-state proof)
a url

## Evidence (paste the actual proof here when done)
(empty until done)
EOF
  out="$(bash "$RUN" check C-001 2>&1)"; ck 1 $? "leftover FILL in Independent test fails check"
  has_out() { if printf '%s' "$1" | grep -q -- "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
  has_out "$out" "FILL" "check names the leftover FILL"
  # Unlock: fill Independent test via awk tmp+mv (no sed -i).
  awk '
    /^## Independent test/ { f=1; print; next }
    f && /^## / { f=0 }
    f && /\[FILL/ { print "infra"; next }
    { print }
  ' "$cardf" > "$cardf.tmp" && mv "$cardf.tmp" "$cardf"
  out="$(bash "$RUN" check C-001 2>&1)"; ck 0 $? "filled Independent test -> check clean"
fi
rm -rf "$SB"

echo "E) manifest.txt registers this suite (self-guard)"
if grep -q 'test_flow_slice_quality.sh' "$HERE/manifest.txt" 2>/dev/null; then
  echo "  ok   [manifest.txt lists test_flow_slice_quality.sh]"; pass=$((pass+1))
else
  echo "  FAIL [manifest.txt lists test_flow_slice_quality.sh]"; fail=$((fail+1))
fi

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?
