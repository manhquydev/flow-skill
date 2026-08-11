#!/usr/bin/env bash
# Parallel cards (Phase 4): ONE execution identity + ONE DB across worktrees, checkpoints
# survive worktree removal, two concurrent worktree records land, card-done revert removes
# dependents from the ready set, stale/terminal execution pins re-mint, card-less workspace
# verbs never touch the stage namespace, and no self-ancestor merge proof from inside a tree.
# Requires python + git. Run: bash tests/test_flow_graph_parallel_cards.sh
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
q() { "$PY" - "$1" "$2" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1]); c.row_factory=sqlite3.Row
print("|".join(str(r[0]) for r in c.execute(sys.argv[2])))
EOF
}

SB="$(mktemp -d)"; cd "$SB" || exit 1
git init -q .; git -c user.email=t@t -c user.name=t commit -qm base --allow-empty
mkdir -p flow cards
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do printf '# %s\nok\n' "$s" > "flow/$s.md"; done
card() { printf '# %s — t\nstatus: %s\ndeps: %s\nimplements: FR1\n## Scope\nx\n## Allowed files\n%s\n## Verify\n- [x] v\n## Done-evidence\nu\n## Evidence\n%s\n' "$1" "$2" "$3" "$4" "${5:-$ curl https://x/healthz -> 200 PASS healthcheck}" > "cards/$1.md"; }
card C-001 todo none "src/a.ts"
card C-002 todo none "src/b.ts"
card C-003 todo "C-001" "src/c.ts"
# Cards must be COMMITTED: a linked worktree checks out the branch, so an uncommitted
# card file simply is not there (and `check` inside the worktree would not find it).
git add flow cards && git -c user.email=t@t -c user.name=t commit -qm cards
export FLOW_GRAPH_EXECUTOR=1
DB="$SB/.flow/harness.db"

echo "A) one execution identity + one DB across worktrees"
bash "$RUN" workspace add card/C-001 --card C-001 >/dev/null 2>&1
bash "$RUN" workspace add card/C-002 --card C-002 >/dev/null 2>&1
EID="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph session)"
W1="$(git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch refs\/heads\/card\/C-001$/{print p}')"
W2="$(git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch refs\/heads\/card\/C-002$/{print p}')"
( cd "$W1" && bash "$RUN" check C-001 >/dev/null 2>&1 )
( cd "$W2" && bash "$RUN" check C-002 >/dev/null 2>&1 )
NDB="$(find "$SB" -name harness.db | wc -l | tr -d ' ')"
ck "1" "$NDB" "exactly one harness.db after two parallel worktrees"
NEX="$(q "$DB" "SELECT COUNT(*) FROM graph_execution")"
ck "1" "$NEX" "recording from INSIDE worktrees reuses the main-tree execution (no split journal)"
NS="$(q "$DB" "SELECT DISTINCT ns FROM graph_checkpoint ORDER BY ns")"
ck "card:C-001|card:C-002" "$NS" "both cards journaled under their own namespaces"
# The worktree DOES get a local .flow (log dir + events sink, ingested at removal by
# design); what must never appear there is a second harness.db.
W1DB="$([ -f "$W1/.flow/harness.db" ] && echo yes || echo no)"
ck "no" "$W1DB" "no stray harness.db minted inside the worktree"

echo "B) checkpoints survive worktree removal"
BEFORE="$(q "$DB" "SELECT COUNT(*) FROM graph_checkpoint WHERE ns='card:C-001'")"
( cd "$W1" && echo x > w.txt && git add w.txt && git -c user.email=t@t -c user.name=t commit -qm w1 )
git -c user.email=t@t -c user.name=t merge -q --no-edit card/C-001
bash "$RUN" workspace remove card/C-001 --force >/dev/null 2>&1
AFTER="$(q "$DB" "SELECT COUNT(*) FROM graph_checkpoint WHERE ns='card:C-001'")"
[ "$AFTER" -gt "$BEFORE" ]; ck 0 $? "card-001 checkpoints survive removal and gained the merge record ($BEFORE -> $AFTER)"
MG="$(q "$DB" "SELECT node FROM graph_checkpoint WHERE ns='card:C-001' ORDER BY checkpoint_id DESC LIMIT 1")"
ck "card-merge" "$MG" "merged branch records card-merge (executor-proved, no self-ancestor)"

