---
title: "harness graph executor - langgraph port"
description: "Promote flow_harness.py + SQLite into a graph executor by porting LangGraph concepts (checkpoint schema, versions_seen, pending_writes, gate-as-interrupt). Python becomes mandatory. Topology-as-data covers planning + shipping."
status: pending
priority: P1
effort: "10-14d"
tags: [harness, graph-executor, langgraph-port, breaking-change]
created: 2026-07-26
blockedBy: [260811-1542-attested-execution]
blocks: []
---

# harness graph executor - langgraph port

## Supersession notice — 2026-08-11

The graph journal/executor foundation already shipped and remains supported.
The **remaining Phase 6 direction that makes Python mandatory and flips the
graph executor default-on is superseded and blocked** by
`plans/260811-1542-attested-execution/`.

Do not remove or revert shipped graph code. Do not implement the old
Python-mandatory/default-on release direction. v0.28 first establishes
standalone risk state, fingerprint-bound receipts, and auto enforcement; graph
default-on may be reconsidered only after that telemetry/dogfood evidence.

<!-- Updated: Red Team Session 1 (2026-07-26) — 15 findings applied -->

## Overview

Port LangGraph concepts (NOT code) into flow's self-owned Python harness, turning it into a graph executor: durable checkpoints at deterministic gate/step boundaries, resume via journal + git-state reconciliation, card-DAG parallel dispatch records, gate-as-interrupt HITL with operator-authority guards. Topology is declarative JSON (stdlib-parseable; YAML rejected: needs PyYAML, violates zero-dependency). Python becomes a hard dependency (deliberate breaking change, major bump).

Canonical input: `plans/reports/xia-260726-1713-langgraph-port-analysis.md`. User decisions (advise 2026-07-26 + red-team gate 2026-07-26): all-in planning+shipping; Python mandatory; self-owned executor; gate parity preserved; **keep the 4-table schema port (versions_seen + step_write + separate graph_interrupt) despite the per-invocation-process evidence — accepted maintenance trade-off**; **supersede the GAP-MATRIX "Changesets / work-graph: Out of scope (FOMO red line)" with a formal decision record** (Phase 1 deliverable).

**Architecture reality (post red-team):** there is NO resident executor process. The auto-run loop is LLM prose (`auto-run.md`); `cmd_auto` is preflight-only (`flow.sh:1330-1348`). The executor is a **record/advance API**: short-lived per-invocation processes called by `flow.sh` and by the orchestrating agent at named boundaries. It records evidence, computes next-steps from topology + journal, and enforces ordering data — it never drives LLM sessions. Resume correctness therefore comes from journal + **git-state reconciliation** (branch exists? merged? tree dirty?), not from journal alone.

