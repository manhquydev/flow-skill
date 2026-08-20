#!/usr/bin/env bash
# Regression guard for the host-agnostic parallel occupancy doc-contract (R1).
# Invariants live in references/host-agnostic-parallel.md (one home). This suite
# asserts each clause is present AND bound — a later edit that deletes/inverts
# one must FAIL, not survive on an unrelated keyword. DOC-CONTRACT test (no
# runner code for this feature; no new flow.sh verb).
# Run: bash tests/test_flow_host_agnostic_parallel.sh   (exit 0 = all pass, 1 = any fail)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
REF="$ROOT/skills/flow/references"
SEAM="$REF/host-agnostic-parallel.md"
SKILL="$ROOT/skills/flow/SKILL.md"
ADR="$ROOT/docs/adr/0001-discipline-layer-identity.md"
pass=0; fail=0
hasE() { if grep -qiE "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing /$2/ in $(basename "$1"))"; fail=$((fail+1)); fi; }
has()  { if grep -qi  "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing '$2' in $(basename "$1"))"; fail=$((fail+1)); fi; }
hasC() { if grep -q   "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing '$2' (case-sensitive) in $(basename "$1"))"; fail=$((fail+1)); fi; }
lacks(){ if grep -qiE "$2" "$1" 2>/dev/null; then echo "  FAIL [$3] (anti-pattern /$2/ present in $(basename "$1"))"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
file() { if [ -f "$1" ]; then echo "  ok   [$2]"; pass=$((pass+1)); else echo "  FAIL [$2] (no file $1)"; fail=$((fail+1)); fi; }

echo "==== Host-agnostic parallel occupancy doc-contract ===="

file "$SEAM" "host-agnostic-parallel.md exists (the one home)"
lacks "$REF/host-herdr.md" "." "home is NOT host-herdr.md"
lacks "$REF/host-multiplexer.md" "." "home is NOT host-multiplexer.md"

# Independence: no named multiplexer; absence never fails a gate.
hasE "$SEAM" "no named multiplexer" "independence: no named multiplexer"
hasE "$SEAM" "never fails a gate" "independence: absence never fails a gate"
hasE "$SEAM" "examples, never as a dependency" "independence: Herdr/tmux are examples, never a dependency"

# Degrade ladder rungs 0–3, clause-bound.
hasE "$SEAM" "in-process subagents" "ladder 0: in-process subagents"
hasE "$SEAM" "cwd .= .the card.s worktree|cwd = the card" "ladder 0: cwd = card worktree"
has  "$SEAM" "print-enter" "ladder 1: print-enter paste-block"
has  "$SEAM" "HERDR_ENV=1" "ladder 2: inside-mux env HERDR_ENV=1"
hasC "$SEAM" "TMUX" "ladder 2: inside-mux env TMUX"
hasE "$SEAM" "does not wrap or detect" "ladder 2: flow does not wrap or detect the mux"
hasE "$SEAM" "serial.{0,20}one card|serial: one card" "ladder 3: serial, one card"

# Gate parity: host idle/done/blocked is not a card pass; check in the card worktree.
hasE "$SEAM" "not a card pass" "gate parity: host idle/done/blocked is not a card pass"
has  "$SEAM" "flow.sh check" "gate parity: flow.sh check still judges"
hasE "$SEAM" "card's worktree|card worktree" "gate parity: check runs in the card worktree"
has  "$SEAM" "host-blocked" "four blocked: host-blocked"
has  "$SEAM" "subagent-BLOCKED" "four blocked: subagent-BLOCKED"
has  "$SEAM" "ready-blocked" "four blocked: ready-blocked"
hasE "$SEAM" "Tier-C security halt" "four blocked: Tier-C security halt"

# File-is-the-wait: the HOST waits; flow.sh never waits on or polls another agent.
has  "$SEAM" "File-is-the-wait" "file-is-the-wait section named"
hasE "$SEAM" "HOST waits" "file-is-the-wait: the HOST waits"
hasE "$SEAM" "never waits on or polls" "file-is-the-wait: flow.sh never waits on or polls"

# Forbidden verbs appear as forbidden (clause-bound, not bare presence).
hasE "$SEAM" "must not exec.{0,80}herdr agent start" "forbidden: herdr agent start"
hasE "$SEAM" "must not exec.{0,120}herdr agent wait" "forbidden: herdr agent wait"
hasE "$SEAM" "must not exec.{0,180}herdr agent prompt" "forbidden: herdr agent prompt"
hasE "$SEAM" "must not exec.{0,220}herdr server stop" "forbidden: herdr server stop"
hasE "$SEAM" "must not exec.{0,200}tmux send-keys" "forbidden: tmux send-keys"
hasE "$SEAM" "Forbidden by name.{0,40}mux-up" "forbidden by name: mux-up"
hasE "$SEAM" "Forbidden by name.{0,80}mux-run-wave" "forbidden by name: mux-run-wave"
hasE "$SEAM" "Forbidden by name.{0,120}mux-proxy" "forbidden by name: mux-proxy"
hasE "$SEAM" "No screen output as evidence|screen output is not evidence" "forbidden: screen output as evidence"
hasE "$SEAM" "hook install into.{0,30}~/.claude" "forbidden: hook home ~/.claude"
hasE "$SEAM" "hook install into.{0,50}~/.omp" "forbidden: hook home ~/.omp"
hasE "$SEAM" "socket subscribe" "forbidden: long-lived socket subscribe"
has  "$SEAM" "events.subscribe" "forbidden: events.subscribe named"
hasE "$SEAM" "never.{0,20}command -v herdr|command -v herdr.{0,40}from outside" "forbidden: command -v herdr from outside"

# Pointers (one home; do not copy recipes).
has  "$SKILL" "host-agnostic-parallel" "SKILL.md points to the reference"
has  "$REF/auto-run.md" "host-agnostic-parallel.md" "auto-run.md Parallel groups points at the home"
has  "$REF/agent-detection.md" "host-agnostic-parallel.md" "agent-detection.md points at the home"

# Parked own-runtime: Deferred list of ADR-0001, not a card in this skill.
has  "$ADR" "flow-orch" "ADR Deferred: flow-orch named"
hasE "$ADR" "SEPARATE product" "ADR Deferred: SEPARATE product"
hasE "$ADR" "flow-orch.{0,200}tripwire 5" "ADR Deferred: flow-orch line carries tripwire 5"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
