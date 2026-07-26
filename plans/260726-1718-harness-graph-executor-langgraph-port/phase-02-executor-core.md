---
phase: 2
title: "Phase 2: Executor Core (record/advance API)"
status: todo
priority: P1
effort: "3d"
dependencies: [1]
---

# Phase 2: Executor Core (record/advance API)

<!-- Updated: Red Team Session 1 (2026-07-26) — findings 3, 5, 10, 13, 14 applied -->

## Overview

Implement the graph executor as a **record/advance API** inside the harness: short-lived per-invocation processes called by `flow.sh` and the orchestrating agent at named boundaries. No resident process, no LLM orchestration. Subcommands: `graph run|record|next|resume|status|abandon|gc`. Ships dark.

## Requirements

- Functional: record checkpoints/step-writes atomically; compute next steps from topology + journal; interrupt open/resolve with operator-authority guards; terminal states (`abandon`, `outcome=killed`); `gc` retention (renamed from `prune` — collides with existing harness `prune` verb, `flow_harness.py:1124`)
- Non-functional: sync durability; stdlib only; every mutation in ONE `BEGIN IMMEDIATE` transaction; fail-closed 3-state exit contract; defined interaction with existing env flags

## Architecture

### Invocation model (honest, post-finding-3)

Each call = fresh process: open DB → one command → close (`flow_harness.py` pattern, `_db.connect`…`con.close()`). Consequences stated plainly:
- `graph_step_write` + checkpoint commit happen in the SAME transaction within one invocation. The ported pending-writes table serves multi-write steps and fork/repair bookkeeping (user decision: keep the 4-table port); the plan does NOT claim it closes a cross-process crash window.
- The unguarded window is BETWEEN invocations (agent works for minutes, then records). Mitigation is the **recording contract** (Phase 4: mandatory boundaries) + **git-state reconciliation** at resume: before re-dispatching any step, the executor checks durable evidence (branch exists / merged / gate output hash present) and marks the step complete-from-evidence instead of re-dispatching.

### Exit contract (findings 14 + R2 — fail-closed)

All value-carrying subcommands: exit 0 + value on stdout; **exit 3 = definitive no-next/complete**; **exit 4 = harness unavailable** (`FLOW_HARNESS_DISABLE` set / harness file missing / no python — today these return rc 0 from `_harness_run`, `flow.sh:192-194`, which is exactly the ambiguity to kill); exit 1/2 = failure.

`harness_call_checked` ALREADY EXISTS (`flow.sh:232-235`, documented `:187`, live caller `story complete` at `:1168`) and `_harness_run` swallows stdout (`:199`, never echoed). Therefore: add a NEW public wrapper `harness_capture_checked`, implemented as an output-mode flag on `_harness_run` rather than a third near-copy beside `_harness_run`/`harness_emit` (Round-3 DRY note) — prints `$out`, maps the three early-exits (`:192-194`) to rc 4, and suppresses the "durable write failed" stderr warn for the semantic rc 3. Do NOT redefine the existing helper; add a test pinning that `:1168` behavior is unchanged.

### Env-flag semantics (finding 10, partial — full decision in Phase 6)

`FLOW_GRAPH_EXECUTOR` documented as the 4th harness flag alongside `FLOW_HARNESS_DISABLE`/`FLOW_HARNESS_STRICT`/`FLOW_HARNESS_BACKEND`. While dark (Phases 2-5): `FLOW_HARNESS_DISABLE=1` + `FLOW_GRAPH_EXECUTOR=1` is a hard error from `graph` subcommands (contradictory instruction), not a silent no-op.

### Interrupts (findings 5 + R4 — out-of-band authority, user decision)

- `graph record --interrupt` opens row (unique open per (execution, ns, node)), sets execution `paused`, exits 3.
- `graph resume --answer <json> --actor <id>` for `security_class=1` refuses unless ALL hold:
  (a) target validated against a CLOSED SET first (literal patterns `^C-[0-9]{1,4}$` / `^[0-9]{2}-[a-z-]+$`), then the DEBT row located by restricting to DEBT rows and fixed-string matching the validated target (`grep -E '^- \[ \] DEBT:' "$ROOT/DEBT.md" | grep -F -- "$target" | head -1`), and the FULL MATCHED LINE captured as `$debt_line`, with an EXPLICIT non-empty refusal `[ -n "$debt_line" ] || refuse` (Round-6: an empty capture would make step 2's `grep -nFx -- ""` match blank lines in HEAD's blob — absent evidence must refuse, not fall through) — this capture is `$debt_line`'s ONLY provenance (Round-5 H1: caller/answer-supplied line text is forbidden; the line therefore contains the validated target by construction) — mirrors `cmd_skip`'s safety structure (closed-set `flow.sh:1232-1233`, security regex `:1242`, DEBT grep `:1247`), never interpolated `grep -E`;
  (b) **out-of-band artifact** (mechanism corrected Round-4 — worktree line numbers do NOT map to HEAD blob lines when uncommitted edits exist above, and `blame HEAD` can never emit `Not Committed Yet`, so the Round-3 spec was bypassable by an uncommitted appended line): step 1 — refuse unless `git -C "$ROOT" diff --quiet HEAD -- DEBT.md` (ANY uncommitted `DEBT.md` change = refuse; closes the append-without-commit bypass); step 2 — locate the (a)-captured line in HEAD's blob of THE SAME FILE (Round-7 H2: `HEAD:DEBT.md` is tree-root-relative while steps 1/3 are `$ROOT`-relative — a monorepo sub-project root would read the wrong blob or deadlock): `pfx=$(git -C "$ROOT" rev-parse --show-prefix)` then `n=$(git -C "$ROOT" show "HEAD:${pfx}DEBT.md" | grep -nFx -- "$debt_line" | head -1 | cut -d: -f1)` (no match or empty `n` = refuse; `-Fx` whole-line match sound because step 1 guarantees worktree == HEAD); step 3 — `git -C "$ROOT" blame -w --line-porcelain -L "$n,$n" HEAD -- DEBT.md` for `author-mail`. The author-distinct check (`author-mail` ≠ session git identity) applies WHEN a distinct operator identity exists; in same-identity environments (solo repo — this repo's own convention) it degrades, documented, to committed-provenance + audit fields, since an always-refuse guard is a deadlock, not a control;
  (c) security-class re-check passes on the answer's reason;
  (d) answer JSON schema valid.
  `resolved_by` + environment-derived session id (`_session_env_id`, `flow.sh:353-368`) stored as AUDIT evidence. Documented residual limit (plan invariant 6): git authorship is forgeable by an agent with git-config control — accepted, stated, not hidden.
