# Stage 02 — Scope (go/no-go)

Scope = features chosen by IMPACT × COST. The red-team cuts are baked into the cut list.

## Gate — check ALL before `/flow next`
- [x] Every feature below has an IMPACT (H/M/L with the business reason) AND a grade (A/B/C)
- [x] No L-impact feature above grade A survives in v1
- [x] The suggested-features section was actually considered (each suggestion has an in/out decision)
- [x] fit(grades, budget) holds — every C in scope is justified as path 1, 2, or 3 above
- [x] If the product IS a C feature: it is FIRST in build order, and its sibling C features are on the cut list
- [x] The cut list is written (what I am NOT building in v1)
- [x] GO / KILL decision is written below
- [x] No FILL placeholders remain in this file

## Time budget

~3 build sessions (one card per session, sequential — all touch `flow.sh`/`harness`).

## Features in v1 (each with impact AND grade)

- **`accessed_count` read-only recall signal** — impact **M** (retention/ops: surfaces reused
  knowledge, memory hygiene) — grade **B** (1 SQLite column + read-path increment + ordering; the
  migration itself is **Tier-C security-class at build** because it is a *data migration* → operator
  signs off in `DEBT.md`). Build order #1 (lowest logic risk).
- **`/flow constitution` advisory command** — impact **H** (core promise: lets the operator's own
  project law — e.g. "PII facility-scoped" — get a real two-layer gate; extends flow's mission of
  building on enforced evidence) — grade **B** (standalone advisory command reusing the
  `consistency`/`contract` pattern + a semantic challenge section). Build order #2.
- **`assess` repo-map symbol ranking** — impact **H** (directly fixes the CMC blind spot: an
  unranked flat scan hid a cross-facility data-leak risk; ranking serves the "inspect first" law) —
  grade **B via path 2** (the full tree-sitter-dependency version is C; re-architected DOWN to B by
  making tree-sitter an **optional import with graceful glob fallback** — same value, one grade
  cheaper, portability preserved). Build order #3 (highest dep risk → last).

## Suggested features (impact-first — proposed, not decided)

- **Gate self-eval harness** — impact H *in principle* (measure whether gates catch hollow
  artifacts) — grade C — **OUT**. Red-team proved the valuable (semantic) half cannot run in the
  offline `run_all.sh` CI (no LLM). Needs an offline-judge / golden-transcript mechanism first.
- **Session-identity / fencing tokens** for the advisory-only concurrency lock (F1) — impact M —
  grade B/C — **OUT**. Genuine gap, but it's a separate *research* pass, not a build feature yet.
- **Auto-promote a "constitution" playbook to the cross-project KB** — impact L — grade A — **OUT**.
  YAGNI for v1; revisit if multiple projects author constitutions.

## Cut list (NOT in v1 — deferred, not deleted)

- **Gate self-eval harness** — deferred until an offline LLM-judge mechanism exists (red-team).
- **`/constitution` wired into every gate** — CUT. Red-team: hot-path LLM token-tax inverts flow's
  mechanical-first law. Shipped as a standalone advisory command instead.
- **`accessed_count` prune / auto-delete** — CUT. Red-team: deletes rare-but-critical security
  lessons (data-loss bug). Read-only ordering signal only; security-class rows hard-excluded.
- **Session-identity primitives** — deferred to a follow-up research scout.

## Decision

**GO** — three dependency-free, red-team-verified upgrades that extend flow's own laws (advisory
two-layer gate, deterministic local memory, inspect-first ranking); no irreducible C in v1.
