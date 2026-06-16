-- Harness v0 schema - migration 005
-- Usage signal: accessed_count tracks how often a durable row is surfaced by recall/query.
-- Read-only reuse signal: incremented on read only, NEVER used to delete or prune a row
-- (a rare-but-critical one-time lesson must survive a low access count). Surfaces what is reused.

ALTER TABLE decision ADD COLUMN accessed_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE trace ADD COLUMN accessed_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE backlog ADD COLUMN accessed_count INTEGER NOT NULL DEFAULT 0;

INSERT INTO schema_version (version) VALUES (5);
