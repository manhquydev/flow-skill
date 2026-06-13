#!/usr/bin/env bash
# Scenario suite mirroring buildflow's 6 validation rounds (mechanical layer).
# Semantic checks (fabricated research, grade-laundering) are the Claude layer's job and
# are not asserted here. Run: bash tests/test_flow_scenarios.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skill/flow/runner/flow.sh"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected $1 got $2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }
clean6() { for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do printf '#%s\n## Gate\n- [x] ok\n\nreal.\n' "$s" > "$1/flow/$s.md"; done; }

echo "Round 1 - happy path: full planning advances, gates pass in order"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
bash "$RUN" next >/dev/null; ck 0 $? "unlock stage 00"
clean6 "$SB"
bash "$RUN" next >/dev/null; ck 0 $? "stage 05 clean -> planning complete"
rm -rf "$SB"

echo "Round 2 - adversarial: skip attempts are blocked"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"
bash "$RUN" card >/dev/null 2>&1; ck 1 $? "card before planning blocked"
printf '#00\n## Gate\n- [ ] not done\n[FILL: x]\n' > "$SB/flow/00-idea.md"
bash "$RUN" next >/dev/null 2>&1; ck 1 $? "gate with unchecked box + FILL blocked"
rm -rf "$SB"

echo "Round 3 - end-to-end: card built to done with durable wiring"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"; clean6 "$SB"
bash "$RUN" card >/dev/null; ck 0 $? "card created after planning"
printf '# C-001 - x\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\na.py\n## Verify\n- [x] curl 200\n## Done-evidence\nurl\n## Evidence\n$ curl ... 200 ok\n' > "$SB/cards/C-001.md"
bash "$RUN" check C-001 >/dev/null; ck 0 $? "done card with real evidence passes"
rm -rf "$SB"

echo "Round 4 - real idea: scope stage enforces fill (decision table is semantic)"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
bash "$RUN" next >/dev/null                    # stage 00
printf '#00\n## Gate\n- [x] ok\n' > "$SB/flow/00-idea.md"; bash "$RUN" next >/dev/null  # ->01
printf '#01\n## Gate\n- [x] ok\n' > "$SB/flow/01-research.md"; bash "$RUN" next >/dev/null # ->02
out="$(bash "$RUN" status)"; has "$out" "02-scope" "reaches scope stage"
bash "$RUN" next >/dev/null 2>&1; ck 1 $? "fresh scope template (FILL) blocks advance"
rm -rf "$SB"

echo "Round 5 - fixes & traps: debt ledger + design check"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB"
bash "$RUN" debt add "skipped contract-test" "endpoints unverified" "before real users" >/dev/null; ck 0 $? "debt recorded"
has "$(bash "$RUN" debt list)" "OPEN debts" "open debt listed"
printf '<input style="background:linear-gradient(135deg,#fff,#eee)"><p>{{x}}</p>\n' > "$SB/ui.html"
bash "$RUN" design "$SB/ui.html" >/dev/null 2>&1; ck 1 $? "design check flags {{}} + gradient"
rm -rf "$SB"

echo "Round 6 - work mode: mode toggles and persists"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB"
bash "$RUN" mode work >/dev/null; ck 0 $? "set mode work"
has "$(bash "$RUN" mode)" "work" "mode persists as work"
bash "$RUN" mode teach >/dev/null; has "$(bash "$RUN" mode)" "teach" "mode resets to teach"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]