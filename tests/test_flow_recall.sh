#!/usr/bin/env bash
# Regression suite for `flow.sh recall` (read-back of durable memory: close capture->reuse loop).
# Run: bash tests/test_flow_recall.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
newsb() { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB"; }

echo "A) empty project -> recall runs, says no project history, surfaces skill playbooks (cross-project)"
newsb
out="$(FLOW_HARNESS_DISABLE=1 bash "$RUN" recall 2>&1)"; rc=$?
ck 0 "$rc" "recall exit 0 on empty project"
has "$out" "no project-specific history" "empty-project message shown"
has "$out" "PLAYBOOKS available" "skill playbooks surfaced even for a fresh project"
no  "$out" "  - README" "README excluded from the playbook list"
rm -rf "$SB"

echo "B) open DEBT is read back"
newsb
printf '# DEBT\n\n- [ ] DEBT: skip 01-research -- exposure X -- close before: demo -- opened 2026-06-14\n' > "$SB/DEBT.md"
out="$(FLOW_HARNESS_DISABLE=1 bash "$RUN" recall 2>&1)"
has "$out" "OPEN DEBT" "debt section shown"
has "$out" "skip 01-research" "the open debt line is shown"
rm -rf "$SB"

echo "C) recent RETRO lines read back (only entries after the --- separator)"
newsb
printf '# Retro\n\ntemplate instructions here\n\n---\n\nrushed the contract gate, cost a re-plan\n' > "$SB/RETRO.md"
out="$(FLOW_HARNESS_DISABLE=1 bash "$RUN" recall 2>&1)"
has "$out" "RECENT RETRO" "retro section shown"
has "$out" "rushed the contract gate" "the retro entry is shown"
no  "$out" "template instructions" "pre--- template text is not surfaced as a lesson"
rm -rf "$SB"

echo "D) previous-card intelligence = most recent DONE card (not a later todo)"
newsb; mkdir -p "$SB/cards"
printf '# C-001 - base feature\nstatus: done\ndeps: none\n## Scope\nbuild the thing carefully\n## Allowed files\nx\n' > "$SB/cards/C-001.md"
printf '# C-002 - next\nstatus: todo\ndeps: none\n## Scope\nnot done yet\n## Allowed files\ny\n' > "$SB/cards/C-002.md"
out="$(FLOW_HARNESS_DISABLE=1 bash "$RUN" recall 2>&1)"
has "$out" "PREVIOUS CARD" "previous-card section shown"
has "$out" "last done: C-001" "names the most recent DONE card, not the todo one"
has "$out" "build the thing carefully" "carries the prior card's Scope forward"
no  "$out" "not done yet" "does not pull Scope from a still-todo card"
rm -rf "$SB"

echo "E) graceful without harness (FLOW_HARNESS_DISABLE) but markdown still read"
newsb
printf '# DEBT\n\n- [ ] DEBT: x -- y -- close before: z -- opened 2026-06-14\n' > "$SB/DEBT.md"
out="$(FLOW_HARNESS_DISABLE=1 bash "$RUN" recall 2>&1)"; rc=$?
ck 0 "$rc" "recall exit 0 with harness disabled"
has "$out" "OPEN DEBT" "markdown ledgers still read back without the harness"
no  "$out" "FRICTION recorded" "no harness section when the durable layer is disabled"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
