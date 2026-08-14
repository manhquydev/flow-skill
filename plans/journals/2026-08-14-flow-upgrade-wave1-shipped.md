---
title: flow upgrade wave1 shipped
date: 2026-08-14
summary: "Skill v0.30.0 / npm 0.7.0: identity ADR + CI/eval hardening; live --record and branch-protection flip still open."
---

# flow upgrade wave1 shipped

**Date**: 2026-08-14 13:32
**Severity**: Medium
**Component**: flow-skill identity / CI / eval
**Status**: Ongoing — product bytes shipped; operator checkpoints still open

## What Happened

Cooked all 8 phases of `plans/260814-0948-flow-upgrade-wave1/` (34/34 tasks) on
`research/deepseek-harness-upgrade` (worktree
`~/.herdr/worktrees/flow-skill/research-deepseek-harness-upgrade`). Skill product
**v0.30.0**, npm installer **0.7.0**. Identity is now a testable ADR, not a vibe:
flow owns gates and receipts, never the runtime.

Cook trail: `cbfe180` ADR → `dfcec59` all-checks-passed → `7bf133c` pack-rehearsal →
`45dc2e6` AGENTS.md budgets → `31e99ab` i18n blob-hash → `a30e598` macOS refuse-guard
→ `030f6c3` keyless `--replay` / live `--record` → `f56de84` B1-S → `c015df3` polish.
Then plan dump, master merge, version bump `8d339f7`, i18n refresh `c86788f`.

Kongming GO: identity ruling → plan red-team R1 (14 accepted) + validate R1 (13) →
R2 (12) + validate R2 (1) → per-phase checkpoints (1, 2+3, 6, 7).

## The Brutal Truth

Calling this "shipped" is half a lie. The code is on the branch. The load-bearing
proofs are not. `eval-replay` CI is skip-with-notice until someone burns real tokens
on `--record`. B1-S added `fcdd`/`fcde` but a live `--n 3` has not measured them —
and the ADR we just wrote says replay verdicts never count toward the floor. Branch
protection still does not require `all-checks-passed`. We built the constitution and
left the enforcement switch off. That is the same hollow-done pattern B1-S exists
to catch. Maddening, because the wave *knew* this in the plan and still marked cook
100%.

## Technical Details

- **Identity ADR** `docs/adr/0001-discipline-layer-identity.md`: process-token
  invariant, five flip-tripwires, proportional floor ("at most one fixture mismatch
  per batch"), replay-never-counts, fixture-pair-per-new-gate, monetization cap.
- **A1**: `tests/run_all.sh` reads `tests/manifest.txt`; `all-checks-passed` is
  `needs` + `if: always()`. Forced-skip experiment not run (no PR to `master`).
- **A2**: `scripts/pack-rehearsal.sh` rc=0 locally — tarball `skills/flow/`
  byte-compare, temp DEST, `e2e-installed-drive.sh` 22 passed. `NPM_TOKEN` set = fail.
- **A3**: stale `gate-rules` hash hard-fails. `_eval_engine_run()` and
  `_run_with_timeout()` bodies unchanged (ADR STOP held).
- **A4/A5**: root `AGENTS.md`; budgets README 3553/3880, SKILL.md 3648/3950;
  EN/VI hashes in `docs/i18n-pairs.txt`.
- **macOS**: live eval refuses without real `timeout`/`gtimeout`;
  `FLOW_EVAL_UNBOUNDED=1` opt-in. Replay never hits the guard. DEBT diagnosis still
  unconfirmed.
- **B1-S**: named-artifact addendum + `fcdd` (hollow) / `fcde` (sound). Mechanical
  scoring untouched.
- **Local**: `tests/run_all.sh` **60/61**. `tests/test_flow_usage_log.sh` 27 failed /
  57 passed. Pre-existing: same suite on `48934b8` was **29 failed / 55 passed**.
  Green in CI. Wave touched neither the suite nor `skills/flow/harness/`. Pointer:
  section 6 `export HOME="$SB/home"` then rollup via `python` — this machine has no
  `python`; `_events_path()` derives from `dirname(_db_path)`
  (`flow_harness.py:673`); observed `r1={"rolled": 0, "skipped": 0}`.

## What We Tried

Cooked the wave as specified. Did not fabricate live transcripts. Did not flip
GitHub settings from an agent. Correct discipline — and why the remaining work is
stuck on a human.

## Root Cause Analysis

The ADR made live batches the only compliance evidence, then cook stopped at the
agent-forbidden line. Research-branch pushes do not run GHA
(`on.pull_request.branches: [master]`). "CI hardened" is a YAML commit, not a
verified required check. We knew this. We shipped anyway.

## Lessons Learned

- A required-check rename that is not flipped is theater. Flip after the first
  green PR, not in the same breath as "shipped."
- Replay without a committed `skills/flow/eval/replay/` tree is a skip job. Do not
  pretend the keyless path is live until `--record` lands.
- Pre-existing local-only `python` vs `python3` failures will keep biting anyone
  who treats `run_all.sh` as the ship gate. Isolate them before the next wave.

## Next Steps

Operator-owned (agent-forbidden):

1. Live `flow.sh eval --record --n 3` (9 fixtures × 3 = 27 + probe); commit stripped
   `skills/flow/eval/replay/`. Then live `--n 3` on `fcdd`/`fcde` and full re-record
   (33 + probe). Replay never counts.
2. PR with base `master`. Forced-skip (`if: false` on `no-python-degradation`) must
   fail `all-checks-passed`; forced 1-byte tarball drift must fail parity; revert
   both; keep run links.
3. Flip branch protection to **only** `all-checks-passed` after the first fully
   green run.
4. Bounded macOS DEBT diagnosis via `scripts/macos-timeout-watchdog-diag.sh`; update
   `DEBT.md` confirmed-or-abandoned.

Owner: operator. Timeline: before treating v0.30.0 as CI-enforced on `master`.

> Historical work record — not durable authority. Prefer docs/specs/ADRs for current decisions.
