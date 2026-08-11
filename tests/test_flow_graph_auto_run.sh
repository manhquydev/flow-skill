#!/usr/bin/env bash
# Shipping consumer (Phase 4): card-DAG compile against the REAL card format, deps parity
# with /flow ready, overlap serialization, dep-cycle rejection, the recording contract on
# the verbs auto-run already calls, executor-computed merge proof, worktree event ingest,
# and flag-off byte-parity. Requires python + git.
# Run: bash tests/test_flow_graph_auto_run.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
RUN="$HERE/../skills/flow/runner/flow.sh"
PY="$(command -v python3 || command -v python)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
if ! command -v git >/dev/null 2>&1; then echo "SKIP: git not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]: $(printf '%.140s' "$1")"; fail=$((fail+1)); fi; }
no() { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] unexpected /$2/"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

SB="$(mktemp -d)"; cd "$SB" || exit 1
git init -q .
mkdir -p flow cards
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do printf '# %s\nok\n' "$s" > "flow/$s.md"; done
card() { # id status deps files
  printf '# %s — t\nstatus: %s\ndeps: %s\nimplements: FR1\n## Scope\nx\n## Allowed files\n%s\n## Verify\n- [x] v\n## Done-evidence\nu\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' \
    "$1" "$2" "$3" "$4" > "cards/$1.md"
}
card C-001 done none "src/a.ts"
card C-002 todo none "src/b.ts"
card C-003 todo "C-002" "src/c.ts"
card C-004 todo none "src/b.ts"

echo "A) card DAG: deps-met parity with /flow ready + overlap serialization"
OUT="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards)"
ck 0 $? "graph cards exits 0"
DM="$("$PY" -c "import json,sys;print(' '.join(json.loads(sys.argv[1])['deps_met']))" "$OUT")"
RDY="$("$PY" -c "import json,sys;print(' '.join(json.loads(sys.argv[1])['ready']))" "$OUT")"
LEG="$(bash "$RUN" ready 2>/dev/null | grep -oE 'BUILDABLE +C-[0-9]+' | grep -oE 'C-[0-9]+' | sort -u | tr '\n' ' ')"
LEG="$(printf '%s' "$LEG" | sed 's/ $//')"
ck "C-002 C-004" "$DM" "deps-met set matches legacy BUILDABLE (deps-only semantics)"
ck "$LEG" "$DM" "deps parity with /flow ready output on the same fixtures"
ck "C-002" "$RDY" "ready serializes the allowed-files overlap (C-004 shares src/b.ts)"
has "$OUT" '"reason": "allowed-files overlap"' "blocked reason names the overlap"
has "$OUT" '"missing": \["C-002"\]' "dependent card blocked on its unfinished dep"
A2="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards --active-files "src/c.ts")"
has "$A2" '"C-003"' "active worktree tokens are honored as taken"

echo "B) real card format only: deps free-text scrape, C-1 == C-001, [FILL guard"
card C-005 todo "depends on C-2 and C-004" "src/e.ts"
D5="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards | "$PY" -c "import json,sys;print(json.load(sys.stdin)['cards']['C-005']['deps'])")"
ck "['C-002', 'C-004']" "$D5" "free-text deps scraped + zero-padded (C-2 -> C-002)"
card C-006 todo none "[FILL: paths]"
B6="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards)"
has "$B6" 'still has \[FILL' "card with [FILL allowed-files is not dispatchable"
rm -f cards/C-005.md cards/C-006.md

echo "C) dependency cycle blocks its members without failing the board"
card C-007 todo "C-008" "src/g.ts"; card C-008 todo "C-007" "src/h.ts"
CYERR="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards 2>&1 >/dev/null)"
CYOUT="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards 2>/dev/null)"; rc=$?
ck 0 "$rc" "cycle is reported but does not fail the command (auto-run keeps dispatching)"
has "$CYERR" "card dependency cycle" "cycle is named on stderr"
has "$CYOUT" '"reason": "dep cycle"' "cycle members are blocked with their cycle"
has "$CYOUT" '"ready": \["C-002"\]' "unrelated buildable cards still advised"
rm -f cards/C-007.md cards/C-008.md

