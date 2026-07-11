# Brainstorm Report — v0.21 Eval-Trust Hardening + Express-Lane Kill

**Date:** 2026-07-10 → 11 | **Session:** /brainstorm "nắm tình trạng + research nâng cấp flow"
**Decision:** PA1 approved by operator — v0.21 = eval-hardening + fixture fix + express-lane A killed with evidence.

## Problem Statement

Operator asked: grasp current project state, continue new-tech research, upgrade flow. Scout found:
research already done same-day (3 researcher reports 260710-0238); roadmap B→C→A locked; B (v0.19
gate-eval) + C (v0.20 legibility) already SHIPPED (commit 3ce9c95, pushed). Remaining item = A
(express-lane), explicitly gated on "B ships numbers". Session redirected (operator-approved) to:
run first real eval baseline + qualitative contract-dwell check + decide A.

## Evidence Gathered This Session (all first-party, zero new internet research)

### 1. First real gate-eval baseline (run e502a371-…-1783701885-516156)
- **hollow-flag-rate 3/3 stages = 100%**, sound-pass-rate 2/3, **0 INVALID of 18 calls**, every fixture 3/3 unanimous.
- model=claude-fable-5, cli=2.1.201, gate_rules_sha=3672145322. Stored in `.flow/eval-results.jsonl`.
- Only MISMATCH = f01a (sound research fixture) FLAGged 3/3 + 2 diag calls = 5/5. Verified by eye:
  fixture's complaint #3 is interview data laundered as "online quote" with a subreddit-homepage
  link (`fixtures/f01a/flow/01-research.md:38-41`) — **fixture dirty, gate right**. Judge FLAG is defensible.

### 2. First batch (22:00) failed 17/18 INVALID — transient, now diagnosed
- Single calls + full rerun batch: all clean. Parse pipeline + `_run_with_timeout` chain + long
  nonce all verified working via isolated replication scripts.
- Root-cause candidates: rate-limit window / inner-session hook contention ("SessionEnd hook
  cancelled" ×18 on stderr). NOT reproducible.
- Gap exposed: harness **discards raw engine output on INVALID** → transient storms unpostmortemable;
  no retry/backoff between calls.

### 3. Contract "1.3h bottleneck" = measurement artifact
- Real-project per-cycle mining (tmp.* noise excluded, first `card` cmd as exit marker):
  **median 40s, range 25–113s, n=12, zero stuck-at-contract**. The 1.2–1.3h avg in
  `usage --global` comes from a different pairing/outlier handling. Roadmap's unresolved question
  "waste or thinking time?" → answer: **neither, it's seconds; artifact**.

### 4. "33% abandonment before Cards" dissolves per-cycle
- Cycles with ≥1 successful `next`: **14/15 (93%) reach Cards**.
- 8 zero-next cycles: 1 = CMC brownfield card-mode by design (83 events, has cards); 7 = exploration
  pokes (status/assess/debt only, 1–9 events). Real mid-pipeline abandonment ≈ 1/15 (7%).
- Full ceremony 00→05 wall-clock ≈ 5 min total (per-stage dwell sums).

## Approaches Evaluated

| Option | Content | Verdict |
|---|---|---|
| **PA1 (chosen)** | Fix f01a fixture; save raw on INVALID + retry/backoff + rate-limit visibility; kill A with evidence + re-trigger condition | Small, every line backed by tonight's measurements |
| PA2 express-lane per original roadmap | Build skip-to-Cards anyway | Premise numbers gone; loosening gates right after gauge shows they're stricter than fixtures = backwards; FOMO vs own roadmap |
| PA3 entry-activation | Pull poke-cycles into pipeline now | v0.20 resume/NEXT-> ships exactly this bet, zero dwell time measured yet; building atop unmeasured feature |

## Final Solution (v0.21 scope)

1. **Fixture f01a repair**: replace complaint #3 with a genuine linked online quote (or honestly
   restructure) so sound-pass baseline = 3/3. Re-run batch to confirm.
2. **Eval robustness**: persist raw engine output per-call when verdict=INVALID (postmortem);
   retry-once-on-INVALID or inter-call backoff; surface rate_limit_event status in results row.
3. **Express-lane A: KILLED** (anti-FOMO log entry). Evidence above. Kill-at-gate is a valid
   outcome per flow's own doctrine.
4. **Re-trigger condition logged**: revisit entry-activation if, after ~15–20 new real cycles on
   v0.20, zero-next poke cycles still dominate and entry conversion hasn't moved.

## Success Metrics
- Eval batch: 6/6 MATCH, 0 unreliable, sound-pass 3/3.
- INVALID verdicts leave a raw artifact on disk.
- Roadmap doc + DEBT/anti-FOMO log reflect A-kill + re-trigger condition.

## Risks
- f01a rewrite must stay "genuinely sound" without becoming easier than real artifacts — judge is
  strict on provenance; keep the strict-lens intent.
- Retry-on-INVALID must not mask real drift: cap at 1 retry, count retries in results row.

## Unresolved Questions
- First-batch INVALID storm exact mechanism unconfirmed (rate-limit vs hook contention) — raw
  capture in v0.21 makes the next occurrence diagnosable.
- macOS eval timeout DEBT still open (needs real macOS access) — unchanged by this session.
- Azure CI operator setup still parked.
