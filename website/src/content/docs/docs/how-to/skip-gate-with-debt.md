---
title: "Skip a gate with debt"
description: "Advance past a gate that genuinely does not fit, by recording the exposure as debt first."
---

Skipping is legitimate; skipping silently is not. Record the exposure with
`/flow debt add "skip 01-research" "<exposure>" "<close-before condition>"`, then
`/flow skip 01-research --reason "…"`. The skip only advances when an open debt line names
that exact stage and the reason is not security-class, and `planning_complete` then tolerates
that stage so cards are not blocked forever. Three guards apply in order: stage 05, the
contract, can never be skipped — adapt it to your project type instead; a security-class
reason such as auth, tenancy, payments, permissions, or data migration halts for the operator
to accept in writing; and an unrelated open debt line will not unlock anything.

Debt ledger, security-class halt rules, and when a run halts:
[`skills/flow/references/debt-and-halts.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/debt-and-halts.md)
