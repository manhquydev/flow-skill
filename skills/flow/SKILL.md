---
name: flow
description: Run the buildflow gated build process from idea to real done-evidence. Walk gated stages (Idea->Research->Scope->PRD->ADR->Contract->Cards->Build->Review->Deploy/Ship->Verify->Retro), each with a honest gate that must pass before advancing. Adapts to project type (web|cli|library|skill). Use when starting or driving a real product build, when the user types /flow, /flow next, /flow card, /flow check, or asks to scope/plan/ship a project through gates. Kill at any gate is a valid outcome.
user-invocable: true
when_to_use: "User wants to build a real product end-to-end with discipline (idea -> a deployed URL for web, or installs+runs for a CLI/library/skill), or types any /flow command, or asks for a gated build process, scope decision, contract-first plan, or card-based shipping."
argument-hint: "[ next | card | check C-NNN | project-type web|cli|library|skill | mode teach|work | skip <stage> | ready | workspace add|list|enter|remove|check|doctor | auto | doctor | retro ]"
keywords: [flow, buildflow, gate, build, ship, scope, prd, contract, card, deploy, vertical-slice, cli, library, skill, worktree, parallel-agents, workspace, multi-agent]
license: MIT
metadata:
  author: flow-skill
  version: "0.13.1"
  attribution: "Methodology from ai20k-build-phase/buildflow (Tony, arealisticdreamer.com); harness/agent layers from repository-harness, claudekit-engineer, BMAD-METHOD."
---

# /flow — buildflow gated build harness

Idea to a **deployed URL**, not idea to paperwork. You walk gated stages; each has an
**output artifact** and a **GATE** — a checklist that must be honestly satisfied before
you advance. **Kill at any gate is a valid, honored outcome** (killing a weak idea at
Scope is cheap and smart).

```
Idea -> Research -> Scope -> PRD -> ADR -> Contract -> Cards -> Build -> Review -> Deploy -> Verify-live -> Retro
|------------------ planning (files in flow/) ------------------|  |------- shipping (inside cards/) -------|
```

## Two-layer harness (this is the core idea)

`/flow` is **two layers working together**:

1. **Mechanical layer — `runner/flow.sh`** (deterministic, exit 0/1). It manages the
   stage/card lifecycle and checks the *cheatable* things: unchecked gate boxes,
   leftover `[FILL]` placeholders, card status validity, empty done-evidence. Always run
   it first — its exit code is ground truth, never your own judgment.
2. **Semantic layer — YOU (Claude), via this skill** (quality gatekeeper). The script
   cannot tell a real competitor quote from a fabricated one, or a grade-laundered C
   feature from an honest B. **That is your job.** After the script passes, apply the
   per-stage challenges in `references/gate-rules.md` before you let the operator advance.

A gate is only truly passed when **both** layers agree. The script can pass while the
content is hollow — catch that.

## Running the mechanical layer

From the **project root** (where `flow/` and `cards/` live), run the runner that ships
with this skill:

```
# macOS / Linux / Windows Git Bash:
bash <skill-dir>/runner/flow.sh <command>          # e.g. bash ~/.claude/skills/flow/runner/flow.sh next

# Windows PowerShell or cmd (INCLUDING inside Codex): use the .cmd launcher, NOT bare `bash`.
<skill-dir>\runner\flow.cmd <command>              # e.g. ...\.codex\skills\flow\runner\flow.cmd status
# from PowerShell call it directly:  & "<skill-dir>\runner\flow.cmd" status
```

**Windows / Codex gotcha (read this):** in PowerShell/Codex a bare `bash` usually resolves to
**WSL** (`C:\WINDOWS\system32\bash.exe`), which **cannot** read `C:/...` or `/c/...` paths and
fails with `No such file or directory` — the mechanical layer then looks "broken" when it is not.
**Always invoke `runner/flow.cmd`** on Windows; it locates Git Bash and runs the engine with a
path Git Bash accepts. Only call `bash flow.sh` directly when you've confirmed `bash` is Git Bash.

`<skill-dir>` is wherever this skill is installed (`~/.claude/skills/flow`, `~/.codex/skills/flow`,
`~/.agents/skills/flow`, the Antigravity homes `~/.gemini/antigravity-cli/skills/flow` (CLI) /
`~/.gemini/config/skills/flow` (IDE), or a project `.claude/skills/flow`). The runner reads/writes
`flow/` and `cards/` under the current directory (override with `FLOW_PROJECT_ROOT`).

**Antigravity (`agy` CLI / IDE):** flow installs as the same `SKILL.md` bundle; run `agy inspect` to
confirm Antigravity discovered it. The mechanical layer is the **same** `bash flow.sh` / `flow.cmd`
runner — the Windows WSL-bash trap below applies identically (use `flow.cmd` from a Windows shell).
The Antigravity agent invokes shell tools, so it drives `flow.sh` like any other harness.

