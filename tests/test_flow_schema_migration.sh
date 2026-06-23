#!/usr/bin/env bash
# Regression suite for the schema-005 collision fix + rust backend-compat guard.
# Covers: fresh init lands upstream tool-extensions (005) + re-homed flow migrations (009-012);
# a legacy DB (built under the old numbering where v5 meant accessed-count) upgrades without a
# duplicate-column crash, gains the tool registry columns, preserves data, and stays idempotent;
# the rust seam refuses to touch a flow-lineage DB. Requires python (stdlib sqlite3).
# Run: bash tests/test_flow_schema_migration.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
PY="$(command -v python || command -v python3)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected $1 got $2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]: $1"; fail=$((fail+1)); fi; }

echo "A) fresh init lands the reconciled schema"
SB="$(mktemp -d)"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null; ck 0 $? "fresh init"
FRESH="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
cols=lambda t:{r[1] for r in c.execute(f"PRAGMA table_info({t})")}
sv=sorted(r[0] for r in c.execute("SELECT version FROM schema_version"))
print("kind" in cols("tool"), "accessed_count" in cols("decision"),
      bool(c.execute("SELECT 1 FROM sqlite_master WHERE name='usage_event'").fetchone()), sv)
EOF
)"
has "$FRESH" "True True True" "tool.kind + accessed_count + usage_event all present"
has "$FRESH" "5, 9, 10, 11, 12" "tool-extensions(5) + re-homed flow migrations(9-12) applied"
rm -rf "$SB"

echo "B) legacy DB (old v5=accessed-count) upgrades cleanly + idempotent"
SB="$(mktemp -d)"; LEG="$SB/legacy.db"
LEGOUT="$("$PY" - "$HDIR" "$LEG" <<'EOF'
import sqlite3, os, sys
hdir, dbp = sys.argv[1], sys.argv[2]
sys.path.insert(0, hdir)
import _db
c = sqlite3.connect(dbp)
for f in ["001-init.sql","002-story-verify.sql","003-tool-registry.sql","004-intervention.sql"]:
    c.executescript(open(os.path.join(hdir,"schema",f)).read())
# Reproduce the OLD numbering: v5 = accessed-count, v6-8 = full usage tables. No tool.kind.
c.executescript("""
ALTER TABLE decision ADD COLUMN accessed_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE trace ADD COLUMN accessed_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE backlog ADD COLUMN accessed_count INTEGER NOT NULL DEFAULT 0;
INSERT INTO schema_version (version) VALUES (5);
CREATE TABLE usage_event (id INTEGER PRIMARY KEY AUTOINCREMENT, src TEXT NOT NULL, line_no INTEGER NOT NULL,
  epoch_s INTEGER, session_id TEXT, cycle_id TEXT, project TEXT, command TEXT, args TEXT, exit_code INTEGER,
  gate_pass INTEGER, duration_s INTEGER, stage_from TEXT, stage_to TEXT, card TEXT, project_type TEXT,
  mode TEXT, flow_version TEXT, tier TEXT, host TEXT, read_only INTEGER, UNIQUE(src,line_no));
CREATE INDEX idx_usage_event_cycle ON usage_event(cycle_id);
CREATE INDEX idx_usage_event_cmd ON usage_event(command);
CREATE TABLE rollup_cursor (src TEXT PRIMARY KEY, last_line INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL DEFAULT (datetime('now')));
INSERT INTO schema_version (version) VALUES (6);
ALTER TABLE usage_event ADD COLUMN gate_fail_reason TEXT;
INSERT INTO schema_version (version) VALUES (7);
ALTER TABLE usage_event ADD COLUMN ephemeral INTEGER;
INSERT INTO schema_version (version) VALUES (8);
""")
c.execute("INSERT INTO tool (name,command,description,responsibility) VALUES ('mcp:foo','mcp:foo','legacy','Tool access')")
c.execute("INSERT INTO decision (id,title) VALUES ('0001','legacy decision')")
c.execute("UPDATE decision SET accessed_count=7 WHERE id='0001'")
c.execute("INSERT INTO usage_event (src,line_no,command) VALUES ('x',1,'next')")
c.commit(); c.close()
def info(c):
    cols={r[1] for r in c.execute("PRAGMA table_info(tool)")}
    return ("kind" in cols,
            c.execute("SELECT accessed_count FROM decision WHERE id='0001'").fetchone()[0],
            c.execute("SELECT command FROM usage_event WHERE line_no=1").fetchone()[0],
            c.execute("SELECT kind FROM tool WHERE name='mcp:foo'").fetchone()[0])
c=_db.connect(db_path=dbp); a=info(c); c.close()          # heal
c=_db.connect(db_path=dbp); _=info(c); c.close()          # 2nd run
c=_db.connect(db_path=dbp); b=info(c)
sv=sorted(r[0] for r in c.execute("SELECT version FROM schema_version")); c.close()
print(a[0], a[1], a[2], a[3], "idem" if a==b else "DRIFT", sv)
EOF
)"
has "$LEGOUT" "True 7 next mcp" "heal adds tool.kind, preserves accessed_count+usage, backfills mcp kind"
has "$LEGOUT" "idem" "upgrade is idempotent across repeated init"
has "$LEGOUT" "5, 6, 7, 8, 9, 10, 11, 12" "schema_version normalized to 1-12"
rm -rf "$SB"

echo "B2) crash-at-v3 (tool exists, no kind, intervention not yet created) heals all gaps"
# Reproduces the reconcile-skips-004 trap: an init interrupted after 003. reconcile must not let
# the version>MAX gate skip migration 004 (the intervention table).
SB="$(mktemp -d)"; LEG="$SB/v3.db"
V3OUT="$("$PY" - "$HDIR" "$LEG" <<'EOF'
import sqlite3, os, sys
hdir, dbp = sys.argv[1], sys.argv[2]
sys.path.insert(0, hdir)
import _db
c = sqlite3.connect(dbp)
for f in ["001-init.sql","002-story-verify.sql","003-tool-registry.sql"]:  # stop AFTER 003, before 004
    c.executescript(open(os.path.join(hdir,"schema",f)).read())
c.commit(); c.close()
c=_db.connect(db_path=dbp)
def has_table(c,t): return c.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",(t,)).fetchone() is not None
def has_col(c,t,col): return col in {r[1] for r in c.execute(f"PRAGMA table_info({t})")}
sv=sorted(r[0] for r in c.execute("SELECT version FROM schema_version"))
print(has_table(c,"intervention"), has_col(c,"tool","kind"), sv)
c.close()
EOF
)"
has "$V3OUT" "True True" "v3-crash heal creates intervention table AND tool.kind (no skipped 004)"
has "$V3OUT" "1, 2, 3, 4, 5, 9, 10, 11, 12" "all versions applied, no gap at 4"
rm -rf "$SB"

echo "C) rust backend-compat guard"
SB="$(mktemp -d)"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_BACKEND=rust "$PY" "$H" query matrix >/dev/null 2>&1; ck 2 $? "rust on flow-lineage DB refused (exit 2)"
G="$(FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_BACKEND=rust "$PY" "$H" query matrix 2>&1 >/dev/null)"
has "$G" "refusing to forward to the rust backend" "guard prints a guiding refusal"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" query matrix >/dev/null 2>&1; ck 0 $? "python backend still works on same DB"
rm -rf "$SB"

echo; echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
