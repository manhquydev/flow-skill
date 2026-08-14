---
title: "Converge the plan back to the code"
description: "Append remainder cards that reconcile what the code actually does with what the plan said."
---

Real builds drift: code gets written that the plan never asked for, and planned work quietly
never lands. `/flow converge` is the flow-back closer for that gap. You assess present code
against the plan, write a `flow-converge/v1` payload describing the gaps, and run the verb.
It is transactional and append-only — either every remainder card is written or none is, it
never edits an existing card, and when there is no gap it prints `CONVERGED` and writes
nothing at all. Work that exists in the code but was never requested becomes a review card,
never a deletion, because deciding to remove something is an operator's call. The semantic
half has its own behavioral proof: `flow.sh eval --stage converge` feeds a repository state to
a judge and asks whether the correct verdict is a gap or convergence.

Gap taxonomy and the payload schema:
[`skills/flow/references/converge.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/converge.md)
