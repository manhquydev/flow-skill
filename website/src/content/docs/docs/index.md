---
title: "Install the skill, then say what you want to build."
description: "Install flow with npx. After install you get an honest stop, and after you walk the gates a written plan. Done means the thing exists. Walk a full project, or look up commands."
---

## Install

You need [Node.js](https://nodejs.org/) **22.14 or newer** and one coding agent: Claude Code, Codex, Cursor, or Antigravity.

```bash
npx @manhquy/flow-skill@latest
```

Do not `npm i` this package. That does not copy the skill. Do not pin the skill version on npm. Always include `@latest`.

What happens: the installer detects agents, you pick homes, the skill lands (example `~/.claude/skills/flow`).

Then restart the agent. Until you restart, the agent does not know the skill exists.

| Agent | After restart |
|---|---|
| Claude Code | type `/flow` |
| Codex CLI | restart once, then type `$flow` |
| Cursor | reload the tool, open the flow skill |
| Antigravity | restart the IDE or `agy`, then `/flow` |

Optional: `bash ~/.claude/skills/flow/runner/flow.sh doctor` should print `READY`.

`--help` prints installer and skill versions. They are two numbers. See [Two version numbers](/docs/how-to/troubleshoot-install/#two-version-numbers).

## What you get

Three capabilities. The first is true after `npx`. The next two are true after you walk gates or close a card.

1. **An honest stop.** `/flow next` will not unlock the next stage if the file is empty, fabricated, or scope-laundered. Killing the idea is valid. This is a gate refuse; the agent itself keeps running.
2. **A written plan in your repo, when you walk the gates.** Six files under `flow/`, then cards under `cards/`. Another session can pick up cold. Those files do not exist after install alone.
3. **Done that means the thing exists.** Live URL, CLI that runs, importable API, or a skill that actually ran. Not “tests pass.”

## First run — one command, one restart, one check.

```bash
npx @manhquy/flow-skill@latest
# restart the agent
# in a project directory:
I want to build an inventory app for my shop.
# or type /flow  (Codex: $flow)
```

Chat is the door. Typed `/flow` always wins. The concierge asks one consent question, then one next action. Routing is reliable on Claude; on Codex or Antigravity treat chat as best-effort and type the verb. The full caveat lives on [Everyday loop](/docs/how-to/use-chat-concierge).

Success on this page: skill on disk, agent restarted, you said what to build **or** typed `/flow`, and the harness answered with **status or a next action or a gate result**.

Long form, including “Watch a gate refuse”: [Install and first run](/docs/tutorials/install-and-first-run).

## Everyday commands

| You want | Type |
|---|---|
| Where am I? | `/flow` |
| Advance or get blocked honestly | `/flow next` |
| Cut a build slice | `/flow card` |
| Prove it exists | `/flow check C-001` |
| Existing codebase | `/flow assess` |
| Machine check | `/flow doctor` |

Codex uses `$flow`. Full table: [Commands](/docs/reference/commands). `/flow auto` is advanced; see [When work must halt](/docs/explanation/auto-tiers-and-security-halts).

## The flows as jobs

Idea → Research → Scope → PRD → ADR → Contract, then cards, then Retro. File names sit beside the job as `flow/00-idea.md` … `flow/05-contract.md`, not as headings.

Contract is the one stage you cannot skip. See [Why the contract can never be skipped](/docs/explanation/stage-pipeline/#contract-never-skipped) and [When work must halt](/docs/explanation/auto-tiers-and-security-halts).

An existing repo starts at `/flow assess` ([Assess a brownfield](/docs/how-to/resume-mid-project/#assess-a-brownfield)). Teach vs work is one consent question; gates stay identical ([Teach vs work](/docs/how-to/use-chat-concierge/#teach-and-work)).

Do not inline the full walkthrough here. [Walk a full project](/docs/tutorials/first-greenfield-project).

## When you are stuck

- Resume a cold project → [Resume mid-project](/docs/how-to/resume-mid-project)
- Unlock a dead session → [Unlock a stale session](/docs/how-to/resume-mid-project/#unlock-stale-session)
- Troubleshoot install → [If install breaks](/docs/how-to/troubleshoot-install)

## Learn more

- How the two layers work → [The two-layer harness](/docs/explanation/what-is-flow/#two-layer-harness)
- Why “tests pass” is not done → [Done means world-state evidence](/docs/explanation/what-is-flow/#done-means-world-state)
- When work must halt → [When work must halt](/docs/explanation/auto-tiers-and-security-halts)
- Why two version numbers → [Two version numbers](/docs/how-to/troubleshoot-install/#two-version-numbers)
- Architecture → [Three layers](/docs/explanation/what-is-flow/#system-architecture)
- [Commands](/docs/reference/commands), [Glossary](/docs/reference/glossary), [Changelog](/docs/reference/changelog)
- Power (auto, attest, extra engines) → [Agent orchestration](/docs/explanation/agent-orchestration)

If you only needed to install and run, you can stop above.