echo "C) two concurrent worktree records both land"
bash "$RUN" workspace add card/C-003 --card C-003 >/dev/null 2>&1
W3="$(git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch refs\/heads\/card\/C-003$/{print p}')"
( cd "$W2" && bash "$RUN" check C-002 >/dev/null 2>&1 ) &
p1=$!
( cd "$W3" && bash "$RUN" check C-003 >/dev/null 2>&1 ) &
p2=$!
wait $p1; wait $p2
CN="$(q "$DB" "SELECT COUNT(*) FROM graph_checkpoint WHERE ns IN ('card:C-002','card:C-003')")"
[ "$CN" -ge 4 ]; ck 0 $? "concurrent worktree records all landed in the shared DB ($CN)"

echo "D) card-done revert removes dependents from the ready set"
card C-001 done none "src/a.ts" '$ curl https://x/healthz -> 200 PASS healthcheck'
R1="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards)"
has "$R1" '"ready": \["C-002", "C-003"\]' "C-003 becomes ready once its dep C-001 is done"
card C-001 todo none "src/a.ts" "(empty until done)"
R2="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards)"
has "$R2" '"C-003": {"reason": "deps", "missing": \["C-001"\]}' "reverting C-001 re-blocks its dependent"

echo "E) stale/terminal execution pin re-mints instead of failing silently"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph abandon --execution "$EID" >/dev/null 2>&1
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph gc >/dev/null 2>&1
bash "$RUN" check C-002 >/dev/null 2>&1
NEW="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph session)"
[ "$NEW" != "$EID" ]; ck 0 $? "pin re-minted after gc deleted the old execution"
N2="$(q "$DB" "SELECT COUNT(*) FROM graph_checkpoint WHERE execution_id='$NEW'")"
[ "$N2" -ge 1 ]; ck 0 $? "recording resumed on the fresh execution ($N2 checkpoint(s))"

echo "F) card-less workspace verbs never touch the stage namespace"
bash "$RUN" workspace add spike/foo >/dev/null 2>&1
ROOTNS="$(q "$DB" "SELECT COUNT(*) FROM graph_checkpoint WHERE ns=''")"
ck "0" "$ROOTNS" "a card-less workspace add records nothing into the root (stage) namespace"
bash "$RUN" workspace remove spike/foo --force >/dev/null 2>&1

echo "G) self-ancestor merge proof refused"
git checkout -q -b card/C-009 2>/dev/null || git checkout -q card/C-009
SELF="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph record --execution "$NEW" --ns card:C-009 \
  --node card-merge --merge --branch card/C-009 2>&1)"; rc=$?
ck 2 "$rc" "base == branch refuses (rc 2), never a trivially-true proof"
has "$SELF" "self-ancestor" "refusal names the reason"
git checkout -q - 2>/dev/null || true

echo "H) manifest is executor-built: a card cannot forge its own gate verdict"
card C-020 'x","gate":{"exit":0},"z":"' none "src/z.ts"
bash "$RUN" check C-020 >/dev/null 2>&1
ck 1 $? "hostile status token still FAILS the mechanical gate"
FORGE="$("$PY" - "$DB" <<'EOF'
import json,sqlite3,sys
c=sqlite3.connect(sys.argv[1])
r=c.execute("SELECT manifest FROM graph_checkpoint WHERE ns='card:C-020' "
            "ORDER BY checkpoint_id DESC LIMIT 1").fetchone()