**Non-negotiable invariants (apply to every phase):**
1. Checkpoints ONLY at deterministic gate/step boundaries (bash checks, git SHA, file hashes). NEVER mid-LLM-work. Resume never replays LLM effort; re-dispatch decisions must consult git state, not only the journal.
2. `flow.sh` remains quality ground-truth (mechanical gate). Executor records outcomes and owns ordering data, never gate verdicts. On any state disagreement: flow.sh/git/card-files win; executor rows are derived records.
3. Zero new dependencies: Python stdlib only (sqlite3, json). No ormsgpack/pickle/PyYAML/LangGraph.
4. Planning stays acyclic (+ skips only via the existing debt-gated `cmd_skip` mechanism). Only bounded cycle = two-strikes repair subgraph.
5. New tables are additive; migration numbering follows the renegotiated lineage contract (Phase 1). No rewrite of `flow.sh` 3.7k lines in this plan.
6. Security boundaries are mechanical where possible, honestly-scoped where not: topology `cmd` is allowlisted argv (no shell strings), arg-shape-linted against the REAL dispatcher signatures and smoke-executed in tests; topology loads only from the skill install dir and is pin-verified. Security-class interrupt resolution requires an out-of-band artifact — the DEBT line naming the target present in a git commit whose author differs from the executing session's git author (executor verifies via `git log`) — plus closed-set target validation (literal patterns, `grep -F`) and security-class re-check; `resolved_by` + environment-derived session id recorded as audit evidence. Documented residual limit: an agent with git-config control can still forge authorship — accepted trade-off, stated in plan, not hidden. `graph` verbs inherit `harness` Must-ask classification.
7. Every new test suite is flat `tests/test_flow_graph_*.sh` AND registered in `tests/run_all.sh` in the same phase that creates it — unregistered tests are phantom green.

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Crash/interrupt at any recorded boundary → `graph resume` yields correct continuation: no step with durable git/gate evidence is re-dispatched (verified against journal + git reconciliation) | P1 |
| 2 | Executor correctly tracks ≥2 concurrent card namespaces in ONE shared DB (worktree-safe), computes deps-met set matching `cmd_ready`, and produces deterministic merge order (card id asc) | P1 |
| 3 | Planning path (incl. debt-gated skips via existing `cmd_skip` mechanism) is recorded in checkpoints and rendered by `flow status`; topology walk with no skips reproduces the legacy ladder exactly | P1 |
| 4 | Gate parity: identical gate outcomes pre/post executor wiring (pass AND fail fixtures) | P1 |
| 5 | Python-mandatory release: preflight reusing `_python()` (accepts python3 OR python), `doctor`/`--help`/`--version` exempt, migration guide, major bump | P2 |
| 6 | Topology lintable + pin-verified (`graph lint` registered in run_all.sh + CI) | P2 |

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Phase 1: Schema, Lineage Contract & Migration Foundation](./phase-01-start.md) | Pending |
| 2 | [Phase 2: Executor Core (record/advance API)](./phase-02-executor-core.md) | Pending |
| 3 | [Phase 3: Topology as Data (trusted, linted, pinned)](./phase-03-topology-as-data.md) | Pending |
| 4 | [Phase 4: Shipping Consumer (auto-run recording contract)](./phase-04-shipping-consumer.md) | Pending |
| 5 | [Phase 5: Planning Consumer (fail-closed next-stage)](./phase-05-planning-consumer.md) | Pending |
| 6 | [Phase 6: Release — Python Mandatory](./phase-06-release-python-mandatory.md) | Pending |

Dependency chain: 1 → 2 → 3 → 4 → 5 → 6 (4 and 5 both need 3).

## Success Criteria

