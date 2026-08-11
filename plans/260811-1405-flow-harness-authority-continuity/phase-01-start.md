---
phase: 1
title: "Start — inventory & contract freeze"
status: pending
priority: P1
effort: "0.5d"
dependencies: []
---

# Phase 1: Start — inventory & contract freeze

## Overview

Freeze the *current* pin/authority surface with a grep matrix and freeze the **new** authority contract wording so phase 2 can flip docs+tests without thrash.

## Requirements

- Functional: complete inventory of live vs historical pin references
- Functional: draft exact “live authority” sentences for README/SKILL
- Non-functional: no product code change in this phase (docs inventory only OK)

## Architecture

Read-only discovery. Output artifact: `plans/260811-1405-flow-harness-authority-continuity/pin-inventory.md` (or section in phase notes) listing path:line for:

1. Live trust pins (must change)  
2. Historical mentions (may stay with reword)  
3. Contract tests assertions  

## Related Code Files

- Read: `skills/flow/harness/README.md`
- Read: `skills/flow/harness/GAP-MATRIX-0.1.17.md`
- Read: `skills/flow/SKILL.md` (pins bullet ~238)
- Read: `skills/harness-skill/SKILL.md`
- Read: `tests/test_flow_skill_harness_docs_contract.sh`
- Read: `tests/test_flow_harness_lineage_contract.sh`
- Read: `docs/system-architecture.md`
- Create (optional): inventory note under this plan dir

## Implementation Steps

1. Run inventory:
   ```bash
   rg -n '0\.1\.14|0\.1\.17|0\.1\.16|GAP-MATRIX|harness-cli|Authority pin|protocol floor' \
     skills/flow skills/harness-skill tests docs README.md README_VN.md CHANGELOG.md \
     --glob '!**/node_modules/**'
   ```
2. Classify each hit: `LIVE_AUTHORITY` | `HISTORICAL_OK` | `TEST_ENFORCES` | `CHANGELOG_IMMUTABLE`.
3. Draft target wording (freeze before edits):
   - **Live authority:** flow durable Python CLI + `flow.sh` + semantic gates; story complete rules unchanged.
   - **Historical:** repository-harness protocol v1 EOL — primary source  
     `/home/manhquy/project/repository-harness/docs/decisions/0027-end-protocol-v1-and-focus-repository-protocol.md`  
     (OBSERVED 2026-08-10): last published compatibility release **`harness-cli-v0.1.22`**.  
     Flow’s 0.1.14/0.1.17 strings were **trust-align inspiration (v0.24)**, not live dependency.
   - **No-sync:** schema 001–005 frozen ancestry; 009–012 + 014+ flow-owned; **no further upstream schema sync**.
4. Classify into inventory (mandatory classes):
   - `LIVE_AUTHORITY` — must edit (SKILL harness bullet, README pins table, harness-skill desc, npm-wrapper mirror of same)
   - `TEST_ENFORCES` — docs_contract, lineage_contract, **native_rituals count**, **optional smoke pin file**, assess tests
   - `ARCHIVE_ASSET` — `harness/pins/harness-cli-v0.1.17.sha256sums` (keep, reframe label)
   - `HISTORICAL_OK` / `CHANGELOG_IMMUTABLE`
5. Confirm non-goals: no live CLI binary, no hollow-done wave 2, strategist = `R-STRATEGIST` deferred (not §6).
6. Hand off frozen wording + exhaustive LIVE_AUTHORITY path list to phase 2.

## Success Criteria

- [x] Inventory covers all skill+test hits (CHANGELOG historical may stay immutable)
- [x] Target live-authority paragraph approved in plan notes (no ambiguity on test flip)
- [x] `TEST_ENFORCES` list includes both docs_contract and lineage_contract scripts with current assertion lines

## Risk Assessment

- Missing a test assertion → phase 2 green locally, red in CI: mitigate by reading full test files, not just rg on pins.
- Scope creep into strategist: keep deferred list visible.

## Todo

- [x] Run rg inventory + classify
- [x] Freeze target wording block
- [x] Hand off phase 2 file list
