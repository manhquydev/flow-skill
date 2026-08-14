---
title: "Advance planning gates"
description: "Use /flow next to walk stages 00 to 05, and read a gate failure without guessing."
---

`/flow next` gate-checks the stage you are on and, only if it passes, unlocks the next one.
When the mechanical layer fails it prints exactly what is wrong with line numbers — unchecked
gate boxes, leftover `[FILL]` placeholders — and stops. Fix those in the file and run it
again. When the script passes, the semantic challenge for the stage just completed is applied
before you are allowed to move on, so a mechanically clean but hollow artifact still gets
named as weak. In `teach` mode the agent will never check a box or write an artifact for you;
it only tells you what is failing.

Stage order, unlock conditions, and what each artifact must contain:
[`skills/flow/references/stage-state-machine.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/stage-state-machine.md)
