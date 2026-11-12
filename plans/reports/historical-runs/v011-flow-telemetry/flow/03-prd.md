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

flow v0.10.2 ships a usage-log (JSONL flight-recorder → SQLite rollup → `/flow usage` analytics). An audit of real logs (CMC, C2-App-001, 1739-line device-global) proved the analytics are empty or misleading on real usage. v0.11.0 fixes the six defects so the telemetry is correct, honest, and decision-grade. This is a brownfield change to `skills/flow/runner/flow.sh` and `skills/flow/harness/flow_harness.py`; the contract is the existing event schema + the `usage`/`rollup` command behavior.

## Target users

The flow skill operator (and any flow user who runs `/flow usage`, `/flow recall`, or relies on the concurrency lock). Behavior: drives mostly brownfield, agent-driven builds; rarely exports env vars manually.

## Pain & gain (mapping table — the traceability spine of the PRD)

| # | Persona | Pain (concrete) | Evidence | Today's workaround | V1 feature that kills it | Observable gain |
|---|---|---|---|---|---|---|
| P1 | operator | `usage --global` says "no events" despite 1739 lines | flow.sh:1391 omits `--global` on rollup | manual `rollup --global` then `usage --global` | **FR1** forward `--global` to rollup | `usage --global` returns analytics in one command |
| P2 | operator | cycle metrics read 0 on real builds | cycle_id empty 100% CMC+C2 (stamped only flow.sh:426) | none — metrics ignored | **FR2** stamp cycle_id at assess + lazily if absent | cycle-time/completion populate on brownfield |
| P3 | operator | "dwell" = script exec time, can't see stalls | all dwell avgs 1-2s | none | **FR3** compute dwell from stage transitions + epoch_s | wall-clock time-in-stage reported |
| P4 | operator | lock never hard-blocks; session_id empty 92% | 1599/1739 empty session_id | hope no 2nd session | **FR4** auto-derive session_id + `kill -0` liveness | lock blocks a real foreign session |
| P5 | operator | device analytics 83% test noise | 1449/1739 events from tmp.* | mental filtering | **FR5** tag ephemeral + default-exclude | rollup shows real projects by default |
| P6 | operator | can't explain gate failures device-wide | global drops gate_fail_reason (flow.sh:1363) | grep per-project logs | **FR6** enrich global line w/ bounded gate_fail_reason | device-wide failure reasons visible |

### Pains NOT addressed in v1 (deliberate — tie to the scope cut list)

- High `skip`/`consistency` usage interpretation → separate behavioral study (not a defect).
- Multi-session-safe per-shard global sink → v2 (only if concurrency rises; FR6 interim covers the need).
- SQLite-WAL canonical sink → v1.0 (large migration).

## Problem statement

flow's shipped usage-log produces empty/misleading analytics on real (brownfield, agent-driven) usage, so it cannot be trusted as the basis for improving the skill. v0.11.0 makes every shipped telemetry metric correct and honest.

## Features (user-centric — action → observable result)

- **FR1**: As the operator, I run `/flow usage --global` once, and I see device-wide analytics (no manual pre-rollup).
- **FR2**: As the operator, I run `/flow assess` (or any command) on a brownfield project, and every logged event carries a non-empty `cycle_id`.
- **FR3**: As the operator, I run `/flow usage`, and per-stage dwell shows wall-clock time spent in each stage (computed from stage transitions), labeled distinctly from command exec time.
- **FR4**: As the operator, I run any `/flow` command in an agent session, and `session_id` is auto-populated; a second concurrent session is hard-blocked (and a dead session's lock is reclaimed via PID-liveness).
- **FR5**: As the operator, I run `/flow usage --global`, and throwaway `tmp.*`/temp-dir runs are excluded by default; `--include-ephemeral` shows them.
- **FR6**: As the operator, I run `/flow usage --global` after a gate failure, and I can see the failure reason (bounded) in the device-global aggregate.

## Non-functional requirements

- No new runtime dependencies (POSIX sh + Git-Bash-on-Windows + Python 3 stdlib only).
- Backward-compatible: the existing 1739-line global log and existing per-project logs must still roll up without corruption (no destructive schema break; new fields optional).
- All existing test suites must stay green; each behavioral fix adds a regression test.

## Tech stack

Shell: `skills/flow/runner/flow.sh` (POSIX sh / Git Bash). Harness: `skills/flow/harness/flow_harness.py` (Python 3 stdlib, sqlite3). Tests: existing `tests/` bash suites. Deploy target (skill): installed into `~/.claude/skills` and a real `flow.sh` run reaches its done-definition.

## Success metric (numbers only)

On a fresh brownfield `assess`→`next`→`card` cycle in a temp project after v0.11.0:
- `cycle_id` non-empty on **100%** of new events (was 0%).
- `session_id` non-empty on **100%** of new invocations (was ~8%).
- `flow usage --global` returns **≥1** event with **0** manual pre-rollup steps (was always "no events").
- default `usage --global` excludes **100%** of `tmp.*` events; `--include-ephemeral` includes them.
- **0** existing test-suite regressions; **≥4** new regression tests (FR1, FR2, FR4, FR5) green.
