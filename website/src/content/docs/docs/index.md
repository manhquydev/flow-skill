---
title: "flow docs"
description: "How to read these docs: tutorials to learn, how-to for a task, explanation for the why, reference for the exact shape."
---

`flow` is a gated build harness for coding agents. It walks a product from an idea to
**real done-evidence** — a deployed URL, an installed CLI that runs, a library API you can
import, or a skill that reaches its own done-definition — through gates that have to be
honestly satisfied before you advance.

These docs are organised as four separate kinds of writing. Each answers a different
question, and mixing them is what makes most documentation hard to read. Pick the bucket
that matches what you are doing right now.

## Tutorials — learn by doing

Start here if you have never run `flow`. A tutorial is a guided lesson with a guaranteed
outcome: you follow the steps in order, and at the end something real has happened on your
machine. Tutorials do not stop to explain every design decision, and they do not list every
option — that would break the lesson.

- [Install and first run](/docs/tutorials/install-and-first-run) — install the skill and get
  a first honest gate result.
- [Your first greenfield project](/docs/tutorials/first-greenfield-project) — idea to a
  build card, walking every planning gate.

## How-to — get a specific task done

Use these when you already know what `flow` is and you have a job in front of you: resume a
project you left two weeks ago, cut a card, skip a gate you have honest debt for, wire in a
second review engine. A how-to assumes competence and gets to the point.

- [Resume mid-project](/docs/how-to/resume-mid-project)
- [Create and check cards](/docs/how-to/create-and-check-cards)
- [Use the chat concierge](/docs/how-to/use-chat-concierge)
- [Troubleshoot an install](/docs/how-to/troubleshoot-install)

## Explanation — understand why it is built this way

Read these away from the keyboard. They cover the mechanism: why there are two gate layers
instead of one, why "tests pass" is never accepted as done, why the harness keeps memory in
a durable store, and why there are two version numbers. Nothing here is a set of steps.

- [What is flow](/docs/explanation/what-is-flow)
- [The two-layer harness](/docs/explanation/two-layer-harness)
- [Done means world-state evidence](/docs/explanation/done-evidence)
- [Versions: npm installer vs skill product](/docs/explanation/versions-npm-vs-skill)

## Reference — look up the exact shape

Dry, factual, and structured for scanning: the command table, where files land per agent,
the artifacts each stage produces, environment variables. Reference pages describe the
machinery; they do not teach and they do not argue.

- [Command reference](/docs/reference/commands)
- [Install CLI](/docs/reference/install-cli)
- [Install paths](/docs/reference/install-paths)
- [Changelog](/docs/reference/changelog)
- [Glossary](/docs/reference/glossary)

## The shortest possible start

Current pairing: skill product **v0.30.0**, npm installer **0.7.0** on `@latest`. See
[Versions: npm installer vs skill product](/docs/explanation/versions-npm-vs-skill).

```bash
npx @manhquy/flow-skill@latest
# expect: flow-skill v0.7.0 (ships skill v0.30.0)
```

Restart your agent, open a project, and say what you want to build in plain language. Chat
is the default front door — typed verbs like `/flow next` always work, but you never have to
learn one to begin.
