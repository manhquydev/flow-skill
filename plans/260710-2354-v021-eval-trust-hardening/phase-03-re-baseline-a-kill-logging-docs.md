---
phase: 3
title: "Re-baseline + A-kill logging + docs"
status: pending
priority: P2
dependencies: [1, 2]
---

# Phase 3: Re-baseline + A-kill logging + docs

## Overview

Produce the canonical drift baseline with the hardened harness + repaired fixture, formally kill
roadmap-A (express-lane) on the record with a re-trigger condition, and ship v0.21.0 coherently.

## Requirements

- Functional: canonical baseline batch 6/6 MATCH; A-kill + re-trigger documented; version bump.
- Non-functional: `/flow coherence` PASS (SKILL.md / plugin.json / portable-manifest version
  agreement); full suite green.

## Architecture

Docs placement follows existing patterns:
- A-kill entry → `docs/quality-metrics.md` (existing anti-FOMO log sections, e.g. lines ~286,
  ~316) with the evidence numbers: 14/15 (93%) cycles with ≥1 successful `next` reach Cards;
  contract dwell median 40s / range 25-113s / n=12 (the 1.3h avg = measurement artifact);
  "33% abandonment" = exploration pokes + CMC brownfield card-mode.
- Re-trigger condition (same entry): revisit entry-activation if after ~15-20 new real cycles on
  v0.20 `resume`/`NEXT ->`, zero-next poke cycles still dominate and entry conversion unmoved.
- Roadmap note: the B→C→A sequence closes with A killed-by-gauge — reference brainstorm report
  `plans/reports/brainstorm-260710-2354-v021-eval-hardening-kill-express-lane-report.md`.
- CHANGELOG.md: new `## 0.21.0` section (robustness, fixture repair, baseline, A-kill).
- INVALID-storm postmortem note → `skills/flow/references/gate-eval.md` failure-modes (first
  batch …-1783695631: 17/18 INVALID despite retry; single-call + rerun clean; stderr signature
  "SessionEnd hook cancelled"; mechanism unconfirmed at the time because raw was discarded —
  Phase 1's stdout+stderr+rc capture now makes the NEXT occurrence diagnosable). Also document:
  eval takes no concurrency lock (prune/raw are the only cross-run writes, guarded by run_id-epoch
  TTL); `rate_limited` is best-effort/advisory (only `allowed` shape ever observed).

## Related Code Files

- Modify: `skills/flow/SKILL.md` (version field), `.claude-plugin/plugin.json`,
  `portable-manifest.json` (version mirror)
- Modify: `CHANGELOG.md`, `docs/quality-metrics.md`, `skills/flow/references/gate-eval.md`
- No runner code changes in this phase.

## Implementation Steps

1. Billable canonical run (operator-triggered, up to 18 calls happy-path): `flow.sh eval --n 3`
   → expect 6/6 MATCH, 0 unreliable, 0 invalid. If the INVALID storm recurs, Phase 1's
   first-UNRELIABLE circuit breaker aborts after ~≤7 calls (probe + n×2) with raw evidence on
   disk — diagnose from the `.flow/eval-raw/` stdout+stderr before rerunning. Do NOT baseline
   from a degraded/aborted batch.
   **If Phase 2 escalated** (f01a never reached PASS 3/3): baseline reflects the chosen
   escalation option — either f01a `expected=FLAG` (6/6 with the judge's read accepted) or a
   documented 5/6. The canonical batch's pass/fail shape must match whatever manifest state
   Phase 2 left. [RT-H7]
2. `flow.sh eval --report` → verify scorecard + drift line reads the new batch as the last
   complete baseline.
3. Write docs entries per Architecture above.
4. Version bump to 0.21.0 in the three coherence-checked files; `flow.sh coherence` → PASS;
   `flow.sh consistency` → no new findings.
5. Full suite `bash tests/run_all.sh` green.
6. Conventional commit (`feat(flow): v0.21.0 eval-trust hardening + express-lane kill`), push,
   then install to homes per operator's release pattern (`install.sh`/`install.ps1`).
7. Update auto-memory (v0.21 shipped entry) — session-level step, not repo content.

## Success Criteria

- [ ] Canonical batch = 6/6 MATCH (with f01a repaired) OR the escalation-chosen shape (f01a
      `expected=FLAG` → 6/6, or documented 5/6); 0 unreliable; `eval --report` shows it with
      drift vs prior.
- [ ] A-kill + re-trigger + evidence in `docs/quality-metrics.md`; CHANGELOG 0.21.0 written.
- [ ] gate-eval.md documents the INVALID-storm failure mode + playbook (incl. no-lock caveat +
      best-effort `rate_limited`).
- [ ] coherence PASS, consistency clean, run_all.sh green.
- [ ] Committed + pushed; homes installed.

## Fallback Ship Path [RT-H7]

If f01a cannot be resolved same-session AND no escalation option is chosen, Phase 1 (eval
robustness) + the A-kill docs still ship as **v0.21.0** with the canonical 6/6 baseline
explicitly DEFERRED to a follow-up run (recorded as an open item, not a silent gap). Phase 1's
value — diagnosable/cost-safe eval — does not depend on the baseline being clean. The version
bump and CHANGELOG note the deferral honestly.

## Risk Assessment

- Canonical run could hit another transient window → first-UNRELIABLE breaker caps cost at
  ~≤7 calls with raw evidence; rerun later. Do not baseline from a degraded/aborted batch.
- Version-bump drift across the 3 mirrored files → `coherence` gate catches; run before commit.
- Deferred items stay disclosed, not silently dropped: macOS eval-timeout DEBT, Azure CI
  operator setup.
