#!/usr/bin/env bash
# Deterministic auto-path / hand-edit done scenarios (no LLM).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
export FLOW_HARNESS_DISABLE=1
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected $1 got $2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }

GPASS='$ curl https://x/healthz -> 200 PASS healthcheck'

scaffold_plan() {
  mkdir -p "$SB/flow" "$SB/cards"
  for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
    printf '#%s\n## Gate\n- [x] ok\n\nbody\n' "$s" > "$SB/flow/$s.md"
  done
}

echo "A) hand-edit done + hollow never re-check → ready blocks dependent"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; scaffold_plan
printf '# C-001\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\na.py\n## Verify\n- [x] v\n## Done-evidence\nu\n## Evidence\nMerged PR with two approvals; CI green; release notes updated.\n' > "$SB/cards/C-001.md"
printf '# C-002\nstatus: todo\ndeps: C-001\n## Scope\nb\n## Allowed files\nb.py\n## Verify\n- [ ] v\n## Done-evidence\nu\n## Evidence\n(empty until done)\n' > "$SB/cards/C-002.md"
out="$(bash "$RUN" ready 2>&1)"; ck 0 $? "ready exits 0"
has "$out" "blocked" "ready reports blocked dependent"
has "$out" "C-002" "ready mentions C-002"
if printf '%s' "$out" | grep -qE 'world-state signal|Evidence fails'; then echo "  ok   [ready notes evidence floor]"; pass=$((pass+1)); else echo "  FAIL [ready notes evidence floor]"; fail=$((fail+1)); fi
printf '%s' "$out" | grep -q "BUILDABLE C-002" && ck 1 0 "must not BUILDABLE" || ck 0 0 "hand-edit hollow does not unblock"
# unchecked Verify + multi-signal evidence still must not unblock
printf '# C-001\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\na.py\n## Verify\n- [ ] not run\n## Done-evidence\nu\n## Evidence\n%s\n' "$GPASS" > "$SB/cards/C-001.md"
out="$(bash "$RUN" ready 2>&1)"
printf '%s' "$out" | grep -q "BUILDABLE C-002" && ck 1 0 "unchecked verify must not BUILDABLE" || ck 0 0 "unchecked verify does not unblock"
rm -rf "$SB"

echo "B) check PASS on G-PASS; FAIL on process-only"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
printf '# C-001\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\na.py\n## Verify\n- [x] v\n## Done-evidence\nu\n## Evidence\n%s\n' "$GPASS" > "$SB/cards/C-001.md"
bash "$RUN" check C-001 >/dev/null; ck 0 $? "G-PASS check"
printf '# C-001\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\na.py\n## Verify\n- [x] v\n## Done-evidence\nu\n## Evidence\nCI pipeline green and teammates approved the pull request.\n' > "$SB/cards/C-001.md"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "process-only check fail"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
