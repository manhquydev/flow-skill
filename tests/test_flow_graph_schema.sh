#!/usr/bin/env bash
# Graph-executor schema foundation (migration 014, flow-owned band).
# Covers: fresh + pre-014 upgrade idempotency; FK/cascade/unique-open-interrupt behavior;
# monotonic graph ids; worktree-aware DB resolver (FLOW_HARNESS_DB, linked-worktree
# translation, non-git fallback); rust never-forward for graph verbs; lifecycle-keyed
# rollup --src/--src-key ingest. Requires python (stdlib sqlite3) and git.
# Run: bash tests/test_flow_graph_schema.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
PY="$(command -v python || command -v python3)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]: $(printf '%.100s' "$1")"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] unexpected /$2/"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

echo "A) fresh init lands the 014 graph tables idempotently"
SB="$(mktemp -d)"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null; ck 0 $? "fresh init"
A="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
t=lambda n: bool(c.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",(n,)).fetchone())
i=lambda n: bool(c.execute("SELECT 1 FROM sqlite_master WHERE type='index' AND name=?",(n,)).fetchone())
sv=sorted(r[0] for r in c.execute("SELECT version FROM schema_version"))
print(t("graph_execution"),t("graph_checkpoint"),t("graph_step_write"),t("graph_interrupt"),
      i("idx_graph_execution_status"),i("idx_graph_checkpoint_parent"),i("idx_graph_interrupt_one_open"),sv)
EOF
)"
has "$A" "True True True True True True True" "4 tables + 3 indexes present"
has "$A" "14" "schema_version records 14"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null; ck 0 $? "re-run init is a no-op"
rm -rf "$SB"

echo "B) pre-014 DB upgrades in place; existing rows untouched"
SB="$(mktemp -d)"; DB="$SB/old.db"
B="$("$PY" - "$HDIR" "$DB" <<'EOF'
import sqlite3, os, sys
hdir, dbp = sys.argv[1], sys.argv[2]
sys.path.insert(0, hdir)
import _db
c = sqlite3.connect(dbp)
for f in sorted(os.listdir(os.path.join(hdir,"schema"))):
    if f.endswith(".sql") and not f.startswith("014"):
        c.executescript(open(os.path.join(hdir,"schema",f)).read())
c.execute("INSERT INTO story (id,title,risk_lane) VALUES ('C-001','pre-existing story','normal')")
c.commit(); c.close()
c=_db.connect(db_path=dbp)
sv=sorted(r[0] for r in c.execute("SELECT version FROM schema_version"))
row=c.execute("SELECT title FROM story WHERE id='C-001'").fetchone()[0]
gt=bool(c.execute("SELECT 1 FROM sqlite_master WHERE name='graph_execution'").fetchone())
c.close()
print(gt, row, sv)
EOF
)"
has "$B" "True pre-existing story" "014 applied, story row preserved"
has "$B" "14" "upgraded DB records version 14"
rm -rf "$SB"

echo "C) FK enforcement, cascade delete, one-open-interrupt constraint"
SB="$(mktemp -d)"
C="$("$PY" - "$HDIR" "$SB" <<'EOF'
import os, sqlite3, sys
hdir, sb = sys.argv[1], sys.argv[2]
sys.path.insert(0, hdir)
import _db
c=_db.connect(db_path=os.path.join(sb,"h.db"))
c.execute("INSERT INTO story (id,title,risk_lane) VALUES ('C-007','s','normal')")
ex=("INSERT INTO graph_execution (id,project,kind,topology_version,topology_hash,story_id) "
    "VALUES (?,?,?,?,?,?)")
c.execute(ex,("e1","p","card",1,"h","C-007")); ok_text_fk=True
try:
    c.execute(ex,("e2","p","card",1,"h","NOPE")); bogus=False
except sqlite3.IntegrityError:
    bogus=True
c.execute("INSERT INTO graph_checkpoint (execution_id,ns,checkpoint_id,node,manifest,versions,seen,meta) "
          "VALUES ('e1','','k1','n','{}','{}','{}','{}')")
c.execute("INSERT INTO graph_step_write (execution_id,ns,checkpoint_id,task_id,idx,channel,value) "
          "VALUES ('e1','','k1','t',0,'ch','{}')")
c.execute("INSERT INTO graph_interrupt (execution_id,ns,interrupt_id,node,prompt) "
          "VALUES ('e1','','i1','n','p?')")
try:
    c.execute("INSERT INTO graph_interrupt (execution_id,ns,interrupt_id,node,prompt) "
              "VALUES ('e1','','i2','n','again')"); dup_open=False
except sqlite3.IntegrityError:
    dup_open=True
c.execute("UPDATE graph_interrupt SET status='resolved', resolved_at=datetime('now') WHERE interrupt_id='i1'")
c.execute("INSERT INTO graph_interrupt (execution_id,ns,interrupt_id,node,prompt) "
          "VALUES ('e1','','i3','n','new open after resolve')")
c.execute("DELETE FROM graph_execution WHERE id='e1'")
left=sum(c.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
         for t in ("graph_checkpoint","graph_step_write","graph_interrupt"))
c.commit(); c.close()
print(ok_text_fk, bogus, dup_open, left)
EOF
)"
has "$C" "True True True 0" "TEXT FK ok, bogus story refused, dup open refused, cascade wipes children"
rm -rf "$SB"

echo "D) graph_ids: 1000 sequential ids strictly increasing"
D="$("$PY" - "$HDIR" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1])
import graph_ids
ids=[graph_ids.new_id() for _ in range(1000)]
print(all(a<b for a,b in zip(ids,ids[1:])), len(set(ids))==1000, len(ids[0]))
EOF
)"
has "$D" "True True 22" "strictly increasing, unique, fixed width"

