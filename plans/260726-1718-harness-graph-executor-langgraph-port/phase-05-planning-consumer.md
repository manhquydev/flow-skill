---
phase: 5
title: "Phase 5: Planning Consumer (fail-closed next-stage)"
status: todo
priority: P1
effort: "2d"
dependencies: [3, 4]
---

# Phase 5: Planning Consumer (fail-closed next-stage)

<!-- Updated: Red Team Session 1 (2026-07-26) — findings 3, 7, 13, 14 applied -->

## Overview

`flow.sh next` consults the executor for the next stage (topology walk incl. debt-gated skips) behind `FLOW_GRAPH_EXECUTOR`, with a fail-closed contract. Gate checks, gate-rules semantics, skip governance untouched. Stage checkpoints recorded (kind=planning, ns='').

## Requirements

- Functional: `graph next --project <root>` (exit 0 + node | exit 3 = PLANNING-COMPLETE | exit 4 = harness unavailable | exit 1/2 = failure); flow.sh consumes via `harness_capture_checked` (Phase 2 — stdout-passthrough; the pre-existing `harness_call_checked` at `flow.sh:232-235` swallows stdout and MUST NOT be used); stage checkpoints; kill-at-gate → `graph abandon --outcome killed`; path rendering in status; `cmd_next` skip-guard (R7)
- Non-functional: gate parity mandatory; skip flows ONLY through `cmd_skip` (topology observes `flow/.skipped`, never writes it); status output additive-only

## Architecture

- `cmd_next` today (`flow.sh:850-902`): contiguous-stage scan + gate + template copy, with three early returns (idx<0 seeds 00, `:853-863`; idx≥LAST complete, `:876-890`; successor exists, `:892-895`) — two of which skip the durable hook. With flag on: flow.sh runs the SAME gate check; on pass, calls `graph next` via `harness_capture_checked`. Executor commits stage checkpoint (manifest = gate evidence) and returns successor per topology + predicates. flow.sh still scaffolds the NEXT stage file, preserving `current_stage_idx` contiguity (`flow.sh:136-145`) and `planning_complete()` (`flow.sh:311-323`).
- **Skip-guard (R7 + Round-3 F1 — must be INDEX-level, not just successor-level):** today `cmd_next` re-scaffolds a skipped stage (`flow.sh:891-898`, sandbox-reproduced), and that accidental re-creation is the only thing un-pinning `current_stage_idx()` — which breaks on the first missing file (`flow.sh:136-145`). Suppressing re-scaffold alone would pin the index at the pre-skip stage forever: 05 never scaffolded (only `cmd_next`/`cmd_skip` copy templates, `flow.sh:855,896,1257`), `planning_complete()` never true, `/flow card` deadlocked. The guard therefore lands in BOTH places, same commit, both modes: (a) `current_stage_idx()` treats a `.skipped` stage as contiguity-satisfied (`elif stage_skipped "$s"; then :;`), and (b) `cmd_next` does not re-create skipped-stage files. Actual callers of `current_stage_idx` (grep-verified Round-4): `cmd_status` (`flow.sh:638`), `cmd_resume` (`:740`), `cmd_next` (`:852`), `_next_action` (`:949`, already skip-aware `:959-967`) — all covered by the index-level fix and asserted in tests. Narrow edge: if a scaffolded successor file is later deleted, `cmd_next` re-creates it via its normal template-copy path (add a test for this state). Deliberate, versioned behavior change; regression tests: after `flow skip 03-prd` + clean 04 → `next` scaffolds `05-contract.md`, `status` shows `at stage 04-adr`, `planning_complete` true.
- **Fail-closed (findings 14 + R2):** empty output NEVER means complete. rc 4 (harness unavailable) or rc 1/2: print harness error, fall back to legacy ladder while it exists (pre-Phase 6); post-Phase 6, abort with recovery hint (`flow harness graph status` + doctor). SQLite contention handled by Phase 1's busy_timeout + Phase 2's BEGIN IMMEDIATE.
- **Skips (finding 7):** `cmd_skip` (`flow.sh:1223-1263`) remains THE skip mechanism — DEBT line + security-class HALT + 05-guard + writes `.skipped` (bare stage name, `:1253`) + scaffolds successor. When flag on, `cmd_skip` additionally records a skip checkpoint carrying the MATCHED DEBT LINE TEXT (R7: DEBT lines have no ids — `cmd_debt add` format at `flow.sh:1436-1438`). Path rendering: `flow status` gains additive line like `path: 00→01→02→04 (03-prd skipped: DEBT "<matched line excerpt>")`.
- Kill-at-gate: kill remains an operator behavior; when a project is killed at a gate (`flow.sh` kill flow prose, `:873`), flow.sh calls `graph abandon --outcome killed` for the planning execution; doctor's stale sweep (Phase 2 `gc --stale-days`) catches unrecorded kills.
- Planning execution created lazily at first flag-on `next` (kind=planning).

