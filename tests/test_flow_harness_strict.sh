#!/usr/bin/env bash
# STRICT durable write honesty (plan phase 2 D5). Run: bash tests/test_flow_harness_strict.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
PY="$(command -v python || command -v python3)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }

echo "A) python: bare implemented rejected"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" story add --id S1 --title t --lane normal >/dev/null
rc=0
out="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" story update --id S1 --status implemented 2>&1)" || rc=$?
ck 1 "$rc" "bare implemented rejected"
has "$out" "story complete" "guides to story complete"
rm -rf "$SB"

echo "B) soft: check-done durable fail still exits 0 with warn (missing story id path uses complete)"
# Force durable complete fail by using check on done card without prior story add → complete may add? 
# Actually complete fails if story not found. check done still returns 0 soft.
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
unset FLOW_HARNESS_DISABLE
unset FLOW_HARNESS_STRICT
printf '# C-001\nstatus: done\ndeps: none\n## Scope\nx\n## Allowed files\nx\n## Verify\n- [x] x\n## Done-evidence\nu\n## Evidence\nproof here\n' > "$SB/cards/C-001.md"
# init empty harness so complete fails not-found
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
errf="$(mktemp)"
rc=0
bash "$RUN" check C-001 >/dev/null 2>"$errf" || rc=$?
ck 0 "$rc" "soft check still exit 0 when complete misses story"
has "$(cat "$errf")" "flow-harness: warn" "soft path prints warn token"
rm -rf "$SB" "$errf"

echo "C) STRICT=fail: check-done fails when durable complete fails"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
unset FLOW_HARNESS_DISABLE
export FLOW_HARNESS_STRICT=fail
printf '# C-001\nstatus: done\ndeps: none\n## Scope\nx\n## Allowed files\nx\n## Verify\n- [x] x\n## Done-evidence\nu\n## Evidence\nproof here\n' > "$SB/cards/C-001.md"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
rc=0
out="$(bash "$RUN" check C-001 2>&1)" || rc=$?
ck 1 "$rc" "STRICT=fail check exits nonzero when story missing"
has "$out" "STRICT=fail|durable" "mentions durable fail"
unset FLOW_HARNESS_STRICT
rm -rf "$SB"

echo "D) STRICT=1: loud fail message, soft exit when story present succeeds quietly"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
unset FLOW_HARNESS_DISABLE
export FLOW_HARNESS_STRICT=1
printf '# C-001\nstatus: done\ndeps: none\n## Scope\nx\n## Allowed files\nx\n## Verify\n- [x] x\n## Done-evidence\nu\n## Evidence\nproof here\n' > "$SB/cards/C-001.md"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" story add --id C-001 --title C-001 --lane normal >/dev/null
rc=0
out="$(bash "$RUN" check C-001 2>&1)" || rc=$?
ck 0 "$rc" "STRICT=1 success still exit 0"
# no warn on success
if printf '%s' "$out" | grep -q 'flow-harness: warn'; then
  echo "  FAIL [no warn on success]"; fail=$((fail+1))
else
  echo "  ok   [no warn on success]"; pass=$((pass+1))
fi
unset FLOW_HARNESS_STRICT
rm -rf "$SB"

echo "E) complete without proof-source fails at python"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" story add --id S1 --title t --lane normal >/dev/null
rc=0
out="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" story complete --id S1 2>&1)" || rc=$?
ck 1 "$rc" "complete without proof-source fails"
has "$out" "proof-source" "mentions proof-source"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
