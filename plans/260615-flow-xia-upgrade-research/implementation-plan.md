# flow xia-upgrade — implementation plan (2026-06-15)

Post-red-team build plan for the confirmed upgrades. **Research + red-team are done; this is
the plan. No code written yet.** Operator-confirmed scope: 3 build items (reshaped per
red-team), self-eval DEFERRED, session-identity scout as follow-up.

## Why these (red-team-verified, grounded in flow source)
- All 3 are **grep-proven genuinely-new** in flow — not redundant (red-team A, 92–95% conf).
- 2 were **reshaped to obey flow's laws**: constitution → advisory command (not gate hot-path);
  accessed_count → read-only signal (not prune — prune was a data-loss bug vs the
  "rare-but-critical security lesson" rule).
- repo-map **promoted** from PLAN: the only candidate tied to a real observed flow failure
  (CMC cross-facility leak) and already on flow's committed backlog.
- Anti-FOMO verified clean: no bucket decision hinged on a (possibly fabricated) star count.

Full evidence: `flow-xia-upgrade-decision-report.md` + the 3 red-team findings (this session).

## Phases (SEQUENTIAL — all touch `flow.sh`/`harness`, no parallel-safe split)
Recommended build order = **risk ascending**. **STATUS: all SHIPPED in flow 0.7.0 (2026-06-16)** —
built via the dogfooded `/flow` run (`flow-run/`), each Codex-reviewed, 18 suites green, installed + verified live.

| Order | Phase | Item | Effort | Risk | Status |
|--|--|--|--|--|--|
| 1 | [phase-02](phase-02-recall-accessed-count-signal.md) | `accessed_count` read-only recall signal | XS | Low | ✅ C-001 done |
| 2 | [phase-01](phase-01-flow-constitution-advisory.md) | `/flow constitution` advisory command | M | Low–Med | ✅ C-002 done |
| 3 | [phase-03](phase-03-assess-repo-map-ranking.md) | `assess` repo-map ranking (refined: stdlib ranker, no tree-sitter dep) | M–H | Med | ✅ C-003 done |

Each phase is independently shippable: feature branch → new test suite → `code-reviewer`
(APPROVE) → merge → version bump + `flow coherence`.

## Deferred (NOT this round)
- **Gate self-eval harness.** Red-team proved it can't run in offline `run_all.sh` CI — semantic
  gates are Claude judgments needing an LLM the test rig has no access to. Metric *definitions*
  already exist in `docs/quality-metrics.md:202-220` (gate false-pass <1%, false-block <2%).
  **Revisit trigger:** a sanctioned offline LLM-judge / golden-transcript mechanism exists.
  Until then it is a manual dev ritual, not a portable test asset. Do not build now.

## Follow-up (separate research task, not a build phase)
- **Session-identity / fencing-token scout.** flow's top live finding F1 — concurrency lock is
  *advisory-only* (`SKILL.md:67-74`, "can only warn, can't prove a different session") — was
  never matched against durable session-identity primitives (LangGraph `thread_id`, Temporal
  execution-identity, fencing tokens). Distinct from crash-resume. Worth its own research pass.

## Cross-cutting constraints (every phase)
- **Portability:** pure bash + python-stdlib; any heavier dep (tree-sitter) OPTIONAL with
  graceful degradation. Windows Git Bash + macOS + Linux + Codex `.cmd` tier parity.
- **No hot-path coupling:** follow the advisory-command pattern (`consistency`/`tokens`/
  `contract`/`coherence`). Never wire a new check into `cmd_next`.
- `flow.sh` is already ~1209 lines — keep additions cohesive; push non-trivial logic into
  `harness/` python helpers.
- **Code-comment / naming law:** migrations, tests, and code comments must NOT reference phase
  numbers or finding codes — domain slugs only (`005-accessed-count.sql`,
  `test_flow_constitution.sh`). Explain the *why* (the invariant), not the plan origin.
- Never edit `_templates/` or `flow.sh` of a *project under test* during a run; this plan edits
  the **flow skill's own** source, which is the legitimate target here.

## Done-definition (whole plan)
All 3 commands behave per spec and degrade gracefully; 3 new test suites green; full
`run_all.sh` green with zero regression to the existing 16 suites; version + `docs/` synced;
no new lint/syntax errors; public command surface documented in `SKILL.md`.
