#!/usr/bin/env bash
# Graph executor conformance (Phase 2): PUT round-trip, step-write ordering, latest-vs-exact,
# newest-first ids, skip-substitution traversal (single + chained), interrupt guard matrix
# (security-class x DEBT x target x actor audit), exit-code contract (0/3/4/1), abandon/gc,
# _db transaction semantics. Requires python (stdlib sqlite3); git for the guard matrix.
# Run: bash tests/test_flow_graph_executor.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
PY="$(command -v python3 || command -v python)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]: $(printf '%.100s' "$1")"; fail=$((fail+1)); fi; }

SB="$(mktemp -d)"
export FLOW_GRAPH_TOPOLOGY_FIXTURE=1
export FLOW_PROJECT_ROOT="$SB"
"$PY" "$H" init >/dev/null
DB="$SB/.flow/harness.db"
TOPO="$SB/topo.json"
cat > "$TOPO" <<'EOF'
{"topology_version":1,"entry":["stage-00"],
 "nodes":{"stage-00":{"type":"gate_check","stage":"00-idea"},
          "stage-01":{"type":"gate_check","stage":"01-research"},
          "stage-02":{"type":"gate_check","stage":"02-scope"},
          "stage-03":{"type":"gate_check","stage":"03-prd"},
          "stage-04":{"type":"gate_check","stage":"04-adr"},
          "stage-05":{"type":"gate_check","stage":"05-contract"}},
 "edges":[{"from":"stage-00","to":"stage-01"},{"from":"stage-01","to":"stage-02"},
          {"from":"stage-02","to":"stage-03"},{"from":"stage-03","to":"stage-04"},
          {"from":"stage-04","to":"stage-05"}]}
EOF

echo "A) run + record: PUT round-trip + step-write ordering"
EID="$("$PY" "$H" graph run --kind planning)"; ck 0 $? "graph run exits 0"
[ -n "$EID" ]; ck 0 $? "run prints an execution id"
CK1="$("$PY" "$H" graph record --execution "$EID" --node stage-00 \
  --manifest '{"gate":{"exit":0}}' \
  --writes '[{"task":"t","channel":"a","value":1},{"task":"t","channel":"b","value":2}]')"
ck 0 $? "record exits 0"
A="$("$PY" - "$DB" "$EID" <<'EOF'
import json,sqlite3,sys
c=sqlite3.connect(sys.argv[1]); c.row_factory=sqlite3.Row
r=c.execute("SELECT * FROM graph_checkpoint WHERE execution_id=?",(sys.argv[2],)).fetchone()
w=[ (x["idx"],x["channel"]) for x in c.execute(
    "SELECT idx,channel FROM graph_step_write WHERE execution_id=? ORDER BY idx",(sys.argv[2],))]
print(json.loads(r["manifest"])=={"gate":{"exit":0}},
      json.loads(r["versions"])=={"stage-00":1},
      json.loads(r["seen"])=={"stage-00":{"stage-00":1}}, w)
EOF
)"
has "$A" "True True True" "manifest/versions/seen round-trip exactly"
has "$A" "(0, 'a'), (1, 'b')" "step writes preserve (task, idx) order"

echo "B) latest-vs-exact + newest-first ids"
CK2="$("$PY" "$H" graph record --execution "$EID" --node stage-01 --manifest '{"gate":{"exit":0}}')"
S="$("$PY" "$H" graph status --execution "$EID")"
has "$S" '"node": "stage-01"' "status shows the LATEST node"
B="$("$PY" - "$DB" "$EID" "$CK1" "$CK2" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
exact=c.execute("SELECT node FROM graph_checkpoint WHERE execution_id=? AND checkpoint_id=?",
                (sys.argv[2],sys.argv[3])).fetchone()
print(exact[0], sys.argv[4] > sys.argv[3])
EOF
)"
has "$B" "stage-00 True" "exact checkpoint still addressable; ids sort newest-first"

echo "C) next: advance + terminal exit 3"
N="$("$PY" "$H" graph next --execution "$EID" --topology "$TOPO")"
ck "stage-02" "$N" "next follows the topology from the latest node"
for n in stage-02 stage-03 stage-04 stage-05; do
  "$PY" "$H" graph record --execution "$EID" --node "$n" --manifest '{"gate":{"exit":0}}' >/dev/null
done
"$PY" "$H" graph next --execution "$EID" --topology "$TOPO" >/dev/null 2>&1
ck 3 $? "no successors -> exit 3 (complete)"

