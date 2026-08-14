# Wave 1 cook — completion & operator handoff

- **Date:** 2026-08-14 13:10
- **Plan:** `plans/260814-0948-flow-upgrade-wave1/` — **8/8 phases, 34/34 tasks (100%)**
- **Branch:** `research/deepseek-harness-upgrade` (worktree `~/.herdr/worktrees/flow-skill/research-deepseek-harness-upgrade`)
- **Gates passed:** kongming identity ruling → plan red-team → cursor red-team R1 (14) + validate R1 (13)
  + red-team R2 (12) + validate R2 (1) → per-phase kongming checkpoints (phases 1, 2+3, 6, 7)
- **Product code touched:** only `skills/flow/`, `npm-wrapper/`, `.github/`, `docs/`, `tests/`, `scripts/`, root docs.
  `website/` untouched; `feat/flow-website` untouched.

## Commits (9)

| Commit | Phase | Subject |
|---|---|---|
| `cbfe180` | 1 | docs(adr): record flow identity as a discipline layer |
| `dfcec59` | 2 | ci: drive suites from a manifest and require all-checks-passed |
| `7bf133c` | 3 | ci: add credentialless pack-rehearsal with tarball skill parity |
| `45dc2e6` | 4 | docs: add root AGENTS.md and enforce word budgets |
| `31e99ab` | 5 | docs: detect EN/VI README drift via committed blob hashes |
| `a30e598` | 6 | fix(eval): refuse live macOS eval without a timeout binary |
| `030f6c3` | 7 | feat(eval): add keyless --replay and live --record for artifact eval |
| `f56de84` | 8 | docs(eval): require named artifacts in done-evidence (B1-S) |
| `c015df3` | polish | fix(eval): drop replay scorecard claim, late-only record meta, CI reads n |

## Verification (local, this machine)

- `tests/run_all.sh`: **60 of 61 suites pass** (wall 328s). The single failure is **pre-existing** — see below.
- `tests/test_flow_eval.sh` 178/178 · `test_flow_done_evidence.sh` 27/27 · `test_i18n_pairs.sh` 18/18 ·
  `test_doc_budgets.sh` 8/8 · `test_manifest_runner.sh` 12/12 · npm-wrapper `npm test` pass.
- `scripts/pack-rehearsal.sh` rc=0 end-to-end (installed-drive e2e 22 passed, runner resolved under the temp DEST).
- `scripts/check-i18n-pairs.sh` PASS · `scripts/check-doc-budgets.sh` PASS (README 3553/3880, SKILL.md 3648/3950).
- Seam integrity: `_eval_engine_run()` and `_run_with_timeout()` definitions unchanged across the wave
  (ADR STOP condition held). Phase 8 changed **zero** mechanical scoring code.

### Pre-existing failure (NOT caused by this wave)

`tests/test_flow_usage_log.sh` — 27 failed / 57 passed locally.

- **Pre-existing:** same suite on pre-wave base `48934b8` fails **worse** (29 failed / 55 passed).
- **Green in CI:** all recent `master` workflow runs report success, so this reproduces locally only.
- **Not in wave scope:** the wave touched neither this suite nor `skills/flow/harness/`.
- **Root-cause pointer for whoever picks it up:** the harness rollup itself is fine
  (`rollup` on a hand-built `.flow/events.jsonl` returns `{"rolled": 1, "skipped": 1}`). Failures start at
  section 6, which sets `export HOME="$SB/home"` (`tests/test_flow_usage_log.sh:78`) and then reads back via
  `python … rollup`. Observed `r1={"rolled": 0, "skipped": 0}` means rollup resolved an events path that
  never saw the appended malformed line — `_events_path()` derives from `dirname(_db_path)`
  (`flow_harness.py:673`), so DB resolution under the overridden `HOME` is the place to look. Also note the
  `python || python3` fallback at `:84`: this machine has no `python`, CI runners do.

## Operator checkpoints (agent-forbidden — your call)

**Billable (live LLM calls; never fabricate transcripts):**

1. **Phase 7 record batch** — `flow.sh eval --record --n 3` on a host with real `timeout`/`gtimeout`
   (or `FLOW_EVAL_UNBOUNDED=1` for that run only): 9 heading-mapped fixtures × 3 = **27 + 1 probe**.
   Then commit the stripped `skills/flow/eval/replay/` tree (meta + vote lines, no envelopes).
   Until this lands, the `eval-replay` CI job is skip-with-notice by design.
2. **Phase 8 fresh-judge measurement** — live `--n 3` on the new pair `fcdd` (hollow) / `fcde` (sound) to
   prove a fresh judge flags the artifact-less evidence; then a full re-record (**33 + probe** at the grown
   manifest). Per the ADR, replay verdicts never count toward the eval floor — only live batches do.
   A manifest change also triggers the ADR re-baseline rule.

**CI / GitHub (need a PR; pushes to this research branch do not run GHA):**

3. Open a PR with **base `master`** for the wave.
4. **Forced-skip experiment** (phase 2 evidence): temp commit `if: false` on the whole
   `no-python-degradation` job — confirm `all-checks-passed` **fails** — revert. Keep the run link.
5. **Forced-drift experiment** (phase 3 evidence): 1-byte drift in the synced skill tree must fail the
   tarball parity step; revert. Keep the run link.
6. **Flip branch protection** so the only required check is `all-checks-passed` — *after* the first fully
   green run. (Phase 2 also removed the `paths` filters so docs-only PRs still report.)
7. **macOS DEBT diagnosis** (phase 6, bounded to 2 macOS CI iterations):
   `scripts/macos-timeout-watchdog-diag.sh` — the step masks PATH so the timeout-less lane actually runs.
   The refuse-by-default guard already shipped, so this is diagnosis-only; update `DEBT.md` with
   confirmed-or-abandoned either way.

## Deferred by design

MCP client bridge (reopen = a concrete blocked card); full structured lineage evidence B1 (escalate only on
recurring hollow-done decoys after B1-S has been exercised); website CI (belongs to `feat/flow-website`);
python coverage floor; hybrid log-anchored attestation receipts. All C-tier items stay closed as
rejected-per-ADR.

## Uncommitted in this worktree

The wave's own planning/research artifacts are still untracked: `plans/260814-0948-flow-upgrade-wave1/`,
`plans/reports/research-260814-0915-*.md` (7), `brainstorm-260814-0933-flow-identity-decision.md`,
`redteam-260814-r{1,2}-wave1.md`, `validate-260814-r{1,2}-wave1.md`, this handoff, plus a one-line
`blockedBy` edit to `plans/260726-1718-harness-graph-executor-langgraph-port/plan.md`. Commit them with the
wave PR (or separately) as you prefer.
