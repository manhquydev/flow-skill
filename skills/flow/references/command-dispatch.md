# Command dispatch

Exact mapping: user input -> runner call -> host duties. Always run the runner
first, relay its output faithfully, then do the semantic part. `<skill>` = this skill's
install dir; run from the project root so `flow/` and `cards/` resolve.

Seekable: `#verb-next`, `#verb-card` (humans). This file is still loaded whole — there
is no fragment loader (ADR-0001).

| User input | Runner call | Host duties after |
|---|---|---|
| `/flow` | `bash <skill>/runner/flow.sh status` | Relay prose `NEXT ->`, PIN v1 after NEXT_VERB (display-only, do not exec), dwell, and (past 10 cards) the compact summary; nothing to author. Compact recovery is prose status/resume, not `--json`. Optional `status --json` prints one `flow_context/v1` object (`v,stage,gate,next_verb,card,dwell,load`) — **display-only**. Hosts MUST NOT dispatch `next_verb` (`next`/`card`/`card-start`/`check`/`fix-gate`/`auto`/`skip`). Default `/flow` stays prose status. |
| `/flow resume` | `bash <skill>/runner/flow.sh resume` | Read-only session-story; no lock. PIN v1 after NEXT_VERB, display-only, do not exec. Compact recovery is prose status/resume, not `--json`. Optional `resume --budget` caps in-flight cards at 5 with count line; `resume --card C-NNN` streams card continuation brief (scope, verify, linked decisions, bounded git status, masked secrets); `resume --json` same closed schema as status; display-only, never exec `next_verb`. FAIL/PASS/Never: SKILL.md STOP + Dispatch. |
| `/flow next` | `bash <skill>/runner/flow.sh next` | V1 target: after the mechanical gate passes, the graph executor supplies the next stage node; `flow.sh` remains the gate verdict authority. Paused/inconsistent/unavailable graph state refuses progression; it never falls back to the legacy ordering ladder. After PASS, compare to `gate-examples.md` (not a second always-on load). FAIL/Never: SKILL.md STOP + Dispatch. |
| `/flow assess` | `bash <skill>/runner/flow.sh assess` | Fill `flow/00-inspect.md` from EVIDENCE; Brownfield challenge in `gate-rules.md`. |
| `/flow card` | `bash <skill>/runner/flow.sh card` | Fill per `law/CLAUDE.md`; before coding, `law/CODING.md`. |
| `/flow card start C-NNN` | `bash <skill>/runner/flow.sh card start C-NNN` | Optional in-flight mark (`cards/.inflight`); does not touch gated `status:`. |
| `/flow card done C-NNN` | `bash <skill>/runner/flow.sh card done C-NNN` | CLI `done` under the same rules as `check`; then semantic review. |
| `/flow check C-NNN` | `bash <skill>/runner/flow.sh check C-NNN` | After PASS, semantic card review (`law/CLAUDE.md`). FAIL/Never: SKILL.md STOP + Dispatch. |
| `/flow gate <stage>` (or `--card C-NNN`) | `bash <skill>/runner/flow.sh gate <stage\|--card C-NNN> [--json]` | Read-only mechanical scan; relay findings. `next`/`check` own progression. Optional `--json` emits one closed `gate.report` envelope (`schema_version`, `kind`, `target`, `clean`, `findings[]`). Exit 0 clean / 1 findings / 2 error. |
| `/flow contract` | `bash <skill>/runner/flow.sh contract` | Advisory client base-URL vs served-path drift; confirm on the running app. |
| `/flow tokens` | `bash <skill>/runner/flow.sh tokens` | Advisory DESIGN.md token unused/mismatch; dated amendment if intentional. |
| `/flow coherence` | `bash <skill>/runner/flow.sh coherence` | Advisory version-field drift; semantic contradictions stay a human challenge. |
| `/flow consistency` | `bash <skill>/runner/flow.sh consistency [--contract]` | Advisory PRD FRn coverage or contract endpoint audit (`--contract`); see `references/gate-consistency.md`. |
| `/flow constitution` | `bash <skill>/runner/flow.sh constitution` | Advisory constitution form + markers; then `gate-rules.md`. Not a `next` gate. |
| `/flow clarify` | `bash <skill>/runner/flow.sh clarify` | List leftover Open-decision boxes; write-back `references/clarify.md`. Not a `next` gate. |
| `/flow converge` | `bash <skill>/runner/flow.sh converge [--file <payload>]` | Assess vs plan per `references/converge.md`; present the findings table first. |
| `/flow eval [--stage 01\|02\|05\|card] [--fixture <id>] [--n 3] [--timeout <s>]` | `bash <skill>/runner/flow.sh eval [...]` | Billable; live mode skips if `claude` absent. `--replay` does not inherit that SKIP. See `references/gate-eval.md`. |
| `/flow eval --report` | `bash <skill>/runner/flow.sh eval --report` | Offline; relay last complete batch + drift. See `references/gate-eval.md`. |
| `/flow eval --replay` | `bash <skill>/runner/flow.sh eval --replay` | Keyless replay; missing/stale fixtures exit 1. Verdicts never count toward the eval floor. |
| `/flow eval --diff <old> <new>` | `bash <skill>/runner/flow.sh eval --diff <old> <new>` | Offline; fixture regression classifier vs baseline. See `references/gate-eval.md`. |
| `/flow project-type <web\|cli\|library\|skill>` | `bash <skill>/runner/flow.sh project-type [t]` | Set/read type per `references/project-types.md`. Confirm before planning. |
| `/flow usage [--global\|--prune]` | `bash <skill>/runner/flow.sh usage [...]` | Relay local JSONL analytics; `--prune` caps the log. Nothing to author. |
| `/flow skip <stage> --reason ...` | `bash <skill>/runner/flow.sh skip <stage> --reason ...` | Advance only with matching `DEBT.md`. Security-class: operator-only HALT. |
| `/flow debt add\|list` | `bash <skill>/runner/flow.sh debt add\|list [--json]` | Record/list deliberate gate-skips in `DEBT.md`. Optional `--json` on list (shorthand `/flow debt --json`) emits one closed `debt.list` envelope (`schema_version`, `kind`, `total`, `open_count`, `debts[{text,open,line}]`). Exit 0 (or 2 on invalid/duplicate flags). Security-class is operator-authored only. |
| `/flow design <file>` | `bash <skill>/runner/flow.sh design <file>` | Advisory DESIGN.md mechanical check; pair `design-review-checklist.md` for UI cards. |
| `/flow harness <args>` | `bash <skill>/runner/flow.sh harness <args>` | Passthrough to the durable-layer CLI; visible output + real exit. Use `recall` to read back. |
| `/flow doctor` | `bash <skill>/runner/flow.sh doctor [--list] [--check <csv>] [--json]` | Relay FAIL as the fix list. Read-only. Named check registry; verifies full bundled tree integrity against manifest receipt and bounded state integrity (`bounded_json`; modes, nofollow); skipped advisory in local dev checkouts. `--json` outputs machine-readable report. |
| `/flow promote <file>` | `bash <skill>/runner/flow.sh promote <file> \| --suggest` | Copy playbook into `~/.claude/flow/playbooks` for cross-project `recall`, or suggest draft playbooks (`--suggest`) whose actions are derived from recorded harness patterns (>=2 occurrences); no generic advice is invented. |
| `/flow mode teach` | `bash <skill>/runner/flow.sh mode teach` | Confirm; host gatekeeps, operator authors. |
| `/flow mode work` | `bash <skill>/runner/flow.sh mode work` | Interview once, draft 00-05, pause for scope sign-off; same gates. See `references/mode-work.md`. |
| `/flow ready` | `bash <skill>/runner/flow.sh ready [--json]` | Relay buildable cards; operator dispatches. Confirm allowed-files don't overlap. `--json` prints one closed `ready.report` envelope, display-only (`schema_version`, `kind`, `planning_complete`, `note`, `buildable[].id/deps/allowed_files/wave`, `blocked[]`, `warnings[]`, `groups[][]`, `auto`, `parallel_policy`); exit 1 when planning is incomplete or, with auto active, no todo card is buildable. `allowed_files` and waves use the same `_ws_tokens` normalization as `workspace check`; undeclared allowed-files conflict with everything (own wave). Waves are advisory: the host places and waits (see `host-agnostic-parallel.md`). |
| `/flow workspace <verb>` | `bash <skill>/runner/flow.sh workspace add\|list\|enter\|remove\|check\|doctor\|port [...]` | Relay worktree isolation output; don't auto-`--force` a `remove`. `workspace port` allocates deterministic per-card port (`references/host-agnostic-parallel.md`). Advisory. |
| `/flow auto` | `bash <skill>/runner/flow.sh auto [--parallel]` | Load `references/auto-run.md`. `--parallel` records the parallel policy (`parallel: true` in auto-state) and prints advisory waves; placement and waiting stay with the host. |
| `/flow auto stop` | `bash <skill>/runner/flow.sh auto stop` | Clear auto policy; return to warning-only manual path. |
| `/flow attest …` | `bash <skill>/runner/flow.sh attest semantic\|live-verify\|status\|recover …` | Mint/inspect receipts (`references/attestations.md`). Must-ask before mint/recover. |
| `/flow recall` | `bash <skill>/runner/flow.sh recall` | Read back prior knowledge; apply at start of a stage/card. |
| `/flow unlock` | `bash <skill>/runner/flow.sh unlock` | Clear lock after crashed session. Confirm the other session is gone first. |
| `/flow retro` | `bash <skill>/runner/flow.sh retro` | Ask the 3 questions; operator writes RETRO.md (`law/RETRO.md`). |
| `/flow rules [agent-skills\|agents-md\|cursor\|windsurf\|roo\|cline\|aider\|openhands\|copilot\|list] [--write]` | `bash <skill>/runner/flow.sh rules [...]` | Preview workspace rules; `--write` creates only absent targets, refusing existing files/symlinks. `agent-skills` emits a standard `.agents/skills/flow/SKILL.md` pointer for project Codex/Gemini discovery to canonical `skills/flow/SKILL.md`, not a runtime or full copy. Claude `.claude/skills` stays separate; npm install scope is unchanged. |