- [ ] Lineage contract renegotiated: migration lands in the flow-owned band chosen in Phase 1, `test_flow_harness_lineage_contract.sh` + `test_flow_schema_migration.sh` updated WITH rationale (no silent guard deletion), GAP-MATRIX + `harness/README.md` updated, FOMO red-line supersession recorded via `flow harness decision add`
- [ ] `flow harness graph lint` exits 0 on shipped topology (incl. cmd-allowlist + pin check); registered in run_all.sh; CI green ubuntu/macos/windows
- [ ] Crash-resume test (portability-checked termination helper, not raw `kill -9` assumption): terminate between recorded boundaries → resume → journal shows 0 re-dispatch of steps with durable evidence; git-reconciliation test: work merged but unrecorded is detected, not rebuilt
- [ ] Worktree test: ALL harness writes (graph, story, trace, usage) from inside a card worktree land in the MAIN repo DB via the centralized `default_db_path()` resolver (linked-worktree translation, git ≥2.31 floor) and survive `git worktree remove`; exactly one `harness.db` after a 2-card parallel run; `flow check` inside a worktree still reads the WORKTREE's card file (no `FLOW_PROJECT_ROOT` export — that variable hijacks all root resolution, `flow.sh:24-31,51-58`); monorepo sub-project fixture behavior unchanged
- [ ] Concurrency test: 2 concurrent writers to the shared DB succeed (busy_timeout + BEGIN IMMEDIATE); 2 active worktree records tracked simultaneously (deterministic assertion — no wall-clock timing)
- [ ] Security-interrupt test: security-class resolution refused without (a) DEBT line naming the closed-set-validated target, (b) committed provenance verified against HEAD's `DEBT.md` blob at the `$ROOT`-relative path (refuse on ANY uncommitted `DEBT.md` change via `git diff --quiet HEAD`; line located in `git show "HEAD:$(git -C "$ROOT" rev-parse --show-prefix)DEBT.md"`; author via `git blame -L n,n HEAD`; author-distinct when a distinct operator identity exists, documented degradation otherwise), (c) security-class re-check pass; `resolved_by` + session id recorded as audit; `graph` stays under `harness` Must-ask with `test_flow_concierge.sh` green (27 dispatcher verbs + the new `gate` verb classified May-run)
- [ ] Deps parity: executor deps-met set == `cmd_ready` BUILDABLE set on all fixtures (real `deps:` format); overlap serialization tested as NEW behavior against `_ws_tokens` logic
- [ ] Conditional path: a debt-gated skip (via `cmd_skip`) is honored by `plan_next`'s skip-substitution traversal (NO topology edges added — Round-7 H1 design), recorded in checkpoints, rendered by `flow status`; `planning_complete()` and `/flow card` work after the skip; a security-class skip attempt is refused
- [ ] Gate-parity suite green: same inputs → same gate outcomes before/after wiring (pass AND fail fixtures)
- [ ] All existing suites + new suites (named, registered, counted in run_all.sh) pass on 3-OS matrix; ONE FULL GREEN Windows run with per-suite `wall_s` recorded BEFORE Phase 4 lands (current budget is UNKNOWN — the prior ~11.5m figure was a cancelled partial run at suite 28/33, `ci.yml:43-47`)
- [ ] Missing Python → non-zero exit + actionable message; `doctor`/`--help`/`--version` still work; no-python CI job green
- [ ] Major version bump published; CHANGELOG breaking section covers: Python requirement, `FLOW_HARNESS_DISABLE` semantics change, paused-execution topology upgrade guidance; migration guide in docs (≤800 LOC per docs limit)

## Rollback Strategy (plan-wide)

- Phases 1-3 ship dark: tables + subcommands + topology have zero effect on flow.sh behavior (lineage-contract test edits land WITH Phase 1 in one commit — CI stays green per-commit). Rollback = git revert; tables additive/inert.
- Phases 4-5 wire consumers behind `FLOW_GRAPH_EXECUTOR` env flag (default off until Phase 6; interaction with `FLOW_HARNESS_DISABLE`/`FLOW_HARNESS_STRICT`/`FLOW_HARNESS_BACKEND` defined in Phase 2). Rollback = unset flag.
- Phase 6 flips default, hard-errors `FLOW_HARNESS_DISABLE`, removes legacy ladder in one revertable commit. Rollback = revert release commit; DB additive so downgraded users unaffected.

## Red Team Review

**LOOP CLOSED 2026-07-26 — Session 10 (termination check): 0 Critical, 0 High, scope verified clean.** Ten rounds total; finding trajectory 15→7→6→3→3→3→2→2→2→0; Criticals extinct from Session 5 onward. All findings adjudicated with evidence, applied, and swept. Plan is cleared for implementation handoff.

### Session 10 — 2026-07-26 (termination check, 1 reviewer, strict scope)
Both Round-9 applications verified clean: subgraph membership formally derivable from `entry`-root reachability (planning = reachable from `stage-00`, card = reachable from `card-dispatch`, disjoint in shipped topology); conditional-path SC consistent with phase-02/03 traversal semantics and existing `_next_action` skip-awareness (`flow.sh:960,964`). No findings.

