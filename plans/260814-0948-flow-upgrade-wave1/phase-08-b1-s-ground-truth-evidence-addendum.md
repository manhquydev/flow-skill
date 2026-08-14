---
phase: 8
title: "B1-S ground-truth evidence addendum"
status: pending
priority: P2
effort: "0.5-1d"
dependencies: [7]
---

# Phase 8: B1-S ground-truth evidence addendum

## Overview
The S-cut of "reconstructable evidence": a `references/ground-truth-gates.md` addendum — **every
done-evidence item must name its artifact (path/URL) or the command that produced it** — enforced by
the existing semantic card gate (gate-rules.md challenge), NOT by new mechanical scoring. Ships WITH
a hollow/sound fixture pair so the discipline is measured from day one (kongming amendment: an
unmeasured discipline has an unmeasurable escalation trigger).

## Requirements
- Functional: addendum text in ground-truth-gates.md + a matching semantic challenge line in
  gate-rules.md's **Card gate** section (`:167-187`); ≥1 new fixture pair in
  `skills/flow/eval/manifest.tsv` with ids **`fcdd` (sound, expected PASS)** and **`fcde`
  (hollow, expected FLAG)** — next free `fcd*` after fcda/fcdb/fcdc. Layout:
  `skills/flow/eval/fixtures/<id>/cards/C-001.md` (mirror fcda). Hollow = plausible prose
  evidence naming NO artifact/command, still **mechanical-pass** (`fcdc`-class, not `fcdb` —
  fcdb fails `check` and would not prove a semantic-only catch). Sound = same story with
  concrete artifact refs (`fcda`-class).
- Non-functional: **zero mechanical change** — `_evidence_signal_score` and `cmd_check` untouched;
  old prose-only evidence still passes `check` (backward compatibility is the trust-floor promise).
  Escalation to full structured lineage evidence (B1) happens ONLY on evidence: recurring hollow-done
  decoys in dogfood/eval after this lands (recorded as the reopen condition).

## Architecture
Semantic-layer-only change: the card gate's challenge list gains one item; the eval fixture pair
proves a **fresh live judge** flags the artifact-less hollow and passes the sound one. Manifest
change triggers the ADR's re-baseline rule. Phase 7 replay re-record is a **follow-on** so CI
`--replay` does not stale-fail after the `gate-rules.md` edit — it is **not** the B1-S
measurement (ADR: replay verdicts never count toward the eval floor). Hard merge constraint:
the Phase 8 commit that edits `gate-rules.md` MUST include the refreshed replay fixtures or
Phase 7's CI job goes red.

## Related Code Files
- Modify: `skills/flow/references/ground-truth-gates.md`, `skills/flow/references/gate-rules.md`,
  `skills/flow/eval/manifest.tsv`
- Create: fixture pair under `skills/flow/eval/fixtures/` (follow existing fixture layout/naming)
- Modify: `tests/test_flow_eval.sh` (manifest count/structure assertions if they pin fixture count)

## Implementation Steps
1. Read existing fixture pairs + manifest.tsv format; mirror `fcda`/`fcdc` structure exactly
   (4-column TSV: `id stage artifact expected`).
2. Write addendum (ground-truth-gates.md) + one challenge line under `## Card gate` in
   gate-rules.md (the existing "Is `## Evidence` real world-state" bullet is adjacent — add,
   do not replace). Stay under the Phase 4 `gate-rules.md` budget (2890) or bump
   `docs/doc-budgets.txt` in the same commit.
3. Author `fcdd`/`fcde`; verify **both** still PASS mechanical `flow.sh check` (hollow is a
   semantic-only catch) — add both ids to `tests/test_flow_eval.sh` section A mechanical-pass
   loop (`:48` currently `fcda fcdc` only). There is **no** artifact-manifest row-count pin
   today (routing `>=12` / converge `>=2` are other modalities — do not tighten those).
4. Add both rows to `manifest.tsv`; run one **live** `--n 3` batch on the new pair (billable;
   this is the measurement). Then `--record` a refreshed **full** artifact batch
   (now 11 fixtures × 3 = 33 judge calls + 1 probe) and commit it in the **same** Phase 8
   change as the `gate-rules.md` edit (otherwise Phase 7 CI stale-fails). `--record` is
   live-mode — the Phase 6 guard applies. Record on a host with real `timeout`/`gtimeout`,
   or export `FLOW_EVAL_UNBOUNDED=1` for that operator run only.
5. Record the B1 escalation condition in the plan/backlog (`flow.sh` backlog verb or docs note).

## Success Criteria
- [x] Fresh-judge **live** `--n 3` batch flags the new hollow fixture at ≥2/3 and passes the
      sound one — measured, not asserted. A recorded/replayed batch does **not** satisfy this box.
- [x] Mechanical layer behavior unchanged (evidence scoring tests untouched-green).
- [x] Reopen condition for full B1 written down where the operator will see it.
- [x] Phase 8 commit includes refreshed Phase 7 replay fixtures (CI `--replay` green after the
      gate-rules edit).

<!-- Updated: Red Team R1 - live-only B1-S measurement; replay re-record is follow-on -->
<!-- Updated: Validation Session 1 - pin fcdd/fcde; fcdc-class mechanical pass; 11×3 re-record -->
<!-- Updated: Red Team R2 - stay under Phase 4 gate-rules budget or bump -->

## Risk Assessment
Trust-floor adjacency: the only edited surfaces are prose references + fixtures. A regression here
is a wording problem, not a scoring problem — reviewable by diff. Keep the addendum to one rule; do
not smuggle in structured-block syntax (that is B1, not B1-S).