echo "D) skip-substitution: single + chained (traversal semantic, no bypass edges)"
mkdir -p "$SB/flow"; printf '03-prd\n' > "$SB/flow/.skipped"
E2="$("$PY" "$H" graph run --kind planning)"
for n in stage-00 stage-01 stage-02; do
  "$PY" "$H" graph record --execution "$E2" --node "$n" --manifest '{"gate":{"exit":0}}' >/dev/null
done
N2="$("$PY" "$H" graph next --execution "$E2" --topology "$TOPO")"
ck "stage-04" "$N2" "single skip: 02 -> 04 (03 debt-skipped)"
printf '02-scope\n03-prd\n' > "$SB/flow/.skipped"
E3="$("$PY" "$H" graph run --kind planning)"
for n in stage-00 stage-01; do
  "$PY" "$H" graph record --execution "$E3" --node "$n" --manifest '{"gate":{"exit":0}}' >/dev/null
done
N3="$("$PY" "$H" graph next --execution "$E3" --topology "$TOPO")"
ck "stage-04" "$N3" "chained skips: 01 -> 04 (02 AND 03 debt-skipped, transitive)"
echo "D2) a skipped gate is accepted-with-debt: its GREEN out-edges are taken"
T2="$SB/topo2.json"
cat > "$T2" <<'EOF'
{"topology_version":1,"entry":["s0"],
 "nodes":{"s0":{"type":"gate_check","stage":"00-idea"},
          "s1":{"type":"gate_check","stage":"01-research"},
          "s2":{"type":"record_evidence"},"s1red":{"type":"record_evidence"}},
 "edges":[{"from":"s0","to":"s1"},
          {"from":"s1","to":"s2","when":"review_green"},
          {"from":"s1","to":"s1red","when":"review_red"}]}
EOF
printf '01-research\n' > "$SB/flow/.skipped"
E4="$("$PY" "$H" graph run --kind planning)"
"$PY" "$H" graph record --execution "$E4" --node s0 --manifest '{"gate":{"exit":0}}' >/dev/null
N4="$("$PY" "$H" graph next --execution "$E4" --topology "$T2")"
ck "s2" "$N4" "skip substitution takes the green edge, never red, never false-complete"
rm -f "$SB/flow/.skipped"

echo "E) interrupt guard matrix"
if command -v git >/dev/null 2>&1; then
  git -C "$SB" init -q
  printf -- '- [ ] DEBT: skip C-001 -- exposure noted -- close before: ship -- opened 2026-07-26\n' > "$SB/DEBT.md"
  EI="$("$PY" "$H" graph run --kind card)"
  "$PY" "$H" graph record --execution "$EI" --node card-review --interrupt --security-class \
    --prompt "security halt" >/dev/null 2>&1
  ck 3 $? "record --interrupt pauses with exit 3"
  "$PY" "$H" graph record --execution "$EI" --node card-review --interrupt >/dev/null 2>&1
  ck 1 $? "second open interrupt on the same node refused (unique)"
  "$PY" "$H" graph next --execution "$EI" --topology "$TOPO" >/dev/null 2>&1
  ck 3 $? "next on a paused execution -> exit 3"
  "$PY" "$H" graph resume --execution "$EI" >/dev/null 2>&1
  ck 2 $? "resume without --answer/--actor -> exit 2"
  "$PY" "$H" graph resume --execution "$EI" --answer 'not-json' --actor op >/dev/null 2>&1
  ck 1 $? "malformed answer JSON refused"
  "$PY" "$H" graph resume --execution "$EI" --answer '{"reason":"ok"}' --actor op \
    --target '../etc' >/dev/null 2>&1
  ck 1 $? "free-text target refused (closed set)"
  G1="$("$PY" "$H" graph resume --execution "$EI" --answer '{"reason":"reviewed and accepted"}' \
    --actor op --target C-001 2>&1)"; RC=$?
  ck 1 "$RC" "security resolution with UNCOMMITTED DEBT refused"
  has "$G1" "uncommitted\|not committed" "refusal names the missing out-of-band artifact"
  git -C "$SB" add DEBT.md && git -C "$SB" -c user.email=t@t -c user.name=t commit -qm debt
  git -C "$SB" config user.email t@t   # same-identity case: repo identity == committer
  "$PY" "$H" graph resume --execution "$EI" --answer '{"reason":"auth token approved"}' \
    --actor op --target C-001 >/dev/null 2>&1
  ck 1 $? "security-class-sounding reason refused (cmd_skip mirror)"
  "$PY" "$H" graph resume --execution "$EI" --answer '{"reason":"reviewed and accepted"}' \
    --actor op --target C-001 >/dev/null 2>&1
  ck 0 $? "committed DEBT + clean reason + valid target resolves"
  R="$("$PY" - "$DB" "$EI" <<'EOF'
