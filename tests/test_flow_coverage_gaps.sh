#!/usr/bin/env bash
# Close the coverage gaps found in the test-coverage analysis: the previously-untested
# commands (retro, ready, auto, harness decision/tool/intervention/query-tools).
# Run: bash tests/test_flow_coverage_gaps.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
PY="$(command -v python || command -v python3)"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected $1 got $2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }
clean6() { for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do printf '#%s\n## Gate\n- [x] ok\n' "$s" > "$1/flow/$s.md"; done; }

echo "retro - prints the 3 retro questions"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
out="$(bash "$RUN" retro)"; ck 0 $? "retro exits 0"
has "$out" "skip or rush" "retro asks the skip/cost question"
has "$out" "RETRO.md" "retro points at RETRO.md"
rm -rf "$SB"

echo "ready - lists buildable (deps met) vs blocked (deps unmet) cards"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow" "$SB/cards"
clean6 "$SB"
printf '# C-001 - base\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\na.py\n## Verify\n- [x] x\n## Done-evidence\nu\n## Evidence\nreal\n' > "$SB/cards/C-001.md"
printf '# C-002 - ready\nstatus: todo\ndeps: C-001\n## Scope\nb\n## Allowed files\nb.py\n## Verify\n- [ ] y\n## Done-evidence\nu\n## Evidence\n(empty)\n' > "$SB/cards/C-002.md"
printf '# C-003 - blocked\nstatus: todo\ndeps: C-002\n## Scope\nc\n## Allowed files\nc.py\n## Verify\n- [ ] z\n## Done-evidence\nu\n## Evidence\n(empty)\n' > "$SB/cards/C-003.md"
out="$(bash "$RUN" ready)"
has "$out" "BUILDABLE C-002" "C-002 buildable (dep C-001 done)"
has "$out" "blocked   C-003" "C-003 blocked (dep C-002 not done)"
rm -rf "$SB"

echo "auto - preflight gates on planning-complete + cards"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"
bash "$RUN" auto >/dev/null 2>&1; ck 1 $? "auto blocks with no planning"
clean6 "$SB"; bash "$RUN" card >/dev/null
out="$(bash "$RUN" auto)"; ck 0 $? "auto preflight passes with planning + a card"
has "$out" "preflight ok" "auto reports preflight ok"
rm -rf "$SB"

if [ -z "$PY" ]; then echo "(skipping harness gap tests - no python)"; echo; echo "RESULT: $pass passed, $fail failed"; [ "$fail" -eq 0 ]; exit $?; fi

echo "harness decision add + verify (was untested)"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
out="$(bash "$RUN" harness decision add --id 0001-auth --title 'auth boundary' --doc docs/decisions/0001.md --verify 'exit 0')"
has "$out" "decision 0001-auth added" "decision add"
out="$(bash "$RUN" harness decision verify --id 0001-auth 2>&1)"; ck 0 $? "decision verify (exit 0 -> pass)"
rm -rf "$SB"

echo "harness tool register + query tools (was untested)"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
bash "$RUN" harness tool register --name pytest --command 'pytest -q' --description 'run unit tests' --responsibility Verification >/dev/null
out="$(bash "$RUN" harness query tools)"
has "$out" "pytest" "registered tool appears in query tools"
has "$out" "Verification" "tool responsibility recorded"
rm -rf "$SB"

echo "harness intervention add (was untested)"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
out="$(bash "$RUN" harness intervention --type override --description 'human approved despite risk' --source human 2>&1)"
has "$out" "intervention" "intervention recorded"
bash "$RUN" harness intervention --type bogus --description x --source human >/dev/null 2>&1; ck 2 $? "invalid intervention type rejected by argparse"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]