### Session 1 — 2026-07-26
**Findings:** 15 deduped from 39 raw (4 hostile reviewers: Security Adversary, Failure Mode Analyst, Assumption Destroyer, Scope & Complexity Critic; Full verification tier)
**Severity breakdown:** 7 Critical, 7 High, 1 Medium-bundle
**Disposition:** 14 accepted; 1 sub-item rejected ("800-LOC docs rule is phantom" — it is a session-environment rule `docs.maxLoc: 800`, criterion kept); schema-simplification proposal (2 tables, drop versions_seen/pending_writes, reuse intervention) presented with new per-invocation-process evidence and **rejected by user decision** — 4-table port stands as approved at the xia gate; recorded as maintenance trade-off.

| # | Finding | Severity | Disposition | Applied To |
|---|---------|----------|-------------|------------|
| 1 | Migration 013 test-forbidden + upstream-reserved; lineage contract renegotiation required | Critical | Accept | Phase 1 |
| 2 | FOMO red-line (work-graph out of scope) reversed without decision record | Critical | Accept — user chose "supersede with record" | Phase 1 |
| 3 | No auto-run loop exists to delegate; executor reframed as record/advance API; wall-clock criterion dropped | Critical | Accept | plan.md, Phases 2, 4 |
| 4 | Worktree-local `harness.db`; checkpoints destroyed on worktree remove | Critical | Accept | Phase 4 |
| 5 | Security interrupts self-resolvable by halted agent | Critical | Accept | Phases 2, 4 |
| 6 | Topology JSON free-form shell cmd = RCE surface | Critical | Accept | Phase 3 |
| 7 | Conditional skip bypasses DEBT gate, deadlocks `planning_complete`, wrong source file | Critical | Accept | Phases 3, 5, plan.md Goal 3 |
| 8 | `depends_on`/`allowed-files` frontmatter fabricated (real: `deps:` line + `## Allowed files` section) | High | Accept | Phases 3, 4 |
| 9 | Ready parity self-contradictory; overlap in `_ws_check`; 4 unreconciled state stores | High | Accept | Phase 4 |
| 10 | `FLOW_HARNESS_DISABLE` (28 sites) unaddressed under mandatory harness | High | Accept | Phases 2, 6 |
| 11 | `graph` verb breaks exhaustive concierge classification test | High | Accept | Phase 4 |
| 12 | New tests in nonexistent dir + unregistered in hardcoded run_all.sh = phantom green | High | Accept | plan.md invariant 7, all phases |
| 13 | Schema defects: story_id TEXT, composite-PK helpers, transactions, FK/cascade, indexes, terminal states, prune naming | High | Accept | Phases 1, 2 |
| 14 | Harness call sites swallow failures; next-stage needs 3-state fail-closed contract | High | Accept | Phases 2, 5 |
| 15 | Realism bundle: `_python()` reuse (no invented 3.9 floor), doctor exempt, topology_hash mismatch policy, merge≠done, wall-clock dropped; 800-LOC sub-item rejected | Medium | Accept (1 sub-item rejected) | Phases 3, 4, 6 |

### Session 2 — 2026-07-26 (verify-fix, 2 reviewers: Failure Mode + Fact Checker)
**Findings:** 7 merged (2 Critical, 4 High, 1 Medium) + 9 failed citations; Round-1 fixes for band/format/skip-observability/concierge/gc/pins verified correct; fixes for DB pinning, fail-closed helper, merge boundary, DISABLE inventory proven wrong and reworked.

