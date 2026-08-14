---
title: "Run several agents in parallel"
description: "Give each agent its own git worktree so one branch switch does not flip every terminal."
---

`/flow workspace add|list|enter|remove|check|doctor` provisions one `git worktree` per agent,
which solves the trap where one agent switches branch and every other terminal flips with it.
Each worktree has its own HEAD, index, and files while sharing the object store. `add <branch>`
creates the tree with a distinct port offset and prints a paste-ready cd and env block;
`list` shows who is where; `enter <branch>` reprints the environment for a crashed terminal;
`check <branch> --card` flags branch-claim and allowed-files overlap *before* you launch;
`remove` tears down without ever auto-forcing, and `doctor` reconciles orphaned trees and
records. git itself is the registry and the real lock — its refusal to check out one branch
twice is what actually protects you; the `.flow/workspaces.jsonl` side-file only adds vendor,
card, port, and task metadata on top.

Subcommand detail:
[`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md)
