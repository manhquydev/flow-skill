-- flow-owned schema - migration 014 (graph-executor band 014+)
-- Graph executor foundation: execution journal, checkpoints (evidence manifests, never
-- blobs), step writes, and operator interrupts. 013 stays reserved/absent (upstream
-- changeset content sha); 014+ is flow-owned per the 2026-07-26 supersession of the
-- work-graph red line (see GAP-MATRIX-0.1.17.md).

CREATE TABLE graph_execution (
    id               TEXT PRIMARY KEY,
    project          TEXT NOT NULL,
    kind             TEXT NOT NULL CHECK(kind IN ('auto_run','planning','card')),
    topology_version INTEGER NOT NULL,
    topology_hash    TEXT NOT NULL,
    status           TEXT NOT NULL DEFAULT 'running'
                     CHECK(status IN ('running','paused','done','failed','abandoned')),
    outcome          TEXT,
    story_id         TEXT REFERENCES story(id),
    created_at       TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_graph_execution_status ON graph_execution(status);

CREATE TABLE graph_checkpoint (
    execution_id         TEXT NOT NULL REFERENCES graph_execution(id) ON DELETE CASCADE,
    ns                   TEXT NOT NULL DEFAULT '',
    checkpoint_id        TEXT NOT NULL,
    parent_checkpoint_id TEXT,
    node                 TEXT NOT NULL,
    manifest             TEXT NOT NULL,
    versions             TEXT NOT NULL,
    seen                 TEXT NOT NULL,
    meta                 TEXT NOT NULL,
    PRIMARY KEY (execution_id, ns, checkpoint_id)
);

CREATE INDEX idx_graph_checkpoint_parent ON graph_checkpoint(parent_checkpoint_id);

CREATE TABLE graph_step_write (
    execution_id  TEXT NOT NULL REFERENCES graph_execution(id) ON DELETE CASCADE,
    ns            TEXT NOT NULL DEFAULT '',
    checkpoint_id TEXT NOT NULL,
    task_id       TEXT NOT NULL,
    idx           INTEGER NOT NULL,
    channel       TEXT NOT NULL,
    value         TEXT NOT NULL,
    PRIMARY KEY (execution_id, ns, checkpoint_id, task_id, idx)
);

CREATE TABLE graph_interrupt (
    execution_id   TEXT NOT NULL REFERENCES graph_execution(id) ON DELETE CASCADE,
    ns             TEXT NOT NULL DEFAULT '',
    interrupt_id   TEXT NOT NULL,
    node           TEXT NOT NULL,
    prompt         TEXT NOT NULL,
    security_class INTEGER NOT NULL DEFAULT 0,
    resume_value   TEXT,
    resolved_by    TEXT,
    status         TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved','abandoned')),
    created_at     TEXT NOT NULL DEFAULT (datetime('now')),
    resolved_at    TEXT,
    PRIMARY KEY (execution_id, ns, interrupt_id)
);

CREATE UNIQUE INDEX idx_graph_interrupt_one_open
  ON graph_interrupt(execution_id, ns, node) WHERE status = 'open';

INSERT INTO schema_version (version) VALUES (14);
