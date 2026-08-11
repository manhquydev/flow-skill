---
phase: 4
title: "Native strategist + optional host hooks (BACKLOG)"
status: pending
priority: P2
effort: "1-1.5d"
dependencies: [1]
---

# Phase 4: Native strategist + optional host hooks (BACKLOG)

## Overview

**Out of P1 ship bar** (red-team RT9). Optional enrichment after phases 1–3 ship and dogfood. Port kongming **protocol** as native strategist counsel; optional detect real kongming; host-hooks docs. Never a gate condition.

## Requirements

- Same as prior draft but **explicitly not required** for plan success criteria
- Do not block cook of phases 1–3 on this phase

## Architecture

Unchanged from prior: native ritual §6; agent-detection optional; host-hooks.md; inform-only.

## Related Code Files

- `skills/flow/references/native-rituals.md`, `auto-run.md`, `gate-rules.md`, `agent-detection.md`
- Create: `skills/flow/references/host-hooks.md`
- Optional: `SKILL.md` reference list

## Implementation Steps

1. Only after 1–3 shipped and operator prioritizes.
2. Write ritual + links; no gate coupling.
3. doctor advisory for hooks.

## Success Criteria (when picked up)

- [ ] Ritual documented; never gate PASS
- [ ] No AgentKit hard dep
- [ ] Suite still green

## Risk Assessment

YAGNI if done before hollow-done floor ships — **do not schedule in same release as 1–3 unless idle**.

## Test / validation gate

```bash
# optional
grep -q Strategist skills/flow/references/native-rituals.md || true
```

<!-- Updated: Red Team Session 1 - demoted to backlog P2 -->
