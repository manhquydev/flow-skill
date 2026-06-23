"""SQLite durable layer for the flow harness (stdlib sqlite3 only).

Schema lives in schema/00N-*.sql (verbatim from repository-harness) and is applied
in order; each migration bumps schema_version, so init/upgrade is idempotent.
DB path defaults to <FLOW_PROJECT_ROOT>/.flow/harness.db.
"""

import os
import re
import sqlite3

SCHEMA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "schema")


def default_db_path(root=None):
    root = root or os.environ.get("FLOW_PROJECT_ROOT") or os.getcwd()
    # On native Windows Python, translate a Git Bash POSIX root like /c/proj -> c:/proj
    # so the db lands under the project (not relative to the current drive root). Only
    # triggers for /<single-letter>/...; leaves /tmp and absolute Windows paths alone.
    if os.name == "nt":
        m = re.match(r"^/([a-zA-Z])/(.*)$", root)
        if m:
            root = m.group(1) + ":/" + m.group(2)
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
        con.execute(p)
    try:
        con.execute("BEGIN")
        for s in ddl:
            stmt = _idempotent_statement(con, s)
            if stmt is None:
                continue
            con.execute(stmt)
        con.execute("COMMIT")
    except Exception:
        con.execute("ROLLBACK")
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


def migrate(con):
    """Apply every migration whose version is above the current schema_version."""
    migs = _migrations()
    _reconcile_legacy(con, migs)
    cur = _current_version(con)
    applied = []
    for version, path in migs:
        if version <= cur:
            continue
        with open(path, "r", encoding="utf-8") as fh:
            sql = fh.read()
        _apply_migration(con, sql)
        applied.append(version)
    return applied


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


def rows(con, sql, params=()):
    return [dict(r) for r in con.execute(sql, params).fetchall()]


def one(con, sql, params=()):
    r = con.execute(sql, params).fetchone()
    return dict(r) if r else None
