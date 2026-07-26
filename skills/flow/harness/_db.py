"""SQLite durable layer for the flow harness (stdlib sqlite3 only).

Schema lives in schema/00N-*.sql (001-005 a faithful port of repository-harness; 009-012
flow-specific: accessed-count + usage-log mirror; 014+ flow-owned graph-executor band) and is
applied by missing-version set; each migration bumps schema_version and statements are
idempotent, so init/upgrade is safe to re-run. DB path defaults to
<FLOW_PROJECT_ROOT>/.flow/harness.db, translated to the MAIN worktree when the root sits
inside a linked git worktree so every parallel card shares one DB.
"""

import contextlib
import os
import re
import sqlite3
import subprocess
import time

SCHEMA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "schema")


_worktree_main_cache = {}


def _git_env():
    """Strip inherited GIT_DIR/GIT_WORK_TREE (exported by every git hook, `rebase -x`,
    `bisect run`, `submodule foreach`): with them set, git answers about a FOREIGN repo
    and the worktree translation silently splits the journal."""
    env = dict(os.environ)
    for k in ("GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE",
              "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"):
        env.pop(k, None)
    return env


def _linked_worktree_main_root(root):
    """Map `root` inside a LINKED git worktree to its main-worktree equivalent path, else None.

    Card worktrees are full checkouts (they contain flow/ + cards/), so without this
    translation every parallel card mints its own throwaway .flow/harness.db that
    `git worktree remove` then deletes. Keys on the RESOLVED ROOT (never CWD — flow.sh
    passes FLOW_PROJECT_ROOT per call and the two are independent). Cached per process:
    this runs on every connect and an uncached `git` spawn multiplies on Windows.
    Any failure (git absent, git < 2.31, not a repo) returns None = current behavior.
    """
    if root in _worktree_main_cache:
        return _worktree_main_cache[root]
    out = None
    try:
        r = subprocess.run(
            ["git", "-C", root, "rev-parse", "--path-format=absolute",
             "--git-dir", "--git-common-dir", "--show-toplevel"],
            capture_output=True, text=True, timeout=10, env=_git_env(),
        )
        git_dir = common_dir = worktree_top = None
        if r.returncode == 0:
            vals = [ln.strip() for ln in r.stdout.splitlines() if ln.strip()]
            if len(vals) >= 3:
                git_dir, common_dir, worktree_top = vals[0], vals[1], vals[2]
        elif "not a git repository" not in (r.stderr or "").lower():
            # git < 2.31 lacks --path-format (declared floor); best-effort re-derive.
            # Gated on the failure NOT being "not a repo" so non-git roots cost one spawn.
            def _rp(flag):
                q = subprocess.run(["git", "-C", root, "rev-parse", flag], env=_git_env(),
                                   capture_output=True, text=True, timeout=10)
                return q.stdout.strip() if q.returncode == 0 and q.stdout.strip() else None
            git_dir = _rp("--absolute-git-dir")
            common_dir = _rp("--git-common-dir")
            worktree_top = _rp("--show-toplevel")
            if common_dir and not os.path.isabs(common_dir):
                common_dir = os.path.abspath(os.path.join(root, common_dir))
        if git_dir and common_dir and worktree_top:
            # Linked worktree iff the per-worktree git dir differs from the shared common
            # dir. Submodules and --separate-git-dir repos have git_dir == common_dir (both
            # live OUTSIDE the worktree) and must never be translated - dirname(common_dir)
            # is git internals there, not a project root. realpath everywhere: macOS mktemp
            # and symlinked checkouts otherwise fail the containment compare silently.
            if os.path.realpath(git_dir) != os.path.realpath(common_dir):
                wt = subprocess.run(["git", "-C", root, "worktree", "list", "--porcelain"], env=_git_env(),
                                    capture_output=True, text=True, timeout=10)
                first = next((ln for ln in wt.stdout.splitlines()
                              if ln.startswith("worktree ")), "") if wt.returncode == 0 else ""
                main_top = first[len("worktree "):].strip()  # main worktree is always first
                # --separate-git-dir: the main `.git` is a FILE, so git itself reports the
                # separate git dir as the "main worktree" and does not record the checkout
                # anywhere discoverable (core.worktree is unset). Translating would put the
                # DB inside git internals, so REFUSE instead of guessing: the worktree keeps
                # its own DB (pre-graph behavior), documented in README, rather than
                # corrupting state. A real checkout always has a `.git` entry.
                if main_top and not os.path.exists(os.path.join(main_top, ".git")):
                    main_top = ""
                rr = os.path.realpath(root)
                wtop = os.path.realpath(worktree_top)
                inside = rr == wtop or rr.startswith(wtop + os.sep)
                if main_top and inside:
                    main_top = os.path.realpath(main_top)
                    rel = os.path.relpath(rr, wtop)
                    out = main_top if rel == "." else os.path.join(main_top, rel)
    except Exception:
        out = None  # best-effort: never break the python path over the resolver
    _worktree_main_cache[root] = out
    return out


