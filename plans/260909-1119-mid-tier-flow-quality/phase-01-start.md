---
title: "Phase 1: Dispatcher SKILL.md"
status: todo
priority: P1
effort: "6h"
dependencies: []
---

# Phase 1: Dispatcher SKILL.md

## Overview

PTC_ONLY dispatcher: run `flow.sh` first, load one reference per verb. Exclusive: `SKILL.md`, `command-dispatch.md`, plus retarget-only edits in tests that grep SKILL.md.

## Requirements

- Always-on: two-layer, STOP set, three laws, pointer to command-dispatch
- Delete Commands table only after inventorying `rg SKILL.md` in `tests/`
- No `YOU (Claude)` / `Your (Claude)`
- `wc -w SKILL.md` ≤ **1600**. Fail here, not in phase 6
- command-dispatch `auto` row = one-line pointer to `auto-run.md` (no AutoDecision enum)
- Keep grepped substrings as one-liners: `antigravity-integration.md`, `agy inspect`, `third engine`/`Gemini-3`, `claudekit-skills`, `codex-integration`, `concierge.md`, `flow-catalog.tsv`, `forge-idea.md`, `BMAD-METHOD`, `host-agnostic-parallel`, flow-owned/R-IMPROVE, attestations

## File inventory

| Action | Path |
|---|---|
| Modify | `skills/flow/SKILL.md` |
| Modify | `skills/flow/references/command-dispatch.md` |
| Modify if grep breaks | listed `tests/test_flow_*integration*.sh` and concierge/forge/host-agnostic/harness/attest contract tests (SKILL.md lines only) |

## Implementation Steps

1. Inventory test greps of SKILL.md
2. Rewrite description ≤500 chars
3. Always-on body in order: two-layer → STOP → `flow.sh` first (Windows `flow.cmd` pointer) → three laws → load table → forbidden
4. command-dispatch: agent duties; After-FAIL/PASS/Never on next/check/card/resume; auto = pointer only
5. Confirm `wc -w` ≤1600 and greps pass

## Test scenario matrix

| Path | Expect |
|---|---|
| Critical | no Claude vocative in exclusive md |
| Critical | wc -w ≤1600 |
| Critical | previously grepped tests pass |
| High | old SKILL verbs still in command-dispatch.md |

## Todo

- [ ] Inventory greps
- [ ] Rewrite SKILL.md + command-dispatch.md
- [ ] wc -w ≤1600
- [ ] tests green

## Success Criteria

- [ ] No Commands table in SKILL.md
- [ ] ≤1600 words
- [ ] PTC_ONLY / STOP before any `/flow <verb>` list

## Dependency map

Parallel with 2, 4, 5.
