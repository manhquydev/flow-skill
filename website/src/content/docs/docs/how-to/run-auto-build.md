---
title: "Run an auto build"
description: "Drive the build phase autonomously with tiered handling, and know where it will stop and wait for you."
---

`/flow auto` preflights an autonomous run and, if the preflight passes, activates the shared
auto policy; `/flow auto stop` returns you to manual. The preflight is fail-closed: every card
must have a classified risk — security-class ones needing a distinct-author acknowledgement in
`DEBT.md` — and stage 05 must carry a current semantic receipt. Per card the loop is
tier-classify, build in an isolated worktree with a scoped subagent, adversarial review,
receipts, `check`, merge, deploy, live verify, world-state evidence, then done plus a durable
trace. Tier-A green cards auto-merge; Tier-B gets one repair attempt by a fresh subagent;
Tier-C security-class work halts for you to accept the exposure in writing. Hard caps on
iterations, tokens, and time are mandatory, and every gate decides on a mechanical signal
rather than an agent's self-assessment.

Tiers, worktree loop, `AUTO-LOG.md`, and halt conditions:
[`skills/flow/references/auto-run.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/auto-run.md)
