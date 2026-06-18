# Raw eval outputs (audit trail — verbatim verdicts, no post-hoc edits)

Kept so the catch-rate counts can be checked against source. Defect target each round is the
ONE planted laundered C-graded-as-B feature (round 1: F3 realtime; round 2: F3 autonomous auto-triage).

## Round 1 — defect F3 = realtime collab (famous prior), Opus

| Agent | Arm | Verdict | F3 flagged should-be-C? |
|---|---|---|---|
| t1 | treatment | HOLD | yes |
| t2 | treatment | HOLD | yes |
| t3 | treatment | HOLD | yes |
| c1 | control(+rubric) | GRADING-OFF | yes |
| c2 | control(+rubric) | GRADING-OFF | yes |
| c3 | control(+rubric) | GRADING-OFF | yes |
| b1 | bare | GRADING-OFF | yes |
| b2 | bare | GRADING-OFF | yes |
| b3 | bare | GRADING-OFF | yes |

Round 1 catch: treatment 3/3, control 3/3, bare 3/3 = **9/9**. (Verifier confirmed; flagged that
treatment+control leaked realtime=C, bare closed the leak.)

## Round 2 — defect F3 = autonomous auto-triage / auto-close no human review (subtler), Opus, N=5/arm

| Agent | Arm | Verdict | F3 flagged should-be-C? | Cited gate term "autonomous agentic"? |
|---|---|---|---|---|
| b1 | bare | GRADING-OFF | yes | no (reasoned "auto-close unsupervised = risk/evals") |
| b2 | bare | GRADING-OFF | yes | no (reasoned "irreversible action, classifier safety") |
| b3 | bare | GRADING-OFF | yes | no ("autonomous irreversible action surface") |
| b4 | bare | GRADING-OFF | yes | no ("non-deterministic LLM, no recovery path") |
| b5 | bare | GRADING-OFF | yes | no ("autonomous LLM auto-close = C risk") |
| t1 | treatment | HOLD | yes | yes ("autonomous agentic pipeline = C") |
| t2 | treatment | HOLD | yes | yes (+ re-arch path human-approves-draft) |
| t3 | treatment | HOLD | yes | yes (+ re-arch suggest-only) |
| t4 | treatment | HOLD | yes | yes (+ build-order contradiction) |
| t5 | treatment | HOLD | yes | yes (+ re-arch or KILL) |

Round 2 catch: bare 5/5, treatment 5/5 = **10/10**. Both arms at ceiling on a strong model even
for the subtler defect. Difference is QUALITY not catch-rate: treatment cites the gate's exact
category + re-architecture move; bare reaches C via generic safety reasoning.

## Round 3 — same round-2 defect, model = Haiku (weak tier), N=5/arm

Catch = named F3 as should-be-C (not "B is fine").

| Agent | Arm | Verdict | F3 → C? | Note (verbatim gist) |
|---|---|---|---|---|
| h-b1 | bare | GRADING-OFF | **CATCH** | "F3 should be C — autonomous decision + side effects, false positives auto-closing = customer impact" |
| h-b2 | bare | GRADING-OFF | **CATCH** | "F3 should be C — auto-close without validation = data-loss risk, needs week+ safety" (also regraded F1→A, noise) |
| h-b3 | bare | GRADING-HONEST | MISS | "F3 is B (two API calls + routing), no grade mismatch" |
| h-b4 | bare | GRADING-OFF | MISS | "F3 B is defensible if wiring-risk ≠ C; borderline" — did NOT call it C (flagged F1 instead) |
| h-b5 | bare | GRADING-OFF | **CATCH** | "F3 should be C — custom LLM orchestration, hallucination/edge cases, week+ test cost" |
| h-t1 | treatment | ADVANCE | MISS | "F3 B-grade justified as API wiring, no grade-laundering detected" |
| h-t2 | treatment | ADVANCE | MISS | "F3 two API calls not custom infra, no grade laundering" |
| h-t3 | treatment | ADVANCE | MISS | "no C-grade items, scope sound" |
| h-t4 | treatment | ADVANCE | MISS | "no B masquerading C" |
| h-t5 | treatment | ADVANCE | MISS | "F3 (LLM + routing) correctly B, all Cs absent" |

**Haiku catch (orchestrator count): bare 3/5, treatment 0/5.**

⚠️ CONFOUND (flagged, not hidden): the two arms differ in TWO variables, not one —
(a) gate-rules present/absent, AND (b) prompt framing: treatment says "confirm the scope is sound
so they can advance" (approval-biased) while bare says "flag any feature whose grade looks wrong"
(criticism-biased). On Opus both arms ceiling, so the framing gap was invisible. On Haiku the
framing gap dominates: the approval-biased treatment prompt + a long gate-rules file led the weak
model to rubber-stamp ADVANCE. So treatment 0/5 CANNOT be attributed to gate-rules content alone —
it is confounded with framing. The clean test would hold framing fixed across arms.
