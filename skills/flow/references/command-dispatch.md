# Command dispatch

Exact mapping: user input -> runner call -> host duties. Always run the runner
first, relay its output faithfully, then do the semantic part. `<skill>` = this skill's
install dir; run from the project root so `flow/` and `cards/` resolve.

Seekable: `#verb-next`, `#verb-card` (humans). This file is still loaded whole — there
is no fragment loader (ADR-0001).

| User input | Runner call | Host duties after |
|---|---|---|
| `/flow` | `bash <skill>/runner/flow.sh status` | Relay `NEXT ->`, dwell, and (past 10 cards) the compact summary; nothing to author. |
| `/flow resume` | `bash <skill>/runner/flow.sh resume` | Read-only session-story; no lock. FAIL/PASS/Never: SKILL.md STOP + Dispatch. |
| `/flow next` | `bash <skill>/runner/flow.sh next` | After PASS, compare to `gate-examples.md` (not a second always-on load). FAIL/Never: SKILL.md STOP + Dispatch. |
| `/flow assess` | `bash <skill>/runner/flow.sh assess` | Fill `flow/00-inspect.md` from EVIDENCE; Brownfield challenge in `gate-rules.md`. |
| `/flow card` | `bash <skill>/runner/flow.sh card` | Fill per `law/CLAUDE.md`; before coding, `law/CODING.md`. |
| `/flow card start C-NNN` | `bash <skill>/runner/flow.sh card start C-NNN` | Optional in-flight mark (`cards/.inflight`); does not touch gated `status:`. |
| `/flow card done C-NNN` | `bash <skill>/runner/flow.sh card done C-NNN` | CLI `done` under the same rules as `check`; then semantic review. |
| `/flow check C-NNN` | `bash <skill>/runner/flow.sh check C-NNN` | After PASS, semantic card review (`law/CLAUDE.md`). FAIL/Never: SKILL.md STOP + Dispatch. |
| `/flow gate <stage>` (or `--card C-NNN`) | `bash <skill>/runner/flow.sh gate <stage\|--card C-NNN>` | Read-only mechanical scan; relay findings. `next`/`check` own progression. |
| `/flow contract` | `bash <skill>/runner/flow.sh contract` | Advisory client base-URL vs served-path drift; confirm on the running app. |
| `/flow tokens` | `bash <skill>/runner/flow.sh tokens` | Advisory DESIGN.md token unused/mismatch; dated amendment if intentional. |
| `/flow coherence` | `bash <skill>/runner/flow.sh coherence` | Advisory version-field drift; semantic contradictions stay a human challenge. |
| `/flow consistency` | `bash <skill>/runner/flow.sh consistency` | Advisory PRD FRn coverage; then `gate-rules.md` cross-artifact passes. |
| `/flow constitution` | `bash <skill>/runner/flow.sh constitution` | Advisory constitution form + markers; then `gate-rules.md`. Not a `next` gate. |
| `/flow clarify` | `bash <skill>/runner/flow.sh clarify` | List leftover Open-decision boxes; write-back `references/clarify.md`. Not a `next` gate. |
| `/flow converge` | `bash <skill>/runner/flow.sh converge [--file <payload>]` | Assess vs plan per `references/converge.md`; present the findings table first. |
| `/flow eval [--stage 01\|02\|card] [--fixture <id>] [--n 3] [--timeout <s>]` | `bash <skill>/runner/flow.sh eval [...]` | Billable; live mode skips if `claude` absent. `--replay` does not inherit that SKIP. See `references/gate-eval.md`. |
| `/flow eval --report` | `bash <skill>/runner/flow.sh eval --report` | Offline; relay last complete batch + drift. See `references/gate-eval.md`. |
| `/flow eval --replay` | `bash <skill>/runner/flow.sh eval --replay` | Keyless replay; missing/stale fixtures exit 1. Verdicts never count toward the eval floor. |
| `/flow project-type <web\|cli\|library\|skill>` | `bash <skill>/runner/flow.sh project-type [t]` | Set/read type per `references/project-types.md`. Confirm before planning. |
| `/flow usage [--global\|--prune]` | `bash <skill>/runner/flow.sh usage [...]` | Relay local JSONL analytics; `--prune` caps the log. Nothing to author. |
| `/flow skip <stage> --reason ...` | `bash <skill>/runner/flow.sh skip <stage> --reason ...` | Advance only with matching `DEBT.md`. Security-class: operator-only HALT. |
| `/flow debt add\|list` | `bash <skill>/runner/flow.sh debt add\|list` | Record/list skips in `DEBT.md`. Security-class is operator-authored only. |
| `/flow design <file>` | `bash <skill>/runner/flow.sh design <file>` | Advisory DESIGN.md mechanical check; pair `design-review-checklist.md` for UI cards. |
| `/flow harness <args>` | `bash <skill>/runner/flow.sh harness <args>` | Passthrough to the durable-layer CLI; visible output + real exit. Use `recall` to read back. |
| `/flow doctor` | `bash <skill>/runner/flow.sh doctor` | Relay FAIL as the fix list. Read-only. |
| `/flow promote <file>` | `bash <skill>/runner/flow.sh promote <file>` | Copy playbook into `~/.claude/flow/playbooks` for cross-project `recall`. |
| `/flow mode teach` | `bash <skill>/runner/flow.sh mode teach` | Confirm; host gatekeeps, operator authors. |
| `/flow mode work` | `bash <skill>/runner/flow.sh mode work` | Interview once, draft 00-05, pause for scope sign-off; same gates. See `references/mode-work.md`. |
| `/flow ready` | `bash <skill>/runner/flow.sh ready` | Relay buildable cards; operator dispatches. Confirm allowed-files don't overlap. |
| `/flow workspace <verb>` | `bash <skill>/runner/flow.sh workspace add\|list\|enter\|remove\|check\|doctor [...]` | Relay worktree isolation output; don't auto-`--force` a `remove`. Advisory. |
| `/flow auto` | `bash <skill>/runner/flow.sh auto` | Load `references/auto-run.md`. |
| `/flow auto stop` | `bash <skill>/runner/flow.sh auto stop` | Clear auto policy; return to warning-only manual path. |
| `/flow attest …` | `bash <skill>/runner/flow.sh attest semantic\|live-verify\|status\|recover …` | Mint/inspect receipts (`references/attestations.md`). Must-ask before mint/recover. |
| `/flow recall` | `bash <skill>/runner/flow.sh recall` | Read back prior knowledge; apply at start of a stage/card. |
| `/flow unlock` | `bash <skill>/runner/flow.sh unlock` | Clear lock after crashed session. Confirm the other session is gone first. |
| `/flow retro` | `bash <skill>/runner/flow.sh retro` | Ask the 3 questions; operator writes RETRO.md (`law/RETRO.md`). |

## verb-next

Table row `/flow next`. After mechanical PASS, `gate-examples.md` (examples; not a second always-on file).

## verb-card

Table row `/flow card`. Fill per `law/CLAUDE.md`; before coding, `law/CODING.md`.

## Install-path note

SKILL.md "Run `flow.sh` first". Windows: `<skill>\runner\flow.cmd <cmd>` (not bare `bash`).