def default_db_path(root=None):
    # Narrow override for tests/tools: DB path ONLY. Never FLOW_PROJECT_ROOT — that is
    # the global root override and repurposing it would hijack CARDS_DIR/lock/DEBT
    # resolution for every flow.sh call in a worktree.
    override = os.environ.get("FLOW_HARNESS_DB")
    if override:
        return override
    root = root or os.environ.get("FLOW_PROJECT_ROOT") or os.getcwd()
    # On native Windows Python, translate a Git Bash POSIX root like /c/proj -> c:/proj
    # so the db lands under the project (not relative to the current drive root). Only
    # triggers for /<single-letter>/...; leaves /tmp and absolute Windows paths alone.
    if os.name == "nt":
        m = re.match(r"^/([a-zA-Z])/(.*)$", root)
        if m:
            root = m.group(1) + ":/" + m.group(2)
    main_equiv = _linked_worktree_main_root(root)
    if main_equiv:
        root = main_equiv
    return os.path.join(root, ".flow", "harness.db")


def _migrations():
    """Return [(version, path)] sorted by leading number in the filename."""
    out = []
    if not os.path.isdir(SCHEMA_DIR):
        return out
    for name in sorted(os.listdir(SCHEMA_DIR)):
        m = re.match(r"(\d+)-.*\.sql$", name)
        if m:
            out.append((int(m.group(1)), os.path.join(SCHEMA_DIR, name)))
    out.sort(key=lambda x: x[0])
    return out


def _current_version(con):
    try:
        row = con.execute("SELECT MAX(version) FROM schema_version").fetchone()
        return row[0] or 0
    except sqlite3.OperationalError:
        return 0  # schema_version table not created yet


def _table_exists(con, table):
    row = con.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (table,)
    ).fetchone()
    return row is not None


def _columns(con, table):
    """Set of column names on `table`, or empty set if the table does not exist."""
    if not _table_exists(con, table):
        return set()
    return {r[1] for r in con.execute(f"PRAGMA table_info({table})").fetchall()}


_ADD_COLUMN_RE = re.compile(
    r"^ALTER\s+TABLE\s+(\w+)\s+ADD\s+COLUMN\s+(\w+)", re.IGNORECASE
)


def _idempotent_statement(con, stmt):
    """Return an idempotent form of one DDL statement, or None to skip it.

    Migrations here are purely additive setup, and init/upgrade is meant to be safe to
    re-run (incl. on legacy DBs whose schema_version numbering predates a reconciliation).
    So we neutralize the three statement shapes that would otherwise crash on re-apply:
      - ADD COLUMN on a column that already exists  -> skip
      - CREATE TABLE/INDEX that already exists       -> IF NOT EXISTS
      - INSERT INTO schema_version                   -> INSERT OR IGNORE (version is PK)
    """
    s = stmt.strip()
    up = s.upper()
    m = _ADD_COLUMN_RE.match(s)
    if m:
        table, col = m.group(1), m.group(2)
        if col in _columns(con, table):
            return None  # already added by an earlier run / reconciliation
        return s
    if up.startswith("CREATE TABLE ") and "IF NOT EXISTS" not in up:
        return "CREATE TABLE IF NOT EXISTS " + s[len("CREATE TABLE "):]
    if up.startswith("CREATE INDEX ") and "IF NOT EXISTS" not in up:
        return "CREATE INDEX IF NOT EXISTS " + s[len("CREATE INDEX "):]
    if up.startswith("CREATE UNIQUE INDEX ") and "IF NOT EXISTS" not in up:
        return "CREATE UNIQUE INDEX IF NOT EXISTS " + s[len("CREATE UNIQUE INDEX "):]
    if up.startswith("INSERT INTO SCHEMA_VERSION ") or up.startswith("INSERT INTO SCHEMA_VERSION("):
        return "INSERT OR IGNORE INTO " + s[len("INSERT INTO "):]
    return s