- Non-security interrupts: (a)+(d) only.
- `graph` verbs inherit `harness` Must-ask classification (Phase 4 wires concierge/dispatch docs).

### Fork & terminal states (finding 13)

Two-strikes attempt 2 = new checkpoint with `parent_checkpoint_id` + `meta.source='fork'`. `graph abandon <execution>` = terminal `abandoned`; kill-at-gate recorded by flow.sh calling `graph abandon --outcome killed` (Phase 5). `graph gc`: deletes executions with terminal status (cascade handles children) + `--stale-days N` sweep that marks `running` executions with no checkpoint newer than N days as `abandoned` (surfaced by doctor first, Phase 4).

### Serde

stdlib JSON + type tag inside value objects. No pickle/msgpack.

## Related Code Files

- Create: `skills/flow/harness/graph_executor.py` (importable snake_case, matches harness convention)
- Modify: `skills/flow/harness/flow_harness.py` (register `graph` group; never-forward already done Phase 1)
- Modify: `skills/flow/runner/flow.sh` (add `harness_capture_checked` + `_harness_run_out` helpers only — no consumers yet; existing `harness_call_checked` untouched)
- Create: `tests/test_flow_graph_executor.sh` (conformance invariants)
- Create: `tests/test_flow_graph_crash_resume.sh`
- Modify: `tests/run_all.sh` (register both)

## Implementation Steps

1. Read `flow_harness.py` subcommand registration (intake/story/trace) and mirror for `graph`; all SQL via `_db` helpers (no raw SQL in `graph_executor.py` — review rule).
2. Implement: `plan_next()` (topology successors, predicate-gated, version-gated per kept `seen` semantics; **skip-substitution semantic, Round-7 H1**: when a candidate successor is a `gate_check` node whose mapped `stage` is in `flow/.skipped`, transitively substitute THAT node's successors — handles single and chained skips with zero bypass edges in topology data), `record()` (step_writes + checkpoint in one `transaction()`), `open_interrupt()`/`resume()` (guards above), `abandon()`, `gc()`, `status()`.
3. Git-reconciliation helper: given a manifest claim (branch, SHA, gate hash), verify against `git` in the pinned project root; used by `resume` to complete-from-evidence.
4. Conformance suite (`test_flow_graph_executor.sh`): PUT round-trip (manifest/versions/seen fidelity), step-write ordering by (task_id, idx), GET latest-vs-exact, LIST newest-first, cascade delete via `gc`, monotonic id ordering, interrupt guard matrix (security-class × DEBT-present × git-author-distinct × target-validity × **monorepo-sub-root** — Round-7 H2 row), skip-substitution traversal (single + chained skips reach the correct successor), exit-code contract (0/3/4/1 incl. DISABLE→4 not 0), `:1168` caller-behavior pin, contradictory-flags hard error. Register in run_all.sh.
5. Crash-resume suite (`test_flow_graph_crash_resume.sh`): portability-checked termination helper (SIGTERM first; document Windows Git Bash behavior; skip-with-note if unsupported rather than false-green), failpoint env `FLOW_GRAPH_FAILPOINT` between record calls → resume → 0 re-dispatch of evidence-backed steps; git-reconciliation case: merged-but-unrecorded work detected. Register in run_all.sh.
6. Concurrency test (inside executor suite): two processes `record` to same DB (BEGIN IMMEDIATE + busy_timeout) — both succeed.

## Success Criteria

- [x] Conformance suite green incl. interrupt guard matrix and exit-code contract
- [x] Crash-resume: 0 evidence-backed steps re-dispatched; merged-but-unrecorded detected via git reconciliation
- [x] 2 concurrent writers succeed; no `database is locked` failure
- [x] `graph gc` removes terminal executions only; `--stale-days` marks stale running → abandoned
- [x] No new imports outside stdlib; no raw SQL outside `_db` helpers
- [x] Both suites registered in `tests/run_all.sh`

## Risk Assessment

- Kept versions/seen vectors (user decision): implement minimally (bump-on-record; `seen` consulted only by `plan_next`) — do not build channel machinery around them.
- Termination-helper portability on Windows is genuinely uncertain: criterion allows documented skip-with-note on Windows ONLY for the kill case; logical failpoint resume cases must run on all 3 OSes.
- Rollback: nothing calls the executor yet; revert removes cleanly.
