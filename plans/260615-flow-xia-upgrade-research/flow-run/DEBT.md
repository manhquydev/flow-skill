# DEBT — deliberate gate-skips & accepted exposures

- [x] DEBT: C-001 ships a schema migration (`005-accessed-count.sql`) — Tier-C data-migration
  class — the exposure: an `ALTER TABLE ADD COLUMN accessed_count INTEGER NOT NULL DEFAULT 0`
  on decision/trace/backlog in existing project harness DBs. Accepted by the operator (standing
  authorization to complete the upgrade autonomously, 2026-06-16). Why low exposure: additive,
  idempotent (version-guarded), back-compatible (existing rows default to 0), non-destructive,
  no data loss, no PII — it is the flow harness's own internal bookkeeping table. — opened
  2026-06-16 (cards: C-001).
