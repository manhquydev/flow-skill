# Stage 02 — Scope (go/no-go)

Scope = features chosen by IMPACT × COST, inside your time budget.
KILL here is cheap and smart. Killing a weak idea at this gate is a SUCCESS outcome.

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

One focused session (this build). 6 small-to-medium fixes to an existing, well-understood codebase with research already done.

## Features in v1 (each with impact AND grade)

- **D1 — `usage --global` forwards `--global` to rollup** — impact **H** (core promise: the device-wide view is the headline of the feature; broken = feature dead) — grade **A** (one-line flag forward + regression test).
- **D2 — `cycle_id` stamped at all entry points** (assess + lazy-if-absent, reusing existing `CYCLE_FILE`) — impact **H** (unblocks ALL cycle analytics on real brownfield builds; without it 4 metrics read 0) — grade **A/B** (reuse existing mechanism, no new deps).
- **D3 — real wall-clock per-stage dwell** computed from existing `stage_from/to`+`epoch_s` — impact **M** (answers "where do builds stall"; depends on D2) — grade **B** (analytics query change in `cmd_usage`, no schema/table change).
- **D4 — auto-derive `session_id`** from `CLAUDE_CODE_SESSION_ID`/Codex/AGY/PPID + `kill -0` lock liveness — impact **H** (makes the concurrency lock actually block — prevents plan corruption, the lock's whole reason to exist) — grade **B** (env cascade + liveness check; verified primitives present).
- **D6 — `ephemeral` tag + default-exclude test runs** (write-time field + retro `tmp.*` read-filter) — impact **M** (removes 83% noise so device analytics are trustworthy) — grade **A/B** (field + read filter, zero migration via name-pattern fallback).
- **D5 — enrich device-global log so failures are explainable** (`gate_fail_reason` + key fields) — impact **M** (device-wide "why gates fail") — grade **B** *path 2*: re-architected the hard C-version (flock/SQLite, **flock verified absent**) DOWN to B — **interim: enrich the single global line + bounded truncation**, accepting the de-facto small-append atomicity that already exists (F5 shows real concurrency ≈ 1 session). Full per-shard sink is deferred to v2.

## Suggested features (impact-first — proposed, not decided)

- **Behavioral study of `skip`=90 / `consistency`=158 signals** — impact L (insight, not a fix) — grade A — **OUT**: it's analysis, not a defect; revisit after v0.11 data is trustworthy.
- **Migrate global sink to per-shard files (no-lock concurrency)** — impact M — grade C — **OUT** (deferred to v2): only justified if multi-session use becomes common; D5 interim covers the need now.
- **Migrate JSONL→SQLite WAL canonical sink** — impact M — grade C — **OUT** (deferred): large migration, revisit at "v1.0".

## Cut list (NOT in v1 — deferred, not deleted)

- Per-shard global logs + merge-at-rollup (v2 — only if concurrency rises).
- SQLite-WAL canonical sink (v1.0 — big migration).
- New-cycle lifecycle policy beyond "one cycle per project dir" (YAGNI until needed).
- Behavioral investigation of skip/consistency usage (separate study).
- Codex/Antigravity session-var name confirmation (use best-effort cascade now; refine when those engines run).

## Decision

**GO** — six real, evidence-backed defects in shipped telemetry; five are grade A/B and cheap, the one C-risk (D5) was re-architected down to B by deferring shards. This makes the usage-log trustworthy as the basis for all future flow improvement.