def connect(db_path=None, root=None, auto_migrate=True):
    db_path = db_path or default_db_path(root)
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys = ON")
    # Explicit 5s wait for the write lock: two parallel card workers share one DB
    # (worktree-translated path), so contention must queue, not raise `database is locked`.
    con.execute("PRAGMA busy_timeout = 5000")
    if auto_migrate:
        migrate(con)
    return con


def _split_statements(sql):
    """Split a migration file into executable statements.

    Drops whole-line `--` comments (inline trailing comments are left for SQLite to
    parse). Our schema has no `;` inside string literals, so a plain split is safe.
    """
    body = "\n".join(ln for ln in sql.splitlines() if not ln.strip().startswith("--"))
    return [s.strip() for s in body.split(";") if s.strip()]


def _apply_migration(con, sql):
    """Apply one migration atomically.

    PRAGMA statements (e.g. journal_mode=WAL) cannot run inside a transaction, so they
    run first, outside. The DDL + the schema_version bump run in one transaction, so a
    failure rolls back fully and re-running init stays idempotent (no half-applied ALTER).
    """
    stmts = _split_statements(sql)
    pragmas = [s for s in stmts if s.upper().startswith("PRAGMA")]
    ddl = [s for s in stmts if not s.upper().startswith("PRAGMA")]
    for p in pragmas:
        # Belt-and-braces retry (a pragma can still meet a busy DB on a cold start).
        for attempt in range(20):
            try:
                con.execute(p)
                break
            except sqlite3.OperationalError as e:
                if "locked" not in str(e).lower() and "busy" not in str(e).lower():
                    raise
                if attempt == 19:
                    raise
                time.sleep(0.05 * (attempt + 1))
    try:
        # IMMEDIATE, not deferred: a deferred BEGIN takes SHARED on the first read probe
        # (_idempotent_statement inspects sqlite_master/table_info) and the later DDL must
        # upgrade SHARED->RESERVED - an upgrade SQLite refuses with SQLITE_BUSY IMMEDIATELY,
        # bypassing the busy handler, so busy_timeout never applies. Taking RESERVED up
        # front puts the wait where busy_timeout can cover it. This is what made cold-start
        # parallel card workers lose records.
        con.execute("BEGIN IMMEDIATE")
        for s in ddl:
            stmt = _idempotent_statement(con, s)
            if stmt is None:
                continue
            con.execute(stmt)
        con.execute("COMMIT")
    except Exception:
        # rollback(), not execute("ROLLBACK"): if BEGIN IMMEDIATE itself failed there is no
        # active transaction, and the raw statement would raise "cannot rollback", masking
        # the original lock error.
        con.rollback()
        raise


def _reconcile_legacy(con, migs):
    """Heal DBs created before the schema-005 reconciliation.

    flow once numbered its accessed-count migration as 005, the same number upstream
    repository-harness uses for the inbound tool-registry extension. A DB built under the
    old numbering recorded version 5 (= accessed-count) and carries usage migrations 006-008,
    so the plain version>MAX gate skips the real 005 (tool-extensions, now re-homed) and the
    `tool` table never gains its kind/capability/status columns. Detect that exact state
    (the legacy `tool` table exists but lacks `kind`) and apply the tool-extensions DDL
    directly. The statements are idempotent, so on a fresh or already-healed DB this is a
    no-op (a fresh `tool` is created with `kind` by migration 005 in the normal loop)."""
    if "kind" in _columns(con, "tool"):
        return  # fresh or already healed
    if not _table_exists(con, "tool"):
        return  # nothing to heal yet; the normal loop will create tool + extensions
    for version, path in migs:
        if version != 5:
            continue
        with open(path, "r", encoding="utf-8") as fh:
            _apply_migration(con, fh.read())
        return