| # | Finding | Severity | Disposition | Applied To |
|---|---------|----------|-------------|------------|
| R1 | DB pinning must live in `default_db_path()` (all harness calls); `FLOW_PROJECT_ROOT` export hijacks all root resolution | Critical | Accept | Phases 1, 4 |
| R2 | `harness_call_checked` already exists (live caller `flow.sh:1168`); stdout swallowed; DISABLE→rc 0 | Critical | Accept — new `harness_capture_checked`, rc 4 = unavailable | Phases 2, 5 |
| R3 | `_ws_remove` verifies no merge; `card-merge` boundary re-hosted to explicit record with executor-computed ancestry proof | High | Accept | Phase 4 |
| R4 | Actor guard is prose; DEBT grep lacks closed-set validation | High | Accept — user chose OUT-OF-BAND artifact (git-author-distinct DEBT commit); residual forge limit documented | Phase 2, plan invariant 6 |
| R5 | DISABLE inventory wrong; `test_flow_usage_log.sh` (version=12 exact + 4 set-sites) invisible to plan | High | Accept — grep-derived inventory; floor assertion | Phases 1, 6 |
| R6 | Topology `cmd` signatures unexecutable (no `check <stage>` verb) | High | Accept — user chose KEEP EXECUTABLE: new read-only `gate <stage>` verb + placeholder set + arg-shape lint + smoke fixture | Phases 3, 4 |
| R7 | `cmd_next` re-scaffolds skipped stage (sandbox-reproduced); stage↔node mapping undefined; DEBT id fabricated | High | Accept — `stage_skipped` guard in `cmd_next` (explicit behavior change), loader mapping + lint, matched-DEBT-text rendering | Phases 3, 5 |
| R8 | Windows CI budget calibrated on cancelled partial run | Medium | Accept — budget restated UNKNOWN; full-green-run gate before Phase 4 | Phase 6, plan SC |
| R9 | Nits: schema_version INSERT tail, verb count 27, `concierge.md:61`, line-range near-misses, drop `--write-pin` | Medium | Accept | Phases 1, 3, 4 |

### Session 3 — 2026-07-26 (final verify, 1 reviewer, Round-2 fixes only)
**Findings:** 6 (1 Critical, 5 High) + 4 medium notes; 11 Round-2 fixes verified clean. All applied same session.

| # | Finding | Severity | Applied To |
|---|---------|----------|------------|
| F1 | Skip-guard must also fix `current_stage_idx` (skip-blind index → planning deadlock at pre-skip stage; 05 never scaffolded) — sandbox-reproduced | Critical | Phase 5 |
| F2 | Phase 4 file list still instructed the `FLOW_PROJECT_ROOT` export the body forbade | High | Phase 4 |
| F3 | Resolver must key on RESOLVED ROOT (env per-call), not CWD; containment guard; per-process cache | High | Phase 1 |
| F4 | Relocating DB orphans `events.jsonl` (`_events_path` pairs with DB dir; flow.sh writes `$ROOT/.flow`) — events sink follows same translation + worktree rollup test | High | Phase 1 |
| F5 | `git log -S` unworkable for DEBT provenance (matches deletions, unscoped, full-history) → `git blame --line-porcelain -L n,n` on current line; same-identity environments degrade documented (always-refuse is a deadlock, not a control) | High | Phase 2, plan SC |
| F6 | Topology executed `check {card}` — a Must-ask, DB-MUTATING verb (story/trace writes on pass) → `gate --card` scan-only variant; mutating verbs lint-banned from autonomous cmd position; smoke fixture isolated + zero-write assertion; no open transaction during node cmds | High | Phase 3 |
| — | Medium notes: merge-base resolution specified (origin/HEAD → main branch → --base); set-site count 16; `gate` added to `_log_is_readonly`; `harness_capture_checked` as output-mode flag not third copy | Medium | Phases 2, 3, 4, 6 |

### Session 4 — 2026-07-26 (narrow verify of Round-3 applications, 1 reviewer)
**Findings:** 3 (1 Critical, 2 High) + 2 medium corrections; 6 verified-clean items. All applied.

