# Stage 02 — Scope (go/no-go)

Scope = features chosen by IMPACT × COST, inside your time budget.
KILL here is cheap and smart. Killing a weak idea at this gate is a SUCCESS outcome.

## Impact rubric
(unchanged — see template)

## AI coding grade rubric
(unchanged — see template)

## Gate — check ALL before `/flow next`
- [x] Every feature below has an IMPACT (H/M/L with the business reason) AND a grade (A/B/C)
- [x] No L-impact feature above grade A survives in v1
- [x] The suggested-features section was actually considered (each suggestion has an in/out decision)
- [x] fit(grades, budget) holds — every C in scope is justified as path 1, 2, or 3 above (written next to the feature)
- [x] If the product IS a C feature: it is FIRST in build order, and its sibling C features are on the cut list
- [x] The cut list is written (what I am NOT building in v1)
- [x] GO / KILL decision is written below
- [x] No FILL placeholders remain in this file

## Time budget

~1 focused session (this session). Additive markdown + ~150 lines shell + ~120 lines Python + tests.

## Features in v1 (post-red-team — built as 3 cards)

Per-event fields (mechanical, aggressive): `{ts, epoch_s, session_id, cycle_id, project, command, args(masked), exit_code, gate_pass, duration_s, stage_from→to, card, project_type, mode, flow_version, tier, host, read_only}`. **Duration in SECONDS** (R1 — `%N` ms is GNU-only, violates portability law; codebase uses `date +%s`).

- **C1 = F1+F2+F3 — Mechanical log + dual sink + mask.** `_log_event` + a single EXIT trap (captures `$?` on its FIRST line, re-exits unchanged) self-records every invocation to JSONL. Full event → per-project `.flow/events.jsonl`; **compact** event → device-global `~/.claude/flow/usage.jsonl` (R4 — global is written by all sessions; compact lines stay <PIPE_BUF to avoid interleave). Args masked by a denylist regex before disk (R7 — hygiene, not security-class). `cycle_id` stamped when stage 00 unlocks (R6). Impact **H** (core promise; only complete+replayable record). Grade **B**. Built FIRST.
- **C2 = F5 (+ the durable sliver of F4) — Rollup + `flow usage` stats.** Idempotent rollup (cursor by byte-offset/ts, R-rollup) of JSONL into a dedicated `usage_event` table (migration 006). `flow usage` prints cycle-time (idea→deploy via `cycle_id`), gate fail-rate, kill rate, per-stage dwell, abandonment. Impact **M**. Grade **B**.
- **C3 — Tests + portability + docs + version.** Tests: event line appears with expected fields · arg masking works · **no-fail** (unwritable sink → command still succeeds, exit code preserved) (R2) · **portability scan** for GNU-only flags before review (retro lesson). Update README/SKILL.md + bump version. Impact **M** (gate parity / no regression). Grade **A/B**.

### Dropped/changed by red-team
- **F4 generic `event` table → DROPPED (R3, DRY).** Semantic events (gate verdict, kill, retro) reuse existing `intervention`/`decision`/RETRO.md; no new `harness event` subcommand. Only the mechanical `usage_event` mirror is added (in C2).
- **"which gate check failed" → SPLIT OUT (R5).** v1 logs `exit_code`+`gate_pass` only; capturing the FILL/box reason needs a body-set global → deferred to a small follow-up, not in the 3 cards.

## Non-functional requirements (load-bearing)
- **No-fail (R2):** logging is best-effort; never alters a command's exit code or breaks it. Writer wrapped `{ …; } 2>/dev/null || true`; trap reads `$?` first, re-exits with it.
- **Portability (R1, retro):** no GNU-only `date`/grep constructs; seconds granularity; scan before review.
- **Degradable:** `FLOW_LOG_DISABLE=1` turns it off; absence of `~/.claude/flow/` is created best-effort, failure is silent.

## Suggested features (considered, default OUT)
- **S-a — Auto-feed `propose`/`recall` from usage stats.** Impact M, grade B. **OUT** — land log+stats first; v2 once real data exists.
- **S-b — OTLP/external telemetry export.** Impact L, grade C. **OUT** — no backend, personal use, YAGNI.
- **S-c — TUI/HTML dashboard.** Impact L, grade B. **OUT** — `flow usage` text suffices.

## Cut list (deferred, not deleted)
- Auto propose/recall wiring (S-a) · OTLP export (S-b) · visual dashboard (S-c) · log rotation/retention · `doctor` log-probe · "which gate check failed" reason capture (R5).

## Decision

**GO** — 3 cards (C1 mechanical core first, C2 rollup+stats, C3 tests/portability/docs). Red-team R1–R9 folded in: seconds not ms, no-fail NFR, dropped the overlapping `event` table, compact global sink, `cycle_id`, redaction de-rated. Everything additive + degradable; zero change to existing behavior when disabled or on failure.