print(json.loads(r[0])["gate"]["exit"] if r else "NONE")
EOF
)"
ck "1" "$FORGE" "journal records the REAL red verdict (no duplicate-key override)"
BADJ="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph record --execution "$NEW" --ns card:C-020 \
  --node card-review --manifest '{"gate":{"exit":1},"gate":{"exit":0}}' 2>&1)"; rc=$?
ck 1 "$rc" "a duplicate-key manifest is rejected outright"
has "$BADJ" "duplicate key" "rejection names the duplicate key"
BROKEN="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph record --execution "$NEW" --ns card:C-020 \
  --node card-review --manifest 'not json' 2>&1)"; rc=$?
ck 1 "$rc" "unparseable manifest refused (never journaled to poison later walks)"

echo "I) one state dir: flow.sh asks the resolver instead of re-deriving it"
SD="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph root)"
# Compare directory IDENTITY, not spelling: one directory legitimately answers to several
# names (macOS /var vs /private/var, Windows 8.3 short vs long), so `-ef` on a file inside
# it asserts what actually matters — the resolver landed on the dir that owns the DB.
[ "$SD/harness.db" -ef "$SB/.flow/harness.db" ]; ck 0 $? "graph root points at the DB-owning dir"
W2B="$(git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch refs\/heads\/card\/C-002$/{print p}')"
if [ -n "$W2B" ]; then
  SDW="$(cd "$W2B" && FLOW_PROJECT_ROOT="$W2B" "$PY" "$H" graph root)"
  [ "$SDW/harness.db" -ef "$SB/.flow/harness.db" ]
  ck 0 $? "from inside a worktree the resolver still points at the main state dir"
fi

echo "J) merge proof prefers the LOCAL integration branch (auto-run never pushes first)"
git remote add origin "$SB/.git" 2>/dev/null || true
git update-ref refs/remotes/origin/master "$(git rev-parse HEAD)" 2>/dev/null || true
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master 2>/dev/null || true
git checkout -q -b card/C-030 2>/dev/null; echo z > z.txt; git add z.txt
git -c user.email=t@t -c user.name=t commit -qm c30
git checkout -q master 2>/dev/null || git checkout -q main
git -c user.email=t@t -c user.name=t merge -q --no-edit card/C-030
git update-ref refs/remotes/origin/master "$(git rev-parse HEAD~1)" 2>/dev/null || true
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph record --execution "$NEW" --ns card:C-030 \
  --node card-merge --merge --branch card/C-030 >/dev/null 2>&1
LM="$("$PY" - "$DB" <<'EOF'
import json,sqlite3,sys
c=sqlite3.connect(sys.argv[1])
r=c.execute("SELECT node,manifest FROM graph_checkpoint WHERE ns='card:C-030' "
            "ORDER BY checkpoint_id DESC LIMIT 1").fetchone()
print(r[0], json.loads(r[1])["merged"] if r else "NONE")
EOF
)"
ck "card-merge True" "$LM" "merged-locally-but-unpushed is proved merged, not abandoned"

echo "K) a dep cycle blocks only its own members"
card C-040 todo "C-040" "src/q.ts"
CY="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards)"; rc=$?
ck 0 "$rc" "cycle no longer fails the whole command"
has "$CY" '"reason": "dep cycle"' "the self-dependent card is blocked with its cycle"
has "$CY" '"C-002"' "other buildable cards still advised"
rm -f cards/C-040.md cards/C-020.md

echo "L) resolver never points state into git internals; parallel mint is race-free"
SG="$(mktemp -d)"
git init -q --separate-git-dir "$SG/gitdir" "$SG/work" 2>/dev/null
( cd "$SG/work" && git -c user.email=t@t -c user.name=t commit -qm b --allow-empty \
  && git worktree add -q "$SG/wt" -b c1 ) >/dev/null 2>&1
