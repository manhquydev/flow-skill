-- Harness schema - migration 015 (flow-owned).
-- Verify-command receipt mirror. The append-only JSONL sink (.flow/events.jsonl,
-- kind:"verify-receipt") is the source of truth; this table is a derived, queryable
-- rollup written by cmd_rollup. Idempotency rests on UNIQUE(src, line_no): re-rolling
-- the same append-only line is ignored (same discipline as usage_event, migration 010).

CREATE TABLE verify_receipt (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    src        TEXT    NOT NULL,        -- absolute path of the JSONL sink the row came from
    line_no    INTEGER NOT NULL,        -- 1-based line number within that file
    card       TEXT,
    cmd        TEXT,
    sha256     TEXT,                    -- sha256 (hex) of merged stdout+stderr
    exit_code  INTEGER,
    UNIQUE(src, line_no)
);

CREATE INDEX idx_verify_receipt_card ON verify_receipt(card);

INSERT INTO schema_version (version) VALUES (15);
