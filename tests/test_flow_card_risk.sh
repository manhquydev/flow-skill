#!/usr/bin/env bash
# Phase 3: card risk parser + auto preflight.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
export FLOW_HARNESS_DISABLE=1
export FLOW_LOG_DISABLE=1
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }

scaffold() {
  SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
  mkdir -p "$SB/flow" "$SB/cards"
  for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
    printf '#%s\n## Gate\n- [x] ok\n\nbody\n' "$s" > "$SB/flow/$s.md"
  done
  git -C "$SB" init -q
  git -C "$SB" config user.email "op@example.com"
  git -C "$SB" config user.name "Operator"
  printf '# debt\n' > "$SB/DEBT.md"
  git -C "$SB" add -A && git -C "$SB" commit -qm init
}

mkcard() { # id risk reason ack
  printf '# %s\nstatus: todo\ndeps: none\nimplements: none\nrisk: %s\nrisk-reason: %s\nrisk-ack: %s\n## Scope\nx\n## Allowed files\na.py\n## Verify\n- [ ] v\n## Done-evidence\nu\n## Evidence\n(empty until done)\n' \
    "$1" "$2" "$3" "$4" > "$SB/cards/$1.md"
}

echo "A) legacy missing risk fields → unknown (manual ok)"
scaffold
printf '# C-001\nstatus: todo\ndeps: none\n## Scope\nx\n## Allowed files\na.py\n## Verify\n- [ ] v\n## Done-evidence\nu\n## Evidence\n(empty until done)\n' > "$SB/cards/C-001.md"
out="$(bash "$RUN" check C-001 2>&1)"; ck 0 $? "legacy check still 0"
has "$out" 'risk=unknown|note: risk' "warns unknown"
rm -rf "$SB"

echo "B) standard preflight READY"
scaffold
mkcard C-001 standard "bounded reason for standard work" none
out="$(bash "$RUN" auto 2>&1)"; rc=$?
# may still fail on stage 05 receipt — risk section should READY
has "$out" 'READY C-001' "standard ready in preflight"
rm -rf "$SB"

echo "C) unknown blocks auto"
scaffold
mkcard C-001 unknown "" none
out="$(bash "$RUN" auto 2>&1)"; ck 1 $? "auto fails unknown"
has "$out" 'BLOCK C-001 risk=unknown' "block unknown"
rm -rf "$SB"

echo "D) duplicate risk invalid"
scaffold
printf '# C-001\nstatus: todo\ndeps: none\nrisk: standard\nrisk: standard\nrisk-reason: reason here ok\nrisk-ack: none\n## Scope\nx\n## Allowed files\na.py\n## Verify\n- [ ] v\n## Done-evidence\nu\n## Evidence\n(empty until done)\n' > "$SB/cards/C-001.md"
out="$(bash "$RUN" auto 2>&1)"; ck 1 $? "auto fails dupe"
has "$out" 'duplicate|invalid' "reports duplicate"
rm -rf "$SB"

echo "E) security without ack HALT"
scaffold
mkcard C-001 security-class "touches auth surface" none
out="$(bash "$RUN" auto 2>&1)"; ck 1 $? "auto fails security no ack"
has "$out" 'HALT|ack' "halt ack"
rm -rf "$SB"

echo "F) new card template includes risk unknown"
scaffold
# force planning complete already; create card via CLI
bash "$RUN" card >/dev/null 2>&1 || true
# highest may create C-001
if [ -f "$SB/cards/C-001.md" ]; then
  has "$(cat "$SB/cards/C-001.md")" 'risk: unknown' "scaffolded risk"
else
  # manual copy template path
  has "$(cat "$HERE/../skills/flow/_templates/card.md")" 'risk: unknown' "template risk"
fi
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
