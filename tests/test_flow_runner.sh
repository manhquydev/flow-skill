#!/usr/bin/env bash
# Regression suite for skills/flow/runner/flow.sh (Phase 1 engine).
# Run: bash tests/test_flow_runner.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected $1 got $2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }

stage_clean() { printf '#%s\n## Gate\n- [x] honestly done\n\nreal content.\n' "$1" > "$2"; }

echo "A) gap-bypass must NOT report planning complete"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"
printf '#00\n## Gate\n- [x] ok\n' > "$SB/flow/00-idea.md"
printf '#05\n## Gate\n- [x] ok\n' > "$SB/flow/05-contract.md"   # stray future stage
has "$(bash "$RUN" next)" "unlocked stage 1" "next advances 00->01, ignores stray 05"
bash "$RUN" card >/dev/null 2>&1; ck 1 $? "card blocked while stages 01-04 missing"
rm -rf "$SB"

echo "B) start + dirty-gate fail + clean-gate advance"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB"
bash "$RUN" next >/dev/null; ck 0 $? "next starts stage 00"
bash "$RUN" next >/dev/null 2>&1; ck 1 $? "fresh template (FILL) fails gate"
stage_clean "Idea" "$SB/flow/00-idea.md"
bash "$RUN" next >/dev/null; ck 0 $? "clean stage 00 advances to 01"
rm -rf "$SB"

echo "C) ### wrong-heading-level rejected; required sections enforced"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
printf '# C-001 — x\nstatus: todo\ndeps: none\n### Scope\nx\n## Allowed files\ny\n## Verify (run)\n- [ ] z\n## Done-evidence (x)\nw\n## Evidence (paste)\n(empty until done)\n' > "$SB/cards/C-001.md"
out="$(bash "$RUN" check C-001)"; rc=$?
has "$out" "missing section: ## Scope" "### Scope does not satisfy ## Scope"
ck 1 $rc "malformed card -> exit 1"
rm -rf "$SB"

echo "D) done-card gates: empty/--- evidence + unchecked verify fail; real evidence passes"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
mkcard() { # $1 status $2 verifybox $3 evidence
  printf '# C-001 — scaffold\nstatus: %s\ndeps: none\n## Scope\none thing\n## Allowed files\ninfra/\n## Verify (run these before calling the card done)\n- [%s] curl 200\n## Done-evidence (world-state proof)\nurl\n## Evidence (paste the actual proof here when done)\n%s\n' "$1" "$2" "$3" > "$SB/cards/C-001.md"
}
mkcard done " " "(empty until done)"; bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "done + empty evidence + unchecked verify fails"
mkcard done "x" "---"; bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "done + '---' evidence fails"
mkcard done "x" '$ curl https://x/healthz -> {"ok":true}'; bash "$RUN" check C-001 >/dev/null 2>&1; ck 0 $? "done + checked verify + real evidence passes"
mkcard todo " " "(empty until done)"; bash "$RUN" check C-001 >/dev/null 2>&1; ck 0 $? "todo card with no FILL passes"
rm -rf "$SB"

echo "E) full happy E2E + ready resolves short dep id"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow" "$SB/cards"
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do stage_clean "$s" "$SB/flow/$s.md"; done
bash "$RUN" card >/dev/null; ck 0 $? "card after planning complete"
printf '# C-001 — base\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\na.py\n## Verify\n- [x] x\n## Done-evidence\nu\n## Evidence\nreal proof\n' > "$SB/cards/C-001.md"
printf '# C-002 — next\nstatus: todo\ndeps: C-1\n## Scope\nb\n## Allowed files\nb.py\n## Verify\n- [ ] y\n## Done-evidence\nu\n## Evidence\n(empty until done)\n' > "$SB/cards/C-002.md"
has "$(bash "$RUN" ready)" "BUILDABLE C-002" "short dep id C-1 resolves to done C-001"
rm -rf "$SB"

echo "F) _python: returns non-zero exit when no python3/python on PATH; exit 0 + path when present"
# Extract _python directly from flow.sh so the test tracks the real implementation.
# Sourcing the full script is unsafe (triggers dispatch); sed-extract + eval is the clean approach.
_PYTHON_DEF="$(sed -n '/^_python()/,/^}/p' "$RUN")"
# No-interpreter case: shadow PATH inside the subshell after bash itself is loaded.
no_py_out="$(bash -c "PATH=/nonexistent; $_PYTHON_DEF; _python; echo exit=\$?")"
ck "exit=1" "$(printf '%s' "$no_py_out" | grep 'exit=')" "_python exit is non-zero when no interpreter on PATH"
ck "" "$(printf '%s' "$no_py_out" | grep -v 'exit=')" "_python stdout is empty when no interpreter found"
# Real-interpreter case: current shell has python available (skip gracefully if truly absent).
real_py="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
if [ -n "$real_py" ]; then
  real_out="$(bash -c "$_PYTHON_DEF; _python; echo exit=\$?")"
  real_path="$(printf '%s' "$real_out" | grep -v 'exit=')"
  real_exit="$(printf '%s' "$real_out" | grep 'exit=')"
  ck "exit=0" "$real_exit" "_python exit 0 when real python present"
  has "$real_path" "python" "_python prints interpreter path when present"
else
  echo "  skip [_python real-interpreter checks] (no python on this PATH)"
fi

echo "G) advisory probe tempdir cleaned even when interrupted (SIGINT) — tempdir-leak guard"
# Run cmd_coherence in a background subshell under a controlled TMPDIR so mktemp -d creates
# dirs there. Send SIGINT immediately; the EXIT trap (_cleanup_tds) fires and removes them.
# A package.json with a version field ensures the tempdir is actually created before the kill.
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
printf '{"name":"t","version":"1.0.0"}\n' > "$SB/package.json"
MY_TMPDIR="$(mktemp -d)"                           # isolated tempdir root for this test
leftover=""
TMPDIR="$MY_TMPDIR" bash "$RUN" coherence >/dev/null 2>&1 &
bgpid=$!
# Wait until the subshell ACTUALLY creates its tempdir (poll w/ timeout), THEN interrupt — a
# fixed sleep could fire before `mktemp -d` on a slow host and false-green without exercising
# cleanup. End-state ("no leftover") holds whether SIGINT lands mid-run or it completed normally.
waited=0
while [ -z "$(ls "$MY_TMPDIR" 2>/dev/null)" ] && [ "$waited" -lt 100 ]; do sleep 0.05; waited=$((waited+1)); done
kill -INT "$bgpid" 2>/dev/null; wait "$bgpid" 2>/dev/null || true
leftover="$(ls "$MY_TMPDIR" 2>/dev/null)"
if [ -z "$leftover" ]; then
  echo "  ok   [advisory probe tempdir_leak_on_sigint: no leftover under controlled TMPDIR]"; pass=$((pass+1))
else
  echo "  FAIL [advisory probe tempdir_leak_on_sigint: leftover dirs: $leftover]"; fail=$((fail+1))
fi
rm -rf "$SB" "$MY_TMPDIR"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]