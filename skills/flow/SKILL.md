---
name: flow
description: Run the buildflow gated build process from idea to real done-evidence. Walk gated stages (Idea->Research->Scope->PRD->ADR->Contract->Cards->Build->Review->Deploy/Ship->Verify->Retro), each with a honest gate that must pass before advancing. Adapts to project type (web|cli|library|skill). Use when starting or driving a real product build, when the user types /flow, /flow next, /flow card, /flow check, or asks to scope/plan/ship a project through gates. Kill at any gate is a valid outcome.
user-invocable: true
when_to_use: "User wants to build a real product end-to-end with discipline (idea -> a deployed URL for web, or installs+runs for a CLI/library/skill), or types any /flow command, or asks for a gated build process, scope decision, contract-first plan, or card-based shipping."
argument-hint: "[ resume | next | card | check C-NNN | project-type web|cli|library|skill | mode teach|work | skip <stage> | ready | workspace add|list|enter|remove|check|doctor | auto [stop] | attest semantic|live-verify|status|recover | doctor | retro | eval | clarify | converge | or just say what you want in plain language ]"
keywords: [flow, buildflow, gate, build, ship, scope, prd, contract, card, deploy, vertical-slice, cli, library, skill, worktree, parallel-agents, workspace, multi-agent]
license: MIT
metadata:
  author: flow-skill
  version: "0.31.0"
  attribution: "Methodology from ai20k-build-phase/buildflow (Tony, arealisticdreamer.com); durable-layer ancestry and improve-ritual spirit from repository-harness (protocol v1 EOL — flow-owned fork); agent patterns from claudekit-engineer, BMAD-METHOD. v0.22 concierge from BMAD bmad-help; forge-idea from bmad-forge-idea (MIT, BMad Code LLC)."
---

# /flow — buildflow gated build harness

Idea to **world-state done-evidence** (deployed URL for web; install+run for cli/library/skill), not paperwork. Each stage has an artifact and a **GATE**.
**Kill at any gate is a valid, honored outcome.**

```
Idea -> Research -> Scope -> PRD -> ADR -> Contract -> Cards -> Build -> Review -> Deploy -> Verify-live -> Retro
|------------------ planning (files in flow/) ------------------|  |------- shipping (inside cards/) -------|
```

## Two-layer harness

`/flow` is two layers. Both must agree; the script can pass hollow content.

1. **Mechanical — `runner/flow.sh`** (deterministic, exit 0/1). Stage/card lifecycle plus
   cheatable checks: unchecked boxes (including leftover `- [ ]` under `## Open decisions`),
   `[FILL]`, card status, empty done-evidence, plus content scanners on 01/02/03/05
   (typed-web entry floor, L-above-A, PRD adjectives, OD cap). Always run it first — its
   exit code is ground truth, never host judgment. Open-decision leftover boxes are the
   same scanner; `clarify` only prints them — not a second gate.
2. **Semantic — this skill.** The script cannot tell a real competitor quote from a
   fabricated one, or a grade-laundered C feature from an honest B. After mechanical
   PASS, apply `references/gate-rules.md` before letting the operator advance.

## PTC_ONLY

This file is always-on. Load **one** extra reference for the verb in play (load table)
plus that verb's row in `references/command-dispatch.md`. Do not load the rest until
needed. Typed verbs always win over chat.

## STOP

- Runner reports **BLOCKED by another session's lock** → STOP. Never `FLOW_FORCE` a live
  session; concurrent runs corrupt the plan. Set `FLOW_SESSION_ID` per session.
- Mechanical **FAIL** → STOP. Relay exact line numbers. In `teach`, never tick a box or
  write an artifact on the operator's behalf.
- Security-class skip/debt → **HALT** until the operator accepts the exposure in `DEBT.md`.
- Never mark a card `done` without pasted world-state evidence.
- Never edit `_templates/` or `runner/flow.sh` during a project run.

## Run `flow.sh` first

From the **project root** (where `flow/` and `cards/` live):

```
# macOS / Linux / Windows Git Bash:
bash <skill-dir>/runner/flow.sh <command>

# Windows PowerShell or cmd (INCLUDING inside Codex): use the .cmd launcher, NOT bare bash.
<skill-dir>\runner\flow.cmd <command>
```

Bare `bash` on Windows/Codex is usually WSL and cannot read `C:/` paths. Always
`runner/flow.cmd` from a Windows shell; it locates Git Bash. Call `flow.sh` directly
only when `bash` is Git Bash.

