---
phase: 3
title: "Improve-flow-harness ritual (R-IMPROVE-HARNESS)"
status: pending
priority: P1
effort: "0.5-1d"
dependencies: [2]
---

# Phase 3: Improve-flow-harness ritual (`R-IMPROVE-HARNESS`)

## Overview

Port the **spirit** of repository-harness `$improve-harness` as native ritual **`R-IMPROVE-HARNESS`**.  
**Do not** number this as fragile “§6 only” — hollow-done backlog already reserved a strategist as former “§6”; strategist id is **`R-STRATEGIST`** (deferred).  
Axis: Continuity + Usefulness.

## Requirements

- Functional: ritual in `native-rituals.md` with stable id `R-IMPROVE-HARNESS` + Purpose/When/Steps + informs-never-judges line
- Functional: forbids “keep” without fresh-agent rerun; prefer durable note (`harness backlog` / decision) recording fresh-rerun yes/no
- Functional: **`tests/test_flow_native_rituals.sh` updated mandatorily** (5→6 Purpose/When/informs; name checks include Improve-flow-harness)
- Non-functional: never auto-invoked by `next`/`check`/`auto`
- Non-functional: no AgentKit dependency

## Architecture

### Ritual contract

```text
R-IMPROVE-HARNESS
1. Explicit operator/maintainer authority to improve skill/harness guidance
2. Baseline: observed failure + evidence (+ human intervention) or stop with proposal only
3. Earliest gap owner: context | capability | authority | proof | environment | domain
4. One intervention hypothesis (If/then/because + weaken evidence)
5. Smallest change (skill docs, template, gate wording, playbook — not product app)
6. Fresh rerun: new session, equivalent start; record available/retrieved/relevant
7. Decision: keep | revise | remove | pending fresh rerun
8. On keep: durable note recommended — backlog close or decision add with "fresh_agent_rerun=yes"
```

### Numbering

| Id | Content | Plan |
|----|---------|------|
| R1–R5 | existing five rituals | unchanged |
| **R-IMPROVE-HARNESS** | this phase | ship |
| **R-STRATEGIST** | hollow plan phase-04 | deferred; never steal this slot’s meaning |

Display as `## 6. Improve-flow-harness ritual (R-IMPROVE-HARNESS)` after updating intro “Six clean-room…” (or “rituals include…”).

### Tests (mandatory — not optional)

`tests/test_flow_native_rituals.sh`:

- Section A: add `has Improve-flow-harness` / `R-IMPROVE-HARNESS`
- Section B: `ck "6"` for Purpose/When/informs counts (or `≥6` if future-proof)
- Header comment: 5 → 6

## Related Code Files

- Modify: `skills/flow/references/native-rituals.md` (intro + new ritual)
- Modify: `tests/test_flow_native_rituals.sh` (**required**)
- Modify: `skills/flow/SKILL.md` (discoverable link)
- Modify (light): harness README “Self-improving the skill”
- Optional: flow-catalog Must-ask row for “improve harness”
- Do not: runner hot path; do not implement R-STRATEGIST

## Implementation Steps

1. Update native-rituals intro count language.
2. Append R-IMPROVE-HARNESS with full Purpose/When/Steps + never judges.
3. Update test_flow_native_rituals.sh to 6 + name.
4. Link from SKILL.md + harness README.
5. Run `bash tests/test_flow_native_rituals.sh`.

## Success Criteria

- [x] Ritual id `R-IMPROVE-HARNESS` present
- [x] Fresh-rerun required before keep; durable note recommended on keep
- [x] native-rituals test green with 6 markers
- [x] No auto path wiring
- [x] R-STRATEGIST not implemented here

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| CI fail on count 5 | Mandatory test update first/same PR |
| Collision with strategist | Stable ids in plan frontmatter |
| Unenforceable continuity theater | Durable note on keep |

## Todo

- [x] Ritual text + intro
- [x] Test 5→6
- [x] Links
