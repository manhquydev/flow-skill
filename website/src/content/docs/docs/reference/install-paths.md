---
title: "Install paths"
description: "Where the flow skill lands per agent, how to invoke it, and the runtime dependencies each path needs."
---

The installer copies the same skill tree into every agent home you select. Nothing is shared
between homes — each is a complete copy.

## Per agent

| Agent | Path | Invoke |
|---|---|---|
| Claude Code | `~/.claude/skills/flow` (or project-local `.claude/skills/flow`) | `/flow` |
| Codex CLI | `~/.codex/skills/flow` | `$flow` — restart Codex after install |
| Agents home | `~/.agents/skills/flow` | host-specific |
| Antigravity | `~/.gemini/antigravity-cli/skills/flow` (CLI) and `~/.gemini/config/skills/flow` (IDE) | `/flow` after reload |
| Cursor | `~/.cursor/skills/flow` | agent skills panel after reload |

Antigravity has two homes because the CLI and the IDE read different directories. It is the
same `SKILL.md` bundle in both; run `agy inspect` to confirm it was discovered.

## What is inside a skill home

| Path | Contents |
|---|---|
| `SKILL.md` | Semantic-layer entry: dispatch, gatekeeping, orchestration. Carries `metadata.version`. |
| `runner/flow.sh` | The mechanical engine. `runner/flow.cmd` is the Windows launcher. |
| `harness/` | The durable layer (Python plus SQLite). |
| `law/` | `CLAUDE.md` build-session law, `DESIGN.md` UI law, `RETRO.md`. |
| `references/` | The semantic playbooks: gate rules, concierge, project types, agent mapping, and more. |
| `_templates/` | The gated artifacts the runner copies into a project. Never edit during a run. |
| `playbooks/` | Stack knowledge — read before building on that stack, harvest after. |

## Where project files go

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

## Cross-project knowledge base

`/flow promote <playbook.md>` copies a playbook to `~/.claude/flow/playbooks`, where
`/flow recall` surfaces it in every project rather than only the one it came from.

## Runtime dependencies

| Dependency | Needed for |
|---|---|
| `bash` | The mechanical engine. On Windows this means Git Bash — use `runner/flow.cmd`. |
| `python3` | Recommended. Powers the durable harness. Without it, gates still run and the SQLite layer disables. |
| `git` | Optional. Needed for worktrees and `/flow auto`. |
| Node.js ≥ 22.14 | The npm installer only, not the skill at runtime. |

## Verifying a home

```bash
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

## See also

- [Install CLI](/docs/reference/install-cli)
- [Alternative install paths](/docs/how-to/alternative-install)
- [Troubleshoot an install](/docs/how-to/troubleshoot-install)