SGW="$(FLOW_PROJECT_ROOT="$SG/wt" "$PY" "$H" graph root)"
case "$SGW" in *"$SG/gitdir"*) R=internals ;; *) R=safe ;; esac
ck "safe" "$R" "separate-git-dir worktree keeps its own state dir, never .git internals"
rm -rf "$SG"
RC="$(mktemp -d)"; git init -q "$RC/m"
( cd "$RC/m" && git -c user.email=t@t -c user.name=t commit -qm b --allow-empty ) >/dev/null 2>&1
mkdir -p "$RC/m/flow" "$RC/m/cards"
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do printf '# %s\nok\n' "$s" > "$RC/m/flow/$s.md"; done
printf '# C-001 — t\nstatus: todo\ndeps: none\n## Scope\nx\n## Allowed files\nsrc/a.ts\n## Verify\n- [x] v\n## Done-evidence\nu\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$RC/m/cards/C-001.md"
( cd "$RC/m" && git add -A && git -c user.email=t@t -c user.name=t commit -qm cards ) >/dev/null 2>&1
( cd "$RC/m" && git worktree add -q "$RC/w1" -b p1 && git worktree add -q "$RC/w2" -b p2 ) >/dev/null 2>&1
( cd "$RC/m"  && FLOW_GRAPH_EXECUTOR=1 bash "$RUN" check C-001 >/dev/null 2>&1 ) &
( cd "$RC/w1" && FLOW_GRAPH_EXECUTOR=1 bash "$RUN" check C-001 >/dev/null 2>&1 ) &
( cd "$RC/w2" && FLOW_GRAPH_EXECUTOR=1 bash "$RUN" check C-001 >/dev/null 2>&1 ) &
wait
NDBS="$(find "$RC" -name harness.db | wc -l | tr -d ' ')"
ck "1" "$NDBS" "cold-start parallel mint keeps ONE shared db"
NEXEC="$(q "$RC/m/.flow/harness.db" "SELECT COUNT(*) FROM graph_execution")"
ck "1" "$NEXEC" "and exactly ONE execution (SQLite transaction arbitrates the mint)"
rm -rf "$RC"

echo "M) cold-DB parallel burst: no lost records, no stray state dirs"
CB="$(mktemp -d)"
FAILS=0
for i in 1 2 3 4 5 6; do
  ( FLOW_PROJECT_ROOT="$CB" "$PY" "$H" graph root >/dev/null 2>&1 || echo x >> "$CB/.fails" ) &
done
wait
[ -f "$CB/.fails" ] && FAILS="$(grep -c x "$CB/.fails")"
ck "0" "$FAILS" "6 concurrent cold-start harness calls all succeed (BEGIN IMMEDIATE)"
rm -rf "$CB"

echo "N) a TERMINAL execution is never adopted (session filters on status=running)"
TE="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph session)"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph abandon --execution "$TE" >/dev/null 2>&1
TE2="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph session)"
[ "$TE2" != "$TE" ]; ck 0 $? "abandoned (but still present) execution is not adopted - a fresh one is minted"
bash "$RUN" check C-002 >/dev/null 2>&1
LIVE="$(q "$DB" "SELECT COUNT(*) FROM graph_checkpoint WHERE execution_id='$TE2'")"
[ "$LIVE" -ge 1 ]; ck 0 $? "records land on the live execution, never blackholed ($LIVE)"
NC="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph session --no-create >/dev/null 2>&1; echo $?)"
ck "0" "$NC" "--no-create returns the running execution when one exists"

echo "O) gc project key is main-root scoped (a worktree-minted execution is reachable)"
PK="$(FLOW_PROJECT_ROOT="$SB" "$PY" - "$HDIR" "$SB" <<'EOF'
import sys, os
sys.path.insert(0, sys.argv[1])
os.environ["FLOW_PROJECT_ROOT"] = sys.argv[2]
import graph_executor as G
print(G._project_key())
EOF
)"
W2C="$(git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch refs\/heads\/card\/C-002$/{print p}')"
if [ -n "$W2C" ]; then
  PKW="$("$PY" - "$HDIR" "$W2C" <<'EOF'
