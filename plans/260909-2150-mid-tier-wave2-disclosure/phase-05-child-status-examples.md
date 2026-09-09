---
phase: 5
title: "Child STATUS examples"
status: pending
priority: P1
effort: "3h"
dependencies: []
---

# Phase 5: Child STATUS examples

## Overview

STATUS schema is docs-only (ADR-0001: runner does not parse). Flash omits the last line unless a filled example sits next to the template. AutoDecision leaked into debt-and-halts halt template (`AutoDecision: halt`). Always-on Vietnamese in the scoped brief poisons EN products.

## Requirements

- Functional: one valid STATUS report + one invalid; AutoDecision body only in auto-run.md; VN copy opt-in
- Non-functional: **do not** parse STATUS in flow.sh; **do not** add FLOW_AUTO_OK

## Exclusive write set

- `skills/flow/references/agent-stage-mapping.md`
- `skills/flow/references/auto-run.md`
- `skills/flow/references/debt-and-halts.md`

## Implementation Steps

1. `agent-stage-mapping.md`: keep the template. Add (a) filled DONE example with evidence paths and empty blocker; (b) missing last-line STATUS → parent treats BLOCKED; (c) invalid `STATUS: DONE` with empty evidence. Cross-field: DONE requires non-empty evidence + empty blocker; BLOCKED/NEEDS_CONTEXT require non-empty blocker; nextSteps never skip/debt/merge. Vietnamese user-facing copy: opt-in (`when the project is Vietnamese-facing` / DESIGN.md VN block), not always-on in the brief.
2. `auto-run.md`: one-block few-shot — missing STATUS → parent BLOCKED; `STATUS: DONE` ≠ card pass (parent still `flow.sh check`). Replace `Task(subagent_type="debugger")` with host-neutral `debugger if present else inline + fresh scoped brief`. Keep default-deny Flash. Keep AutoDecision closed enum **in this file only**.
3. `debt-and-halts.md` halt template: keep `STATUS: BLOCKED`. Change `AutoDecision: halt` to a pointer (`see auto-run.md AutoDecision`). Do not list the five tokens here.

## Success Criteria

- [ ] agent-stage-mapping.md contains a line `STATUS: DONE` inside a filled example (not only the schema)
- [ ] Brief VN constraint is gated, not unconditional
- [ ] `rg -n 'Task\(subagent_type=' skills/flow/references/auto-run.md` empty
- [ ] `rg -n 'AutoDecision:' skills/flow/references/debt-and-halts.md` has no enum values (pointer only)
- [ ] `rg -n 'AutoDecision' skills/flow/references/auto-run.md` still defines the closed enum
- [ ] git diff does not add STATUS parsing to flow.sh

## Risk Assessment

Docs-only means Flash can still ignore STATUS. Accepted: ADR-0001. Few-shots raise the floor; do not grow a parser.
