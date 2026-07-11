---
title: v0.21 eval-trust hardening + express-lane kill
description: >-
  Make flow.sh eval's failure modes diagnosable and cost-safe (raw-on-INVALID
  capture, retry backoff, rate-limit visibility, batch circuit-breaker), repair
  the dirty f01a fixture, establish the canonical 6/6 baseline, and formally
  kill roadmap-A (express-lane) with evidence + re-trigger condition.
status: completed
priority: P2
branch: master
tags:
  - eval
  - telemetry
  - anti-fomo
blockedBy: []
blocks: []
created: '2026-07-10T18:31:25.507Z'
createdBy: 'ck:plan'
source: skill
---

# v0.21 eval-trust hardening + express-lane kill

## Overview

First real gate-eval run (260710) proved: hollow-flag-rate 100% (3/3 stages), judge unanimous
18/18 votes — but exposed three trust gaps:

1. An earlier same-night batch failed 17/18 INVALID **despite the existing in-run retry**
   (transient window, likely rate-limit; "SessionEnd hook cancelled" ×18 on stderr). Raw engine
   output is discarded on INVALID → the storm is unpostmortemable, and the batch burned all 18
   billable calls producing junk.
2. Fixture f01a ("sound" research artifact, expected PASS) is FLAGged 5/5 by the judge with
   defensible reasoning: its complaint #3 is interview data laundered as an "online quote" with a
   subreddit-homepage link (`skills/flow/eval/fixtures/f01a/flow/01-research.md:38-41`). Fixture
   dirty, gate right → sound-pass baseline stuck at 2/3.
3. Roadmap A (express-lane v0.21 candidate) lost its numbers: cycles with ≥1 successful `next`
   reach Cards 14/15 (93%); contract dwell median 40s (the 1.3h avg was a measurement artifact);
   "33% abandonment" decomposes into exploration pokes + brownfield card-mode. A must be killed
   on the record, not silently dropped.

Evidence + decisions: `plans/reports/brainstorm-260710-2354-v021-eval-hardening-kill-express-lane-report.md`
(operator approved PA1). Baseline batch: run `…-1783701885-516156` in `.flow/eval-results.jsonl`.

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Eval robustness (raw-on-INVALID + retry + rate-limit visibility)](./phase-01-eval-robustness-raw-on-invalid-retry-rate-limit-visibility.md) | Completed |
| 2 | [Fixture f01a repair](./phase-02-fixture-f01a-repair.md) | Completed |
| 3 | [Re-baseline + A-kill logging + docs](./phase-03-re-baseline-a-kill-logging-docs.md) | Completed |

## Dependencies

- None blocking (external). Builds on shipped v0.19 eval harness (commit 3ce9c95) and v0.20.
- Phase 2 depends on Phase 1 (its billable f01a verification must run on the hardened harness so a
  transient leaves evidence + is cost-capped). [RT-H13]
- Phase 3 depends on Phases 1+2 (canonical baseline produced by hardened code against the
  repaired fixture; a fallback ship path covers f01a-unresolved). [RT-H7]

## Acceptance Criteria (plan-level)

- [ ] Final-INVALID votes leave raw **stdout + stderr + rc** on disk (both attempts), stripped of
      the cwd/session/plugin envelope, git-ignored — postmortemable. [RT-C2, RT-H4]
- [ ] In-run retry waits (injectable backoff, `FLOW_EVAL_RETRY_BACKOFF`) and is skipped when a
      rate-limit signal fired; asserted via emitted text, not stopwatch. [RT-H6, RT-H8]
- [ ] **First-UNRELIABLE** fixture aborts the batch early (catches a 17/18-class storm, not just
      all-INVALID) with a guarded `done` trailer so the aborted batch is NOT recorded complete;
      `--keep-going` overrides. [RT-C1, RT-H3]
- [ ] Results rows carry `retries` + best-effort `rate_limited` (anchored to `rate_limit_info`);
      single call site (`flow.sh:2833`); `--report`/drift tolerate new fields; line < 4096B. [RT-H5, RT-H12]
- [ ] f01a repaired (lines 38-41 only, no deny-list tokens); `eval --fixture f01a --n 3` = PASS
      3/3 — OR Phase 2 escalation memo produced with a chosen manifest outcome. [RT-H7, RT-H13]
- [ ] Canonical batch = 6/6 MATCH (or escalation-chosen shape) → drift baseline; may DEFER via
      the Phase 3 fallback ship path if f01a unresolved. [RT-H7]
- [ ] A-kill + re-trigger condition recorded in docs; CHANGELOG v0.21.0; version bump coherent
      (SKILL.md / plugin.json / portable-manifest.json — `/flow coherence` PASS).
