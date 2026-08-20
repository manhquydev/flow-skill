---
title: "Troubleshoot an install"
description: "Fix the common flow install failures, then the CLI flags, install paths, environment variables, and the two version numbers."
---

Work down this table first — most reports match one of these six rows.

| Symptom | Fix |
|---|---|
| No `/flow` after `npm i` | Run `npx @manhquy/flow-skill@next`. You must **execute** the CLI; installing the package alone copies nothing into a skill home. |
| Old skill after a "reinstall" | Use `@next` for skill v0.31.0 (`@latest` still ships 0.30.0 until promoted). A bare package name can be served from the npx cache. |
| Claude or Codex does not list the skill | Fully restart the agent once after the first install. |
| `flow.sh: No such file` in PowerShell | Call `…/runner/flow.cmd`, not `bash`. |
| `durable layer DISABLED` | Install `python3`, or ignore it — the mechanical gates still run. |
| CRLF or "bad interpreter" | The repo enforces LF via `.gitattributes`; re-clone if line endings were mangled. |

## Start with doctor

```bash
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

`doctor` checks bash, python, grep, and git and reports the install paths it can see. A
`READY` result means the environment is fine and the problem is elsewhere — usually the agent
not having been restarted.

## "I installed it but there is no /flow"

Two distinct causes, in order of likelihood.

**You installed the package instead of running it.** `npm i @manhquy/flow-skill` adds a
package to a `node_modules` folder. It does not copy the skill tree anywhere an agent looks.
The installer is a CLI you execute:

```bash
npx @manhquy/flow-skill@latest
```

**You did not restart the agent.** Agents enumerate their skill directory at startup. Claude
Code needs a restart; Codex needs a restart and then `$flow` rather than `/flow`; Cursor and
Antigravity need a reload of the tool or IDE.

Confirm the files actually landed:

```bash
ls ~/.claude/skills/flow/SKILL.md
```

## "It installed an old version"

Check what you actually have, from the machine rather than from any document:

```bash
npx @manhquy/flow-skill@latest --help
# --help prints both numbers: installer CLI, then the skill product it ships

grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
```

If the installed skill version is behind the one `--help` reports, the copy step did not
reach that home — re-run the installer and select the agent explicitly.

Two pinning mistakes cause most stale installs:

- Pinning the **skill product** version on npm. That number is not a published package
  version. Pin the installer CLI version, or use `@next` for the current skill.
- Using the `@rc` tag. It is retired and stale.

If npm says `No matching version found`, you pinned the skill product number. Use `@next`
or pin the installer. The two numbers and why they differ are under
[Two version numbers](#two-version-numbers).

## Windows: PowerShell resolves the wrong bash

In PowerShell or cmd — including inside Codex — a bare `bash` usually resolves to WSL at
`C:\WINDOWS\system32\bash.exe`. WSL cannot read `C:/...` or `/c/...` paths, so it fails with
`No such file or directory` and the harness looks broken when it is not.

Use the launcher, which finds Git Bash and passes a path it accepts:

```powershell
& "$env:USERPROFILE\.codex\skills\flow\runner\flow.cmd" status
```

Only call `bash flow.sh` directly once you have confirmed that `bash` is Git Bash.

## "durable layer DISABLED"

This is a degraded mode, not a failure. The durable layer is a Python plus SQLite store for
intake, story, trace, decision, and backlog records. Without `python3` the mechanical gates
and every stage and card check still run — you lose cross-session memory, so `/flow recall`
has less to read back. Install `python3` to re-enable it.

## Still stuck

Collect three things before asking for help: the full `doctor` output, the two version
numbers `--help` prints, and the exact command with its error text. Open an issue at
[github.com/manhquydev/flow-skill](https://github.com/manhquydev/flow-skill/issues).

## Alternative install paths {#alternative-install}

The npm installer, `npx @manhquy/flow-skill@next`, is the recommended path for skill v0.31.0.
The alternatives exist for contributors and air-gapped machines.

From a git checkout:

```bash
bash install.sh global          # or: pwsh install.ps1 global  on Windows
bash install.sh project [dir]   # project-local Claude skill
```

`bash install.sh global` syncs every detected agent home and runs the doctor step.
`bash install.sh project [dir]` installs a project-local Claude skill. On Windows use
`pwsh install.ps1 global` instead, since a bare `bash` in PowerShell is usually WSL and
cannot read Windows paths.

Claude Code can also add the repository as a plugin marketplace and install
`flow@flow-marketplace`.

The fully manual path is copying `skills/flow/` to `~/.claude/skills/flow/` and making
`runner/flow.sh` executable. Every channel writes the same tree, so a project can switch
between them without reissuing any gate or card.

Commands and platform notes:
[`README.md`](https://github.com/manhquydev/flow-skill/blob/master/README.md)

## Install CLI flags {#install-cli-flags}

```bash
npx @manhquy/flow-skill@next
```

Requires [Node.js](https://nodejs.org/) **22.14 or newer**. Use `@next` for the current skill;
`@latest` still ships 0.30.0 until promoted. A bare `npx @manhquy/flow-skill` can be served
from the npx cache and re-run an older copy.

Copy these; do not paraphrase flag meaning. `--project` applies only to `claude`.

```bash
npx @manhquy/flow-skill@next --yes
npx @manhquy/flow-skill@next --yes --target claude
npx @manhquy/flow-skill@next --yes -t claude -t codex
npx @manhquy/flow-skill@next --yes --all
npx @manhquy/flow-skill@next --yes --project --dir .
npx @manhquy/flow-skill@next --yes --all --dry-run --json
```

| Flag | Meaning |
|---|---|
| `-y`, `--yes` | Skip prompts; install default selection (detected + Claude) |
| `-t`, `--target <name>` | Target (repeatable or comma-separated) |
| `--all` | All targets, even if not detected |
| `--project` | Project scope — Claude only → `<dir>/.claude/skills/flow` |
| `--dir <path>` | Project directory (implies `--project`; default: cwd) |
| `--json` | JSONL events (`plan`, `install:*`, `summary`) |
| `--dry-run` | Print plan; do not write |
| `-h`, `--help` | Help. `--help` prints both version numbers. |

`--project` supports **only** `claude`. Other targets with `--project` exit `2`.

| Do | Don’t |
|---|---|
| `npx @manhquy/flow-skill@next` | Bare `npx @manhquy/flow-skill` (stale npx cache) |
| **Run** the CLI to copy the skill | `npm i` alone (package only; no skill files in agent homes) |
| Pin the installer version if you need a fixed release | Pin the skill product version on npm |
| Prefer `@next` for the current skill | `@rc` (retired / behind) |

Package: [`@manhquy/flow-skill` on npm](https://www.npmjs.com/package/@manhquy/flow-skill).
Flag meanings are kept with the installer:
[`npm-wrapper/README.md`](https://github.com/manhquydev/flow-skill/blob/master/npm-wrapper/README.md).

## Install paths {#install-paths}

The installer copies the same skill tree into every agent home you select. Nothing is shared
between homes — each is a complete copy.

### Per agent

| Agent | Path | Invoke |
|---|---|---|
| Claude Code | `~/.claude/skills/flow` (or project-local `.claude/skills/flow`) | `/flow` |
| Codex CLI | `~/.codex/skills/flow` | `$flow` — restart Codex after install |
| Agents home | `~/.agents/skills/flow` | host-specific |
| Antigravity | `~/.gemini/antigravity-cli/skills/flow` (CLI) and `~/.gemini/config/skills/flow` (IDE) | `/flow` after reload |
| Cursor | `~/.cursor/skills/flow` | agent skills panel after reload |

Antigravity has two homes because the CLI and the IDE read different directories. It is the
same `SKILL.md` bundle in both; run `agy inspect` to confirm it was discovered.

### What is inside a skill home

| Path | Contents |
|---|---|
| `SKILL.md` | Semantic-layer entry: dispatch, gatekeeping, orchestration. Carries `metadata.version`. |
| `runner/flow.sh` | The mechanical engine. `runner/flow.cmd` is the Windows launcher. |
| `harness/` | The durable layer (Python plus SQLite). |
| `law/` | `CLAUDE.md` build-session law, `DESIGN.md` UI law, `RETRO.md`. |
| `references/` | The semantic playbooks: gate rules, concierge, project types, agent mapping, and more. |
| `_templates/` | The gated artifacts the runner copies into a project. Never edit during a run. |
| `playbooks/` | Stack knowledge — read before building on that stack, harvest after. |

### Where project files go

The skill home holds the harness. Your **project** holds the work, under the directory you
run from:

```
flow/00-idea.md .. 05-contract.md   planning artifacts, gated
cards/C-NNN.md                      shipping units
MODE, PROJECT_TYPE                  authoring mode and project type
RETRO.md, DEBT.md, AUTO-LOG.md      ledgers
DESIGN.md                           project UI law
.flow/harness.db                    durable records
```

Override the project root with `FLOW_PROJECT_ROOT`. Running from a subdirectory that has no
`flow/` of its own adopts the nearest ancestor flow project and prints a note to stderr,
rather than creating a second fragmented root.

### Cross-project knowledge base

`/flow promote <playbook.md>` copies a playbook to `~/.claude/flow/playbooks`, where
`/flow recall` surfaces it in every project rather than only the one it came from.

### Runtime dependencies

| Dependency | Needed for |
|---|---|
| `bash` | The mechanical engine. On Windows this means Git Bash — use `runner/flow.cmd`. |
| `python3` | Recommended. Powers the durable harness. Without it, gates still run and the SQLite layer disables. |
| `git` | Optional. Needed for worktrees and `/flow auto`. |
| Node.js ≥ 22.14 | The npm installer only, not the skill at runtime. |

### Verifying a home

```bash
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

