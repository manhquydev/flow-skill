---
phase: 1
title: "Phase 1: Schema, Lineage Contract & Migration Foundation"
status: todo
priority: P1
effort: "2d"
dependencies: []
---

# Phase 1: Schema, Lineage Contract & Migration Foundation

<!-- Updated: Red Team Session 1 (2026-07-26) — findings 1, 2, 13 applied -->

## Overview

Renegotiate the harness migration lineage contract, formally supersede the GAP-MATRIX work-graph red line, then add executor tables via the idempotent migration engine. Additive-only; zero behavior change. Keeps the approved 4-table port (user decision at red-team gate).

## Requirements

- Functional: lineage supersession record; migration in a flow-owned band; tables `graph_execution`, `graph_checkpoint`, `graph_step_write`, `graph_interrupt`; monotonic sortable id util; `_db.py` extensions (composite-key update, transaction context manager)
- Non-functional: migration idempotent on fresh AND existing v0.24 DBs; stdlib only; per-commit CI green (test-contract edits land in the SAME commit as the migration)

## Architecture

### Lineage renegotiation (MUST land first, same commit as DDL)

Current contract: inventory frozen to 001-005 + 009-012 (`tests/test_flow_harness_lineage_contract.sh:38`), `013-` explicitly forbidden (`:47`), GAP-MATRIX reserves 006-013 for upstream changesets ("FOMO red line", `GAP-MATRIX-0.1.17.md:28`) with floor "re-home ≥014 (separate epic)" (`:41`), and exact version-set strings asserted in `tests/test_flow_schema_migration.sh:31,83,108`.

Resolution (user-approved supersession; band confirmed **014+** in validation interview — GAP-MATRIX floor, contiguous lineage; accepted trade-off: if upstream ever extends its changeset band past 013, lineage renegotiates again):
1. Migration file: `schema/014-graph-executor.sql`.
2. Record supersession: `flow harness decision add` — decision "flow owns graph-executor work-graph; upstream changesets 006-013 will NOT be adopted; band 014+ is flow-owned", predicted outcome, link to this plan. Update `GAP-MATRIX-0.1.17.md` (changesets row → "Superseded 2026-07-26 by flow-owned graph executor, band 014+"; add band table row) and `harness/README.md` lineage section.
3. Update BOTH test suites in the same commit, preserving their guards: keep `no 013-` assertion, extend inventory assertion to 001-005 + 009-012 + 014, update the three exact version-set strings. Commit message states the lineage rationale.
4. Guard the rust seam: `_maybe_forward_to_rust` (`flow_harness.py:59-83`) forwards unknown argv to the rust CLI before parsing — add `graph` (and any argv containing it as first verb) to the never-forward set so a rust backend cannot receive graph verbs it does not implement.

### Tables (approved 4-table port; defects from finding 13 fixed)

LangGraph → flow mapping: `thread_id`→`execution_id`; `checkpoint_ns`→`ns` (`''`=planning, `card:C-NNN`=card); `checkpoint_id`→monotonic id; `parent_checkpoint_id`→fork chain; `channel_values`→`manifest` JSON evidence refs (git SHA, file hashes, gate exit/output-hash — never blobs); `versions_seen`→`seen`; `pending_writes`→`graph_step_write`.

DDL (`schema/014-graph-executor.sql`):

```sql
CREATE TABLE graph_execution (
  id TEXT PRIMARY KEY,
  project TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('auto_run','planning','card')),
  topology_version INTEGER NOT NULL,
  topology_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'running'
    CHECK (status IN ('running','paused','done','failed','abandoned')),
  outcome TEXT,                      -- e.g. 'killed' for kill-at-gate
  story_id TEXT REFERENCES story(id),   -- TEXT: story.id is TEXT PK (001-init.sql:45)
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE INDEX idx_graph_execution_status ON graph_execution(status);

CREATE TABLE graph_checkpoint (
  execution_id TEXT NOT NULL REFERENCES graph_execution(id) ON DELETE CASCADE,
  ns TEXT NOT NULL DEFAULT '',
  checkpoint_id TEXT NOT NULL,
  parent_checkpoint_id TEXT,
  node TEXT NOT NULL,
  manifest TEXT NOT NULL,
  versions TEXT NOT NULL,
  seen TEXT NOT NULL,
  meta TEXT NOT NULL,                -- JSON {source: input|loop|update|fork, step, ts}
  PRIMARY KEY (execution_id, ns, checkpoint_id)
);
CREATE INDEX idx_graph_checkpoint_parent ON graph_checkpoint(parent_checkpoint_id);

CREATE TABLE graph_step_write (
  execution_id TEXT NOT NULL REFERENCES graph_execution(id) ON DELETE CASCADE,
  ns TEXT NOT NULL DEFAULT '',
  checkpoint_id TEXT NOT NULL, task_id TEXT NOT NULL, idx INTEGER NOT NULL,
  channel TEXT NOT NULL, value TEXT NOT NULL,
  PRIMARY KEY (execution_id, ns, checkpoint_id, task_id, idx)
);

CREATE TABLE graph_interrupt (
  execution_id TEXT NOT NULL REFERENCES graph_execution(id) ON DELETE CASCADE,
  ns TEXT NOT NULL DEFAULT '',
  interrupt_id TEXT NOT NULL,
  node TEXT NOT NULL, prompt TEXT NOT NULL,
  security_class INTEGER NOT NULL DEFAULT 0,
  resume_value TEXT,
  resolved_by TEXT,                  -- actor/session id, distinct from executing session
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','abandoned')),
  created_at TEXT NOT NULL, resolved_at TEXT,
  PRIMARY KEY (execution_id, ns, interrupt_id)
);
CREATE UNIQUE INDEX idx_graph_interrupt_one_open
  ON graph_interrupt(execution_id, ns, node) WHERE status = 'open';

INSERT INTO schema_version (version) VALUES (14);
```