- [ ] Full test suite green (`FLOW_EVAL_RETRY_BACKOFF=0 tests/run_all.sh`), incl. stderr-channel +
      breaker + filtered-run + rate-limit-false cases; BSD/bash-3.2-safe.

## Constraints

- POSIX/bash-3.2-portable, no `grep -oP`, BSD-sed-safe (CI lesson v0.12.x); Windows Git Bash is
  the primary dev OS; macOS eval-timeout DEBT stays open (unchanged by this plan).
- Mock engine in tests — zero billable calls in CI. Billable verification runs are
  operator-triggered steps in Phases 2–3 only (3 + 18 calls).
- No new dependencies (no jq); keep the grep/sed parsing posture.

## Red Team Review

### Session — 2026-07-11
**Reviewers:** 3 (Security Adversary, Assumption Destroyer, Failure Mode Analyst — `code-reviewer`
subagents, Standard verification tier). **Findings:** 26 raw → 14 after dedup, **all Accepted**
(every finding carried `file:line` evidence; strong 3-lens convergence on the two Criticals).
**Severity:** 2 Critical, 5 High, 7 Medium. No finding reversed the operator's A-kill decision;
all are implementation-hardening.

| # | Finding | Sev | Disp | Applied To |
|---|---------|-----|------|------------|
| C1 | Breaker (`invalid_count==n` first fixture) misses the 17/18 storm that motivated it → retrip on **first-UNRELIABLE** | Critical | Accept | Phase 1 §4, AC |
| C2 | Raw captures stdout only; storm signature was on **stderr** → persist stdout+stderr+rc, both attempts | Critical | Accept | Phase 1 §1, step 7b |
| H3 | "No done trailer" contradicts unconditional `_eval_emit_batch_marker done` (`flow.sh:2840`); filtered run → junk batch recorded COMPLETE, poisons drift → `aborted` flag guards trailer | High | Accept | Phase 1 §4 |
| H4 | "No secrets" false — envelope has cwd(username)/session_id/plugin/memory paths; `cmd_eval` never `_ignore_run_state` → strip envelope + git-ignore | High | Accept | Phase 1 §1 |
| H5 | `rate_limit_event` shape guessed + unscoped grep forgeable; **empirical:** real `allowed` event contains `overageStatus":"rejected"` → anchor to `rate_limit_info.status`, mark advisory | High | Accept | Phase 1 §3 |
| H6 | `sleep 5` hardcoded → untestable + slows suite ×3 OS → `FLOW_EVAL_RETRY_BACKOFF` env + text assert | High | Accept | Phase 1 §2 |
| H7 | 6/6 AC has no contingency; Phase 2 escalation undefined → escalation memo (3 options) + Phase 3 fallback ship path | High | Accept | Phase 2 step 7, Phase 3 |
| H8 | Retry doubles cost; "~3 calls" wrong (≤7; --keep-going ~37); backoff cosmetic vs minutes-long window → correct math, skip retry on rate-limit | Medium | Accept | Phase 1 §2, risk |
| H9 | Prune-to-3 by mtime destroys the storm dir being diagnosed; no lock; mtime unreliable → prune by run_id epoch + 900s TTL guard | Medium | Accept | Phase 1 step 4 |
| H10 | Write keyed by `fid` (only `tr -d '\r'`) → path traversal past read-side v1 trust boundary → sanitize fid to nonce charset | Medium | Accept | Phase 1 §1 |
| H11 | Raw-write failure silent under house `2>/dev/null||true` → loud warning (diagnostic-critical) | Medium | Accept | Phase 1 §1 |
| H12 | "both call sites" phantom — exactly one (`flow.sh:2833`); name 5 readers + 4096B PIPE_BUF invariant | Medium | Accept | Phase 1 §5 |
| H13 | Phase 2 `dependencies:[]` but needs Phase 1; line range 36-41 wrong (#3 = 38-41); deny-list token trap | Medium | Accept | Phase 2 frontmatter, steps 1-2 |
| H14 | (rolled into H5) throttled shape UNVERIFIED → capture a real sample before drift trusts `rate_limited` | Medium | Accept | Phase 1 §3, Phase 3 docs |

### Whole-Plan Consistency Sweep
- Files reread: plan.md, phase-01, phase-02, phase-03.
- Decision deltas checked: breaker semantics (all-invalid → first-UNRELIABLE), raw scope (stdout →
  stdout+stderr+rc), trailer guard, backoff env knob, prune key (mtime → run_id epoch), call-site
  count (2 → 1), Phase 2 dep (`[]` → `[1]`) + line range (36-41 → 38-41), 6/6 AC → contingency +
  fallback ship.
- Reconciled stale references: 9 (plan AC ×3, Phase 3 cost "~3 calls" → ≤7, Phase 3 success shape,
  gate-eval storm note, Phase 2 dep+range+deny-list, Phase 1 full re-spec).
- Unresolved contradictions: 0.

