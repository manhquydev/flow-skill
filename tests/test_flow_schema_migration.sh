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
PY="$(command -v python3 || command -v python)"
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
has "$FRESH" "5, 9, 10, 11, 12, 14" "tool-extensions(5) + re-homed flow migrations(9-12) + graph band(14) applied"
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
has "$LEGOUT" "5, 6, 7, 8, 9, 10, 11, 12, 14" "schema_version normalized to 1-12 + graph band 14"
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
has "$V3OUT" "1, 2, 3, 4, 5, 9, 10, 11, 12, 14" "all versions applied, no gap at 4"
rm -rf "$SB"

echo "C) rust backend-compat guard"
SB="$(mktemp -d)"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_BACKEND=rust "$PY" "$H" query matrix >/dev/null 2>&1; ck 2 $? "rust on flow-lineage DB refused (exit 2)"
G="$(FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_BACKEND=rust "$PY" "$H" query matrix 2>&1 >/dev/null)"
has "$G" "refusing to forward to the rust backend" "guard prints a guiding refusal"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" query matrix >/dev/null 2>&1; ck 0 $? "python backend still works on same DB"
rm -rf "$SB"

echo "D) populated WAL database backup, interruption, restore and repeat"
SB="$(mktemp -d)"
RECOVERY="$("$PY" - "$HDIR" "$SB" <<'EOF'
import glob, os, sqlite3, subprocess, sys
sys.path.insert(0, sys.argv[1])
import _db
path = os.path.join(sys.argv[2], "populated.db")
c = _db.connect(db_path=path)
c.execute("PRAGMA journal_mode=WAL")
c.execute("PRAGMA wal_autocheckpoint=0")
c.execute("INSERT INTO story(id,title,risk_lane) VALUES ('S-1','preserved','normal')")
c.execute("INSERT INTO decision(id,title) VALUES ('0001','durable')")
c.execute("INSERT INTO usage_event(src,line_no,command) VALUES ('wal',1,'next')")
c.execute("INSERT INTO trace(task_summary,story_id,outcome) VALUES ('preserved trace','S-1','completed')")
c.execute("INSERT INTO graph_execution(id,project,kind,topology_version,topology_hash,status) "
          "VALUES ('dark','fixture','planning',0,'','paused')")
c.execute("INSERT INTO graph_checkpoint(execution_id,ns,checkpoint_id,node,manifest,versions,seen,meta) "
          "VALUES ('dark','','ck','stage-00','{}','{}','{}','{}')")
c.execute("INSERT INTO graph_interrupt(execution_id,ns,interrupt_id,node,prompt) "
          "VALUES ('dark','','interrupt','stage-00','operator required')")
# Simulate a missing migration marker: additive DDL must preserve every existing row.
c.execute("DELETE FROM schema_version WHERE version=14")
# An interrupted migration must roll back its DDL, row writes and version together.
c.commit()
try:
    _db._apply_migration(c, "CREATE TABLE half_applied (x INTEGER); "
                         "INSERT INTO schema_version(version) VALUES (99); "
                         "INSERT INTO missing_table VALUES (1);")
    raise AssertionError('bad migration accepted')
except sqlite3.OperationalError:
    assert not _db._table_exists(c, 'half_applied')
    assert c.execute('SELECT 1 FROM schema_version WHERE version=99').fetchone() is None
c.commit()
def snapshot(db):
    names = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
    return {n: [tuple(r) for r in db.execute('SELECT * FROM "' + n + '" ORDER BY rowid')] for n in names}
before = snapshot(c)
assert os.path.getsize(path + '-wal') > 0
_db.migrate(c)
backups = glob.glob(path + '.pre-migration-*.sqlite3')
assert len(backups) == 1
b = sqlite3.connect(backups[0])
assert snapshot(b) == before, 'backup must contain committed WAL state before DDL'
assert b.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
after = snapshot(c)
assert {k:v for k,v in after.items() if k != 'schema_version'} == {
    k:v for k,v in before.items() if k != 'schema_version'}
