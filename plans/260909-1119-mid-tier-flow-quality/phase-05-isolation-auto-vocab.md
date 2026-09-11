---
title: "Phase 5: Isolation + auto vocab"
status: todo
priority: P1
effort: "5h"
dependencies: []
---

# Phase 5: Isolation + auto vocab

## Overview

Structured child reports and auto vocabulary **in docs**. Runner does not enforce actor identity this wave (ADR-0001; R1 reject). Exclusive: `auto-run.md`, `agent-stage-mapping.md`, `agent-detection.md`, `debt-and-halts.md`, `mode-work.md`.

## Requirements

- Brief last line `STATUS: DONE|DONE_WITH_CONCERNS|BLOCKED|NEEDS_CONTEXT` plus summary/evidence/nextSteps/blocker
- Missing STATUS = BLOCKED **in the brief contract**
- Child complete = worker report; parent still `flow.sh check` (prose)
- Briefs tell children not to resolve Tier-C / DEBT / skip / merge — not a runner control
- AutoDecision enum **only** in auto-run.md: `auto-merge | repair | halt | blocked | needs-operator`
- Docs default-deny auto on hosts without scoped subagents; recommend next+check for Flash
- `cmd_auto` unchanged
- Strip `YOU (Claude)` from auto-run.md
- mode-work: numbered questions; self-challenge is not a verdict

## Implementation Steps

1. Replace mapping Return line with structured block + spawn-not-fork + "brief is whole context"
2. agent-detection: built-in-first; missing status = BLOCKED
3. auto-run: vocative gone; AutoDecision; child complete ≠ check; default-deny paragraph
4. debt-and-halts halt report template
5. mode-work host-neutral interview

## Todo

- [ ] Structured report in mapping + detection
- [ ] AutoDecision + vocative gone
- [ ] Halt template + work-mode color-not-verdict

## Success Criteria

- [ ] No flow.sh edits
- [ ] `rg "YOU \\(Claude\\)" auto-run.md` empty
- [ ] AutoDecision not duplicated in command-dispatch.md

## Risk Assessment

Flash ignores docs. Residual accepted. Do not add FLOW_AUTO_OK.

## Dependency map

Parallel with 1, 2, 4.
