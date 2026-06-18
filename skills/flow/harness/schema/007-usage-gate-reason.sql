-- Harness schema - migration 007
-- Record WHICH gate check failed (not just the gate_pass bool) so "stage X fails often" is
-- diagnosable from the usage log. Additive column on the existing mirror; no new table.
-- Old JSONL lines without the field roll up as NULL (back-compatible).

ALTER TABLE usage_event ADD COLUMN gate_fail_reason TEXT;

INSERT INTO schema_version (version) VALUES (7);
