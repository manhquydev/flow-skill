# Phase 02 — `accessed_count` read-only recall signal

## Context links
- Decision report: `flow-xia-upgrade-decision-report.md` (item #3, score 4.0 → softened ~3.6)
- Red-team A (overlap): GENUINELY-NEW, 95% — no `accessed_count|last_accessed|prune|usage`
  anywhere; existing `_repeated_values(threshold=2)` (`flow_harness.py:306-318`) counts
  *occurrences at capture*, not *recall reuse*; `cmd_recall` (`flow.sh:710-737`) is read-only,
  never increments; staleness is time-based (`flow_harness.py:287-290`), not usage-based.
- Red-team B (cost): DESCOPE — LOC estimate honest, but **`prune` is a latent data-loss bug**
  (deletes rare-but-critical one-time security lessons). Keep the count, cut the prune.

## Overview
- **Priority:** Medium (cheap, safe, but value unproven for flow's short-lived memory — build as
  a low-risk experiment, not a confirmed winner).
- **Status:** Planned.
- **What:** add a usage signal — increment `accessed_count` when a harness row is surfaced by
  `recall`/`query`, and order recall output by reuse. **Read-only signal: never auto-prune or
  auto-delete.**

## Key insights (from red-team, do not re-litigate)
- The new signal is genuinely orthogonal to the `≥2` occurrence-count consolidation — they
  measure different things (reuse vs recurrence). Do not merge them.
- **Hard rule: low `accessed_count` is NOT evidence of low value.** A one-time security/DEBT
  decision is recalled rarely *because it is rare, not worthless*. Pruning by access would delete
  exactly that class → violates the "verified decisions are sticky / rare-but-critical" rule.
- Security-class rows (matching `auth|authoriz|admin|tenan|payment|...`, the guard at
  `flow.sh:610`) must be hard-excluded from any access-based deprioritization, as a guard against
  a future regression into pruning.

## Requirements
**Functional**
- New migration adds `accessed_count INTEGER DEFAULT 0` (and optional `last_accessed_at`) to the
  harness tables `recall`/`query` read from (`decision`, `trace`, `story`, `intervention`).
- On every `recall`/`query` read, increment `accessed_count` for the surfaced rows.
- `recall` orders output by `accessed_count DESC` (secondary sort) — most-reused first.
- **No prune / no delete / no auto-archive by this signal anywhere.**

**Non-functional**
- Python-stdlib + sqlite only; idempotent versioned migration; back-compatible
  (`_db.insert` already omits None columns, `_db.py:108`); ~10–20 LOC + 1 migration.

## Architecture
- New `harness/schema/005-accessed-count.sql` following the versioned-migration pattern
  (`_db.py:91-102`, bumps `schema_version`).
- Increment logic in `flow_harness.py` read path; recall ordering in the surfacing query.
- Security-class exclusion enforced in the ordering/any-future-deprioritization step.

## Related code files
**Modify**
- `skills/flow/harness/flow_harness.py` — increment on read; recall ordering; security-class guard.
- `skills/flow/runner/flow.sh` — `cmd_recall` passes through (no logic change beyond display order).
- `skills/flow/harness/README.md` — document the signal + the **no-prune** rule + security guard.
- `tests/test_flow_recall.sh` — extend with the new cases.
**Create**
- `skills/flow/harness/schema/005-accessed-count.sql`.

## Implementation steps
1. Write `005-accessed-count.sql`: `ALTER TABLE ... ADD COLUMN accessed_count INTEGER DEFAULT 0`
   (+ optional `last_accessed_at`) for the 4 read tables; bump `schema_version`.
2. In `flow_harness.py`, increment `accessed_count` for rows returned by the recall/query read
   path; add `ORDER BY accessed_count DESC` to recall surfacing.
3. Add the security-class exclusion guard (reuse the `flow.sh:610` pattern) so such rows are never
   ordered down / never eligible for any future deprioritization.
4. Document in `harness/README.md`: signal meaning, **NO prune**, security guard, rationale.
5. Extend `tests/test_flow_recall.sh`: count increments on recall; ordering reflects reuse; ZERO
   rows ever deleted; security-class row never deprioritized; migration idempotent + back-compat.
6. Bump version + run `flow coherence`.

## Todo
- [ ] `005-accessed-count.sql` migration
- [ ] increment-on-read + recall ordering in `flow_harness.py`
- [ ] security-class exclusion guard
- [ ] `harness/README.md` documents signal + no-prune + guard
- [ ] `test_flow_recall.sh` extended (incl. no-deletion assertion)
- [ ] version bumped + `flow coherence` clean

## Success criteria
- `accessed_count` increments on each recall read; recall surfaces reused items first.
- A test explicitly asserts **no row is ever deleted/pruned** by this feature.
- Security-class rows never deprioritized; migration idempotent; existing recall tests still green.

## Risk assessment
- *Future regression into pruning* → the no-prune rule lives in code comments (the WHY) + a
  standing test that fails if any delete is introduced.
- *Migration on existing project DBs* → `DEFAULT 0` + None-omitting insert keeps old DBs valid.

## Security considerations
- The whole point of the guard: never let a usage heuristic erase a one-time security lesson.
  This phase ADDS a protective invariant; it must not weaken existing capture.

## Next steps
- Optional later: expose reuse counts in `recall` health output to inform (not automate) curation.
