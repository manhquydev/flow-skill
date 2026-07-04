---
title: "deep-integration of repository-harness v0.1.10 into /flow"
status: done
priority: P1
created: 2026-06-23
---

> **Retired 2026-07-04**: adding machine-readable frontmatter so watzup/project-management stop
> flagging this as live work — the doc body below already states P0+P1 shipped 2026-06-24; P2 was
> a deliberate YAGNI defer (no context-rules surface existed to score against), not abandoned work.

# Plan: deep-integration of repository-harness v0.1.10 into /flow

**Created:** 2026-06-23 · **Target flow version:** v0.17.0 · **Status:** P0+P1 BUILT & GREEN (2026-06-24); P2 deferred

## Outcome (2026-06-24)

- **P0 SHIPPED** — schema-005 collision fixed (upstream `005-tool-extensions` adopted verbatim; flow's
  accessed-count/usage re-homed to 009-012), migration runner made column-idempotent + legacy reconciliation,
  rust seam frozen+guarded. New `test_flow_schema_migration.sh` (9 checks).
- **P1 SHIPPED** — kind-aware tool registry ported (stdlib `_presence.py`; `tool register/check/remove`,
  `query tools --capability/--status`). New `test_flow_tool_registry.sh` (17 checks).
- **P2 DEFERRED** (evidence-based, operator-approved).
- Version bumped 0.16.2→0.17.0 (5 files, coherence PASS). Full suite green (27 suites / 632 checks before fixes).
- code-reviewer: REQUEST_CHANGES → 1 CRITICAL (C1 whitespace-command IndexError) + 1 HIGH (H1 schema_version
  prefix match) fixed + regression test added; re-verified green. Not yet committed/installed.

## Context

`flow_harness.py` is a one-time Python port of `repository-harness` (Rust `harness-cli`).
Upstream advanced to **v0.1.10** (kind-aware inbound tool registry, schema 005). flow forked
its schema numbering at 005 and drifted. This plan reconciles the divergence and adopts the
one genuinely net-new upstream capability flow lacks.

Source of truth: `D:\project\flow\flow-skill\skills\flow\harness\` (install.ps1 fans out to all 5 homes).

## Scope (operator-approved)

| Phase | What | Decision |
|---|---|---|
| **P0** | Fix schema-005 collision + backend-compat guard | IN — must-fix (latent data-corruption) |
| **P1** | Port kind-aware tool/capability registry to Python | IN — high value, field-aligned (verified) |
| **P2** | score-context | **DEFERRED** — blocked (flow has no context-rules surface; naive port rewards context-bloat per Chroma). Revisit in a later cycle if a consuming gate appears. |
| Rust seam | FLOW_HARNESS_BACKEND=rust | **FREEZE + GUARD** — keep seam, add compat guard, do not build/maintain binary |

## Phases & dependencies

1. `phase-01-schema-collision-fix.md` (P0) — **blocks P1** (P1's tool columns must land as the real 005).
2. `phase-02-tool-registry-port.md` (P1) — depends on P0.

## Acceptance criteria (whole plan)

- AC1: Fresh `init` produces schema with upstream `005-tool-extensions` columns present on `tool`,
  flow's accessed-count/usage migrations re-homed to 009–012, no number collision.
- AC2: An **existing** `.flow/harness.db` (schema_version {1..8}) upgrades cleanly — no duplicate-column
  crash, tool-extensions columns added, accessed_count/usage data intact. (Proven by a legacy-DB test.)
- AC3: `FLOW_HARNESS_BACKEND=rust` against an incompatible binary/DB is blocked with a guiding stderr message, exit 2 — never silent divergence.
- AC4: `flow harness tool register --kind … --capability …`, `tool check`, `tool remove`,
  `query tools --capability X --status present` all work in pure stdlib Python (0 new deps).
- AC5: Full existing test suite green (memory baseline: 25 suites / 607 checks) + new P0 legacy-DB
  test + new P1 registry test. coherence + consistency audits PASS.
- AC6: No regression to usage-log (schema 006→010 etc.), accessed-count recall ordering, or any flow.sh wiring.

## Out of scope this round

- P2 score-context + authoring flow CONTEXT_RULES.
- Building/shipping the Rust binary; tool-RAG / tool-search (FOMO per research).
- Wiring `query tools` lookups into stage gate prose (data layer only this round; gate-prose
  mechanization is a follow-up once the registry exists).

## Verification baseline

`bash skills/flow/tests/run_all.sh` (or per-suite) + flow.sh coherence/consistency. POSIX `sed -E`
only (BSD/macOS CI leg). Cross-OS via azure-pipelines.yml.
