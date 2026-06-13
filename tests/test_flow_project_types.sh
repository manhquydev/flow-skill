#!/usr/bin/env bash
# Tests for project-type awareness + skip-with-debt (the dogfood v2 features).
# Run: bash tests/test_flow_project_types.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skill/flow/runner/flow.sh"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected $1 got $2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }
stage_clean() { printf '#%s\n## Gate\n- [x] ok\n\nreal.\n' "$1" > "$2"; }

echo "A) project-type get/set + per-type done-evidence"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
has "$(bash "$RUN" project-type)" "project type: web" "defaults to web"
bash "$RUN" project-type cli >/dev/null; ck 0 $? "set cli"
has "$(bash "$RUN" project-type)" "exit code" "cli done-evidence = install + invoke + exit code"
has "$(bash "$RUN" project-type)" "project type: cli" "persists as cli"
bash "$RUN" project-type skill >/dev/null; has "$(bash "$RUN" project-type)" "~/.claude/skills" "skill done-evidence = install + real run"
bash "$RUN" project-type bogus >/dev/null 2>&1; ck 1 $? "invalid type rejected"
has "$(bash "$RUN" status)" "type:    skill" "status shows project type"
rm -rf "$SB"

echo "B) skip requires an open DEBT, refuses security-class, advances when valid"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"
bash "$RUN" next >/dev/null                       # stage 00
stage_clean Idea "$SB/flow/00-idea.md"; bash "$RUN" next >/dev/null  # -> 01 (fresh, blocked)
bash "$RUN" skip 01-research --reason "internal tool" >/dev/null 2>&1; ck 1 $? "skip fails with no open DEBT"
bash "$RUN" debt add "skip 01-research" "no public market" "before public release" >/dev/null
bash "$RUN" skip 01-research --reason "auth tokens involved" >/dev/null 2>&1; ck 1 $? "security-class reason blocked"
out="$(bash "$RUN" skip 01-research --reason "internal tool, no public market")"; rc=$?
ck 0 $rc "valid skip advances"
has "$out" "debt-skipped" "skip logs + advances"
ck 0 "$([ -f "$SB/flow/.skipped" ] && echo 0 || echo 1)" ".skipped marker written"
rm -rf "$SB"

echo "C) planning_complete tolerates a debt-skipped stage -> card unblocks; next/card agree"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"
# all stages clean EXCEPT 01 which we will debt-skip
for s in 00-idea 02-scope 03-prd 04-adr 05-contract; do stage_clean "$s" "$SB/flow/$s.md"; done
printf '#01\n## Gate\n- [ ] cannot honestly satisfy\n' > "$SB/flow/01-research.md"   # genuinely blocked
bash "$RUN" card >/dev/null 2>&1; ck 1 $? "card blocked while 01 is dirty (not skipped)"
bash "$RUN" debt add "skip 01-research" "no market" "before release" >/dev/null
bash "$RUN" skip 01-research --reason "internal tool" >/dev/null
bash "$RUN" card >/dev/null 2>&1; ck 0 $? "card unblocks after legitimate debt-skip"
has "$(bash "$RUN" next)" "COMPLETE" "next reports COMPLETE consistently with card"
rm -rf "$SB"

echo "D) skip hardening: stage-matched DEBT, contract never skipped, paraphrase caught, no-file skip"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"
# DEBT for a DIFFERENT stage must NOT unlock skip of another (HIGH-1)
bash "$RUN" debt add "skip 03-prd" "x" "later" >/dev/null
bash "$RUN" skip 01-research --reason "no public market" >/dev/null 2>&1; ck 1 $? "skip blocked when no DEBT names THIS stage"
bash "$RUN" debt add "skip 01-research" "no market" "release" >/dev/null
bash "$RUN" skip 01-research --reason "no public market" >/dev/null 2>&1; ck 0 $? "skip works when a stage-matched DEBT exists"
# the contract (05) is never skippable (HIGH-2 primary guard)
bash "$RUN" debt add "skip 05-contract" "x" "later" >/dev/null
bash "$RUN" skip 05-contract --reason "no time" >/dev/null 2>&1; ck 1 $? "contract stage 05 can never be skipped"
# paraphrased security reason still caught (HIGH-2 broadened list)
bash "$RUN" debt add "skip 04-adr" "x" "later" >/dev/null
bash "$RUN" skip 04-adr --reason "RBAC permission layer deferred" >/dev/null 2>&1; ck 1 $? "paraphrased security reason (rbac/permission) blocked"
rm -rf "$SB"
# planning_complete tolerates a skipped stage that has NO file (MEDIUM-1)
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"
for s in 00-idea 02-scope 03-prd 04-adr 05-contract; do stage_clean "$s" "$SB/flow/$s.md"; done   # 01 absent entirely
bash "$RUN" debt add "skip 01-research" "no market" "release" >/dev/null
bash "$RUN" skip 01-research --reason "internal tool" >/dev/null
bash "$RUN" card >/dev/null 2>&1; ck 0 $? "card unblocks even when the skipped stage file never existed"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]