_db.migrate(c)
assert snapshot(c) == after
assert glob.glob(path + '.pre-migration-*.sqlite3') == backups
print('WAL snapshot and populated graph preserved; repeat creates no backup')
# Restore to a separate, settled destination using SQLite, never copy a live main file.
restored = sqlite3.connect(os.path.join(sys.argv[2], 'restored.db'))
b.backup(restored)
assert snapshot(restored) == before
restored.close(); b.close()
print('restore exact pre-migration readback')
# Backup failure must prevent even the schema-version bump.
c.execute('DELETE FROM schema_version WHERE version=14'); c.commit()
failed_before = snapshot(c)
original = _db._backup_before_migration
def fail_backup(con):
    raise OSError('injected backup failure')
_db._backup_before_migration = fail_backup
try:
    _db.migrate(c)
    raise AssertionError('migration accepted failed backup')
except OSError:
    assert snapshot(c) == failed_before
finally:
    _db._backup_before_migration = original
print('backup failure blocks migration')
# A directory-fsync error after publication must still block all migration DDL.
import stat
real_fsync = os.fsync
syncs = []
def fail_directory_sync(fd):
    is_directory = stat.S_ISDIR(os.fstat(fd).st_mode)
    syncs.append('directory' if is_directory else 'file')
    if is_directory:
        raise OSError('injected directory fsync failure')
    return real_fsync(fd)
os.fsync = fail_directory_sync
try:
    _db.migrate(c)
    raise AssertionError('migration accepted failed directory fsync')
except OSError:
    assert snapshot(c) == failed_before
    assert syncs == ['file', 'directory']
finally:
    os.fsync = real_fsync
print('file synced before publication; directory fsync failure blocks DDL')
# Kill a separate writer while DDL and data are uncommitted. Reopen must roll both back.
code = '''import os,sqlite3,sys
c=sqlite3.connect(sys.argv[1]); c.execute('BEGIN IMMEDIATE')
c.execute('CREATE TABLE interrupted (x INTEGER)')
c.execute("INSERT INTO decision(id,title) VALUES ('lost','uncommitted')")
os._exit(23)
'''
assert subprocess.run([sys.executable, '-c', code, path]).returncode == 23
c.close(); c = _db.connect(db_path=path)
assert not _db._table_exists(c, 'interrupted')
assert c.execute("SELECT 1 FROM decision WHERE id='lost'").fetchone() is None
assert c.execute("SELECT status FROM graph_execution WHERE id='dark'").fetchone()[0] == 'paused'
assert c.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
print('process interruption rolls back DDL and data; retry preserves pause')
c.close()
# Exercise actual migrate -> backup -> migration transaction under process death.
migration = os.path.join(sys.argv[2], '015-interruption.sql')
with open(migration, 'w') as f:
    f.write("CREATE TABLE migration_interrupted (x INTEGER); "
            "INSERT INTO decision(id,title) VALUES ('retry','migration write'); "
            "INSERT INTO schema_version(version) VALUES (15);")
prior_backups = set(glob.glob(path + '.pre-migration-*.sqlite3'))
c = _db.connect(db_path=path, auto_migrate=False)
pre_crash = snapshot(c); c.close()
code = '''import os,sys
sys.path.insert(0,sys.argv[1]); import _db
c=_db.connect(db_path=sys.argv[2],auto_migrate=False)
_db._migrations=lambda:[(15,sys.argv[3])]
def interrupt(sql):
    if 'INSERT' in sql and 'schema_version' in sql:
        os._exit(29)
c.set_trace_callback(interrupt)
_db.migrate(c)
'''
assert subprocess.run([sys.executable, '-c', code, sys.argv[1], path, migration]).returncode == 29
retained = set(glob.glob(path + '.pre-migration-*.sqlite3')) - prior_backups
assert len(retained) == 1
retained_path = retained.pop()
with sqlite3.connect(retained_path) as preserved:
    assert snapshot(preserved) == pre_crash
    restored = sqlite3.connect(os.path.join(sys.argv[2], 'interrupted-restore.db'))
    preserved.backup(restored)
    assert snapshot(restored) == pre_crash
    restored.close()
c = _db.connect(db_path=path, auto_migrate=False)
assert snapshot(c) == pre_crash
original_migrations = _db._migrations
try:
    _db._migrations = lambda: [(15, migration)]
    assert _db.migrate(c) == [15]
    assert _db.migrate(c) == []