**One session per project (concurrency lock).** Two `/flow` sessions sharing one project
will stomp each other's plan. The runner keeps a `flow/.lock` (auto-reclaimed after
`FLOW_LOCK_TTL`, default 900s): mutating commands (`next`/`card`/`skip`/`auto`) refuse a
fresh **foreign** lock and `status` warns. For hard protection, **export a stable
`FLOW_SESSION_ID` once per session** and pass it on every call (e.g.
`FLOW_SESSION_ID=$mysid bash <skill-dir>/runner/flow.sh next`) — without it the runner can
only warn (it can't prove a different session, so it never self-blocks). `FLOW_FORCE=1`
takes over a lock you're sure is dead; `/flow unlock` clears it.

## Commands

| You type | Skill does |
|---|---|
| `/flow` | `flow.sh status` — where am I, what's blocking, card states |
| `/flow next` | `flow.sh next` — gate-check current stage; on pass, unlock next stage. **Then** you apply the semantic challenge for the stage just passed. |
| `/flow assess` | `flow.sh assess` — **brownfield**: scaffold + gate a current-state assessment (`flow/00-inspect.md`, auto-scan seeded) for an EXISTING codebase before planning. Operator-reviewed. |
| `/flow card` | `flow.sh card` — create next build card (only after all 6 planning gates pass) |
| `/flow check C-NNN` | `flow.sh check C-NNN` — validate a card; **then** you review diff-vs-scope, allowed-files drift, contract shapes, DESIGN.md for UI, and that evidence is real world-state |
| `/flow mode teach\|work` | set who writes the artifacts (default `teach`) |
| `/flow ready` | `flow.sh ready` — which todo cards are buildable + parallel-safety hint |
| `/flow workspace add\|list\|enter\|remove\|check\|doctor` | `flow.sh workspace …` — **multi-agent worktree isolation** for running several agents (Claude/Codex/Antigravity, many terminals) in parallel WITHOUT the "one agent switches branch → every terminal flips" trap. Each agent gets its own `git worktree` (own HEAD/index/files, shared object store); git is the live registry (`git worktree list`) and a 10-field JSONL side-file (`.flow/workspaces.jsonl`) adds vendor/card/port/task. `add <branch> [--card C-NNN] [--vendor …] [--task …] [--copy-env]` provisions a worktree + distinct port-offset + paste-ready cd/env block; `list` shows who-is-where; `enter <branch>` re-prints a crashed terminal's env; `check <branch> [--card]` flags branch-claim + allowed-files overlap before you launch; `remove <branch> [--force]` tears down safely (never auto-forces); `doctor` reconciles orphan trees/records. Advisory layer; git's refusal to check out one branch twice is the real lock. |
| `/flow auto` | `flow.sh auto` preflight, then drive the autonomous run (see AUTO principles) |
| `/flow recall` | `flow.sh recall` — read back durable memory (open debt, recent retro, previous-card scope, harness friction/backlog, playbooks) **at the start of a stage/card** so you don't re-learn known pain |
| `/flow usage` | `flow.sh usage` — roll up the mechanical usage log (JSONL flight-recorder of every invocation) into `usage_event` and print build analytics: cycle-time, gate fail-rate, per-stage dwell, cycle completion, command breakdown. `--global` for the device-wide view; `--prune [--keep N]` caps the log (crash-safe). Local-only; disable with `FLOW_LOG_DISABLE=1`/`DO_NOT_TRACK=1`. `recall` now surfaces a one-line usage digest and `retro`'s `propose` flags chronically-failing stages. |
| `/flow contract` | `flow.sh contract` — flag client base-URL vs served-path prefix drift (web; advisory; run after the contract gate) |
| `/flow tokens` | `flow.sh tokens` — flag DESIGN.md vs CSS design-token drift: unused tokens + value mismatches + orphan vars (advisory; UI cards) |
| `/flow coherence` | `flow.sh coherence` — flag version drift across declared version fields (doc-vs-code coherence; advisory) |
| `/flow consistency` | `flow.sh consistency` — audit cross-artifact coverage: every PRD `FRn` is claimed by a card (`implements:`) and served by a contract interface; numeric success metric; no leftover placeholders (advisory; run after the contract gate, before cards) |
| `/flow constitution` | `flow.sh constitution` — check operator-authored per-project invariants in `flow/constitution.md` (structure + optional grep-markers); **advisory and NOT a `next` gate** — run it at the scope/PRD/contract seam, then apply the semantic challenge in `gate-rules.md` |
| `/flow promote <file>` | `flow.sh promote <file>` — copy a playbook into the cross-project KB (`~/.claude/flow/playbooks`); `recall` then surfaces it everywhere |
| `/flow project-type <web\|cli\|library\|skill>` | `flow.sh project-type` — set/read the project type that selects the per-type gate lens (`references/project-types.md`) |
| `/flow skip <stage>` | `flow.sh skip` — advance past a gate that has a matching open `DEBT.md` line; **security-class skips are operator-only and HALT** (never auto-skipped) |
| `/flow doctor` | `flow.sh doctor` — environment/install self-check (paths, runner, Git Bash) |
| `/flow harness … \| debt … \| design` | runner subsystems: `harness` (durable intake/story/trace/decision/backlog — see `harness/README.md`), `debt` (record/list deliberate gate-skips), `design` (mechanical UI-token check) |
| `/flow unlock` | `flow.sh unlock` — clear this project's concurrency lock after a crashed/abandoned session |
| `/flow retro` | the 3 retro questions; the operator writes the line, never you |

## Dispatch rules (how to behave for each command)

1. **Always call `flow.sh` first** and read its exit code + output. Relay it faithfully. If it
   reports **BLOCKED by another session's lock**, STOP and coordinate — never `FLOW_FORCE` past a
   live session; concurrent `/flow` runs corrupt the plan.
2. **On `next`:** if the script FAILS, stop — report exactly what it listed (line numbers),
   and offer to help fill, but **never check a box or write an artifact on the operator's
   behalf** in `teach` mode. If the script PASSES, run the **semantic gate** for the stage
   just completed (see `references/gate-rules.md`). If you find hollow content (fabricated
   quotes, grade-laundering, a pain with no feature, an endpoint with no auth), tell the
   operator it mechanically passed but is qualitatively weak, and let them decide. Do not
   silently advance past a hollow artifact; do not silently block a sound one.
3. **On `card`/`check`:** enforce the build-session laws in `law/CLAUDE.md` — one card per
   session, touch only `## Allowed files`, contract is the seam, done = world-state proof.
   **Before authoring a new stage or card, run `/flow recall`** and treat its output (prior
   debt / retro / friction / previous-card scope) as context to apply, not noise.
4. **Mode `work`:** interview the operator once, draft stages 00–05 yourself, pause only
   for scope sign-off, deliver the card set as one summary. Gates and done-rules are
   identical to `teach` — you still must pass every gate, you just also author.
5. **Never** edit `_templates/` or `runner/flow.sh` during a project run. Read any file the
   runner just created before editing it.

## The three rules under everything (from law/CLAUDE.md)

1. **Inspect first.** Before planning, look at what already exists (competitors, live
   systems, code). Evidence, not vibes.
2. **Contract is the seam.** The API contract (stage 05) is written before any code.
   Backend builds TO it, UI consumes FROM it. Never improvise a shape; amend the contract
   first, then code. Honor a shape now (null/stub) even when its value ships in a later card.
3. **Done = proof in the world.** Every card names its done-evidence up front. Verify on
   the live URL as a user. "Tests pass" / "code merged" are mid-pipeline, never done.

## Agent orchestration

Each stage can delegate to a specialist agent, and degrades to built-in behavior when none
exist — `/flow` stays portable. Priority: **ck: agents first, bmad-* skills as alternative,
built-in fallback** (`references/agent-detection.md`). When the `openai-codex` plugin is present
**and usable**, a cross-vendor **Codex (GPT-5.x) second engine** unlocks — used at three gated
moments: two-strikes rescue, cross-model adversarial review (a different *model*, not just a
different context), and opt-in primary drafter at research/build (default stays ck:). It detects
and degrades like every other tier (installed≠usable; absence never breaks a run). Full seam,
cost gate, and shapes: **`references/codex-integration.md`**. When `agy`/the Antigravity IDE is
present **and usable**, a cross-vendor **Antigravity (Gemini-3) third engine** unlocks too — same
high-value moments, giving a **three-model** adversarial gate. Antigravity needs the strictest
usability check (`agy -p` returns exit 0 + empty stdout even when unauthenticated, so route only on
non-empty expected output, never exit code; headless capture is unreliable → interactive review is
the supported default). Full seam: **`references/antigravity-integration.md`**. The stage→agent map, scoped prompt
template, and durable-record hooks are in `references/agent-stage-mapping.md`:
research→`researcher`, scope/PRD→`planner`, ADR→`architect`, contract→`bmad-spec` kernel,
build→`fullstack-developer`, review→`code-reviewer` or `bmad-code-review` (3-layer
adversarial), verify-live→`tester`. **The gate is identical on every path** — an agent
drafts, the gate still judges. Give each subagent ONLY task + files + acceptance + relevant
law/contract excerpts (no session history); each returns DONE/DONE_WITH_CONCERNS/BLOCKED/
NEEDS_CONTEXT. After a delegation: run the gate, apply the semantic challenge, write the
durable hook (`flow.sh harness ...`), announce which path ran.

Mode `work` (`references/mode-work.md`): interview once → draft 00-05 → one scope pause →
deliver the card set as one summary. Gates bind the same as `teach`.

## AUTO principles

`/flow auto` drives the build phase autonomously (`references/auto-run.md`). Operator
setting: **Tier-A auto-merge green cards; halt at security-class.** Per card: tier-classify
→ one scoped subagent in its own worktree → build to contract → adversarial review →
`flow.sh check` PASS → merge in card order → deploy → **verify on the LIVE URL** (merge ≠
shipped) → world-state evidence → `status: done` → durable trace + `AUTO-LOG.md`.
- **Tier A**: green + no security-class → auto-merge, no ask.
- **Tier B**: fixable issues → one repair by a FRESH subagent (two-strikes), else escalate.
- **Tier C**: security-class (auth, authorization, admin exposure, tenancy, payments, data
  migration, removing validation) → **HALT.** Operator accepts the exposure in `DEBT.md`,
  in writing. Never planner-decided.
Hard stops (iteration/token/time caps) and ground-truth gates (`flow.sh` exit, real
`## Verify` runs, live check — never an agent's self-assessment) are mandatory.

## Law & reference files

- `law/CLAUDE.md` — build-session discipline, card sequence, PR/merge, debt, worktree, forbidden. **Read before building any card.**
- `law/DESIGN.md` — UI law for every mock/frontend card (tokens, affordance ladder, object-first, never-do list).
- `law/RETRO.md` — one honest line per run.
- `references/gate-rules.md` — the per-stage semantic challenges (the heart of your gatekeeping).
- `references/stage-state-machine.md` — stage order, unlock conditions, what each artifact must contain.
- `references/project-types.md` — per-type (web|cli|library|skill) adaptations of the stages, gate lenses, and done-evidence.
- `references/command-dispatch.md` — exact mapping of each `/flow` command to runner call + your duties.
- `references/agent-detection.md` — detect ck:/bmad agents + priority + fallback.
- `references/agent-stage-mapping.md` — stage→agent map, scoped prompt template, durable hooks.
- `references/codex-integration.md` — the Codex cross-vendor second-engine seam: detection (installed≠usable), cost gate, invocation surfaces, ReviewResult shape, gate parity.
- `references/antigravity-integration.md` — the Antigravity (Gemini-3) cross-vendor third-engine seam: install homes, strict usability (exit code lies → route on non-empty output), interactive-default review, cost/data gate, gate parity.
- `references/gate-rules.md` → "Cross-artifact consistency" — the semantic passes behind `/flow consistency` (hollow coverage, conflicting requirements, cut-list contradiction, terminology drift) that the runner's ID-based check can't judge.
- `references/mode-work.md` — work-mode script (interview once → draft → one scope pause → summary).
- `references/auto-run.md` — `/flow auto` tiers, worktree loop, AUTO-LOG, security-class halt.
- `references/loop-harness-2026-principles.md` — harness-first, hard stops, ground-truth, context isolation.
- `references/ground-truth-gates.md` — the mechanical signal each gate decides on (never self-assessment).
- `references/adversarial-review.md` — the 3-layer "must find issues" Review gate + triage.
- `references/debt-and-halts.md` — `DEBT.md` ledger, security-class Tier-C halt, when a run halts.
- `references/design-review-checklist.md` — UI card review (mechanical `flow.sh design` + semantic DESIGN.md).
- `references/ui-patterns-tcr.md` — 7 UI patterns + T-C-R frame + pattern-choice priority rules.
- `harness/` — durable layer (`flow.sh harness ...`): intake/story/trace/decision/backlog. See `harness/README.md`. Read it back with `/flow recall` (open debt, retro, previous-card, friction, backlog, playbooks) — this is the capture→reuse loop.
- `playbooks/` — paid-for stack knowledge: read before building a card on that stack, harvest the lesson after.
- `_templates/` — the 7 artifacts the runner copies into `flow/` and `cards/`. Never edit during a run.

## Forbidden

- Checking a gate box or writing a planning artifact on the operator's behalf (in `teach` mode).
- Setting a card `done` without pasted world-state evidence.
- Building two cards in one session, or in parallel before `/flow ready` marks them safe.
- Frontend code before the UI mock card is approved.
- Editing `_templates/` or `runner/flow.sh` during a project run.
