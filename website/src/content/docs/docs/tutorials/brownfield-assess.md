---
title: "Assess a brownfield project"
description: "Start flow on an existing codebase by gating a current-state assessment before any planning."
---

An existing codebase does not start at the Idea stage. `/flow assess` scaffolds and gates
`flow/00-inspect.md`, a current-state map covering the stack, what the product actually does
today against what it is supposed to do, the risks you can already see, and the test
baseline. Part of it is auto-scanned, all of it is operator-reviewed, and it must pass its
gate before planning stages open. The point is that planning for an existing system should be
grounded in what is there, not in what the repository's README claims is there.

Full stage definition and gate wording:
[`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md)
