---
title: "Install and first run"
description: "Install, restart, say what you want to build (or type /flow), and get a status, a next action, or a gate result."
---

By the end of this tutorial the `flow` skill is on disk in an agent home, the agent has been
restarted, and the harness has answered with a **status, a next action, or a gate result**.

Time: one command, one restart, then one mechanical check. The optional deep path (versions
and a gate-refuse transcript) is about ten minutes. That is not the success line.

## Before you start

You need [Node.js](https://nodejs.org/) **22.14 or newer** and one supported coding agent
(Claude Code, Codex CLI, Cursor, Antigravity, or an Agents home). The skill itself also
wants `bash` at runtime — on Windows that means Git Bash. `python3` is recommended but
optional: without it the gates still run and only the durable SQLite layer switches off.

## Step 1 — run the installer

```bash
npx @manhquy/flow-skill@next
```

Use `@next` for skill **v0.31.0** (installer `0.7.1-next.0`). `@latest` still ships 0.7.0 /
skill 0.30.0 until promoted. A bare `npx @manhquy/flow-skill` can be served from the npx
cache and quietly re-run an older copy.

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

## Step 3 — check the environment

```bash
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

You want `READY`. `doctor` checks bash, python, grep, and git across macOS, Linux, and
Windows. A missing `python3` reports the durable layer as disabled — that is a degraded
mode, not a failure. Anything else, go to
[If install breaks](/docs/how-to/troubleshoot-install).

On Windows PowerShell, call `runner\flow.cmd` instead of `bash`. A bare `bash` in PowerShell
usually resolves to WSL, which cannot read `C:/...` paths and makes a working install look
broken.

Confirming installer vs skill version numbers is optional depth. See
[Two version numbers](/docs/how-to/troubleshoot-install/#two-version-numbers).

<details>
<summary>Print both version numbers</summary>

```bash
npx @manhquy/flow-skill@next --help
# expect: flow-skill v0.7.1-next.0 (ships skill v0.31.0)
```

The installer prints its own version and the skill version it ships. Then read the skill
version from disk:

```bash
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
```

Those two numbers move independently. Do not copy digits from this page.

</details>

## Step 4 — say what you want to build

You never have to learn the verbs. In a fresh agent session, in a project directory, type:

> "I want to build an inventory app for my shop."

Or type `/flow` (Codex: `$flow`).

The concierge runs the status command first to get mechanical ground truth, asks one plain
consent question about who should draft the artifacts, and proposes exactly one next action.
Typed `/flow` verbs always win over chat routing.

Routing is reliable on Claude. On Codex or Antigravity, treat chat routing as best-effort and
type the verb. The full caveat is on
[Everyday loop](/docs/how-to/use-chat-concierge).

Success is any of: a status, a next action, or a gate result. “The concierge said yes” is
not the trophy by itself.

## What you have now

- The skill installed in at least one agent home.
- The agent restarted so it can see the skill.
- One harness answer: status, next action, or a gate result.

## Next

Walk a real project through every planning gate in
[Walk a full project](/docs/tutorials/first-greenfield-project), or read
[The two-layer harness](/docs/explanation/what-is-flow/#two-layer-harness) to understand
what judged the file.

## Watch a gate refuse {#watch-a-gate-refuse}

This is optional depth. It is the deterministic demo that the mechanical layer is alive.
Kill at a gate is also valid.

<details id="watch-a-gate-refuse">
<summary>Transcript of an empty Idea file</summary>

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

</details>