finally:
    _db._migrations = original_migrations
assert c.execute("SELECT title FROM decision WHERE id='retry'").fetchone()[0] == 'migration write'
assert c.execute("SELECT status FROM graph_execution WHERE id='dark'").fetchone()[0] == 'paused'
with sqlite3.connect(retained_path) as preserved:
    assert snapshot(preserved) == pre_crash
c.close()
print('actual migrate interrupted after backup; snapshot retained/restored; retry idempotent')
EOF
)"
ck 0 $? "recovery assertions complete"
has "$RECOVERY" "WAL snapshot and populated graph preserved" "WAL backup contains populated pre-upgrade state"
has "$RECOVERY" "restore exact pre-migration readback" "backup restores exact state"
has "$RECOVERY" "backup failure blocks migration" "backup failure is fail-closed"
has "$RECOVERY" "process interruption rolls back DDL and data" "interrupted transaction recovers"
has "$RECOVERY" "directory fsync failure blocks DDL" "durable publication failure blocks migration"
has "$RECOVERY" "actual migrate interrupted after backup" "migrate interruption retains recoverable backup and retries"
rm -rf "$SB"
echo "E) Windows durable directory fsync publication and error handling"
SB="$(mktemp -d)"
WIN_FSYNC="$("$PY" - "$HDIR" "$SB" <<'EOF'
import ctypes, os, sqlite3, sys, tempfile, types
sys.path.insert(0, sys.argv[1])
import _db

class MockFunc:
    def __init__(self, fn):
        self.fn = fn
        self.argtypes = None
        self.restype = None
    def __call__(self, *args):
        if self.argtypes is not None:
            from ctypes import wintypes
            for arg, expected_type in zip(args, self.argtypes):
                if expected_type == wintypes.HANDLE:
                    wintypes.HANDLE(arg)
        return self.fn(*args)

orig_windll_class = getattr(ctypes, "WinDLL", None)
orig_windll = getattr(ctypes, "windll", None)
orig_msvcrt = sys.modules.get("msvcrt")
orig_fsync = os.fsync
orig_close = os.close
orig_os_name = os.name

