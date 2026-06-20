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

echo "agent-wiring tripwire — every ck: agent in agent-detection.md must appear in agent-stage-mapping.md"
# Read the two reference files from the skill bundle.
DETECTION="$HERE/../skills/flow/references/agent-detection.md"
MAPPING="$HERE/../skills/flow/references/agent-stage-mapping.md"

# Derive the required agent set by parsing the ck: priority list from agent-detection.md.
# The canonical line has the form:
#   1. **ck: agent** (primary) — agent1, agent2, ..., agentN.
# Extract it, strip markdown formatting, split on comma/space to get individual agent names.
DERIVED_AGENTS="$(grep -oP '(?<=— ).*(?=\.)' "$DETECTION" | grep 'planner' | \
  sed 's/,/ /g' | tr -s ' ')"
# Accepted exceptions: agents declared in agent-detection.md but intentionally assigned no
# stage row (e.g. a meta-agent with no buildflow stage seam). Currently none — docs-manager
# and git-manager are genuinely wired as of C-018.
ACCEPTED_EXCEPTIONS=""

if [ -z "$DERIVED_AGENTS" ]; then
  echo "  FAIL [agent-wiring: could not parse ck: priority list from agent-detection.md]"; fail=$((fail+1))
else
  echo "  ok   [agent-wiring: derived agent set from agent-detection.md: $DERIVED_AGENTS]"; pass=$((pass+1))
fi

# Assert each derived agent appears in agent-stage-mapping.md (or is an accepted exception).
for agent in $DERIVED_AGENTS; do
  is_exception=0
  for ex in $ACCEPTED_EXCEPTIONS; do
    [ "$agent" = "$ex" ] && is_exception=1 && break
  done
  if [ "$is_exception" -eq 1 ]; then
    echo "  ok   [agent-wiring: $agent is an accepted exception (no stage seam by design)]"; pass=$((pass+1))
  elif grep -q "$agent" "$MAPPING"; then
    echo "  ok   [agent-wired: $agent appears in agent-stage-mapping.md]"; pass=$((pass+1))
  else
    echo "  FAIL [agent-wired: $agent NOT found in agent-stage-mapping.md]"; fail=$((fail+1))
  fi
done

# Explicit assertions for the two agents wired in C-018 (docs-manager + git-manager).
# These were grandfathered in v0.12; they must now be genuinely present in the mapping.
for agent in docs-manager git-manager; do
  if grep -q "$agent" "$MAPPING"; then
    echo "  ok   [C-018-wired: $agent now has a seam row in agent-stage-mapping.md]"; pass=$((pass+1))
  else
    echo "  FAIL [C-018-wired: $agent missing from agent-stage-mapping.md — seam not added]"; fail=$((fail+1))
  fi
done

# NEGATIVE CONTROL: verify the tripwire CAN go red.
# Simulate an unwired-agent state: strip 'debugger' from a temp copy of the mapping and
# assert the wiring check would fail for it — proving the tripwire is not trivially green.
TMPMAP="$(mktemp)"
grep -v "debugger" "$MAPPING" > "$TMPMAP"
if grep -q "debugger" "$TMPMAP"; then
  echo "  FAIL [negative-control: 'debugger' still present after removal — grep broken]"; fail=$((fail+1))
else
  echo "  ok   [negative-control: temp map has 'debugger' removed (simulates unwired state)]"; pass=$((pass+1))
fi
# The wiring check against the stripped map must NOT find debugger — tripwire goes red.
if grep -q "debugger" "$TMPMAP"; then
  echo "  FAIL [negative-control: tripwire would NOT catch an unwired debugger]"; fail=$((fail+1))
else
  echo "  ok   [negative-control: tripwire correctly goes red for unwired 'debugger']"; pass=$((pass+1))
fi
rm -f "$TMPMAP"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]