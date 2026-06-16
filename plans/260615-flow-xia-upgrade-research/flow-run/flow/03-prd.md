# Stage 03 — PRD

## Gate — check ALL before `/flow next`
- [x] Every section below is filled from MY scope decision (stage 02), not re-expanded
- [x] Success metric is a NUMBER, not vibes
- [x] Each feature names the user action and the observable result, tagged with a stable `FRn:` id
- [x] Pain & gain is a MAPPING TABLE: every pain cites evidence and names the v1 feature; every feature kills a pain
- [x] A stranger could build v1 from this without asking me anything
- [x] No FILL placeholders remain in this file

## Context

`flow` is a portable, gated build-harness skill (v0.6.3) used by its maintainer to drive real
builds (CMC Odoo ERP, `flowstat`). It already absorbed the 2025–26 agentic research; a 4-domain
research + 3-verifier red-team pass identified 3 dependency-free upgrades that extend flow's own
laws. This PRD specifies those 3 for a v1 increment; everything heavier was cut as FOMO or deferred.

## Target users

The flow-skill maintainer + any operator driving `/flow` (solo builders, small teams). Behavior:
runs `/flow` stages from a terminal on Windows Git Bash / macOS / Linux and inside Codex.

## Pain & gain (mapping table — the traceability spine)

| # | Persona | Pain (concrete) | Evidence | Today's workaround | V1 feature that kills it | Observable gain |
|---|---|---|---|---|---|---|
| P1 | operator | gates can't enforce an operator-authored project rule (e.g. "PII facility-scoped") | red-team grep: no `constitution\|invariant` concept in `skills/flow` (92%) | manual memory / nothing | **FR1** `/flow constitution` | a seeded invariant violation is flagged by the command |
| P2 | operator | `recall` can't tell a reused decision from a never-recalled one | `cmd_recall` (`flow.sh:710-737`) is read-only, never increments (95%) | none | **FR2** `accessed_count` signal | recall surfaces reused items first; reuse is counted |
| P3 | operator / reviewer | flat `assess` scan gives no signal which surfaces matter — a cross-facility data-leak risk hid in it | CMC assess finding R1 (`memory: flow-cmc-odoo-assess`) | scarce manual senior review | **FR3** `assess` repo-map ranking | the high-reference data-flow surface ranks in the top-N of `00-inspect.md` |

### Pains NOT addressed in v1 (deliberate — tie to cut list)
- Measuring whether the gates themselves catch hollow artifacts → gate self-eval harness deferred
  (needs offline LLM-judge infra; red-team).
- Concurrency-lock can only *warn*, not prove a foreign session (F1) → session-identity research scout.

## Problem statement

flow needs to keep improving on red-teamed evidence (enforce operator law, know which memory is
reused, rank what to inspect) without adopting the heavyweight infra that breaks its portability.

## Features (user-centric — action → observable result)

- **FR1:** As an operator, I run `/flow constitution` and I see a clean exit on a valid
  `flow/constitution.md`, a fail on a leftover placeholder token or a missing-ID, and advisory
  warnings for unmet invariant markers — a standalone advisory command, never wired into `/flow next`.
- **FR2:** As an operator, I run `/flow recall` and the harness increments `accessed_count` for
  surfaced rows and orders output most-reused-first — and no row is ever deleted by this signal.
- **FR3:** As an operator, I run `/flow assess` and `flow/00-inspect.md` is seeded with a ranked
  repo-map (stdlib reference-count ranker — Aider's ranking idea, no tree-sitter dependency), and
  falls back to the flat glob scan (no error) when python/helper is absent.

## Non-functional requirements

- Portability: runs on Windows Git Bash + macOS + Linux + Codex `.cmd`; no new REQUIRED dependency
  (tree-sitter optional). Graceful degradation on every path.
- `/flow constitution` adds zero cost to the `cmd_next` hot path.
- `accessed_count` migration is back-compatible with existing project DBs; security-class rows
  hard-excluded from any deprioritization.
- The existing 16 test suites stay green; each FR ships with its own new suite.

## Tech stack

Runner: POSIX bash (`runner/flow.sh`). Durable layer: Python 3 stdlib + `sqlite3`
(`harness/`). Optional: `tree-sitter` (degrades to globs). Artifacts: markdown templates.
Deploy target: installed into `~/.claude/skills/flow` (+ `~/.codex/skills/flow`); no network.

## Success metric (numbers only)

- 3 new test suites added; full `run_all.sh` ≥ 19 suites green with **0 regressions** to the 16.
- FR1: ≥1 seeded constitution violation flagged; `cmd_next` call-graph shows **0** constitution calls.
- FR2: a test asserts `accessed_count` increments on recall AND **0 rows deleted** by the feature.
- FR3: with tree-sitter absent (CI default), `assess` exits 0; with it present, the seeded
  high-reference file appears in the top-5 ranked surfaces.
