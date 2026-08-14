---
title: "Build a CLI or skill project"
description: "Set the project type so the contract seam, card sequence, and done-evidence match a CLI or an agent skill instead of a web app."
---

`flow` was born web-shaped, so the first thing to do on a CLI or skill build is
`/flow project-type cli` or `/flow project-type skill`. The type changes three things: what
the stage 05 contract describes, the standard card sequence, and what counts as done. For a
CLI the contract is commands, flags, output shapes and exit codes, and done means the tool
installs and a real invocation returns the expected output and exit code. For a skill the
contract is the command and file surface the agent reads, and done means it is installed into
a skill home and a real run reaches its own done-definition. The gates themselves are
unchanged — only the shape of the proof moves.

Per-type adaptations, card sequences, and the gate-wording note:
[`skills/flow/references/project-types.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/project-types.md)