`<skill-dir>` is the install home (`~/.claude/skills/flow`, `~/.codex/skills/flow`,
`~/.agents/skills/flow`, Antigravity `~/.gemini/antigravity-cli/skills/flow` (CLI) /
`~/.gemini/config/skills/flow` (IDE), or project `.claude/skills/flow`). Override with
`FLOW_PROJECT_ROOT`. Antigravity (`agy` CLI / IDE): same `SKILL.md` bundle; run
`agy inspect` to confirm it loaded.

**One session per project.** `flow/.lock` auto-reclaims after `FLOW_LOCK_TTL` (default
900s). Mutating commands refuse a fresh foreign lock. Export a stable `FLOW_SESSION_ID`.
`FLOW_FORCE=1` only for a lock known dead; `unlock` clears it.

## Three laws (`law/CLAUDE.md`)

1. **Inspect first.** Competitors, live systems, code. Evidence, not vibes.
2. **Contract is the seam.** Stage 05 before any code. Backend builds TO it, UI consumes
   FROM it. Amend the contract, then code. Honor a shape now (null/stub) even when the
   value ships later.
3. **Done = proof in the world.** Name done-evidence up front. Verify on the live URL as
   a user. "Tests pass" / "code merged" are mid-pipeline, never done.

## Load table

| In play | Load |
|---|---|
| typed verb | `references/command-dispatch.md` (that row only) |
| plain language | `references/concierge.md`, `references/flow-catalog.tsv` |
| next PASS / check semantic | `references/gate-rules.md` |
| card / build session | `law/CLAUDE.md` |
| UI | `law/DESIGN.md` |
| auto | `references/auto-run.md` |
| attest / receipts | `references/attestations.md` |
| mode work | `references/mode-work.md` |
| eval | `references/gate-eval.md` |
| Idea/Scope ritual | `references/forge-idea.md` |
| engines | `references/codex-integration.md`, `references/antigravity-integration.md`, `references/claudekit-skills.md` |
| parallel occupancy | `references/host-agnostic-parallel.md` |
| agents | `references/agent-detection.md`, `references/agent-stage-mapping.md` |
| skip / halt | `references/debt-and-halts.md` |
| harness | `harness/README.md` |
| retro | `law/RETRO.md` |

## Dispatch rules

1. **Entering a project mid-cycle?** Fresh session and existing `flow/` or `cards/` → run
   resume first (read-only session-story: last session, in-flight + dwell, gate state,
   one `NEXT ->` line). Skip only with live context this session.
2. **Always call `flow.sh` first** and relay exit + output. Lock BLOCKED → STOP.
3. **On next:** FAIL → stop, offer help, never author/tick in teach. PASS → semantic
   challenge in `gate-rules.md`. Do not silently advance hollow content; do not silently
   block a sound artifact.
4. **On card/check:** `law/CLAUDE.md` — one card per session, only `## Allowed files`,
   contract is the seam, done = world-state proof. Run recall first; apply its output.
5. **Mode `work`:** interview once, draft 00–05, pause only for scope sign-off, same
   gates as teach.
6. **Never** edit `_templates/` or `runner/flow.sh` during a project run. Read any file
   the runner just created before editing it.

## Seams (one-line pointers)

- Verb map: `references/command-dispatch.md` (no Commands table in this file).
- Chat front door: `references/concierge.md` + `references/flow-catalog.tsv`.
- Idea/Scope persona ritual: `references/forge-idea.md` (adapted from BMAD-METHOD,
  `bmad-forge-idea`, MIT, opt-in, never a gate condition).
- Codex second engine: `references/codex-integration.md`.
- Antigravity Gemini-3 **third engine**: `references/antigravity-integration.md`
  (confirm load with `agy inspect`).
- ck-skill layer: `references/claudekit-skills.md`.
- Parallel occupancy: `references/host-agnostic-parallel.md`.
- Receipts: `references/attestations.md`.
- `harness/` is **flow-owned**. Improve via **R-IMPROVE-HARNESS** in
  `references/native-rituals.md`. Never `story update --status implemented` — use
  `story complete --proof-source`.

## Forbidden

- Checking a gate box or writing a planning artifact on the operator's behalf (teach).
- Setting a card `done` without pasted world-state evidence.
- Building two cards in one session, or in parallel before `ready` marks them safe.
- Frontend code before the UI mock card is approved.
- Editing `_templates/` or `runner/flow.sh` during a project run.
