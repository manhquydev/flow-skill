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

`/flow` is a gated build harness whose durable layer (`.flow/harness.db`) is **agent-authored at gate moments only** and whose trace-tier check is advisory — so runs that die between gates, or where the agent skips a trace, leave no record. The runner has no mechanical event log (grep of `runner/flow.sh` finds no append-event writer). This feature adds an automatic, append-only **usage log** written by `flow.sh` itself on every invocation (the one component that runs deterministically every time), plus a rollup + `flow usage` stats view, so the device gains a complete, replayable record of how builds actually go — feeding the existing recall/propose loop. Personal, single-device use.

## Target users

The flow operator (me, this device). Builds many projects via `/flow`; today reconstructs run history by hand from `git log` + memory `.md` files. Wants zero-effort, complete capture that survives dead runs and is queryable.

## Pain & gain (mapping table — the traceability spine)

| # | Persona | Pain (concrete) | Evidence | Today's workaround | V1 feature that kills it | Observable gain |
|---|---|---|---|---|---|---|
| P1 | operator | No record exists unless the agent remembers to write a trace; thin/absent traces routine | `harness/README.md:55,58-66` (agent-authored, advisory tier) | hope a trace got written | **FR1** mechanical event on every invocation | every `flow.sh` call leaves a JSON event with zero agent effort |
| P2 | operator | No device-wide view of how I build across projects | observed: `git log` + memory files only, post-hoc | manual reconstruction | **FR2** dual sink (per-project full + global compact) | one global log aggregates every project's runs |
| P3 | operator | A logging bug could break every flow command | risk of editing the shared runner | n/a | **FR4** no-fail, exit-code-preserving capture | logging failure never alters or breaks a command |
| P4 | operator | Can't measure cycle time / gate fail-rate / kills / abandonment | no replayable per-cycle record (cross-cycle `flow/` reuse, observed this session) | none | **FR5** `cycle_id` + **FR6** rollup + **FR7** `flow usage` | numeric cycle-time, gate fail-rate, kill rate, dwell from real data |
| P5 | operator | Free-text args (`intake --summary`) could write a secret to disk | global rule "never log secrets" | n/a | **FR3** denylist arg masking before disk | secret-shaped args masked in the written line |

### Pains NOT addressed in v1 (tie to scope cut list)
- "Which specific gate check failed" (FILL/box reason) → deferred (R5): needs a body-set global; v1 logs `exit_code`+`gate_pass` only.
- Auto-feeding propose/recall from stats (S-a) → v2, after real data lands.
- Log rotation/retention → deferred; personal volume is low.

## Problem statement

A gated harness with only agent-authored, gate-moment memory has silent gaps; the fix is a mechanical, no-fail, append-only event log written by the runner on every invocation, rolled up into queryable stats — additive and degradable so it never changes existing behavior.

## Features (action → observable result; stable `FRn:` ids)

- **FR1:** As the operator, when I run any `flow.sh` command, the runner appends one well-formed JSON event (ts, session, cycle, command, exit_code, gate_pass, duration_s, stage, card, type, mode, version, tier, host, read_only) — automatically, without me or the agent doing anything.
- **FR2:** As the operator, each event is written full to `.flow/events.jsonl` (per-project) and compact to `~/.claude/flow/usage.jsonl` (device-global), so I see both per-project detail and a cross-project view.
- **FR3:** As the operator, any arg matching a secret/token/credential/password denylist is masked before the line hits disk.
- **FR4:** As the operator, if a sink is unwritable (or any logging step errors), the flow command still completes with its original exit code and output unchanged.
- **FR5:** As the operator, events carry a `cycle_id` stamped when stage 00 unlocks, so events group into one build cycle for cycle-time/abandonment analysis.
- **FR6:** As the operator, I roll up JSONL into the `usage_event` table idempotently (re-running never double-counts), via the existing harness Python.
- **FR7:** As the operator, I run `flow usage` and see numeric cycle-time, gate fail-rate, kill rate, and per-stage dwell from real events.

## Non-functional requirements
- **No-fail / exit-code-preserving** (load-bearing): writer wrapped `{ …; } 2>/dev/null || true`; EXIT trap captures `$?` first, re-exits unchanged.
- **Portability:** no GNU-only `date`/grep constructs; seconds granularity (`date +%s`); scan for GNU-only flags before review.
- **Degradable:** `FLOW_LOG_DISABLE=1` disables; missing global dir created best-effort, failure silent. Reuse existing best-effort idiom.
- **DRY:** no new generic event table; semantic events reuse `intervention`/`decision`/RETRO.md. Only the mechanical `usage_event` mirror is added.

## Tech stack

No new runtime deps. POSIX sh additions to `runner/flow.sh` (the SOURCE copy at `D:\project\flow\flow-skill\skills\flow`, not the installed running copy) — `_log_event`, EXIT trap, dual append. Python stdlib `sqlite3` for migration 006 (`usage_event`) + rollup + `flow usage`, in `harness/`. Tests as bash files alongside the existing dev suites. Verify via a real `flow.sh` run + reading the JSONL/stats.

## Success metric (numbers only)

1. A real `flow.sh` invocation appends ≥1 schema-valid JSON event to BOTH sinks (asserted by test).
2. An arg matching the denylist appears MASKED (0 plaintext secret tokens) in the written line (test).
3. A forced unwritable sink leaves exit code identical and stdout intact (test) — 0 broken commands.
4. `flow usage` prints ≥4 distinct numeric metrics from ≥1 real cycle's events.
5. All existing dev suites stay green + new tests green → 0 regressions.
6. Portability scan reports 0 GNU-only constructs in the new runner code.