| # | Finding | Severity | Applied To |
|---|---------|----------|------------|
| C1 | Blame provenance: worktree line n ≠ HEAD blob line n; `blame HEAD` never emits `Not Committed Yet` → uncommitted-append bypass. Fixed: refuse on ANY uncommitted DEBT.md change (`git diff --quiet HEAD`), locate line in `git show HEAD:DEBT.md`, then blame | Critical | Phase 2, plan SC |
| H1 | `gate --card` example violated the phase's own arg-shape rule; stale `check` shape row read as conditional permission; missing implementation step for the `gate` verb | High | Phase 3 |
| H2 | Events-sink relocation half-splits `.flow` and breaks read-side (foreign-session detector, interleaved-row drops, cycle_id) → corrected to worktree-local sinks + ingest at `workspace remove` + sibling-glob rollup | High | Phase 1 |
| — | Medium: `current_stage_idx` caller list corrected (cmd_status/cmd_resume/cmd_next/_next_action); deleted-successor edge test; citation drift 3679→3674,3681,3682 | Medium | Phases 1, 5 |

### Session 5 — 2026-07-26 (spot check of Round-4 applications, 1 reviewer)
**Findings:** 3 High, 0 Critical (first Critical-free round). All applied.

| # | Finding | Severity | Applied To |
|---|---------|----------|------------|
| H1 | `$debt_line` provenance unpinned: `-Fx` vs constructed-literal mismatch → either always-refuse deadlock or arbitrary-line nomination. Fixed: `$debt_line` = full line captured by (a)'s own DEBT-row match (only provenance; contains validated target by construction) | High | Phase 2 |
| H2 | Example topology disconnected (`card-dispatch`/`card-build`/`must-ask-gate` edge-less) → fails own unreachable rule. Fixed: explicit `entry` roots, dispatch→build→review edges, static interrupt node removed from example (dynamic interrupts via `graph record --interrupt`) | High | Phase 3 |
| H3 | Recycled worktree paths + `rollup_cursor` bare-path key silently swallow lifecycle-2 events; `rollup --src` does not exist and had no owning step. Fixed: lifecycle-unique src key `<path>#<branch>#<created_at>`, `rollup --src/--src-key` scheduled in Phase 1, `_ws_remove` ingest hook + tests scheduled in Phase 4 | High | Phases 1, 4 |

### Session 6 — 2026-07-26 (closing spot check, 1 reviewer)
**Findings:** 3 High, 0 Critical (second consecutive Critical-free round). All applied.

| # | Finding | Severity | Applied To |
|---|---------|----------|------------|
| H1 | Empty `$debt_line` capture → `grep -nFx ""` matches blank lines in HEAD blob → guard passes on absent evidence. Fixed: explicit `[ -n "$debt_line" ] \|\| refuse` | High | Phase 2 |
| H2 | Only stage-03 had a skip bypass edge; skipped 00/01/02/04 dead-end the executor walk (gate node RED on missing file). Fixed: bypass edges for every skippable stage + lint rule requiring them | High | Phase 3 |
| H3 | Dual ingest paths (removal-hook lifecycle key vs periodic glob bare key) → double-count + reintroduced cursor swallow. Fixed: single ingest point at `_ws_remove`; glob dropped; idempotent-reingest SC | High | Phases 1 |

### Session 7 — 2026-07-26 (spot check, 1 reviewer; continued at user request)
**Findings:** 2 High, 0 Critical (third consecutive Critical-free round). Both applied; empty-capture refusal and single-ingest-point verified clean.

| # | Finding | Severity | Applied To |
|---|---------|----------|------------|
| H1 | Bypass edges additive-only: skipped nodes stayed reachable via unguarded default edges; chained skips (reachable — `cmd_skip` has no once-only constraint) dead-ended. Fixed per reviewer-preferred route: skip becomes a `plan_next` TRAVERSAL semantic (transitive successor substitution), all bypass edges deleted, lint rule replaced with skip-powerset reachability assertion, chained-skip fixtures added | High | Phases 2, 3 |
| H2 | `HEAD:DEBT.md` is tree-root-relative vs `$ROOT`-relative steps 1/3 → wrong blob or deadlock under monorepo sub-project root. Fixed: `rev-parse --show-prefix` + `HEAD:${pfx}DEBT.md`; monorepo-sub-root row added to interrupt guard matrix | High | Phase 2 |

