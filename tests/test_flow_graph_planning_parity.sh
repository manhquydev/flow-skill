#!/usr/bin/env bash
# Planning consumer (Phase 5): legacy-vs-executor parity across every cmd_next exit path,
# the two-level debt-skip guard (index contiguity + no re-scaffold), planning-lane session
# separation, and fail-closed behavior when the harness is unavailable.
# Requires python. Run: bash tests/test_flow_graph_planning_parity.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
RUN="$HERE/../skills/flow/runner/flow.sh"
PY="$(command -v python || command -v python3)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]: $(printf '%.140s' "$1")"; fail=$((fail+1)); fi; }
no() { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] unexpected /$2/"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

# Make every stage file gate-clean: tick boxes and remove [FILL ...] spans (which are
# MULTI-LINE in the real templates, so a per-line regex cannot see the closing bracket).
fill_stages() { # $1 = dir holding flow/*.md
  "$PY" - "$1" <<'PYEOF'
import pathlib, re, sys
for f in sorted(pathlib.Path(sys.argv[1], "flow").glob("*.md")):
    t = f.read_text(encoding="utf-8")
    t = t.replace("- [ ]", "- [x]")
    t = re.sub(r"\[FILL.*?\]", "filled", t, flags=re.S)
    f.write_text(t, encoding="utf-8")
PYEOF
}

# Walk 00->05 in a sandbox, filling each stage so its gate passes. Echoes the
# "stage:file-created" transition per step so both modes can be compared byte-for-byte.
walk() { # $1 = sandbox, $2 = "on"|"off" (executor flag)
  local sb="$1" mode="$2" out="" line
  ( cd "$sb" && for i in 1 2 3 4 5 6 7; do
      if [ "$mode" = on ]; then FLOW_GRAPH_EXECUTOR=1 bash "$RUN" next; else bash "$RUN" next; fi
      rc=$?
      fill_stages "$sb"
      echo "step$i rc=$rc files=$(ls flow/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ',')"
    done )
}

echo "A) legacy vs executor: identical transitions across the full ladder"
SB1="$(mktemp -d)"; SB2="$(mktemp -d)"
W1="$(walk "$SB1" off)"
W2="$(walk "$SB2" on)"
ck "$W1" "$W2" "every cmd_next step produces the same rc + same scaffolded files"
has "$W1" "05-contract.md" "the ladder reaches 05-contract"
rm -rf "$SB1" "$SB2"

echo "B) debt-skip: index advances, stage is NOT re-created, planning completes"
SB="$(mktemp -d)"; cd "$SB" || exit 1
# Walk to 02-scope so 03-prd has NOT been scaffolded yet - that is the real shape of a
# debt skip (you skip the stage before it is created, not after).
bash "$RUN" next >/dev/null 2>&1          # creates 00
for i in 1 2; do                           # creates 01, then 02
  fill_stages "$SB"
  bash "$RUN" next >/dev/null 2>&1
done
fill_stages "$SB"
ck "0" "$([ -f flow/03-prd.md ] && echo 1 || echo 0)" "03-prd not scaffolded yet (pre-skip state)"
printf -- '- [ ] DEBT: skip 03-prd -- small tool, no product surface -- close before: v2 -- opened 2026-07-26\n' > DEBT.md
SK="$(bash "$RUN" skip 03-prd --reason "small internal tool, no product surface" 2>&1)"
has "$SK" "debt-skipped" "cmd_skip accepts the debt-recorded skip"
ck "1" "$([ -f flow/04-adr.md ] && echo 1 || echo 0)" "cmd_skip scaffolds the SUCCESSOR (04-adr), never the skipped stage"
ck "0" "$([ -f flow/03-prd.md ] && echo 1 || echo 0)" "the skipped stage itself is not created"
fill_stages "$SB"
N1="$(bash "$RUN" next 2>&1)"
no  "$N1" "unlocked stage 3" "next does NOT re-scaffold the skipped 03-prd"
ck "0" "$([ -f flow/03-prd.md ] && echo 1 || echo 0)" "03-prd.md still absent after next (skip respected)"
has "$N1" "05-contract\|already exists" "next advanced past the skip to 05-contract"
fill_stages "$SB"
N2="$(bash "$RUN" next 2>&1)"
has "$N2" "Planning is COMPLETE" "planning_complete() true with a debt-skipped stage"
CARD="$(bash "$RUN" card 2>&1)"
no "$CARD" "planning not complete" "/flow card unlocks after the skip"
ST="$(bash "$RUN" status 2>&1)"
has "$ST" "04-adr\|05-contract" "status reports a post-skip stage, not the pinned pre-skip one"
cd /; rm -rf "$SB"