(The `schema_version` tail is convention-mandated — cf. `004-intervention.sql` — omitting it makes `migrate()` re-apply on every connect.)

### `_db.py` extensions (findings 13 + R1 — engine change IS expected)

- `update_where(con, table, where_cols: dict, **cols)` — composite-key update; same SECURITY INVARIANT comment (table/columns are code literals, never user input).
- `transaction(con)` context manager: `BEGIN IMMEDIATE` … commit/rollback — multi-row atomicity for step_writes + checkpoint in one transaction.
- `connect()` gains `busy_timeout` pragma (5000ms explicit) for concurrent worktree writers.
- **Centralized DB resolver (R1 + Round-3 F3):** `default_db_path()` (`_db.py:16-25`) gains linked-worktree translation so ALL harness tables (graph, story, trace, usage) share one DB. Translation keys on the RESOLVED ROOT, never CWD (flow.sh passes `FLOW_PROJECT_ROOT="$ROOT"` per call, `flow.sh:199,258,270,3674,3681,3682` — root and CWD are independent): `git -C "$root" rev-parse --path-format=absolute --git-common-dir --show-toplevel` (git ≥2.31 declared floor; fallback parse `git worktree list --porcelain`); translate ONLY if `show-toplevel` equals or is an ancestor of `root` (containment guard against cross-repo mixing); `db_root = dirname(common_dir) + relpath(root, worktree_top)` then apply existing root rules. Result CACHED per process (`default_db_path` is hit at `flow_harness.py:40,1151` and via `_db.connect` — uncached git spawns multiply on Windows). Main-worktree/monorepo sub-project behavior UNCHANGED (`tests/test_flow_monorepo_root.sh` layout preserved); non-git or any git failure: current behavior. Explicit `FLOW_HARNESS_DB` env override (narrow — DB path only) for tests. NEVER via `FLOW_PROJECT_ROOT` (global root override, `flow.sh:24-31` — would hijack CARDS_DIR/locks/DEBT resolution).
- **Events sink: ingest, don't relocate (Round-3 F4, corrected Round-4 H2):** `_events_path` pairs the JSONL sink with the DB dir (`flow_harness.py:656`) while flow.sh writes `$ROOT/.flow/events.jsonl` (`flow.sh:85-86`). RELOCATING the sink would half-split `$ROOT/.flow` (CYCLE_FILE/WS_FILE/eval files stay local) and break read-side consumers: `cmd_resume`'s foreign-session detector would see concurrent worktree sessions (`flow.sh:774-779`), `_resume_valid_lines` silently drops interleaved multi-writer rows (`:731-733`), and cycle_id fragments (`:3636-3640`). Resolution: events stay WORKTREE-LOCAL (read semantics + single-writer append unchanged); merging happens at ONE ingest point — `_ws_remove` ingests the worktree's `events.jsonl` into the main DB BEFORE `git worktree remove` (hook lands in Phase 4 with the other workspace wiring). NO periodic sibling-glob ingest (Round-6 H3: a second ingest path under a different src key would double-count every event and reintroduce the recycled-path cursor swallow — worktree telemetry reaching `usage_event` at removal time is the accepted lag). NEW HARNESS WORK (Round-5 H3 — none of this exists): `cmd_rollup` accepts only `--global` today (`flow_harness.py:1114-1115`; `srcs` built internally `:673-676`) — add `rollup --src <path> --src-key <key>`. Cursor lifecycle: worktree paths are deterministic and RECYCLED (`_ws_path`, `flow.sh:1900`), and `rollup_cursor` keys on bare src path with `UNIQUE(src, line_no)` (`schema/010-usage-event.sql:30,36`) — a recreated worktree at the same path would have lines 1..N silently swallowed. Fix: ingest under a LIFECYCLE-UNIQUE src key `<path>#<branch>#<created_at-from-workspaces.jsonl-record>` so each worktree lifecycle has its own cursor and unique-rows namespace. `_events_path` keeps its DB-dir pairing at the main root. Tests (harness side this phase): `rollup --src` ingests a sink under a lifecycle key; two lifecycles at the same path both fully ingested. (Worktree-integration tests live in Phase 4.)
- Rule stated in code review checklist: `graph_executor.py` contains NO raw SQL string construction outside `_db` helpers.

