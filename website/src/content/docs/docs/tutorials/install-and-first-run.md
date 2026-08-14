---
title: "Install and first run"
description: "Install the flow skill with npx, verify both version numbers, and watch a gate fail honestly for the first time."
---

By the end of this tutorial the `flow` skill is installed into your agent's skill home, you
have confirmed which versions you got, and you have seen a gate refuse to advance — which is
the behaviour the whole harness exists for.

Time: about ten minutes.

## Before you start

You need [Node.js](https://nodejs.org/) **22.14 or newer** and one supported coding agent
(Claude Code, Codex CLI, Cursor, Antigravity, or an Agents home). The skill itself also
wants `bash` at runtime — on Windows that means Git Bash. `python3` is recommended but
optional: without it the gates still run and only the durable SQLite layer switches off.

## Step 1 — run the installer

```bash
npx @manhquy/flow-skill@latest
```

Always include `@latest`. A bare `npx @manhquy/flow-skill` can be served from the npx cache
and quietly re-run an older copy.

Three things happen:

1. npm downloads the current released installer.
2. The installer shows an interactive multi-select of the agents it detected on this machine.
3. It copies the skill tree into every home you selected, for example
   `~/.claude/skills/flow`.

Select the agent you actually use. You can re-run the command later to add another.

## Step 2 — restart the agent

The skill is a set of files on disk; agents read that directory when they start. Until you
restart, the agent does not know the skill exists.

| Agent | After restart |
|---|---|
| Claude Code | type `/flow` |
| Codex CLI | restart once, then type `$flow` |
| Cursor / Agents home | reload the tool, open the flow skill |
| Antigravity | restart the IDE or `agy`, then `/flow` |

## Step 3 — confirm what you installed

There are two version numbers on purpose, and confirming both now saves confusion later.

```bash
npx @manhquy/flow-skill@latest --help
```

The installer prints its own version and the skill version it ships:

```
flow-skill v0.6.0 (ships skill v0.29.0)
```

Then read the skill version from disk:

```bash
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
# version: "0.29.0"
```

`0.6.0` is the npm installer CLI. `0.29.0` is the skill product — the thing that actually
gates your build. They move independently. If that seems odd, read
[Versions: npm installer vs skill product](/docs/explanation/versions-npm-vs-skill).

## Step 4 — check the environment

```bash
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

You want `READY`. `doctor` checks bash, python, grep, and git across macOS, Linux, and
Windows. A missing `python3` reports the durable layer as disabled — that is a degraded
mode, not a failure. Anything else, go to
[Troubleshoot an install](/docs/how-to/troubleshoot-install).

On Windows PowerShell, call `runner\flow.cmd` instead of `bash`. A bare `bash` in PowerShell
usually resolves to WSL, which cannot read `C:/...` paths and makes a working install look
broken.

## Step 5 — see a gate fail

Make an empty directory and open your agent there. Then ask for the first stage:

```
/flow next
```

The runner scaffolds `flow/00-idea.md` and immediately gate-checks it. Because you have not
written anything yet, it refuses:

```
FAIL: gate for stage 00-idea is not clean.
  [x] unchecked gate boxes:
      L4:- [ ] The pitch below is 3 sentences, no more
  [x] unfilled [FILL] placeholders:
      L10:[FILL: sentence 1 — who has the problem]
Fix the above, then run '/flow next' again. (Kill at a gate is also valid.)
```

This is the install working. The mechanical layer read the file, found unchecked boxes and
unfilled placeholders, and exited non-zero with line numbers. It did not fill them in for
you, and it will not.

## Step 6 — ask in plain language instead

You never have to learn the verbs. In a fresh agent session, type:

> "I want to build an inventory app for my shop."

The concierge runs the status command first to get mechanical ground truth, asks one plain
consent question about who should draft the artifacts, and proposes exactly one next action.
Typed `/flow` verbs always win over chat routing, so power users lose nothing.

## What you have now

- The skill installed in at least one agent home.
- Both version numbers confirmed from the machine, not from a README.
- One gate failure read end to end, with line numbers.

## Next

Walk a real project through every planning gate in
[Your first greenfield project](/docs/tutorials/first-greenfield-project), or read
[The two-layer harness](/docs/explanation/two-layer-harness) to understand what just judged
your file.
