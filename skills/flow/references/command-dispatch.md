# Command dispatch

Exact mapping: user input -> runner call -> your (Claude) duties. Always run the runner
first, relay its output faithfully, then do the semantic part. `<skill>` = this skill's
install dir; run from the project root so `flow/` and `cards/` resolve.

| User input | Runner call | Your duties after |
|---|---|---|
| `/flow` | `bash <skill>/runner/flow.sh status` | Summarize where they are + the single next action. Nothing to author. |
| `/flow next` | `bash <skill>/runner/flow.sh next` | If FAIL: relay the exact violations + line numbers; offer help, don't author/tick in teach mode. If PASS: run the stage's challenge in `gate-rules.md`; flag hollow content, let operator decide. |
| `/flow card` | `bash <skill>/runner/flow.sh card` | Confirm the new card id; remind: fill Scope (one thing) / Allowed files / Verify / Done-evidence per `law/CLAUDE.md`. |
| `/flow check C-NNN` | `bash <skill>/runner/flow.sh check C-NNN` | If PASS mechanically: review diff-vs-scope, allowed-files drift, contract-shape match, DESIGN.md for UI, evidence = real world-state. |
| `/flow mode teach` | `bash <skill>/runner/flow.sh mode teach` | Confirm; you only gatekeep, operator authors. |
| `/flow mode work` | `bash <skill>/runner/flow.sh mode work` | Interview once, draft 00-05, pause for scope sign-off, deliver card set; still pass every gate. |
| `/flow ready` | `bash <skill>/runner/flow.sh ready` | Relay buildable cards; confirm allowed-files truly don't overlap before suggesting parallel. Operator dispatches. |
| `/flow auto` | `bash <skill>/runner/flow.sh auto` | On preflight PASS, drive the autonomous run per SKILL.md AUTO principles (subagent/card, planner review, worktree, Tier-C halt on security debt). |
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

## Install-path note
- Project install: `bash .claude/skills/flow/runner/flow.sh <cmd>`
- Global install: `bash ~/.claude/skills/flow/runner/flow.sh <cmd>`
- Override project root: `FLOW_PROJECT_ROOT=/path bash <skill>/runner/flow.sh <cmd>`
