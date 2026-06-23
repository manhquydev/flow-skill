# Phase 01 (P0): schema-005 collision fix + backend-compat guard

**Depends on:** none · **Blocks:** Phase 02 · **Effort:** 5–8h

## Problem (verified)

- flow `schema/005-accessed-count.sql` vs upstream `005-tool-extensions.sql` — same version, different DDL.
- Migration runner (`_db.py`) applies files where `filename_version > MAX(schema_version.version)` and is
  idempotent **only at the file level** (bare `INSERT INTO schema_version`). It is **not** column-idempotent.
- Naive rename breaks EXISTING DBs (schema_version {1..8}): re-homed `009-accessed-count` would re-`ALTER`
  an existing column → `duplicate column name`; adopted `005-tool-extensions` would be skipped (5 ≤ 8) → tool
  columns never added.

## Files to change (source of truth: skills/flow/harness/)

- `schema/005-accessed-count.sql` → **rename** `009-accessed-count.sql`
- `schema/006-usage-event.sql` → **rename** `010-usage-event.sql`
- `schema/007-usage-gate-reason.sql` → **rename** `011-usage-gate-reason.sql`
- `schema/008-usage-ephemeral.sql` → **rename** `012-usage-ephemeral.sql`
- `schema/005-tool-extensions.sql` — **new** (copied verbatim from upstream `scripts/schema/005-tool-extensions.sql`)
- `_db.py` — make migrations **column-idempotent** + add legacy-DB reconciliation
- `flow_harness.py` — `_maybe_forward_to_rust()` compat guard
- tests — 1 new legacy-DB suite + 2 comment updates

## Implementation steps

1. **Column-idempotent migrations.** In `_db.py` migration runner, before each `ALTER TABLE … ADD COLUMN`,
   skip if the column already exists (parse `PRAGMA table_info(<t>)`). Implement as a small wrapper that runs
   each statement and tolerates "duplicate column" (or pre-checks). This makes re-homed 009–012 safe on legacy DBs.
2. **Legacy reconciliation (one-time).** On `migrate()`, detect the legacy fingerprint: `schema_version` MAX ≥ 5
   AND `tool` table lacks `kind` column AND `decision` has `accessed_count`. When detected:
   - apply `005-tool-extensions` DDL (column-idempotent) so the tool columns land,
   - ensure `schema_version` rows for 5–12 are normalized so subsequent runs are stable,
   - leave accessed_count / usage_event data untouched.
   Keep it best-effort + transactional; never destructive.
3. **Adopt upstream 005 verbatim.** Copy `005-tool-extensions.sql` from upstream into flow schema dir unchanged
   (re-establishes the "verbatim from repository-harness" invariant for 001–005).
4. **Backend-compat guard.** In `_maybe_forward_to_rust()` (flow_harness.py ~L24-39), before forwarding: open DB
   read-only, compute a compat check. Block (stderr + exit 2) when the flow DB carries flow-only migrations
   (010–012 usage tables, or accessed_count) that an upstream rust binary doesn't know — so a rust binary can
   never silently write a divergent schema. Best-effort: if the check itself errors, fall through (don't break python path).
5. **Tests.**
   - New `tests/test_flow_schema_migration.sh`: (a) fresh init → assert `tool.kind` + `accessed_count` + `usage_event`
     all present, schema_version monotonic, no gaps that re-run; (b) **legacy DB**: seed a DB at the OLD layout
     (versions 1..8, accessed_count present, no tool.kind), run `init`, assert no crash + tool columns added + old
     data intact + second `init` idempotent; (c) guard: `FLOW_HARNESS_BACKEND=rust` with a dummy/absent binary on a
     flow DB → exit 2 + guiding message.
   - Update comments in `test_flow_accessed_count.sh` (005→009) and `test_flow_usage_log.sh` (006-008→010-012).

## Risks & rollback

- **Risk:** legacy reconciliation mis-detects a fresh DB. Mitigate: detection requires accessed_count present AND
  tool.kind absent — a fresh post-fix DB has tool.kind, so it won't trigger.
- **Rollback:** revert renames + delete new 005 + revert `_db.py`/guard; DBs created under the fix remain readable by
  python (extra columns are additive).

## Validation

`bash tests/test_flow_schema_migration.sh` green; full `run_all.sh` green; manual: copy a real legacy
`.flow/harness.db` (e.g. from CMC or C2-App-001 dogfood) and run `flow harness init` → no error, `query` works.