`agent-skills` is only for repositories with the canonical bundle checked into project-root `skills/flow`. `--write` refuses without both `skills/flow/SKILL.md` and `skills/flow/runner/flow.sh`, before creating directories or files. Global installs or `.claude/skills/flow` alone are insufficient; preview remains available and states this prerequisite.

The eight harness-rule templates resolve runner commands when scaffolded: use `bash skills/flow/runner/flow.sh` when that file exists in the project; otherwise use the shell-escaped absolute path of the running install. Run commands from the project root (Git Bash on Windows; WSL path mapping is not verified). Roo's command regex and Aider's test command use the same resolved runner. Regenerate rules after relocating an install; existing files are never overwritten, so remove stale scaffold files first before re-running with `--write`.

## verb-next

Table row `/flow next`. After mechanical PASS, `gate-examples.md` (examples; not a second always-on file).

## verb-card

Table row `/flow card`. Fill per `law/CLAUDE.md`; before coding, `law/CODING.md`.

## Install-path note

SKILL.md "Run `flow.sh` first". Windows: `<skill>\runner\flow.cmd <cmd>` (not bare `bash`).

## V1 compatibility gate

The owner-approved v1 target makes Python required, graph ordering the default for `/flow next`,
and `FLOW_HARNESS_DISABLE` a product-operation refusal. This is a breaking change and remains
unreleased until implementation, independent review, exact-head CI, migration/rollback evidence,
and installed-package acceptance pass. The skill product and npm installer remain separate
version axes; an npm installer pin restores bytes only through the installer CLI and does not
by itself reverse a migrated database. See the [v1 migration guide](https://github.com/manhquydev/flow-skill/blob/master/docs/migration-v1.md).
