# /flow — quality metrics

Living record of the quality experiment: collect real numbers, improve, ensure quality.
Updated as the skill evolves. Current: **v0.2** (2026-06-13).

## Size & surface
| Metric | Value |
|---|---|
| Gate engine (`runner/flow.sh`) | 637 LOC |
| Durable layer (python) | 627 LOC (flow_harness + _db + _domain) |
| Commands | ~15 (`next/card/check/status/mode/project-type/skip/ready/auto/harness/debt/design/doctor/retro`) |
| Semantic references | 14 markdown playbooks |
| Stack playbooks | 4 |
| Schema migrations | 4 SQL (verbatim from repository-harness) |

## Test coverage
| Suite | Checks | Covers |
|---|---|---|
| `test_flow_runner.sh` | 13 | gate lifecycle, FILL/checkbox/evidence, gap-bypass, card validation |
| `test_flow_harness.sh` | 19 | intake/risk-lane, trace tiers, story verify, decision, backlog, query |
| `test_flow_scenarios.sh` | 14 | the 6 buildflow validation rounds (mechanical) |
| `test_flow_project_types.sh` | 20 | project-type get/set, per-type done-evidence, skip hardening |
| `test_flow_gate_wording.sh` | 13 | Research/Contract gates project-type aware, web path preserved |
| `test_flow_coverage_gaps.sh` | 14 | retro, ready (deps), auto preflight, harness decision/tool/intervention |
| **Total (dev)** | **93** | all green (`bash tests/run_all.sh`) |
| **+ e2e (installed)** | **22** | `flow-test-drive/e2e-drive.sh` — happy+edge against a fresh per-project install (Windows) |
| **Grand total** | **115** | all green |

**Command coverage:** ~100% of runner commands now have a dedicated assertion (was 14/15;
`retro`/`ready`/`auto` + harness `decision`/`tool`/`intervention` gaps closed 2026-06-13).

## Review history (evidence-based, not self-assessed)
| Pass | Scope | Findings | Resolution |
|---|---|---|---|
| 1 | Phase 1 engine (flow.sh) | 1 HIGH + 4 MEDIUM | all fixed (gap-bypass, evidence SIGPIPE, section anchoring, …) |
| 2 | Phase 2 durable layer (python) | 3 HIGH | all fixed (migration atomicity, init crash, tool guard, Windows path) |
| 3 | Phase 4-6 shell (debt/design/install) | 0 HIGH, 1 MED + 1 LOW | both applied (PS 5.1 fallback, debt newline strip) |
| 4 | v2 skip-with-debt (dogfood) | **2 HIGH** | both fixed (stage-matched DEBT, contract never skippable, broadened guard) |
| 5 | project-type-aware gates (dogfood #1/#4) | 0 HIGH, 1 LOW | applied (stale column label); confirmed no web-gate regression |

The pattern that matters: review pass #4 caught a real security weakness (the contract/auth
seam could be skipped) before it shipped; pass #5 confirmed the gate-wording change did NOT
weaken the web/market path. The process works.

## Cross-platform support (macOS / Linux Ubuntu / Windows)
Portability self-audit of `runner/flow.sh` (re-run any time):
- ❌ none of: `mapfile`/`readarray`, `declare -A`, `${var^^}`/`${var,,}`, `[[ ]]` → **bash 3.2 safe** (macOS default shell).
- `grep -P` (emoji in `flow design`) is **probe-guarded** → degrades gracefully on macOS BSD grep.
- **no `sed -i`** in the shipped runner → no BSD/GNU `-i` divergence.
- python uses stdlib only (`sqlite3` present on all three OSes); `_python()` tries `python` then `python3`.
- `flow.sh doctor` reports the live environment on any platform.

Verified directly on Windows (Git Bash, bash 5.2). macOS/Linux: scripts written to POSIX +
bash-3.2 constraints from researched BSD/GNU differences (not yet run on real mac/linux —
the doctor command + the audit are the safety net; a real-machine run is the open item).

## Dogfood findings (using /flow to build /flow)
5 findings; 2 fixed + shipped, 3 tracked. See `plans/reports/dogfood-self-build-260613.md`.
This file's #1 and #4 are the next target (research/contract gate web-flavoring).

## Metrics to collect over time (to drive improvement)
The aim: make quality measurable so we know if `/flow` is getting better. Most of these are
recorded **for free** by `/flow`'s own durable layer (`harness/` tables) — wire the events,
read the trend.

| Metric | Definition | How to measure (durable layer) | Baseline | Target |
|---|---|---|---|---|
| **Gate false-pass** | gate passes but artifact is hollow/incomplete | `intervention --type correction --source reviewer`; count vs stages | 0 in tests | <1% |
| **Gate false-block** | gate blocks legitimate work | `backlog add --pain "gate blocked valid stage"` then close | 1 (dogfood v1, fixed) | <2% |
| **Card first-pass rate** | cards passing `check` first try | `story` rows: `last_verified_result='pass'`/total | ~70% (dogfood) | ≥85% |
| **Command coverage** | commands with a test | suite audit | ~100% | 100% |
| **Cross-platform pass** | suite green per OS | GitHub Actions matrix CI (`.github/workflows/ci.yml`) | **3/3 OS ✓** (CI green: ubuntu 11s, macOS bash-3.2 14s, windows 49s) | 3/3 OS |
| **Dogfood close rate** | self-found issues fixed | `backlog WHERE discovered_while~'dogfood'`, closed/total | 4/5 (80%) | ≥80% |
| **Reviews-to-clean** | review passes until 0 HIGH | `decision`/`intake` per review cycle | ~1-2 per change | ≤2 |
| **Doctor pass rate** | fresh envs returning READY | `flow doctor` exit + `trace --outcome` | Windows READY | ≥90% |

Durable-layer wiring (already present): card→`story add`, check-done→`story update`+`trace`;
to collect the rest, log review findings as `intake`, friction as `backlog`, overrides as
`intervention`. No new schema needed — see the coverage analysis (subagent report, 2026-06-13).

### Top-5 next (from the coverage analysis)
1. Run the 93-test suite on a **real macOS + Ubuntu** machine (currently static-audited).
2. `ready` **parallel-safety** test: assert no allowed-files overlap in the BUILDABLE set.
3. `trace` **tier-3 boundary** unit tests (9/10/11-char summaries, CRLF input).
4. Wire SKILL.md to auto-log high-risk gate decisions as `harness decision add` (metrics-as-byproduct).
5. `retro validate` gate (RETRO.md has ≥3 real lines) before a release.

## Open quality items
- ~~Run the suite on a real macOS + Ubuntu machine~~ — **DONE**: GitHub Actions matrix
  (`.github/workflows/ci.yml`) runs all 115 checks (93 dev + 22 e2e on a real install) on
  ubuntu/macOS/windows; green on all three (macOS verified on real bash 3.2.57 arm64).
- ~~Findings #1 + #4~~ — **DONE** (branch `fix/non-web-gates`, merged; reviewed 0 HIGH; +13 tests).
- Automated per-type done-evidence validators (currently guidance enforced by the Claude layer).
- Finding #3 (the "forbidden: edit flow.sh during a run" rule wording) — clarify in CLAUDE.md.