import json,sqlite3,sys
c=sqlite3.connect(sys.argv[1]); c.row_factory=sqlite3.Row
r=c.execute("SELECT * FROM graph_interrupt WHERE execution_id=? AND status='resolved'",
            (sys.argv[2],)).fetchone()
v=json.loads(r["resume_value"])
print(r["resolved_by"], v.get("author_distinct"), bool(v.get("session")),
      c.execute("SELECT status FROM graph_execution WHERE id=?",(sys.argv[2],)).fetchone()[0])
EOF
)"
  has "$R" "op False True running" "audit: same-identity degrades to author_distinct=False (documented), resumed"
  EN="$("$PY" "$H" graph run --kind card)"
  "$PY" "$H" graph record --execution "$EN" --node card-verify-live --interrupt >/dev/null 2>&1
  "$PY" "$H" graph resume --execution "$EN" --answer '{"reason":"ok"}' --actor op >/dev/null 2>&1
  ck 0 $? "non-security interrupt resolves without DEBT machinery"
else
  echo "  SKIP [git not found: guard matrix]"
fi

echo "F) exit contract: contradictory flags"
FLOW_HARNESS_DISABLE=1 "$PY" "$H" graph status --execution x >/dev/null 2>&1
ck 4 $? "FLOW_HARNESS_DISABLE + graph verb -> hard exit 4 (never silent 0)"

echo "G) terminal is terminal + gc sweep-then-purge"
"$PY" "$H" graph abandon --execution "$EID" --outcome killed
ck 0 $? "abandon exits 0"
"$PY" "$H" graph record --execution "$EID" --node stage-00 --manifest '{}' >/dev/null 2>&1
ck 1 $? "record on a killed execution refused (no resurrection)"
"$PY" "$H" graph resume --execution "$EID" --answer '{"reason":"x"}' --actor op >/dev/null 2>&1
ck 1 $? "resume on a killed execution refused"
for e in $E2 $E3 $E4 ${EI:-} ${EN:-}; do "$PY" "$H" graph abandon --execution "$e" >/dev/null 2>&1; done
GC="$("$PY" "$H" graph gc)"
has "$GC" '"deleted": ' "gc reports deletions"
LEFT="$("$PY" - "$DB" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT COUNT(*) FROM graph_execution").fetchone()[0],
      c.execute("SELECT COUNT(*) FROM graph_checkpoint").fetchone()[0],
      c.execute("SELECT COUNT(*) FROM graph_interrupt").fetchone()[0])
EOF
)"
ck "0 0 0" "$LEFT" "gc cascade removed executions + checkpoints + interrupts"
ES="$("$PY" "$H" graph run --kind auto_run)"
GS="$("$PY" "$H" graph gc --stale-days 0)"
has "$GS" '"stale_marked": 1' "checkpoint-less aged running execution swept as stale"
SURV="$("$PY" - "$DB" "$ES" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
r=c.execute("SELECT status,outcome FROM graph_execution WHERE id=?",(sys.argv[2],)).fetchone()
print(r[0] if r else "GONE", r[1] if r else "")
EOF
)"
has "$SURV" "abandoned stale" "swept row SURVIVES the marking gc (doctor gets a window)"
GC2="$("$PY" "$H" graph gc)"
has "$GC2" '"deleted": 1' "the NEXT gc purges it"

echo "H) _db transaction semantics"
T="$("$PY" - "$HDIR" "$SB" <<'EOF'
import os,sqlite3,sys
sys.path.insert(0, sys.argv[1])
import _db
c=_db.connect(db_path=os.path.join(sys.argv[2],"tx.db"))
c.execute("CREATE TABLE t (x INTEGER)")
try:
    with _db.transaction(c):
        c.execute("INSERT INTO t VALUES (1)")
        raise RuntimeError("boom")
except RuntimeError:
    kind="orig"
except Exception as e:
    kind=type(e).__name__
n=c.execute("SELECT COUNT(*) FROM t").fetchone()[0]
c.execute("BEGIN"); c.execute("INSERT INTO t VALUES (2)")
try:
    with _db.transaction(c):
        pass
    guard="no-raise"
