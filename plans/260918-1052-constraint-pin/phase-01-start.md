---
phase: 1
title: "AgentKit overlay"
status: pending
priority: P1
effort: "1h"
dependencies: []
---

# Phase 1: AgentKit overlay

## Overview

Land the already-written `ak:*` ≡ `ck-*` Name resolution overlay so AgentKit hosts get the same whitelist. Hygiene. Does not reprint STOP after compact.

## Context Links

- `plans/reports/brainstorm-260918-1651-next-direction.md` (overlay is ship-with, not story)
- Working tree already contains the diff (11 files)

## Requirements

- Functional: host skill registries matching `ak:predict` / `ak:scenario` / `ak:security` / `ak:loop` / `ak:review-pr` offer the same rows as `ck-*`.
- Functional: competing orchestrators include `agentkit`; never invoke `ak:agentkit` mid-gate.
- Functional: unprefixed host specialists (`planner`) match `ck:planner`.
- Non-functional: no runner change. Detection stays host-side. Skill INFORMS, gate JUDGES.

## Architecture

Docs-only seam in `claudekit-skills.md` Name resolution. Gates 04/05 and Review offer aliases. Catalog TSV `enrich-if-present` uses `ck-|ak:` pipes.

## Related Code Files

- Modify (already in WT): `skills/flow/references/claudekit-skills.md`, `agent-detection.md`, `agent-stage-mapping.md`, `gate-04.md`, `gate-05.md`, `adversarial-review.md`, `native-rituals.md`, `flow-catalog.tsv`, `skills/flow/SKILL.md`, `docs/system-architecture.md`, `tests/test_flow_claudekit_integration.sh`
- Create: none
- Delete: none
- Do **not** touch `flow.sh` or `test_flow_status_legibility.sh` (phase 2)

## Implementation Steps

1. Keep the uncommitted overlay; do not rewrite.
2. Re-run `bash tests/test_flow_claudekit_integration.sh` and `bash tests/test_flow_native_rituals.sh` and `bash tests/test_flow_concierge.sh`.
3. If any fail, fix **only** overlay exclusive files.
4. Do not add PIN text to SKILL.md.

## Todo

- [ ] Overlay tests green on this tree
- [ ] No PIN / `pin-v1` strings in phase-1 files

## Success Criteria

- [ ] `test_flow_claudekit_integration.sh` 54/54 (or current count) exit 0
- [ ] Native ritual still before ck-predict / ck-scenario / ck-security
- [ ] Catalog still 6 columns

## Risk Assessment

- SKILL.md word budget: currently 1181/1600. Overlay added one `ck/ak` token. Signal it broke: `test_doc_budgets.sh` fail. Response: revert SKILL.md line only.
- Wave2 pending also listed SKILL.md. Signal: merge conflict. Response: overlay-only hunk is one line; rebase.

## Security Considerations

- Offering `ak:security` must not auto-pass Tier-C HALT (already in adversarial-review.md).
- `ak:agentkit` must stay in Don't-surface (routes away from flow).
