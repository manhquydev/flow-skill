# flow self-upgrade dogfood — run findings (2026-06-16)

Dogfooded `/flow` on the flow skill itself to drive the 3 red-teamed upgrades (constitution,
accessed_count, assess repo-map) through the gated pipeline. Run root:
`plans/260615-flow-xia-upgrade-research/flow-run/`. Stopped at **cards-created** (operator chose
"plan → cards, then stop" — no code built). Planning gates 00→05 all PASS; `consistency` green.

## What worked (validated by the run)
- Full gate walk Idea→Research→Scope→PRD→ADR→Contract passed mechanically + semantically.
- `consistency` correctly went CRITICAL (3 uncovered FR) before cards existed, then GREEN once
  C-001/2/3 declared `implements: FRn` + the contract served each. The traceability spine works.
- Harness `decision add` recorded the 3 load-bearing red-team decisions durably.
- `ready` surfaced all 3 cards as buildable and exposed their allowed-file overlap (shared
  `flow.sh`/`run_all.sh`/`SKILL.md`) so the operator can see they are NOT parallel-safe.

## Findings (actionable bugs/gaps in the flow runner)

| ID | Severity | Where | Finding | Suggested fix |
|----|----------|-------|---------|---------------|
| DF1 | Medium (design gap) | stage state machine | A project whose planning is already `done` (original v0.6.3 build: all 10 cards done) has **no second-cycle / epic concept** for a new feature increment. Had to spin up a separate run root. | Add a `/flow increment` (or epic) that re-opens a fresh planning cycle in-place, preserving history — or document the fresh-root pattern as the supported path. |
| DF2 | Medium (correctness) | `cmd_project_type` / `cmd_mode` (≈`flow.sh:566,583`) | When `FLOW_PROJECT_ROOT` dir does not exist, the settings-file write fails (`No such file or directory`) but the runner still prints **`PASS`** — a silent write-failure reported as success. | Create the root dir if missing, or check the write's exit status and FAIL loudly. |
| DF3 | Low-Med (false positive) | `[FILL]` placeholder check (gate scan) | The check is a naive substring match for `[FILL]`. It hard-failed (exit 1) on a **legitimate mention** of the token in PRD prose (describing FR1 behavior), blocking advance. | Anchor the match to template lines (e.g. `[FILL:` with the colon, or only inside known placeholder regions), not any occurrence of the bare token. |
| DF4 | Low (doc/CLI drift) | `harness decision add` hint vs `flow_harness.py` | The runner's hint says `--summary`, but the python CLI requires `--title`. Hint drifted from the actual contract — ironic for a tool that ships a `coherence` checker. | Align the hint text with the `decision add` arg parser (use `--title`), or add `--summary` as an alias. |

## Build outcome (2026-06-16, autonomous + Codex-reviewed)
All 3 cards BUILT, tested, gate-validated, and shipped as **flow 0.7.0** (installed + verified live):
- C-001 accessed_count read-only reuse signal (migration 005 + cmd_query) — test_flow_accessed_count.sh
- C-002 /flow constitution advisory command (+ template, gate-rules, recall surfacing) — test_flow_constitution.sh
- C-003 assess stdlib repo-map ranker (harness/repo_map.py, optional, graceful fallback) — test_flow_assess.sh E/F/G

18 suites / ALL PASSED, coherence clean at 0.7.0, 0 regressions. **Codex cross-model review caught 10
real bugs the green test pass missed** (C-001: narrow security regex, read-only-DB write; C-002:
code-fence parsing, malformed-row, test-range gap; C-003: no size cap, O(n²) perf, stopword noise,
non-unique-symbol corruption, py2 interpreter pick) — all fixed + regression-locked. Build done in-place
on master (serial cards, no per-card branches); changes uncommitted pending operator decision.

## Status
DONE — upgrade shipped. Runner findings DF1–DF4 remain open as a separate flow-skill fix pass.
The flow-run artifacts (`flow/00..05`, `cards/C-001..003`, DEBT.md, RETRO.md) are a faithful worked example.
