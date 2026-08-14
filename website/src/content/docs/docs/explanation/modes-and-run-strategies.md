---
title: "Modes and run strategies"
description: "Four independent mode axes — authoring, project type, run mode, and greenfield versus brownfield — that mix freely."
---

`flow` has four mode axes and they are genuinely independent, so you set each one per project
and combine them however the work demands. **Authoring mode** decides who writes the gate
artifacts: `teach`, the default, means you write and the agent only gate-keeps; `work` means
the agent interviews you once, drafts stages 00 to 05, and pauses only for the scope
sign-off. **Project type** decides what done means — a live URL for web, a real invocation
and exit code for a CLI, an importable API for a library, an installed run for a skill.
**Run mode** decides how cards get built: manual, where you drive card, build, check; or
auto, an autonomous run with tiered handling that halts on security-class work.
**Greenfield versus brownfield** decides where you start: stage 00-idea for something new, or
a gated current-state assessment for an existing codebase.

What no axis changes is the bar. Gates and done-rules are identical across every combination;
the modes move authorship, proof shape, and drive, never the height of the gate.

Work-mode script and mode boundaries:
[`skills/flow/references/mode-work.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/mode-work.md)
