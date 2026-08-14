---
title: "Auto tiers and security halts"
description: "Why an autonomous run sorts work into three tiers, and why the third one stops and waits for a human."
---

Autonomy is not all-or-nothing in `flow`; it is tiered by how much a wrong answer costs.
Tier-A is a green card with no security exposure, and it auto-merges without asking, because
requiring a human to approve work that every gate already passed just trains people to click
approve. Tier-B is fixable trouble, and it gets exactly one repair attempt by a *fresh*
subagent — the two-strikes rule — before escalating; freshness matters because the agent that
wrote the bug is the agent least able to see it. When the repair needs repeated experimental
attempts against a single numeric target rather than a review disagreement, the loop protocol
is the right tool instead.

Tier-C is security-class work — authentication, authorization, admin exposure, tenancy,
payments, data migration, removing validation — and it **halts**. The operator accepts the
exposure in writing in `DEBT.md`; it is never a planner's decision. The reasoning is asymmetry:
a wrong Tier-A merge costs a revert, and a wrong Tier-C merge can cost data or an account.
Alongside the tiers sit hard stops on iterations, tokens, and time, and every gate decides on
a mechanical signal — a real exit code, a real verify run, a live check — never an agent's own
assessment.

Tier definitions, the worktree loop, and halt conditions:
[`skills/flow/references/auto-run.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/auto-run.md)
