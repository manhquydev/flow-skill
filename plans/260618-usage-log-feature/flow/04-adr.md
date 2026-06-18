# Stage 04 — ADR (architecture decisions)

Short. The most valuable section is what you are NOT doing and why.

## Gate — check ALL before `/flow next`
- [x] Each decision has a one-line "why" and a one-line "what I rejected"
- [x] The NOT-doing list is written
- [x] Decisions cover: data storage, auth approach, deploy target
- [x] No FILL placeholders remain in this file

## Decisions

| # | Decision | Why | Rejected alternative |
|---|---|---|---|
| 1 | **Storage: append-only JSONL as source of truth; SQLite `usage_event` is a derived rollup** | JSONL append is crash-safe, lock-free, grep-able, survives schema errors; line-recoverable on read | SQLite as primary write per invocation — adds lock contention + a failure surface on the hot path (would violate FR4 no-fail) |
| 2 | **Capture point: one `_log_event` + a single EXIT trap in `flow.sh`** (the source copy) | the runner is the only component that runs deterministically on every invocation; trap guarantees exit_code+duration even on early `exit` | logging from the semantic layer (Claude) — non-deterministic, the exact gap we are closing |
| 3 | **No-fail contract: writer `{ …; } 2>/dev/null \|\| true`; trap reads `$?` first, re-exits unchanged** | a logging bug must never break/alter any flow command (R2) | best-effort-but-unwrapped — a bad redaction/append could change exit code |
| 4 | **Dual sink: full event → per-project `.flow/events.jsonl`; compact event → global `~/.claude/flow/usage.jsonl`** | global is written by all sessions concurrently → compact lines stay <PIPE_BUF so O_APPEND stays atomic (R4) | one shared full log — long lines (`--summary`, file lists) can exceed PIPE_BUF and interleave/corrupt |
| 5 | **Time in SECONDS (`date +%s`)** | matches existing `_now()`; `%N` ms is GNU-only → portability-law violation (R1) | millisecond duration — non-portable on BSD/macOS date |
| 6 | **Semantic events reuse `intervention`/`decision`/RETRO.md; only mechanical `usage_event` table is new (R3)** | avoids a 6th durable stream overlapping `trace`; keeps mechanical vs semantic cleanly separated | new generic `event` table + `harness event` subcommand — DRY violation, fragments durable layer |
| 7 | **"Deploy target" = installed skill + a real run writes events** (skill-type done-evidence) | skill ships by install into `~/.claude/skills`; done = a live `flow.sh` run produces a valid event line | a web deploy/URL — N/A for a skill |
| 8 | **Redaction = denylist regex mask, de-rated to hygiene (R7)** | flow.sh args are mostly `next`/`card`/`check`; only free-text `--summary` is a real vector | treating it as security-class C work — over-engineered for the actual arg surface (mask still ships) |
| 9 | **Honor `DO_NOT_TRACK` env + log is local-only, never transmitted (I-A)** | DO_NOT_TRACK is a free-standing, zero-cost standard env; cheap hygiene, NOT trend-driven | OTel GenAI semconv field-naming / OTLP export (I-B) — rejected as technical FOMO: no credible numbers, LLM-call-shaped not harness-lifecycle-shaped |

## NOT doing in v1 (and why it's safe to skip)

- **No new generic `event` table / `harness event` subcommand** — semantic events already have homes; only `usage_event` (mechanical mirror) is added.
- **No "which gate check failed" reason capture** — needs a body-set global; v1 logs `exit_code`+`gate_pass`. Safe: the pass/fail bool already enables fail-rate stats.
- **No log rotation/retention** — personal volume is low; revisit when file size is a real problem.
- **No OTLP/external telemetry, no HTML dashboard** — single device; `flow usage` text view suffices.
- **No auto-feed into propose/recall** — land the data first (v2); reading is decoupled from writing.
- **No millisecond timing** — seconds is enough for cycle-time analytics and stays portable.