try:
    calls = []
    closed = []
    def mock_create_file(path, access, share, sec, disp, flags, template):
        calls.append(("create_file", path, access, share, disp, flags))
        return 12345
    def mock_close_handle(h):
        closed.append(h)

    mock_k32 = types.SimpleNamespace()
    mock_k32.CreateFileW = MockFunc(mock_create_file)
    mock_k32.CloseHandle = MockFunc(mock_close_handle)
    windll_loader_calls = []
    def mock_windll(name, use_last_error=False):
        windll_loader_calls.append((name, use_last_error))
        return mock_k32
    ctypes.WinDLL = mock_windll
    ctypes.windll = types.SimpleNamespace(kernel32=mock_k32)
    mock_msvcrt = types.ModuleType("msvcrt")
    mock_msvcrt.open_osfhandle = lambda h, flags: 88
    sys.modules["msvcrt"] = mock_msvcrt

    fsync_calls = []
    close_calls = []
    os.fsync = lambda fd: fsync_calls.append(fd)
    os.close = lambda fd: close_calls.append(fd)

    # 1. Normal path: CreateFileW flags, open_osfhandle, fsync, close(fd)
    from ctypes import wintypes
    _db._fsync_directory_windows("/mock/dir")
    assert windll_loader_calls == [("kernel32", True)]
    assert mock_k32.CloseHandle.argtypes == [wintypes.HANDLE]
    assert mock_k32.CloseHandle.restype == wintypes.BOOL
    assert calls == [("create_file", "/mock/dir", 0xC0000000, 0x3, 3, 0x02000000)]
    assert fsync_calls == [88] and close_calls == [88]
    assert closed == []  # CloseHandle handled by os.close(fd)
    print("windows fsync flags, use_last_error loader and lifecycle verified")

    # 2. Invalid handle: CreateFileW returns INVALID_HANDLE_VALUE
    mock_k32.CreateFileW = MockFunc(lambda *a: ctypes.c_void_p(-1).value)
    try:
        _db._fsync_directory_windows("/mock/dir")
        raise AssertionError("invalid handle accepted")
    except OSError as e:
        assert "CreateFileW failed" in str(e)
        assert closed == []
    print("windows fsync invalid handle fails closed")

    # 3. open_osfhandle failure: CloseHandle called directly with handle >= 2**31
    large_handle = (1 << 63) - 1
    mock_k32.CreateFileW = MockFunc(lambda *a: large_handle)
    def fail_open(h, flags):
        raise OSError("open_osfhandle failed")
    mock_msvcrt.open_osfhandle = fail_open
    try:
        _db._fsync_directory_windows("/mock/dir")
        raise AssertionError("open_osfhandle failure swallowed")
    except OSError:
        assert closed == [large_handle]
    print("windows open_osfhandle failure closes large handle with prototype")

    # 4. fsync failure: os.close called in finally
    mock_msvcrt.open_osfhandle = lambda h, flags: 99
    close_calls.clear()
    os.fsync = lambda fd: (_ for _ in ()).throw(OSError("injected win fsync error"))
    try:
        _db._fsync_directory_windows("/mock/dir")
        raise AssertionError("fsync error swallowed")
    except OSError:
        assert close_calls == [99]
    print("windows fsync error closes fd in finally")

    # Restore OS functions before testing _backup_before_migration integration
    os.fsync = orig_fsync
    os.close = orig_close

    # 5. Integration: _backup_before_migration exercises Windows fsync on os.name == 'nt'
    dbp = os.path.join(sys.argv[2], "win_test.db")
    c = _db.connect(db_path=dbp)
    c.execute("INSERT INTO story(id,title,risk_lane) VALUES ('S-1','win','normal')")
    c.execute("DELETE FROM schema_version WHERE version=14")
    c.commit()

    win_sync_dirs = []
    _db._fsync_directory_windows = lambda d: win_sync_dirs.append(d)
    _db.os.name = "nt"
    _db.migrate(c)
    assert len(win_sync_dirs) == 1 and os.path.samefile(win_sync_dirs[0], sys.argv[2])
    print("backup before migration routes to windows fsync when nt")

    # 6. Windows fsync failure blocks DDL and version bump
    c.execute("DELETE FROM schema_version WHERE version=14")
    c.commit()
    def fail_win(d):
        raise OSError("windows fsync failure")
    _db._fsync_directory_windows = fail_win
    try:
        _db.migrate(c)
        raise AssertionError("migration accepted failing windows fsync")
    except OSError:
        assert c.execute("SELECT 1 FROM schema_version WHERE version=14").fetchone() is None
    c.close()
    print("windows fsync failure blocks migration DDL")

finally:
    if orig_windll_class is None:
        if hasattr(ctypes, "WinDLL"):
            del ctypes.WinDLL
    else:
        ctypes.WinDLL = orig_windll_class
    if orig_windll is None:
        if hasattr(ctypes, "windll"):
            del ctypes.windll
    else:
        ctypes.windll = orig_windll
    if orig_msvcrt is None:
        sys.modules.pop("msvcrt", None)
    else:
        sys.modules["msvcrt"] = orig_msvcrt
    os.fsync = orig_fsync
    os.close = orig_close
    _db.os.name = orig_os_name
EOF
)"
ck 0 $? "windows fsync assertions complete"
has "$WIN_FSYNC" "windows fsync flags, use_last_error loader and lifecycle verified" "CreateFileW flags, use_last_error loader and open/sync/close lifecycle verified"
has "$WIN_FSYNC" "windows fsync invalid handle fails closed" "invalid handle aborts without CloseHandle"
has "$WIN_FSYNC" "windows open_osfhandle failure closes large handle with prototype" "open failure closes large OS handle with declared prototype"
has "$WIN_FSYNC" "windows fsync error closes fd in finally" "fsync error ensures fd closed"
has "$WIN_FSYNC" "backup before migration routes to windows fsync when nt" "nt routes to windows directory fsync"
has "$WIN_FSYNC" "windows fsync failure blocks migration DDL" "windows fsync error fail-closed blocks DDL"
rm -rf "$SB"


echo; echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
