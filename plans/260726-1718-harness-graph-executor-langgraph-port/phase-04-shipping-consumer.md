---
phase: 4
title: "Phase 4: Shipping Consumer (auto-run recording contract)"
status: todo
priority: P1
effort: "3d"
dependencies: [3]
---

# Phase 4: Shipping Consumer (auto-run recording contract)

<!-- Updated: Red Team Session 1 (2026-07-26) — findings 3, 4, 5, 8, 9, 11, 15 applied -->

## Overview

Wire auto-run to the executor behind `FLOW_GRAPH_EXECUTOR=1` (default off). Honest seam (finding 3): the LLM agent orchestrates per SKILL.md AUTO PRINCIPLES — there is no bash loop (`cmd_auto` is preflight-only, `flow.sh:1330-1348`). This phase delivers the **recording contract**: named boundaries where flow.sh verbs (which the agent already calls) record into the executor, plus DAG compile, dispatch records, durable interrupts, and git-reconciled resume.

## Requirements

- Functional: card DAG compile from REAL card format; deps-met computation; dispatch/boundary recording via flow.sh calls; durable Tier-C interrupts with authority guards; `graph resume` reconstructs state incl. git reconciliation
- Non-functional: ONE shared DB across worktrees (pinned root); git remains concurrency ground-truth; existing Tier-A/B/C semantics unchanged; state-ownership rules explicit

## Architecture

### Recording contract (the seam — finding 3)

Boundaries recorded by instrumenting verbs the agent ALREADY calls, so recording does not depend on the agent remembering extra calls: `card-dispatch` (recorded by `flow.sh workspace add`), `card-build` evidence (recorded by `flow.sh check <card>` runs — gate exit + SHA), `card-review` (same), `card-verify-live`/done (recorded by `cmd_card_done` evidence gate, `flow.sh:1037-1054`). **`card-merge` (R3): `_ws_remove` performs NO merge verification (`flow.sh:2077-2114`) and no merge verb exists — so merge is recorded by an explicit `flow.sh harness graph record --merge <card>` step in the auto-run prose, and the executor COMPUTES the proof itself (`git merge-base --is-ancestor <branch> <base>`) rather than trusting the caller's claim. Base resolution (Round-3): `origin/HEAD` if set, else the main worktree's checked-out branch, else explicit `--base` required — a wrong base recording "not merged" for merged work would trigger re-dispatch, the exact Goal-1 failure. `workspace remove --force` of an unmerged branch records `abandoned`, never merge (branch ref survives worktree removal, so ancestry stays computable).** `auto-run.md` prose updated so each step names the verb that records it; remaining explicit `graph record` calls have their JSON payloads spelled out.

Hand-edited `status: done` + `flow check` (the documented alternate done-path, `flow.sh:908-910`) is covered by the state-ownership table: card file is the done-authority, so the executor's ready-set keys on card status regardless of which path flipped it.

**Merge is non-terminal (finding 15):** dependent cards unblock ONLY on `card_status == done` (post evidence gate) — matching `cmd_ready` (`flow.sh:1308-1318`). A `cmd_card_done` revert removes dependents from the ready set (test).

### One DB (findings 4 + R1 — resolver-level pinning, NOT env export)

DB location is resolved centrally in `default_db_path()` (Phase 1 R1 work: linked-worktree translation via `git rev-parse --path-format=absolute --git-common-dir`, git ≥2.31 floor, `FLOW_HARNESS_DB` narrow override) — so ALL harness writes (graph, story, trace, usage) from any worktree land in the main DB, not just executor calls. **`FLOW_PROJECT_ROOT` is NEVER exported for this** — it is the global root override (`flow.sh:24-31`) and would make every flow.sh call in the worktree operate on the main tree (wrong card files, shared locks, wrong `.skipped`). `_ws_print_enter` stays untouched. Tests: checkpoint + story writes inside a worktree land in main DB and survive `git worktree remove`; exactly one `harness.db` after a 2-card parallel run; regression: `flow check C-NNN` inside a worktree reads the WORKTREE's card file; monorepo sub-project fixture unchanged.

### Card DAG (finding 8 — real format)

Compile at auto-run start from `cards/C-*.md`: `deps:` body line (`grep -m1 -E '^deps:'`, normalize `C-[0-9]+`, `C-1`≡`C-001` — mirror `flow.sh:1310-1319`); allowed-files from `## Allowed files` section via the SAME awk/token logic (`_card_allowed_files`/`_ws_tokens`, `flow.sh:1289-1292,1948-1950` — reuse, do not reimplement). NEW: cycle rejection at compile (no cycle detection exists today). Card template unchanged.

### Ready-set & overlap (finding 9 — split criteria)

(a) **Deps parity**: executor deps-met set == `cmd_ready` BUILDABLE set (`flow.sh:1294-1328` computes deps only). (b) **Overlap serialization = NEW deliberate behavior** (legacy `ready` only prints an advisory, `:1302`): overlap computed from card files at compile time (crash-independent; NOT from `workspaces.jsonl`), overlapping pairs get a serialization edge; tested against `_ws_tokens` token-intersection semantics. `[FILL:]` placeholder in allowed-files = card not dispatchable (lint at compile).

### State ownership (finding 9)