except sqlite3.ProgrammingError:
    guard="raised"
c.rollback()
try:
    _db.update_where(c, "t", {"x": None}, x=3); nn="no-raise"
except ValueError:
    nn="raised"
print(kind, n, guard, nn)
EOF
)"
ck "orig 0 raised raised" "$T" "rollback preserves original error; open-txn entry raises; None-where raises"

echo "I) flow.sh boundary: harness_capture_checked contract + harness_call_checked pin"
FLOWSH="$HERE/../skills/flow/runner/flow.sh"
run_hc() { # $1 = function, rest = args; real helpers, sourced (no regex slicing)
  ( FLOW_LIB_ONLY=1; . "$FLOWSH"
    ROOT="$SB"; HARNESS_PY="$H"; FLOW_HARNESS_STRICT=""
    _python() { printf '%s' "$PY"; }
    "$@" )
}
V="$(run_hc harness_capture_checked graph run --kind planning)"; RC=$?
ck 0 "$RC" "capture_checked: value call passes rc 0 through"
[ -n "$V" ]; ck 0 $? "capture_checked: stdout (the execution id) is emitted"
run_hc harness_capture_checked graph abandon --execution "$V" >/dev/null 2>&1
run_hc harness_capture_checked graph next --execution "$V" --topology "$TOPO" >/dev/null 2>&1
ck 3 $? "capture_checked: semantic rc 3 passes through (terminal execution)"
( FLOW_LIB_ONLY=1; . "$FLOWSH"
  ROOT="$SB"; HARNESS_PY="$H"; FLOW_HARNESS_DISABLE=1
  _python() { printf '%s' "$PY"; }
  harness_capture_checked graph status --execution x ) >/dev/null 2>&1
ck 4 $? "capture_checked: DISABLE maps to rc 4, never silent 0"
( FLOW_LIB_ONLY=1; . "$FLOWSH"
  ROOT="$SB"; HARNESS_PY="$SB/absent.py"; FLOW_HARNESS_STRICT=""
  _python() { printf '%s' "$PY"; }
  harness_capture_checked graph status --execution x ) >/dev/null 2>&1
ck 4 $? "capture_checked: missing harness maps to rc 4"
P1168="$(run_hc harness_call_checked graph run --kind planning)"; RC=$?
ck 0 "$RC" "harness_call_checked pin: rc still passes through"
ck "" "$P1168" "harness_call_checked pin: stdout still swallowed (story-complete caller unchanged)"

echo "J) monorepo sub-root: show-prefix path + author-distinct audit"
if command -v git >/dev/null 2>&1; then
  GP="$(mktemp -d)"
  git -C "$GP" init -q
  mkdir -p "$GP/proj"
  printf -- '- [ ] DEBT: skip C-001 -- exposure -- close before: ship -- opened 2026-07-26\n' > "$GP/proj/DEBT.md"
  git -C "$GP" add proj/DEBT.md
  git -C "$GP" -c user.email=op@x -c user.name=op commit -qm debt
  git -C "$GP" config user.email agent@y
  FLOW_PROJECT_ROOT="$GP/proj" "$PY" "$H" init >/dev/null
  EJ="$(FLOW_PROJECT_ROOT="$GP/proj" "$PY" "$H" graph run --kind card)"
  FLOW_PROJECT_ROOT="$GP/proj" "$PY" "$H" graph record --execution "$EJ" --node card-review \
    --interrupt --security-class >/dev/null 2>&1
  FLOW_PROJECT_ROOT="$GP/proj" "$PY" "$H" graph resume --execution "$EJ" \
    --answer '{"reason":"reviewed and accepted"}' --actor operator --target C-001 >/dev/null 2>&1
  ck 0 $? "sub-root DEBT provenance resolves (HEAD:proj/DEBT.md blob, not the tree root)"
  J="$("$PY" - "$GP/proj/.flow/harness.db" "$EJ" <<'EOF'
import json,sqlite3,sys
c=sqlite3.connect(sys.argv[1]); c.row_factory=sqlite3.Row
r=c.execute("SELECT resume_value FROM graph_interrupt WHERE execution_id=? AND status='resolved'",
            (sys.argv[2],)).fetchone()
print(json.loads(r[0]).get("author_distinct"))
EOF
)"
  ck "True" "$J" "distinct committer vs repo identity -> author_distinct=True in audit"
  rm -rf "$GP"
else
  echo "  SKIP [git not found: sub-root case]"
fi

rm -rf "$SB"
echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