### Session 8 — 2026-07-26 (spot check, 1 reviewer)
**Findings:** 2 High, 0 Critical (fourth consecutive Critical-free round; both are textual consistency defects in Round-7 edits). Both applied. Blob-path git semantics, guard-matrix row, skip-walk consistency, registry cleanliness, edge removal all VERIFIED clean.

| # | Finding | Severity | Applied To |
|---|---------|----------|------------|
| F1 | Skip-reachability rule quantified over every entry root (card subgraph can't reach stage-05 → unsatisfiable on shipped example) + subset count 2^4 wrong (5 skippable stages → 2^5=32). Fixed: per-subgraph scoping (planning: stage-00→stage-05 under 32 subsets; card: card-dispatch→card-verify-live) | High | Phase 3 |
| F2 | plan.md SC still carried unprefixed `HEAD:DEBT.md` removed by Round-7 H2 (missed in Session-7 sweep). Fixed: `$ROOT`-relative prefixed form | High | plan.md SC |

### Session 9 — 2026-07-26 (closing check, 1 reviewer)
**Findings:** BOTH Round-8 applications VERIFIED CLEAN; 2 High from commissioned adjacent walks (fifth consecutive Critical-free round). Both applied.

| # | Finding | Severity | Applied To |
|---|---------|----------|------------|
| F1 | Unqualified `stage`-field lint rule → card-review (gate_check, no stage) fails it; likely resolution (placeholder stage) would make review gate skippable sans DEBT row. Fixed: rule scoped per-subgraph; card gate_check nodes MUST NOT declare `stage`; skip mapping covers stage-carrying nodes only | High | Phase 3 |
| F2 | plan.md SC "represented in topology" survived Round-7's design change (sweep grep was too narrow). Fixed: SC restated as plan_next skip-substitution traversal; skip-specific sweep run | High | plan.md SC |

### Whole-Plan Consistency Sweep (Session 9)
- Files reread: plan.md + phase-03 after Round-9 edits
- Skip-design sweep (`represented in topology|bypass edge|skip predicate|stage_debt_skipped`): only Session-1 history delta line remains (audit trail — at that time it WAS the design)
- Unresolved contradictions: 0

### Whole-Plan Consistency Sweep (Session 8)
- Files reread: plan.md + phase-03 after Round-8 edits
- Decision deltas checked: 2 (per-subgraph reachability scoping + 2^5 count; prefixed SC path)
- Reconciled stale references: 0 remaining (`grep "HEAD:DEBT"` → session-log rows only)
- Unresolved contradictions: 0

### Whole-Plan Consistency Sweep (Session 7)
- Files reread: plan.md + phases 02/03 after Round-7 edits
- Decision deltas checked: 2 (traversal-semantic skips replacing edge class; prefix-correct blob path)
- Reconciled stale references: 1 (phase-03 SC line updated to skip-substitution + chained fixture); registry now {review_green, review_red, always}
- Unresolved contradictions: 0

### Whole-Plan Consistency Sweep (Session 6)
- Files reread: plan.md + phases 01/02/03 after Round-6 edits
- Decision deltas checked: 3 (non-empty refusal, full bypass-edge coverage + lint rule, single ingest point)
- Reconciled stale references: 0 new
- Unresolved contradictions: 0

### Whole-Plan Consistency Sweep (Session 5)
- Files reread: plan.md + phases 01/02/03/04 after Round-5 edits
- Decision deltas checked: 3 (captured-line provenance, entry-roots + connected example, lifecycle-keyed ingest)
- Reconciled stale references: 0 new
- Unresolved contradictions: 0

### Whole-Plan Consistency Sweep (Session 4)
- Files reread: plan.md + phases 01/02/03/05 after Round-4 edits (04/06 untouched this round)
- Decision deltas checked: 3 (HEAD-blob provenance, gate shape rule + no check row, ingest-not-relocate)
- Reconciled stale references: phase-03 step renumbering (duplicate step 3); SC security bullet aligned
- Unresolved contradictions: 0

### Whole-Plan Consistency Sweep (Session 3)
- Files reread: plan.md + all 6 phases after Round-3 edits
- Decision deltas checked: 6 (index-level skip-guard, no-export file list, root-keyed cached resolver + containment, events-sink translation, blame-based provenance + documented degradation, gate --card + mutating-verb lint ban)
- Reconciled stale references: phase-06 "9 test files"/"15 set-sites" → grep-derived 16; plan SC security bullet aligned to blame mechanism
- Unresolved contradictions: 0

### Whole-Plan Consistency Sweep (Session 2)
- Files reread: plan.md + all 6 phases after Round-2 edits
- Decision deltas checked: 10 (resolver-level DB pinning w/o FLOW_PROJECT_ROOT, harness_capture_checked + rc 4, explicit merge-record w/ executor-computed ancestry, out-of-band DEBT-commit authority + closed-set targets, grep-derived DISABLE inventory + usage_log floor, executable cmd + `gate` verb + placeholders + shape-lint + smoke, cmd_next skip-guard + stage-field mapping + matched-DEBT rendering, Windows budget = unknown + full-run gate, schema_version INSERT tail, --write-pin dropped)
- Reconciled stale references: 2 ("9 test files" leftovers in phase-06); remaining grep hits contextual only
- Unresolved contradictions: 0
- `ak plan validate`: format valid

### Whole-Plan Consistency Sweep (Session 1)
- Files reread: plan.md, phase-01 … phase-06 (all rewritten this session; phase-05 duplicate-H1 + stray-step defects fixed post-write)
- Decision deltas checked: 9 (migration 013→014, depends_on→deps:, tests/harness/→flat+registered, project_type_skips_prd→stage_debt_skipped, prune→gc, wall-clock→deterministic assertion, python3-probe→_python() reuse, 02-scope→PROJECT_TYPE/.skipped, story_id INTEGER→TEXT)
- Reconciled stale references: all remaining grep hits are contextual (findings log, "does not exist" notes)
- Unresolved contradictions: 0
- `ak plan validate`: format valid

## Validation Log

### Session 1 — 2026-07-26
Verification pass: skipped per guard (Red Team Session 1 carries Full-tier verification evidence; 0 unresolved `[UNVERIFIED]` tags).
Questions asked: 4. Decisions:
1. **Migration band = 014+** (not 020+): GAP-MATRIX floor, contiguous lineage; accepted residual risk of future upstream renegotiation. Propagated to Phase 1 (file name, schema_version 14, inventory strings, band prose).
2. **`FLOW_HARNESS_DISABLE` end-state = hard error** at dispatch post-v1 (confirmed as planned).
3. **Python floor = measured floor** (audit code, document real number; no invented 3.9) (confirmed as planned).
4. **Red-team round 2 = verify-fix, 2 reviewers** (Failure Mode + Assumption lenses) — loop closes when no new Critical/High survives.

### Whole-Plan Consistency Sweep (Validation Session 1)
- Files reread post-propagation: plan.md, phase-01 (7 edits applied); phases 02-06 contain no band references — verified by grep
- Unresolved contradictions: 0

## Open Questions

Resolved during planning + red-team: topology format JSON; card DAG source = existing `deps:` body lines (normalized `C-[0-9]+`); checkpoint retention = `graph gc` with abandoned/age policy (renamed from `prune` to avoid collision with existing harness `prune` verb); migration band + `FLOW_HARNESS_DISABLE` final semantics + Python floor value = confirmed in validation interview (see Validation Log).

<!-- slug: harness-graph-executor-langgraph-port -->
