---
phase: 2
title: Fixture f01a repair
status: completed
priority: P1
dependencies:
  - 1
---

# Phase 2: Fixture f01a repair

> **Red-teamed 2026-07-11.** `dependencies: [1]` — the billable verification (step 4) must run on
> the hardened harness so a transient INVALID during the `--n 3` run leaves raw evidence + is
> cost-capped, instead of reverting to the exact blindness this plan fixes [RT-H13]. The mock-only
> steps (1-3) can run anytime.

## Overview

f01a is the "genuinely sound" 01-research fixture (expected PASS) but the judge FLAGs it 5/5
with defensible reasoning: complaint #3 has incoherent provenance. Fixture dirty, gate right —
repair the fixture so the sound-pass baseline can honestly reach 3/3.

## Requirements

- Functional: complaint #3 becomes a coherent, genuinely-online-quote-shaped item; artifact
  stays "sound under the strict web/market lens" of
  `skills/flow/references/gate-rules.md` (## Stage 01 section).
- Non-functional: fixtures are synthetic shipped content — provenance must be COHERENT, not
  resolvable; do not add real URLs that could rot or point at real people.

## Architecture

Judge's exact objections (from 5 recorded verdicts, all consistent):
1. Complaint #3 (`skills/flow/eval/fixtures/f01a/flow/01-research.md:38-41`) self-describes as
   "paraphrased-with-permission during a pilot household interview" while claiming a Reddit
   source, and links `reddit.com/r/Roommates` (subreddit homepage, not a thread). Gate box
   demands "3 REAL user complaints online, quoted, with source links" — this is interview data
   laundered into the online-complaint slot: the exact pattern the gate exists to catch.
2. Complaint #2 (App Store listing link, "dated within the last 6 months" hedge) judged weak but
   acceptable — leave content, optionally tighten the hedge.

Repair = rewrite complaint #3 as a direct quoted online complaint with a thread-style synthetic
link (e.g. `reddit.com/r/Roommates/comments/<id>/...`), quote text consistent with an online
post (not interview phrasing), no permission/paraphrase framing. Keep the household-interview
material where it already legitimately lives (switch-reason section) — do NOT delete signal,
just stop mislabeling it.

## Related Code Files

- Modify: `skills/flow/eval/fixtures/f01a/flow/01-research.md` (complaint #3 block; optional
  hedge tightening in complaint #2)
- No manifest change (`skills/flow/eval/manifest.tsv` untouched — same id/stage/expected).

## Implementation Steps

1. Rewrite **lines 38-41 only** (complaint #3 — verified location): direct quote, thread-style
   link, provenance stated once and coherently. Do NOT touch lines 34-37 (complaint #2's App
   Store link + hedge) — the Risk Assessment orders that acceptable weakness left in place; the
   original "36-41" was a line-range slip that would pull complaint #2 into the edit. [RT-H13]
2. Constraint: the rewrite must NOT introduce any deny-listed token — `tests/test_flow_eval.sh`
   test N (~line 278) hard-fails any fixture body matching `hollow|fake|fabricat|GATE-EVAL`
   (case-insensitive). A natural anti-laundering rewrite ("not a fabricated quote", "fake
   attribution") trips it. Phrase around it; do NOT narrow the deny-list grep (it is an injection
   defense). Prefer a reserved-looking thread id in the synthetic link so it cannot collide with a
   real reddit thread/user. [RT-H13]
3. Self-review against the full `## Stage 01` gate-rules section — every checked box must be
   true as written after the edit.
4. Mock-path suite: `bash tests/test_flow_eval.sh` (fixture content change must not break
   fixture-presence/extraction/deny-list tests).
5. Billable verification (operator-triggered, 3 calls): `flow.sh eval --fixture f01a --n 3`
   → expect PASS 3/3, 0 invalid. (Runs on the Phase-1-hardened harness, so a transient leaves
   raw evidence rather than a blind INVALID.)
6. If still FLAG: read the recorded reasoning (Phase 1 raw capture now persists INVALID stdout+
   stderr; a single manual diag call surfaces a FLAG rationale), fix the NAMED defect, repeat
   once. **Note the live risk:** the judge already called complaint #2 "weak" — with #3 fixed,
   #2 can become the new decisive objection, so a single provenance fix is not guaranteed to
   flip 5/5 FLAG → 3/3 PASS.
7. **Escalation deliverable (if FLAG persists after 2 repair rounds):** produce a short decision
   memo (in the plan's `reports/`) presenting three options with the recorded judge reasoning as
   evidence — (a) deepen the fixture rewrite, (b) flip the manifest `expected` for f01a to FLAG
   (accept the judge's read as correct and re-baseline to 6/6 with f01a=FLAG), (c) ship the
   canonical baseline at 5/6 with f01a documented as a known-strict case. Do NOT weaken
   gate-rules.md to force a PASS. Hand the memo to the operator; Phase 3's fallback ship path
   (Phase 1 + docs as v0.21.0, baseline deferred) applies if no option is chosen same-session.
   [RT-H7]

## Success Criteria

- [ ] Complaint #3 provenance coherent; no laundering pattern; artifact still substantive.
- [ ] `eval --fixture f01a --n 3` = PASS 3/3, 0 invalid.
- [ ] test_flow_eval.sh green.

## Risk Assessment

- Over-polishing risk: making f01a artificially easy would inflate sound-pass and blunt the
  eval's teeth. Mitigation: change ONLY the provenance defect; leave every other imperfection
  (e.g. complaint #2's acceptable weakness) in place — realistic-sound, not ideal-sound.
- Judge nondeterminism: 5/5 consistency observed so far; --n 3 majority voting already absorbs
  a stray vote.
