-- Harness schema - migration 008
-- Mark throwaway/test runs so device-wide analytics aren't dominated by them. A run is
-- ephemeral when its project root is under the system temp dir or named like an mktemp dir.
-- Additive column; old JSONL lines without the field roll up as NULL and are treated as
-- non-ephemeral, except the read-time `project LIKE 'tmp.%'` fallback still excludes legacy
-- temp runs from the default view (back-compatible, no log rewrite).

ALTER TABLE usage_event ADD COLUMN ephemeral INTEGER;

INSERT INTO schema_version (version) VALUES (8);
