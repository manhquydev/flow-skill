---
title: "Clarify open decisions"
description: "Find and settle the unresolved product decisions sitting in your Scope, PRD, and Contract."
---

Unresolved product decisions live as `- [ ]` bullets under an `## Open decisions` heading on
the Scope, PRD, and Contract artifacts. They are counted by the *same* box scanner the gates
already use, which means an unsettled decision genuinely blocks the stage rather than sitting
in a comment nobody reads. `/flow clarify` prints those leftover bullets, scoped to that
section, and always exits 0 — it is an advisory printer, not a second gate. Settling them is
a bounded, opt-in write-back ritual: work through the bullets one at a time, record the
decision in the artifact, and check the box. Nothing about `clarify` is a prerequisite for
`/flow next`; the gate scanner enforcing the boxes already is.

The write-back ritual:
[`skills/flow/references/clarify.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/clarify.md)
