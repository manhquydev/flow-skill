-- Harness schema - migration 006
-- Mechanical usage-log mirror. The append-only JSONL sinks (.flow/events.jsonl full,
-- ~/.claude/flow/usage.jsonl compact) are the source of truth; this table is a derived,
-- queryable rollup for `flow usage` stats. Idempotency rests on UNIQUE(src,line_no):
-- re-rolling the same append-only line is ignored. rollup_cursor stores the last line
-- number processed per source file (a skip-ahead optimization; correctness is the UNIQUE key).

CREATE TABLE usage_event (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    src           TEXT    NOT NULL,        -- absolute path of the JSONL sink the row came from
    line_no       INTEGER NOT NULL,        -- 1-based line number within that file
    epoch_s       INTEGER,
    session_id    TEXT,
    cycle_id      TEXT,
    project       TEXT,
    command       TEXT,
    args          TEXT,
    exit_code     INTEGER,
    gate_pass     INTEGER,                 -- 1 / 0 / NULL (non-gate command)
    duration_s    INTEGER,
    stage_from    TEXT,
    stage_to      TEXT,
    card          TEXT,
    project_type  TEXT,
    mode          TEXT,
    flow_version  TEXT,
    tier          TEXT,
    host          TEXT,
    read_only     INTEGER,
    UNIQUE(src, line_no)
);

CREATE INDEX idx_usage_event_cycle ON usage_event(cycle_id);
CREATE INDEX idx_usage_event_cmd   ON usage_event(command);

CREATE TABLE rollup_cursor (
    src         TEXT PRIMARY KEY,
    last_line   INTEGER NOT NULL DEFAULT 0,
    updated_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO schema_version (version) VALUES (6);