| Question | Authority | Others |
|---|---|---|
| Worktree exists/where | git (`git worktree list`) | `workspaces.jsonl` advisory |
| Card in-flight | `cards/.inflight` (flow.sh owned) | `graph_execution` derived |
| Card done | card file `status:` (post evidence gate) | checkpoint derived |
| Execution position/history | `graph_checkpoint` journal | — |
| Evidence of work | git (SHA, branches) + gate outputs | manifest refs derived |

On disagreement: left column wins; `workspace doctor` (`_ws_doctor`, `flow.sh:2158+`) extended execution-aware — flags DB executions whose worktree/card state diverges; never auto-deletes a worktree backing a `paused` execution.

### Interrupts & tiers (finding 5)

Tier-C security halt → `graph record --interrupt --security-class`; resolution rules enforced by Phase 2 guards (DEBT line + regex re-check + distinct actor). Two-strikes strike-2 → fork checkpoint (parent = strike-1) then Tier-B escalation as today. Must-ask during auto-run → interrupt row, survives session death; surfaced by `/flow resume` + concierge.

### Verb surface (finding 11)

`graph` stays a `harness` subcommand → inherits Must-ask (`harness` listed Must-ask at `concierge.md:61`). NO May-run carve-out for graph. The suite's extraction takes the FIRST token after `/flow ` from `command-dispatch.md` rows, so `harness graph …` collapses to `harness` — classification stays green without new rows (verified: 27 dispatcher verbs today; the only new top-level verb is Phase 3's `gate`, classified there). `references/concierge.md` resume-intent prose may READ `graph status` output relayed by flow.sh `status`/`resume`, which ARE May-run.

## Related Code Files

- Modify: `skills/flow/harness/graph_executor.py` (card compile, deps/overlap edges, dispatch records, git reconciliation for cards)
- Modify: `skills/flow/runner/flow.sh` (`workspace add/remove`, `check`, `cmd_card_done` recording hooks behind flag; `_ws_doctor` execution-aware — `_ws_print_enter` UNTOUCHED, no `FLOW_PROJECT_ROOT` export)
- Modify: `skills/flow/references/auto-run.md` (each loop step names its recording verb; tier semantics text intact)
- Modify: `skills/flow/references/concierge.md` (resume surfacing prose), `skills/flow/references/command-dispatch.md` (verify no new top-level verb needed)
- Create: `tests/test_flow_graph_auto_run.sh`, `tests/test_flow_graph_parallel_cards.sh`
- Modify: `tests/run_all.sh` (register both)

## Implementation Steps

1. Map every `auto-run.md` step (`:15-38`) to its recording verb in a table (PR description + doc update).
2. Implement DAG compile (real `deps:` + allowed-files reuse + cycle rejection + `[FILL:]` guard); property test: deps-met set == `cmd_ready` BUILDABLE on shared fixtures.
3. Implement recording hooks in the named flow.sh verbs behind `FLOW_GRAPH_EXECUTOR=1` (DB location comes from Phase 1's resolver — no per-call pinning).
4. Extend `_ws_doctor` execution-aware (`_ws_doctor` header at `flow.sh:2157`); `_ws_print_enter` untouched.
5. Interrupt path: Tier-C fixture → paused row survives process exit → guarded resume completes; unguarded attempts refused (matrix from Phase 2 re-run end-to-end).
6. Crash/reconcile tests: terminate mid-card → resume → completed cards untouched; merged-but-unrecorded card detected from git, not re-dispatched; `cmd_card_done` revert removes dependents from ready set; unmerged branch + `workspace remove --force` → `abandoned` recorded, card stays dispatchable.
6b. Events-ingest wiring (Round-5 H3): `_ws_remove` ingests the worktree's `events.jsonl` via `rollup --src --src-key <path>#<branch>#<created_at>` BEFORE `git worktree remove`; tests: worktree event in `usage_event` after remove; re-dispatched card at the recycled path gets its second lifecycle fully ingested; `resume`/`status` inside worktree A during a 2-worktree run reports only its own session.
7. Parallel fixture: 2 independent + 1 dependent card → 2 concurrent worktree records active (deterministic assertion — NO wall-clock), dependent waits for `status: done`, merge order = card id asc.
8. Flag off → byte-identical legacy behavior (existing suites green with flag unset).

## Success Criteria

- [ ] Deps parity green on all fixtures; overlap serialization green against `_ws_tokens` semantics
- [ ] One-DB + survive-worktree-remove tests green
- [ ] Recording contract: every auto-run.md step names its recording verb; instrumented verbs write boundaries without agent-remembered extra calls (except explicitly documented `graph record` steps)
- [ ] Interrupt guard matrix green end-to-end; Tier-C survives session death
- [ ] Git-reconciliation: merged-but-unrecorded work never re-dispatched
- [ ] `test_flow_concierge.sh` green (no verb classification break); both new suites registered in run_all.sh
- [ ] Flag off → all existing auto-run/workspace suites green

## Risk Assessment

- Highest-risk phase. Mitigation: env-flag gating, parity tests both ways, state-ownership table with flow.sh/git precedence, rollback = unset flag.
- Recording-contract completeness is the residual risk (agent skips a documented `graph record` step): resume git-reconciliation is the backstop — evidence-backed work is never redone even if unrecorded.
- Executor never auto-PASSes gates (invariant 2): records outcomes only.
