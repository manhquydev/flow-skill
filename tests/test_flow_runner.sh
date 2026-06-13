#!/usr/bin/env bash
# Regression suite for skill/flow/runner/flow.sh (Phase 1 engine).
# Run: bash tests/test_flow_runner.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skill/flow/runner/flow.sh"
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

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]