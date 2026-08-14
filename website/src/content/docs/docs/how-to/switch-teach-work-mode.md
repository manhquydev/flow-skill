---
title: "Switch teach and work mode"
description: "Choose who writes the planning artifacts. The gates bind identically either way."
---

`/flow mode teach` and `/flow mode work` set the authoring mode, stored in a `MODE` file and
defaulting to `teach`. In `teach` you write every planning artifact and the agent only
gate-keeps, catching hollow or fabricated content; it is forbidden from checking a box or
drafting on your behalf. In `work` the agent interviews you once, drafts stages 00 to 05
itself, pauses only for the scope sign-off, and delivers the card set as one summary. The
gates and done-rules are identical in both — `work` mode changes authorship, never the bar.

Work-mode interview script and hand-off shape:
[`skills/flow/references/mode-work.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/mode-work.md)
