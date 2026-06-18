# Stage 03 — PRD

1-2 pages max. Test: could a stranger build v1 from this without asking you anything?

## Gate — check ALL before `/flow next`
- [x] Every section below is filled from MY scope decision (stage 02), not re-expanded
- [x] Success metric is a NUMBER, not vibes
- [x] Each feature names the user action and the observable result, tagged with a stable `FRn:` id
- [x] Pain & gain is a MAPPING TABLE: every pain cites evidence and names the v1 feature that kills it; every v1 feature kills at least one pain
- [x] A stranger could build v1 from this without asking me anything
- [x] No FILL placeholders remain in this file

## Context

v0.9.0 added a mechanical usage log that records every `flow.sh` invocation but nothing consumes it. This increment closes the capture→reuse loop by feeding the recorded `usage_event` data into the two surfaces where the operator already acts — `recall` (start of stage/card) and `propose` (retro) — plus a prune for the unbounded log and a captured gate-fail reason so "stage X fails" is diagnosable. Additive and degradable; no behavior change when usage data or python is absent. Personal, single-device use.

## Target users

The flow operator (me, this device). Builds many projects via `/flow`; wants the recorded build history to surface automatically and turn into improvements, without manually running `flow usage`.

## Pain & gain (mapping table)

| # | Persona | Pain (concrete) | Evidence | Today's workaround | V1 feature | Observable gain |
|---|---|---|---|---|---|---|
| P1 | operator | Recorded usage data never reaches working context | `recall` printed "no project-specific history yet" with events.jsonl present | manually run `flow usage` | **FR1** usage-aware recall | `recall` shows cycle-time + top gate-fail stage automatically |
| P2 | operator | Recurring mechanical gate friction produces no improvement proposal | `_build_proposals` reads friction/intervention/audit only | notice it by hand | **FR2** usage→propose | a high-fail stage emits a committable backlog proposal |
| P3 | operator | Global JSONL grows unbounded (rotation cut from v1) | quality-metrics open follow-up "global-log rotation" | nothing | **FR3** `flow usage --prune` | log capped to last N lines, crash-safe |
| P4 | operator | `gate_pass` is a bare bool — can't tell WHICH check failed | v1 R5 deferred | read the stage file by hand | **FR4** gate-fail reason capture | event carries `gate_fail_reason` (fill/unchecked counts) |

### Pains NOT addressed (deliberate — tie to scope cut list)
- Sub-second timing (#3b) → WONTFIX: seconds is the portability-correct choice (`%N` is GNU-only).
- trace-tier auto-population (#3c/DF-4) → separate harness-DX increment, not this loop.
- Usage trend arrows / dashboard (S-x/S-y) → deferred (YAGNI; needs more data / not worth the surface).

## Problem statement

The usage log is write-only; close the loop by surfacing its data in `recall`, turning recurring gate-fail into `propose` backlog items, bounding the log with a prune, and recording why a gate failed — all additive and no-fail.

## Features (action → observable result; stable `FRn:` ids)

- **FR1:** As the operator, when I run `flow.sh recall`, I see a compact usage summary (median cycle-time, top gate-fail stage(s), cycles started vs reached-cards) read from `usage_event` — or nothing extra if there is no data / no python (recall never breaks).
- **FR2:** As the operator, when I run `flow.sh propose`, a stage whose gate fail-rate is high across ≥N recorded cycles produces a backlog proposal I can commit (heuristic, surfaced not auto-applied).
- **FR3:** As the operator, when I run `flow.sh usage --prune [--keep N]`, each JSONL sink is capped to its last N lines via a crash-safe atomic rewrite (default keep, e.g., 5000), and I see how many lines were dropped.
- **FR4:** As the operator, when a `next`/`check` gate fails, the recorded event's `gate_fail_reason` names the failing checks (e.g. `fill:2,unchecked:1`); the gate's own control flow and exit code are unchanged.

## Non-functional requirements
- **No-fail / exit-code preserving:** FR1/FR4 must never break or alter `recall`/`next`/`check`; FR2 must not break `propose`. Best-effort, degrade silently without usage data or python.
- **Portability:** seconds granularity; no GNU-only constructs; crash-safe prune (temp + atomic replace, never lose the live tail).
- **Honest heuristic (FR2):** the fail-rate threshold + min-cycles is a surfaced proposal for the operator to judge, never an auto-change; documented as a heuristic, not a magic number.
- **DRY:** reuse `usage_event`/rollup + the existing `recall`/`propose`/`_build_proposals` surfaces; no new parallel mechanism.

## Tech stack

No new deps. POSIX sh additions to `runner/flow.sh` (cmd_recall summary call; a `FLOW_LAST_GATE_FAIL` export in the gate path read by `_log_event`; `usage --prune` dispatch). Python stdlib in `harness/flow_harness.py` (a `usage --summary` mode for recall; a usage branch in `_build_proposals`; a `prune` routine). SOURCE skill `D:\project\flow\flow-skill\skills\flow`. Verify via real runs + the test suite.

## Success metric (numbers only)

1. After ≥1 recorded cycle, `flow.sh recall` prints ≥3 usage figures (cycle-time, top gate-fail stage, cycle completion) — asserted by test.
2. A seeded high-fail stage (≥ threshold over ≥N cycles) yields ≥1 `propose` backlog row referencing that stage — asserted by test.
3. `usage --prune --keep K` on a sink with K+M lines leaves exactly K lines and reports M dropped — asserted by test.
4. A failing `next` records a non-empty `gate_fail_reason`; a passing one records empty/null; `next` exit codes unchanged — asserted by test.
5. recall/propose/next behave identically (byte-for-byte on the non-usage output) when `FLOW_HARNESS_DISABLE=1` or no data — asserted by test.
6. Full suite stays green (≥386 + new) → 0 regressions; coherence clean at the new version.
