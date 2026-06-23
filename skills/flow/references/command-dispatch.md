# Command dispatch

Exact mapping: user input -> runner call -> your (Claude) duties. Always run the runner
first, relay its output faithfully, then do the semantic part. `<skill>` = this skill's
install dir; run from the project root so `flow/` and `cards/` resolve.

| User input | Runner call | Your duties after |
|---|---|---|
| `/flow` | `bash <skill>/runner/flow.sh status` | Summarize where they are + the single next action. Nothing to author. |
| `/flow next` | `bash <skill>/runner/flow.sh next` | If FAIL: relay the exact violations + line numbers; offer help, don't author/tick in teach mode. If PASS: run the stage's challenge in `gate-rules.md`; flag hollow content, let operator decide. |
| `/flow assess` | `bash <skill>/runner/flow.sh assess` | Brownfield only: fill `flow/00-inspect.md` from EVIDENCE (read the code) — functionality/UI/UX vs product, risks, test baseline. Reuse `scout`/`researcher`. Gate is operator-reviewed; then proceed to `/flow next`. |
| `/flow card` | `bash <skill>/runner/flow.sh card` | Confirm the new card id; remind: fill Scope (one thing) / Allowed files / Verify / Done-evidence per `law/CLAUDE.md`. |
| `/flow card start C-NNN` | `bash <skill>/runner/flow.sh card start C-NNN` | Optional: mark the card in flight (operator-visible in-progress, shown in `/flow status`). Portable `cards/.inflight` registry; does NOT touch the gated `status:` field. Coexists with hand-edit. |
| `/flow card done C-NNN` | `bash <skill>/runner/flow.sh card done C-NNN` | Optional convenience: CLI-owned flip to `done`, gated by the SAME done-rules as `check` (reverts on fail — never a hollow done). Then still apply the semantic card review (diff-vs-scope, contract shapes, real evidence) as with `check`. |
| `/flow check C-NNN` | `bash <skill>/runner/flow.sh check C-NNN` | If PASS mechanically: review diff-vs-scope, allowed-files drift, contract-shape match, DESIGN.md for UI, evidence = real world-state. |
| `/flow contract` | `bash <skill>/runner/flow.sh contract` | After the contract gate / before UI cards (web): flags client base-URL vs served-path prefix drift (double-`/api`, mixed-prefix) — the class spec-diff tools miss. Advisory; confirm on the running app. |
| `/flow tokens` | `bash <skill>/runner/flow.sh tokens` | On/after UI cards: flags DESIGN.md tokens the CSS never uses + VALUE mismatches (same name, drifted value) + orphan CSS vars (info). Advisory; if the swap is intentional, record a dated DESIGN.md amendment. |
| `/flow coherence` | `bash <skill>/runner/flow.sh coherence` | Flags version drift across declared version fields (package.json / pyproject / src app_version). The cheap doc-vs-code slice; semantic contradictions stay a human gate-challenge. |
| `/flow consistency` | `bash <skill>/runner/flow.sh consistency` | After the contract gate, before cards: every PRD `FRn` is claimed by a card (`implements:`) and served by a contract interface; numeric success metric; no leftover placeholders. Then apply the semantic cross-artifact passes in `gate-rules.md` (hollow coverage, conflicting requirements, terminology drift). Advisory. |
| `/flow constitution` | `bash <skill>/runner/flow.sh constitution` | At the scope/PRD/contract seam: checks `flow/constitution.md` is well-formed (no placeholder, every invariant has an ID) + scans declared grep-markers. **Advisory, NOT a `next` gate** — then apply the semantic challenge in `gate-rules.md`. |
| `/flow project-type <web\|cli\|library\|skill>` | `bash <skill>/runner/flow.sh project-type [t]` | Set/read the project type that selects the per-type gate lens + done-evidence definition (`references/project-types.md`). Confirm the type matches reality before planning. |
| `/flow usage [--global\|--prune]` | `bash <skill>/runner/flow.sh usage [...]` | Roll up the JSONL usage log and relay the analytics (cycle-time, gate fail-rate, per-stage + per-card dwell, command breakdown). Local-only; `--prune [--keep N]` caps the log. Read-only — nothing to author. |
| `/flow skip <stage> --reason ...` | `bash <skill>/runner/flow.sh skip <stage> --reason ...` | Advance past a gate that has a matching open `DEBT.md` line. **Security-class skips are operator-only and HALT** — never auto-skip; the operator accepts the exposure in writing first. |
| `/flow debt add\|list` | `bash <skill>/runner/flow.sh debt add\|list` | Record/list deliberate gate-skips in `DEBT.md`. Security-class debt is operator-authored only; surface it at retro and before any real user touches the surface. |
| `/flow design <file>` | `bash <skill>/runner/flow.sh design <file>` | Mechanical DESIGN.md check on a UI file (emoji / `{{}}` / engine-words / gradient). Advisory; pair with the semantic `design-review-checklist.md` for mock/frontend cards. |
| `/flow harness <args>` | `bash <skill>/runner/flow.sh harness <args>` | Passthrough to the durable-layer CLI (intake/story/trace/decision/backlog/query). Visible output + real exit code. Use to write the durable hook after a stage/card; read it back with `recall`. |
| `/flow doctor` | `bash <skill>/runner/flow.sh doctor` | Environment/install self-check (bash/python/grep/git across macOS/Linux/Windows, runner path, Git Bash). Relay any FAIL as the fix list. Read-only. |
| `/flow promote <file>` | `bash <skill>/runner/flow.sh promote <file>` | Copy a hard-won playbook into the cross-project KB (`~/.claude/flow/playbooks`) so its lesson is surfaced by `recall` in every project, not just this one. |
| `/flow mode teach` | `bash <skill>/runner/flow.sh mode teach` | Confirm; you only gatekeep, operator authors. |
| `/flow mode work` | `bash <skill>/runner/flow.sh mode work` | Interview once, draft 00-05, pause for scope sign-off, deliver card set; still pass every gate. |
| `/flow ready` | `bash <skill>/runner/flow.sh ready` | Relay buildable cards; confirm allowed-files truly don't overlap before suggesting parallel. Operator dispatches. |
| `/flow workspace <verb>` | `bash <skill>/runner/flow.sh workspace add\|list\|enter\|remove\|check\|doctor [...]` | Multi-agent worktree isolation (human-driven, cross-vendor). Relay the runner output faithfully: on `add`, hand the operator the printed cd/env block (one worktree per agent — Claude `--worktree`/`-w`, Codex CLI manual + `CODEX_HOME`, Antigravity = open the dir as a workspace); on `check`/`doctor` exit 1, surface the collision/drift, don't auto-`--force` a `remove`. git is the source of truth; the `.flow/workspaces.jsonl` side-file only adds vendor/card/port/task. Advisory — not a `next` gate. |
| `/flow auto` | `bash <skill>/runner/flow.sh auto` | On preflight PASS, drive the autonomous run per SKILL.md AUTO principles (subagent/card, planner review, worktree, Tier-C halt on security debt). |
| `/flow recall` | `bash <skill>/runner/flow.sh recall` | Read back prior knowledge (open debt, recent retro, previous-card scope, harness friction/backlog, playbooks). Run at the START of a stage/card; apply it, don't re-learn known pain. |
| `/flow unlock` | `bash <skill>/runner/flow.sh unlock` | Clear this project's concurrency lock after a crashed/abandoned session. Confirm the other session is really gone first. |
| `/flow retro` | `bash <skill>/runner/flow.sh retro` | Ask the 3 questions; the operator writes the RETRO.md line — never you. |

## Behavioral invariants (all commands)
1. The runner's exit code is ground truth. Don't override it with optimism.
2. In `teach` mode never tick a box or write an artifact for the operator.
3. Never set a card `done` without pasted world-state evidence.
4. Read any file the runner just created before editing it.
5. Never edit `_templates/` or `runner/flow.sh` during a project run.
6. Relay failures verbatim (line numbers included) — they are the operator's to-do list.
7. If the runner reports BLOCKED by another session's lock, STOP and coordinate — never `FLOW_FORCE` past a live session; concurrent runs corrupt the plan. Set `FLOW_SESSION_ID` per session for hard protection.
8. At the start of a stage or build card, run `/flow recall` first — its output (prior debt / retro / friction / previous-card scope) is context to apply, not noise. `status` shows a one-line memory summary; `card` injects the previous card's scope automatically.

## Install-path note
- Project install: `bash .claude/skills/flow/runner/flow.sh <cmd>`
- Global install: `bash ~/.claude/skills/flow/runner/flow.sh <cmd>`
- Override project root: `FLOW_PROJECT_ROOT=/path bash <skill>/runner/flow.sh <cmd>`