echo "E) DB resolver: linked-worktree translation, override, submodule/sgd no-translate"
UN="$(uname -s 2>/dev/null || echo unknown)"
case "$UN" in MINGW*|MSYS*|CYGWIN*) GITOK=0;; *) GITOK=1;; esac
if [ "$GITOK" = 1 ] && command -v git >/dev/null 2>&1; then
  SB="$(mktemp -d)"; MR="$SB/main"
  mkdir -p "$MR"; git -C "$SB" init -q "$MR"
  ( cd "$MR" && echo x > f && git add f && git -c user.email=t@t -c user.name=t commit -qm x )
  git -C "$MR" worktree add -q "$SB/wt" -b card-x
  mkdir -p "$SB/wt/sub" "$SB/plain"
  # realpath both sides: macOS mktemp lives under a symlink and the resolver compares realpaths
  MRR="$("$PY" -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$MR")"
  res() { FLOW_PROJECT_ROOT="$1" "$PY" - "$HDIR" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1])
import _db
print(_db.default_db_path())
EOF
  }
  ck "$MRR/.flow/harness.db" "$(res "$SB/wt")" "worktree root -> main DB"
  ck "$MRR/sub/.flow/harness.db" "$(res "$SB/wt/sub")" "worktree subdir -> main-equivalent subdir DB"
  ck "$MR/.flow/harness.db" "$(res "$MR")" "main root unchanged"
  ck "$SB/plain/.flow/harness.db" "$(res "$SB/plain")" "non-git root unchanged"
  ov="$(FLOW_HARNESS_DB="$SB/x.db" FLOW_PROJECT_ROOT="$SB/wt" "$PY" - "$HDIR" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1])
import _db
print(_db.default_db_path())
EOF
)"
  ck "$SB/x.db" "$ov" "FLOW_HARNESS_DB narrow override wins"
  # Submodule + --separate-git-dir: git_dir == common_dir -> NEVER translated (their common
  # dir lives outside the worktree; dirname(common_dir) would be git internals, not a root).
  SUPER="$SB/super"; mkdir -p "$SUPER"; git -C "$SB" init -q "$SUPER"
  ( cd "$SUPER" && git -c protocol.file.allow=always submodule add -q "$MR" sub 2>/dev/null \
      && git -c user.email=t@t -c user.name=t commit -qm sm ) >/dev/null 2>&1
  if [ -d "$SUPER/sub" ]; then
    ck "$SUPER/sub/.flow/harness.db" "$(res "$SUPER/sub")" "submodule root NOT translated"
  else
    echo "  SKIP [submodule add unavailable]"
  fi
  SGD="$SB/sgd"; mkdir -p "$SGD/work"
  git init -q --separate-git-dir "$SGD/gitdir" "$SGD/work"
  ck "$SGD/work/.flow/harness.db" "$(res "$SGD/work")" "separate-git-dir root NOT translated"
  git -C "$MR" worktree remove --force "$SB/wt" >/dev/null 2>&1 || true
  rm -rf "$SB"
else
  echo "  SKIP [resolver path-shape cases: windows shell or git missing]"
fi

echo "F) rust backend never receives graph verbs (even on a fresh DB)"
SB="$(mktemp -d)"
FAKE="$SB/fake-harness-cli"
printf '#!/bin/sh\necho should-not-run\nexit 0\n' > "$FAKE"; chmod +x "$FAKE" 2>/dev/null || true
OUT="$(FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_BACKEND=rust FLOW_HARNESS_CLI="$FAKE" \
  "$PY" "$H" graph 2>&1)"; RC=$?
no  "$OUT" "should-not-run" "fake rust CLI was not invoked for graph"
has "$OUT" "invalid choice\|not accepted" "python path answered (argparse), not the forward"
ck 2 "$RC" "unknown graph verb exits 2 via python argparse"
OUT2="$(FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_BACKEND=rust FLOW_HARNESS_CLI="$FAKE" \
  "$PY" "$H" --db "$SB/nope.db" graph run 2>&1)" || true
no  "$OUT2" "should-not-run" "--db-prefixed graph argv also never forwarded"
rm -rf "$SB"

echo "G) rollup --src/--src-key: recycled path, two lifecycles, idempotent, READABLE"
SB="$(mktemp -d)"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
P="$SB/wt-events.jsonl"
# Key convention: prefix = DESTINATION project's events sink, so usage/prune group the rows.
K="$SB/.flow/events.jsonl"
printf '{"command":"next","epoch_s":1}\n{"command":"check","epoch_s":2}\n' > "$P"
r1="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" rollup --src "$P" --src-key "$K#card-x#100")"
has "$r1" '"rolled": 2' "lifecycle 1 ingests 2 lines"
printf '{"command":"next","epoch_s":3}\n{"command":"check","epoch_s":4}\n' > "$P"
r2="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" rollup --src "$P" --src-key "$K#card-x#200")"
has "$r2" '"rolled": 2' "lifecycle 2 at the SAME path ingests fully (no cursor swallow)"
r3="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" rollup --src "$P" --src-key "$K#card-x#200")"
has "$r3" '"rolled": 0' "same key re-ingest is idempotent (no duplicates)"
n="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
print(sqlite3.connect(sys.argv[1]).execute("SELECT COUNT(*) FROM usage_event").fetchone()[0])
EOF
)"
ck "4" "$n" "usage_event holds exactly both lifecycles"
u="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" usage --include-ephemeral 2>&1)"
no  "$u" "no events yet" "lifecycle-keyed rows are VISIBLE to usage (not write-only)"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