def _applied_versions(con):
    try:
        return {r[0] for r in con.execute("SELECT version FROM schema_version").fetchall()}
    except sqlite3.OperationalError:
        return set()


def migrate(con):
    """Apply every migration whose version is not yet recorded in schema_version.

    Set-membership, NOT version>MAX: a reconciliation that inserts a high version out of order,
    or a crash that left a gap below the max, must still apply the missing lower migrations. E.g.
    an init interrupted between 003 and 004, then healed by _reconcile_legacy inserting 005, must
    still create migration 004 (the intervention table) — a `version <= MAX` gate would skip it."""
    migs = _migrations()
    _reconcile_legacy(con, migs)
    applied = _applied_versions(con)
    out = []
    for version, path in migs:
        if version in applied:
            continue
        with open(path, "r", encoding="utf-8") as fh:
            sql = fh.read()
        _apply_migration(con, sql)
        out.append(version)
    return out


def insert(con, table, **cols):
    # SECURITY INVARIANT: `table` must be a code literal, never user input.
    # Columns whose value is None are omitted; callers ensure NOT NULL columns are non-None.
    keys = [k for k, v in cols.items() if v is not None]
    vals = [cols[k] for k in keys]
    ph = ", ".join("?" for _ in keys)
    sql = f"INSERT INTO {table} ({', '.join(keys)}) VALUES ({ph})"
    cur = con.execute(sql, vals)
    con.commit()
    return cur.lastrowid


def update(con, table, id_col, id_val, **cols):
    # SECURITY INVARIANT: `table` and `id_col` must be code literals, never user input.
    sets, vals = [], []
    for k, v in cols.items():
        if v is not None:
            sets.append(f"{k} = ?")
            vals.append(v)
    if not sets:
        return 0
    vals.append(id_val)
    sql = f"UPDATE {table} SET {', '.join(sets)} WHERE {id_col} = ?"
    cur = con.execute(sql, vals)
    con.commit()
    return cur.rowcount


def update_where(con, table, where, **cols):
    # SECURITY INVARIANT: `table` and every key in `where`/`cols` must be code literals,
    # never user input. Composite-key variant of update() for the graph tables whose
    # primary keys span (execution_id, ns, ...); update()'s single id_col cannot address them.
    sets, vals = [], []
    for k, v in cols.items():
        if v is not None:
            sets.append(f"{k} = ?")
            vals.append(v)
    if not sets:
        return 0
    conds = []
    for k, v in where.items():
        if v is None:
            # `col = NULL` never matches in SQL - a None key would silently update nothing.
            raise ValueError(f"update_where: where[{k!r}] is None")
        conds.append(f"{k} = ?")
        vals.append(v)
    sql = f"UPDATE {table} SET {', '.join(sets)} WHERE {' AND '.join(conds)}"
    cur = con.execute(sql, vals)
    con.commit()
    return cur.rowcount


@contextlib.contextmanager
def transaction(con):
    """Multi-row atomicity: BEGIN IMMEDIATE ... COMMIT/ROLLBACK.

    IMMEDIATE takes the write lock up front so concurrent worktree writers queue on
    busy_timeout instead of failing mid-transaction. Do NOT call insert()/update()/
    update_where() inside this block — their per-call con.commit() would end the
    transaction early; use con.execute directly. An already-open transaction at entry
    RAISES (this helper never commits or discards a caller's pending work). The
    except-path uses con.rollback(), a no-op when SQLite already auto-rolled-back
    (disk full / IO error), so the ORIGINAL exception always propagates.
    """
    if con.in_transaction:
        raise sqlite3.ProgrammingError(
            "transaction(): connection already has an open transaction - "
            "commit or roll it back before entering this block"
        )
    con.execute("BEGIN IMMEDIATE")
    try:
        yield con
        con.commit()
    except Exception:
        con.rollback()
        raise


def rows(con, sql, params=()):
    return [dict(r) for r in con.execute(sql, params).fetchall()]


def one(con, sql, params=()):
    r = con.execute(sql, params).fetchone()
    return dict(r) if r else None