import sys, os
sys.path.insert(0, sys.argv[1])
os.environ["FLOW_PROJECT_ROOT"] = sys.argv[2]
import graph_executor as G
print(G._project_key())
EOF
)"
  ck "$PK" "$PKW" "main tree and card worktree agree on the project key (gc can see both)"
fi

echo "P) every transition the runner emits is a declared topology edge"
# Dedicated sandbox: run this on a FRESH lifecycle, never after a gc (a check over an
# emptied table passes vacuously - exactly the phantom this section exists to prevent).
PB="$(mktemp -d)"; ( cd "$PB" && git init -q . \
  && git -c user.email=t@t -c user.name=t commit -qm b --allow-empty ) >/dev/null 2>&1
mkdir -p "$PB/flow" "$PB/cards"
for s0 in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do printf '# %s\nok\n' "$s0" > "$PB/flow/$s0.md"; done
printf '# C-001 — t\nstatus: todo\ndeps: none\n## Scope\nx\n## Allowed files\nsrc/a.ts\n## Verify\n- [x] v\n## Done-evidence\nu\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$PB/cards/C-001.md"
( cd "$PB" && git add -A && git -c user.email=t@t -c user.name=t commit -qm c ) >/dev/null 2>&1
( cd "$PB" && FLOW_GRAPH_EXECUTOR=1 bash "$RUN" workspace add card/C-001 --card C-001 ) >/dev/null 2>&1
( cd "$PB" && FLOW_GRAPH_EXECUTOR=1 bash "$RUN" check C-001 ) >/dev/null 2>&1
PWT="$(cd "$PB" && git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch refs\/heads\/card\/C-001$/{print p}')"
( cd "$PWT" && echo x > w.txt && git add w.txt && git -c user.email=t@t -c user.name=t commit -qm w ) >/dev/null 2>&1
( cd "$PB" && git -c user.email=t@t -c user.name=t merge -q --no-edit card/C-001 ) >/dev/null 2>&1
( cd "$PB" && FLOW_GRAPH_EXECUTOR=1 bash "$RUN" workspace remove card/C-001 --force ) >/dev/null 2>&1
SEQ="$("$PY" - "$PB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(",".join(r[0] for r in c.execute(
  "SELECT node FROM graph_checkpoint WHERE ns='card:C-001' ORDER BY checkpoint_id")))
EOF
)"
has "$SEQ" "card-dispatch" "the fresh lifecycle actually recorded a card chain ($SEQ)"
TRANS="$("$PY" - "$PB/.flow/harness.db" "$HERE/../skills/flow/references/flow-topology.json" <<'EOF'
import json,sqlite3,sys
c=sqlite3.connect(sys.argv[1]); c.row_factory=sqlite3.Row
topo=json.load(open(sys.argv[2]))
edges={(e["from"],e["to"]) for e in topo["edges"]}
nodes=set(topo["nodes"])
bad=[]
seen_any=False
for ns in [r[0] for r in c.execute("SELECT DISTINCT ns FROM graph_checkpoint WHERE ns<>''")]:
    seq=[r["node"] for r in c.execute(
        "SELECT node FROM graph_checkpoint WHERE ns=? ORDER BY checkpoint_id",(ns,))]
    if seq: seen_any=True
    for n in seq:
        if n not in nodes: bad.append(f"{ns}: node {n} not in topology")
    for a,b in zip(seq,seq[1:]):
        if a!=b and (a,b) not in edges: bad.append(f"{ns}: {a}->{b} is not a declared edge")
print("|".join(bad) if bad else ("OK" if seen_any else "EMPTY-JOURNAL"))
EOF
)"
ck "OK" "$TRANS" "recorded card transitions all exist as topology edges"
rm -rf "$PB" "$PB"-card-* 2>/dev/null

cd /; rm -rf "$SB" "$SB"-card-* "$SB"-spike-* 2>/dev/null
echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