echo "C) executor mode records planning boundaries in the planning lane"
SB="$(mktemp -d)"; cd "$SB" || exit 1
export FLOW_GRAPH_EXECUTOR=1
bash "$RUN" next >/dev/null 2>&1
for i in 1 2; do
  fill_stages "$SB"
  bash "$RUN" next >/dev/null 2>&1
done
K="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print("|".join(f"{k}:{n}" for k,n in c.execute(
  "SELECT e.kind, COUNT(cp.checkpoint_id) FROM graph_execution e "
  "LEFT JOIN graph_checkpoint cp ON cp.execution_id=e.id GROUP BY e.kind ORDER BY e.kind")))
EOF
)"
has "$K" "planning:" "a planning-lane execution exists"
NSR="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT COUNT(*) FROM graph_checkpoint WHERE ns=''").fetchone()[0])
EOF
)"
[ "$NSR" -ge 1 ]; ck 0 $? "stage boundaries journaled in the root namespace ($NSR)"
NODES="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(",".join(r[0] for r in c.execute(
  "SELECT node FROM graph_checkpoint WHERE ns='' ORDER BY checkpoint_id")))
EOF
)"
has "$NODES" "stage-0" "recorded node ids are topology stage nodes"
BEFORE_N="$(printf '%s' "$NODES" | tr ',' '\n' | grep -c .)"
bash "$RUN" next >/dev/null 2>&1; bash "$RUN" next >/dev/null 2>&1
AFTER_N="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT COUNT(*) FROM graph_checkpoint WHERE ns=''").fetchone()[0])
EOF
)"
ck "$BEFORE_N" "$AFTER_N" "re-running next with unchanged evidence records NOTHING (boundary, not heartbeat)"

echo "C2) a blocked earlier stage is never journaled as planning-complete"
SBB="$(mktemp -d)"; cd "$SBB" || exit 1
export FLOW_GRAPH_EXECUTOR=1
bash "$RUN" next >/dev/null 2>&1
for i in 1 2 3 4 5; do
  fill_stages "$SBB"
  bash "$RUN" next >/dev/null 2>&1
done
fill_stages "$SBB"          # 05-contract was created by the last next; make it clean too
# now re-block an EARLIER stage: the current stage passes, an earlier one does not
printf '\n- [ ] deliberately unchecked\n' >> flow/02-scope.md
OUTB="$(bash "$RUN" next 2>&1)"
has "$OUTB" "earlier stage is still BLOCKED" "flow.sh reports the blocked earlier stage"
PEID="$(FLOW_PROJECT_ROOT="$SBB" "$PY" "$H" graph session --kind planning)"
GN="$(FLOW_PROJECT_ROOT="$SBB" "$PY" "$H" graph next --execution "$PEID" 2>/dev/null)"; grc=$?
no "$GN" "^$" "executor does not answer complete for a blocked project"
ck "0" "$grc" "graph next still advises a node (rc 0), never rc 3 while blocked"
unset FLOW_GRAPH_EXECUTOR
cd /; rm -rf "$SBB"
cd "$SB" || exit 1
export FLOW_GRAPH_EXECUTOR=1
unset FLOW_GRAPH_EXECUTOR
cd /; rm -rf "$SB"

echo "D) fail-closed: harness disabled never fabricates progress"
SB="$(mktemp -d)"; cd "$SB" || exit 1
D1="$(FLOW_GRAPH_EXECUTOR=1 FLOW_HARNESS_DISABLE=1 bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "next still works with the durable layer disabled (engine is the floor)"
has "$D1" "unlocked stage 00" "legacy ladder behavior preserved"
ck "0" "$([ -f .flow/harness.db ] && echo 1 || echo 0)" "no DB minted when the harness is disabled"
cd /; rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
