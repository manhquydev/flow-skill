---
title: "Command reference"
description: "Every flow verb, what it does, and whether it mutates state. Codex uses $flow instead of /flow."
---

All verbs dispatch to the mechanical engine, `bash <skill-dir>/runner/flow.sh <command>`.
In Claude Code, Cursor, and Antigravity you type `/flow …`; in Codex CLI you type `$flow …`.
On Windows PowerShell, call `<skill-dir>\runner\flow.cmd <command>` rather than `bash`.

## Everyday verbs

```
/flow              status — where am I, what's blocking
/flow next         gate-check + unlock next stage
/flow assess       brownfield assessment
/flow card         create a build card
/flow check C-001  validate card (done = world-state proof)
/flow auto         autonomous build (halts on security-class)
/flow doctor       environment check
```

## State and entry

| Command | What it does |
|---|---|
| `/flow resume` | Read-only session-story brief for entering a project mid-cycle: last session (command names only, never raw arguments), in-flight card plus dwell, gate state, one `NEXT ->` line. Takes no lock. Run this first when picking up an existing project cold. |
| `/flow` *(status)* | Where am I, what is blocking, a `NEXT ->` line from the same helper as `resume`, current-stage dwell, card list (compact summary past ten cards), and a one-line memory summary. |
| `/flow recall` | Read back durable memory — open debt, recent retro, previous card's scope, harness friction and backlog, audit health, playbooks — at the start of a stage or card. |
| `/flow unlock` | Clear this project's concurrency lock after a crashed or abandoned session. |
| `/flow doctor` | Environment self-check across macOS, Linux, and Windows: bash, python, grep, git, install paths. |

## Stages and planning

| Command | What it does |
|---|---|
| `/flow next` | Gate-check the current stage; on pass, unlock the next one (or start at stage 00). The semantic challenge for the stage just passed is applied after the mechanical pass. |
| `/flow assess` | Brownfield: scaffold and gate a current-state assessment in `flow/00-inspect.md` before planning. Operator-reviewed. |
| `/flow skip <stage> --reason` | Advance past a gate that has a matching open debt line. Non-security-class only; stage 05 can never be skipped. |
| `/flow clarify` | List leftover `- [ ]` bullets under `## Open decisions` on Scope, PRD, and Contract. Advisory, not a `next` gate. |
| `/flow constitution` | Check operator-authored per-project invariants in `flow/constitution.md`. Advisory, not a `next` gate. |
| `/flow converge` | Append-only remainder cards reconciling present code against the plan. Transactional — all cards or none; never edits an existing card; prints `CONVERGED` and writes nothing when there is no gap. |

## Cards and building

| Command | What it does |
|---|---|
| `/flow card` | Create the next build card, only after all planning gates pass. |
| `/flow card start\|done C-NNN` | Mark a card in flight, or perform a CLI-owned flip to `done` gated by the same rules as `check` — it reverts on failure. Coexists with hand-editing. |
| `/flow check C-NNN` | Validate a card: `[FILL]` placeholders, status, required sections, done-evidence. |
| `/flow ready` | List buildable todo cards plus a parallel-safety hint. |
| `/flow auto` | Preflight an autonomous run; `auto stop` clears it. Tier-A auto-merges, Tier-B gets one fresh-subagent repair, Tier-C security-class halts. |
| `/flow attest semantic\|live-verify\|status\|recover` | Mint or inspect fingerprint-bound receipts used by the attested-execution control plane. |
| `/flow workspace add\|list\|enter\|remove\|check\|doctor` | Multi-agent worktree isolation: one `git worktree` per agent so several agents run in parallel without one branch switch flipping every terminal. |
| `/flow loop-prep <card>` | Plumbing for iteration against a single numeric target: an isolated worktree plus a numeric verify command derived from the card's allowed files. |
| `/flow loop-log <card> --iterations N --start M --end K --outcome …` | Record a finished loop run into usage telemetry. |

## Modes and configuration

| Command | What it does |
|---|---|
| `/flow mode [teach\|work]` | Show or set who writes the gate artifacts. Default `teach`. |
| `/flow project-type [web\|cli\|library\|skill]` | Show or set the project type, which selects the done-evidence rule and the contract seam. Default `web`. |
| `/flow debt add\|list` | Record or list deliberate gate-skips in `DEBT.md`. Security-class entries are operator-only. |

## Drift and audit checks

All four are advisory: they flag, they never auto-fix.

| Command | What it checks |
|---|---|
| `/flow contract` | Client base-URL versus served-path prefix drift (web). |
| `/flow tokens` | `DESIGN.md` declared tokens versus the CSS actually used: unused, value mismatch, orphan. |
| `/flow coherence` | Version drift across declared version fields. |
| `/flow consistency` | Cross-artifact coverage: every PRD `FRn` claimed by a card and served by a contract interface, a numeric success metric, no leftover placeholders. |
| `/flow design <file>` | Mechanical `DESIGN.md` check on a UI file. |

## Durable layer and knowledge

| Command | What it does |
|---|---|
| `/flow harness <args>` | Passthrough to the durable layer CLI: intake, story, trace, decision, backlog, query, audit, propose. |
| `/flow promote <file>` | Copy a playbook into the cross-project knowledge base at `~/.claude/flow/playbooks`. |
| `/flow usage [--global\|--prune]` | Roll the local JSONL usage log into build analytics: cycle time, gate fail-rate, per-stage and per-card dwell, command breakdown. Local only. |
| `/flow retro` | Print the three retro questions. The operator writes the line, never the agent. |

## Evaluation

| Command | What it does |
|---|---|
| `/flow eval [--stage 01\|02\|05\|card\|routing\|converge] [--fixture <id>] [--n 3]` | Behavioral proof for the semantic gate: does the model actually flag a hollow-but-mechanically-clean fixture? Opt-in and **billable**; skips cleanly with zero calls if the `claude` CLI is absent. |
| `/flow eval --report` | Offline, zero calls: the last complete batch's scorecard plus drift against the previous batch. |

## See also

- [Install CLI](/docs/reference/install-cli)
- [Drift commands](/docs/reference/drift-commands)
- [Harness subcommands](/docs/reference/harness-subcommands)
- Full source: [`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md)
