#!/usr/bin/env bash
# Graph executor crash/resume (Phase 2): failpoint atomicity (nothing persists from an
# aborted record), resume-without-redo (journal continues from the last checkpoint),
# concurrent writers on one DB (BEGIN IMMEDIATE + busy_timeout), and git evidence
# reconciliation (merged-but-unrecorded work detectable). Requires python; git for D.
# Run: bash tests/test_flow_graph_crash_resume.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
PY="$(command -v python || command -v python3)"
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
          "stage-02":{"type":"gate_check","stage":"02-scope"}},
 "edges":[{"from":"stage-00","to":"stage-01"},{"from":"stage-01","to":"stage-02"}]}
EOF

echo "A) failpoint atomicity: an aborted record persists NOTHING"
EID="$("$PY" "$H" graph run --kind planning)"
FLOW_GRAPH_FAILPOINT=before-commit "$PY" "$H" graph record --execution "$EID" \
  --node stage-00 --manifest '{"gate":{"exit":0}}' \
  --writes '[{"task":"t","channel":"a","value":1}]' >/dev/null 2>&1
ck 1 $? "failpoint record exits 1"
A="$("$PY" - "$DB" "$EID" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT COUNT(*) FROM graph_checkpoint WHERE execution_id=?",(sys.argv[2],)).fetchone()[0],
      c.execute("SELECT COUNT(*) FROM graph_step_write WHERE execution_id=?",(sys.argv[2],)).fetchone()[0])
EOF
)"
ck "0 0" "$A" "no checkpoint, no step writes after the abort (transaction rolled back whole)"

echo "B) resume without redo: fresh invocations continue, never re-issue recorded steps"
"$PY" "$H" graph record --execution "$EID" --node stage-00 --manifest '{"gate":{"exit":0}}' >/dev/null
"$PY" "$H" graph record --execution "$EID" --node stage-01 --manifest '{"gate":{"exit":0}}' >/dev/null
N="$("$PY" "$H" graph next --execution "$EID" --topology "$TOPO")"
ck "stage-02" "$N" "next resumes at the successor of the LAST checkpoint (no redo of 00/01)"

echo "C) two concurrent writers on one DB both land (BEGIN IMMEDIATE + busy_timeout)"
"$PY" "$H" graph record --execution "$EID" --node stage-02 --ns w1 --manifest '{}' >/dev/null 2>&1 &
p1=$!
"$PY" "$H" graph record --execution "$EID" --node stage-02 --ns w2 --manifest '{}' >/dev/null 2>&1 &
p2=$!
wait $p1; r1=$?; wait $p2; r2=$?
ck "0 0" "$r1 $r2" "both concurrent records exit 0 (no 'database is locked')"
C="$("$PY" - "$DB" "$EID" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT COUNT(*) FROM graph_checkpoint WHERE execution_id=? AND ns IN ('w1','w2')",
                (sys.argv[2],)).fetchone()[0])
EOF
)"
ck "2" "$C" "both writers' checkpoints present"

echo "D) git evidence reconciliation: merged work is detectable, never re-dispatchable"
if command -v git >/dev/null 2>&1; then
  GR="$SB/repo"; mkdir -p "$GR"
  git -C "$SB" init -q "$GR"
  ( cd "$GR" && echo a > f && git add f && git -c user.email=t@t -c user.name=t commit -qm base )
  BASE="$(git -C "$GR" rev-parse HEAD)"
  git -C "$GR" checkout -qb card/x
  ( cd "$GR" && echo b >> f && git add f && git -c user.email=t@t -c user.name=t commit -qm work )
  SHA="$(git -C "$GR" rev-parse HEAD)"
  git -C "$GR" checkout -q - && git -C "$GR" merge -q --no-edit card/x
  git -C "$GR" branch -q card/y "$BASE"
  D="$("$PY" - "$HDIR" "$GR" "$SHA" <<'EOF'
import json,sys
sys.path.insert(0, sys.argv[1])
import graph_executor as G
root, sha = sys.argv[2], sys.argv[3]
merged = G.verify_evidence(root, {"branch": "card/x", "git_sha": sha, "base": "HEAD"})
unmerged = G.verify_evidence(root, {"branch": "card/y", "git_sha": sha, "base": sha + "~0"})
missing = G.verify_evidence(root, {"branch": "card/zzz"})
spoof = G.verify_evidence(root, {"branch": "--help"})
print(merged.get("branch_exists"), merged.get("merged"),
      unmerged.get("branch_exists"), missing.get("branch_exists"),
      "branch_exists" not in spoof)
EOF
)"
  ck "True True True False True" "$D" "ancestry proof executor-computed; option-shaped refs refused"
  FLOW_PROJECT_ROOT="$GR" "$PY" "$H" init >/dev/null
  ER="$(FLOW_PROJECT_ROOT="$GR" "$PY" "$H" graph run --kind card)"
  FLOW_PROJECT_ROOT="$GR" "$PY" "$H" graph record --execution "$ER" --node card-merge \
    --manifest "{\"branch\":\"card/x\",\"git_sha\":\"$SHA\",\"base\":\"HEAD\"}" >/dev/null
  REC="$(FLOW_PROJECT_ROOT="$GR" "$PY" "$H" graph resume --execution "$ER")"
  ck 0 $? "resume with no open interrupt returns the reconciliation report (rc 0)"
  has "$REC" '"merged": true' "CLI reconciliation proves merged-but-unrecorded work from the journal"
else
  echo "  SKIP [git not found: reconciliation]"
fi

rm -rf "$SB"
echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