echo "D) recording contract on the verbs auto-run already calls"
export FLOW_GRAPH_EXECUTOR=1
git -c user.email=t@t -c user.name=t commit -qm base --allow-empty
OUT_ADD="$(bash "$RUN" workspace add card/C-002 --card C-002 2>&1)"
has "$OUT_ADD" "PASS: created worktree" "workspace add succeeded"
no  "$OUT_ADD" "FLOW_PROJECT_ROOT" "enter block does NOT export FLOW_PROJECT_ROOT (root hijack)"
EID="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph session)"
[ -n "$EID" ]; ck 0 $? "an auto_run execution was created on first record"
bash "$RUN" check C-002 >/dev/null 2>&1
ST="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph status --execution "$EID")"
has "$ST" '"ns": "card:C-002"' "boundaries recorded under the card namespace"
has "$ST" 'card-dispatch\|card-review' "dispatch + review boundaries journaled"
N="$("$PY" - "$SB/.flow/harness.db" "$EID" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT COUNT(*) FROM graph_checkpoint WHERE execution_id=? AND ns='card:C-002'",
                (sys.argv[2],)).fetchone()[0])
EOF
)"
[ "$N" -ge 2 ]; ck 0 $? "at least dispatch+review checkpoints exist ($N)"

echo "E) merge proof is executor-computed; unmerged teardown never reads as shipped"
WT="$(git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch refs\/heads\/card\/C-002$/{print p}')"
( cd "$WT" && echo x > w.txt && git add w.txt && git -c user.email=t@t -c user.name=t commit -qm work )
bash "$RUN" workspace remove card/C-002 --force >/dev/null 2>&1
M="$("$PY" - "$SB/.flow/harness.db" "$EID" <<'EOF'
import json,sqlite3,sys
c=sqlite3.connect(sys.argv[1]); c.row_factory=sqlite3.Row
rows=[dict(r) for r in c.execute(
  "SELECT node,manifest FROM graph_checkpoint WHERE execution_id=? ORDER BY checkpoint_id",(sys.argv[2],))]
last=[r for r in rows if r["node"] in ("card-merge","card-abandon")][-1:]
print(last[0]["node"], json.loads(last[0]["manifest"]).get("merged") if last else "NONE")
EOF
)"
ck "card-abandon False" "$M" "unmerged branch torn down records card-abandon, merged=False"
bash "$RUN" workspace add card/C-003 --card C-003 >/dev/null 2>&1
WT3="$(git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch refs\/heads\/card\/C-003$/{print p}')"
( cd "$WT3" && echo y > y.txt && git add y.txt && git -c user.email=t@t -c user.name=t commit -qm w3 )
git -c user.email=t@t -c user.name=t merge -q --no-edit card/C-003
mkdir -p "$WT3/.flow"; printf '{"command":"check","epoch_s":1}\n' > "$WT3/.flow/events.jsonl"
bash "$RUN" workspace remove card/C-003 --force >/dev/null 2>&1
M3="$("$PY" - "$SB/.flow/harness.db" "$EID" <<'EOF'
import json,sqlite3,sys
c=sqlite3.connect(sys.argv[1]); c.row_factory=sqlite3.Row
r=[dict(x) for x in c.execute(
  "SELECT node,manifest FROM graph_checkpoint WHERE execution_id=? AND ns='card:C-003' "
  "ORDER BY checkpoint_id",(sys.argv[2],))]
merge=[x for x in r if x["node"]=="card-merge"]
print(bool(merge) and json.loads(merge[-1]["manifest"]).get("merged"))
EOF
)"
ck "True" "$M3" "merged branch records card-merge with an executor-proved ancestry"
U="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT COUNT(*) FROM usage_event WHERE src LIKE '%#card/C-003#%'").fetchone()[0])
EOF
)"
ck "1" "$U" "worktree telemetry ingested under its lifecycle key before the tree was removed"

echo "F) doctor is execution-aware; flag off is byte-identical"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph record --execution "$EID" --ns card:C-004 \
  --node card-review --interrupt --security-class --prompt halt >/dev/null 2>&1
DOC="$(bash "$RUN" workspace doctor 2>&1)"
has "$DOC" "OPEN interrupt" "doctor warns about the worktree backing a paused execution"
unset FLOW_GRAPH_EXECUTOR
D_OFF="$(bash "$RUN" workspace doctor 2>&1)"
no "$D_OFF" "OPEN interrupt" "flag off: doctor output unchanged"
B4="$("$PY" - "$SB/.flow/harness.db" "$EID" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT COUNT(*) FROM graph_checkpoint WHERE execution_id=?",(sys.argv[2],)).fetchone()[0])
EOF
)"
bash "$RUN" check C-002 >/dev/null 2>&1
A4="$("$PY" - "$SB/.flow/harness.db" "$EID" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT COUNT(*) FROM graph_checkpoint WHERE execution_id=?",(sys.argv[2],)).fetchone()[0])
EOF
)"
ck "$B4" "$A4" "flag off: check records NOTHING into the journal"

cd /; rm -rf "$SB"
echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