## Environment variables {#environment-variables}

The runner reads a number of `FLOW_*` variables. These are the ones documented for everyday
use; the complete set is defined in the runner source.

| Variable | Effect |
|---|---|
| `FLOW_PROJECT_ROOT` | Override the project root instead of relying on the directory walk. |
| `FLOW_SESSION_ID` | A stable session identifier. Export it once per session and pass it on every call to get hard concurrency protection rather than a warning. |
| `FLOW_LOCK_TTL` | Seconds before a `flow/.lock` is auto-reclaimed. Default 900. |
| `FLOW_FORCE` | Set to `1` to take over a lock you are certain is dead. |
| `FLOW_LOG_DISABLE` / `DO_NOT_TRACK` | Disable the local JSONL usage log that `/flow usage` rolls up. The log is local-only either way. |
| `FLOW_EVAL_RETRY_BACKOFF` | Retry backoff in seconds for the billable eval batch. Default 5; set 0 in tests. |

Without `FLOW_SESSION_ID` the runner cannot prove that a competing session is different, so
it warns rather than blocking — that is why exporting it matters on a shared machine.

Authoritative definitions:
[`skills/flow/runner/flow.sh`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/runner/flow.sh)

## Two version numbers {#two-version-numbers}

`flow` publishes two version numbers, and they do not match. That is intentional, not drift.
`--help` prints both numbers. Check them from your own machine rather than from any document.

| What | What it versions |
|---|---|
| **Skill product** | The gates, `SKILL.md`, the runner, references, and templates — the thing that judges your build. Lives in `SKILL.md` metadata. |
| **npm installer** | The `@manhquy/flow-skill` CLI that copies the skill into your agent homes. Lives on the npm package. |

```bash
npx @manhquy/flow-skill@next --help
# flow-skill v0.7.1-next.0 (ships skill v0.31.0)

grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
```

### Why two numbers

They version different artefacts with different change rates.

```
  monorepo skills/flow/  --npm run sync-->  npm-wrapper/skills/flow  --npm pack-->  registry
         |                                         |
         | install.sh / agent skill homes          | npx @manhquy/flow-skill@latest
         v                                         v
  ~/.claude/skills/flow                     same tree via installer CLI
```

The skill product is the harness itself. Its version drives the coherence check and the
telemetry field recorded in the durable layer, so a project can always say which gate
semantics it was built under. It changes whenever a gate, a stage, or a reference playbook
changes — which is often.

The npm package versions only the **installer CLI**: agent detection, the interactive
multi-select, where files get copied, the flags. That surface is small and stable. Publishing
a new installer version because a gate rule changed would be a lie about what changed, and
would force users to reason about a number that tells them nothing.

Collapsing the two would mean either bumping the installer for every gate change or freezing
gate versions to the installer's release cadence. Both are worse than explaining one table.

### The mistake this causes, and how to avoid it

The failure mode is pinning the wrong number. The skill product version is not a published
npm package version. Pin the installer CLI if you need a fixed release. Better for almost
everyone: `@next` (until `@latest` is promoted).

```bash
# Wrong — pin the skill product version (it is not an npm package version)
# Right — pin the installer CLI version, or use @next for the current skill
npx @manhquy/flow-skill@next
```

Right now the newest skill is on `@next` (`0.7.1-next.0` ships skill `0.31.0`). `@latest`
still ships installer `0.7.0` / skill `0.30.0` until promoted. A bare
`npx @manhquy/flow-skill` can be served from the npx cache and quietly re-run an older copy.
The `@rc` tag is retired; do not use it.

If npm reports `No matching version found`, you almost certainly pinned the skill product
number. `--help` prints both numbers; pin the installer one.

### Which number matters to you

If you are **using** flow, the skill product version is the one that describes your
experience — it tells you which gates and which commands you have. The installer version only
matters when you are debugging an install or pinning a build.

If you are **reporting a problem**, give both. `--help` prints them together in one line,
which is why that line exists.

### Checking for drift inside a project

```
/flow coherence
```

This flags version drift across declared version fields — the cheap document-versus-code
slice of the drift lattice. It is advisory: it flags, it never auto-fixes.

---

[Install and first run](/docs/tutorials/install-and-first-run) ·
[Changelog](/docs/reference/changelog)