### Monotonic id

`graph_ids.py` — UUID6-equivalent from stdlib (`time.time_ns()` hex + per-process counter + random suffix), lexicographically sortable. ~50 LOC.

## Related Code Files

- Create: `skills/flow/harness/schema/014-graph-executor.sql`
- Create: `skills/flow/harness/graph_ids.py`
- Modify: `skills/flow/harness/_db.py` (update_where, transaction, busy_timeout)
- Modify: `skills/flow/harness/flow_harness.py` (`_maybe_forward_to_rust` never-forward set; `cmd_rollup` gains `--src`/`--src-key` for lifecycle-keyed ingest)
- Modify: `tests/test_flow_harness_lineage_contract.sh` (extend inventory; keep `no 013-`)
- Modify: `tests/test_flow_schema_migration.sh` (three version-set strings — substring `has` checks; extend to include 14)
- Modify: `tests/test_flow_usage_log.sh` (R5: `ck "12" "$ver"` at `:119-122` is an EXACT max-version assertion that breaks at 14 — change to floor assertion `>= 12` or subset check)
- Modify: `skills/flow/harness/GAP-MATRIX-0.1.17.md`, `skills/flow/harness/README.md` (lineage + supersession)
- Create: `tests/test_flow_graph_schema.sh` (flat layout — `tests/harness/` does not exist)
- Modify: `tests/run_all.sh` (register `test_flow_graph_schema.sh`)

## Implementation Steps

1. Read `_db.py` `_migrations()` + one existing migration (`schema/004-intervention.sql`) to copy conventions.
2. Land lineage renegotiation: decision record + GAP-MATRIX/README edits + both test-suite updates + `014-graph-executor.sql` in ONE commit.
3. Implement `graph_ids.py`; extend `_db.py` (update_where, transaction, busy_timeout) carrying SECURITY INVARIANT comments.
4. Guard `_maybe_forward_to_rust` against `graph` verbs; add regression test case.
4b. Implement `rollup --src/--src-key` (lifecycle-keyed ingest) with the two-lifecycle same-path test.
5. `tests/test_flow_graph_schema.sh`: fresh DB migrate → 4 tables + indexes exist; re-run → no-op; v0.24 DB fixture → tables added, rows untouched; schema_version records 14; FK enforcement (TEXT story_id round-trip; cascade delete removes checkpoints/writes/interrupts); unique-open-interrupt constraint; id sortability (1000 ids strictly increasing). Register in `run_all.sh`.

## Success Criteria

- [x] One commit contains migration + updated lineage tests + GAP-MATRIX/README + decision record; CI green on that commit
- [x] `migrate()` idempotent on fresh + existing DB; schema_version records 14; `no 013-` guard preserved
- [x] Cascade delete + unique-open-interrupt + TEXT FK verified by test
- [x] `FLOW_HARNESS_BACKEND=rust` with `graph …` argv does NOT forward to rust CLI
- [x] DB resolver: from inside a linked worktree, ALL harness writes land in main-worktree DB; monorepo sub-project fixture unchanged; `FLOW_HARNESS_DB` override works; non-git falls back to current behavior
- [x] `test_flow_usage_log.sh` floor assertion updated and green
- [x] `rollup --src --src-key`: two worktree lifecycles at the same recycled path both fully ingested (no cursor/unique swallowing); same sink ingested twice under the same key → no duplicate `usage_event` rows (implementation note: `created_at` in workspaces.jsonl is unquoted numeric — read via `_ws_get_num`)
- [x] `test_flow_graph_schema.sh` listed in `tests/run_all.sh` and green

## Risk Assessment

- Lineage band 014+ confirmed in validation interview (2026-07-26); residual risk: upstream extending changesets past 013 forces another renegotiation — accepted.
- Keeping 4 tables (user decision) accepts: versions/seen maintenance cost and interrupt/intervention dual-store; mitigation = `graph_interrupt` is the ONLY interrupt store for executor flows (no writes to `intervention` from graph code; documented in Phase 2).