## Related Code Files

- Modify: `skills/flow/runner/flow.sh` (`cmd_next` delegation via `harness_capture_checked` + skip-guard; `cmd_skip` checkpoint hook; kill path abandon call; status path line)
- Modify: `skills/flow/harness/graph_executor.py` (`next` planning walk; path rendering data)
- Modify: `skills/flow/references/stage-state-machine.md` (note only; authority flip happens Phase 6)
- Create: `tests/test_flow_graph_planning_parity.sh`
- Modify: `tests/run_all.sh` (register); note: `tests/test_flow_status_legibility.sh` + `tests/test_flow_gate_capture.sh` (runs `FLOW_HARNESS_DISABLE=1 next`) must stay green — listed as verified consumers

## Implementation Steps

1. Read `cmd_next` incl. all three early returns; extract exact transition table into parity fixture (early-return paths included).
2. Implement `graph next` walk; all-`always` walk must reproduce the legacy ladder exactly (Phase 3 SC already asserts topology-side; this asserts consumer-side).
3. Wire delegation branch via `harness_capture_checked` (rc 0/3/4/1 handling); implement the two-level skip-guard (`current_stage_idx` + `cmd_next`) with regression tests: skip 03 → next does NOT re-create `03-prd.md`, index advances, 05 scaffolds, `planning_complete` true.
4. Hook `cmd_skip` → skip checkpoint; kill path → `graph abandon --outcome killed`.
5. Parity suite: for each stage 00→05 + each early-return path, both modes produce same next stage, same files scaffolded, same gate verdicts on pass AND fail fixtures; `FLOW_HARNESS_DISABLE=1` path unchanged pre-Phase-6. Register in run_all.sh.
6. Conditional-path test: fixture with a legitimate debt-gated skip (via `cmd_skip`) → path recorded, `flow status` renders it, `planning_complete()` true, `/flow card` unlocks; security-class skip attempt refused (existing `cmd_skip` guard re-verified).

## Success Criteria

- [x] Parity suite green: legacy vs executor identical transitions + gate verdicts on all stage fixtures incl. early-return paths
- [x] Debt-gated skip works end-to-end: `.skipped` written by `cmd_skip` only, `cmd_next` does NOT re-scaffold the skipped stage (regression test on the sandbox-reproduced case), path visible in `flow status` with matched DEBT text, `/flow card` reachable
- [x] Harness failure during `next` → fail-closed (no silent completion), legacy fallback pre-Phase-6
- [x] Kill-at-gate → execution `abandoned/outcome=killed`; stale sweep catches unrecorded kills
- [x] `test_flow_status_legibility.sh` + `test_flow_gate_capture.sh` green (additive output only)
- [x] Suite registered in `tests/run_all.sh`

## Risk Assessment

- Split-brain: stage files on disk remain mechanical truth; executor checkpoints derived; parity test asserts agreement; on disagreement flow.sh wins + doctor warns (mirrors Phase 4 ownership table).
- Status output consumers: additive line only; legibility suite is the guard.
