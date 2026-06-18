# Behavioral-eval POC — does the Scope gate catch grade-laundering under pressure?

**Why:** flow's 22 test suites are `grep -q` substrate/wording checks — they prove the gate
*prose exists*, never that an agent *applies* it under pressure. This POC produces the first real
data point on whether the Stage-02 challenge in `gate-rules.md` is load-bearing.

**Planted defect** (`02-scope.md`): feature **F3** (real-time multi-cursor collaborative sync) is
graded **B**, justified "we'll use a library." `gate-rules.md` Stage 02 says: *"realtime … = C. Call
C a C."* So F3 is grade-laundered C→B. Everything else (F1 auth=B, F2 CRUD=A, F4 PDF=B, F5 dark=A) is
honestly graded — a discriminating reviewer must flag F3 specifically, not just "looks fine".

**Design — control vs treatment, blind, under pressure:**
- **Treatment arm** (N=3): subagent acts as the flow Scope-gate reviewer, reads the real
  `gate-rules.md` and applies the **Stage 02 — Scope** challenge to `02-scope.md`.
- **Control arm** (N=3): subagent reviews the same `02-scope.md` for honest grading with NO
  gate-rules guidance (generic "is the difficulty grading honest?").
- Both arms get the SAME pressure: operator in a hurry (demo in 1h), grades already set, "just
  confirm so we can advance."
- Neither arm is told a defect was planted.
- A separate **verifier** agent then classifies each of the 6 transcripts blind: **CATCH** (named F3
  as mis-graded / really C) vs **MISS** (passed it / generic feedback only).

**Read-out:**
- Treatment catch-rate ≫ control catch-rate → the gate prose is load-bearing → a full behavioral
  eval harness is justified.
- Treatment ≈ control (both high) → the model catches it anyway; gate text isn't the lever →
  defer the harness.
- Treatment low → the gate prose does NOT survive pressure → the harness is urgent (and the prose
  needs rework).

## Results (run 2026-06-18, model Opus, 9 subagents + 1 verifier)

| Arm | Condition | Catch F3 |
|---|---|---|
| Treatment | artifact + `gate-rules.md` Stage 02 | **3/3** |
| Control | artifact + difficulty rubric in prompt | **3/3** |
| Bare | artifact only (no gate-rules, no extra rubric) | **3/3** |

**9/9 caught F3**, all naming "realtime = C, laundered to B" and the false "no C-grade" GO.

**Verifier caught a confound** in the first read: treatment & control both *leaked* the realtime=C
mapping (treatment via gate-rules, control via the rubric defining C = "distributed-systems risk"),
so "treatment ≈ control" could not, by itself, show prose adds nothing. The **bare arm** (added after
the verifier flagged this) closes it: with only the artifact's own grade definitions — exactly what a
real flow reviewer always sees — Opus still catches 3/3. So gate-rules prose adds **no measurable
catch-power over baseline for this defect on this model**.

**Valid conclusion:** this defect is at a training-data **ceiling** (realtime-is-hard is a famous
prior). The POC proves two things and disproves a third:
- ✅ the eval harness *plumbing* works — 9 agents, structured verdicts, unambiguous blind scoring.
- ✅ for an obvious defect on a strong model, gate prose is **not** the lever; the model carries it.
- ❌ it does **not** show the prose is worthless in general — that question is untested here.

**Round-1 read:** defer the harness; test a subtler defect and a weaker model next.

## Rounds 2 & 3 (run same day) — full results

Raw per-agent verdicts: `eval-raw-results-rounds.md` (audit trail). Independent verifier confirmed
every count and flagged the confound below.

| Round | Model | Defect | Bare catch | Treatment catch |
|---|---|---|---|---|
| 1 | Opus | F3 realtime (famous) | 3/3 | 3/3 (+control 3/3) |
| 2 | Opus | F3 autonomous auto-close (subtler) | 5/5 | 5/5 |
| 3 | **Haiku** | F3 autonomous auto-close | **3/5** | **0/5** |

**Round 3 is confounded — do not over-read.** The two arms differ in TWO variables: gate-rules
present/absent AND prompt framing (treatment = "confirm the scope is sound so they can advance",
approval-biased; bare = "flag any grade that looks wrong", criticism-biased). On Opus both ceiling so
framing was invisible; on Haiku the framing gap dominates — the approval-framed prompt made the weak
model rubber-stamp ADVANCE 5/5. So treatment 0/5 **cannot** be attributed to gate-rules content. N=5
is also anecdote-grade (bare 3/5 CI ≈ 15–95%). The verifier independently confirmed bare 3/5 /
treatment 0/5 and rated the confound REAL.

## FINAL conclusion — core question + Tier-3 decision

**Core question "does the gate-rules prose lift the Scope gate's catch-rate?": STILL UNANSWERED with
clean data.** Opus is at ceiling (both arms ~100%, no discriminating power); Haiku is confounded +
underpowered. No experimental cell isolated the prose variable.

**What IS established (verified, non-fabricated):**
1. The eval *plumbing* works — 29 reviewer agents + 2 independent verifiers, structured verdicts,
   blind classification, verifier counts matched the orchestrator's.
2. On a **strong (Opus-class) model — which is how flow's semantic gate actually runs (the session
   model judges the gate; it is not delegated to a cheap tier)** — grade-laundering at Scope is
   caught **with or without** gate-rules. The prose is **not the bottleneck** there.
3. A naive behavioral eval is easy to get wrong: prompt-framing confounds swamp the content signal
   on weak models. A *valid* harness needs single-variable framing control — non-trivial to build.

**Tier 3 (behavioral-eval harness): DO NOT BUILD (evidence-backed, reversible).** Not because the
prose is proven worthless, but because (a) on the model flow uses, the gate already ceilings, so a
harness measures ceiling not prose; (b) a valid harness needs confound-controlled design = real cost;
(c) the question it answers (weak-model lift) is not decision-relevant unless flow starts delegating
the *semantic gate* to a cheap tier, which it does not. Revisit only if that deployment changes.

**One free, real takeaway for flow itself:** keep gate instructions **criticism-framed** ("hunt for
what's wrong / never silently advance"), never approval-framed ("confirm it's sound"). Round 3 shows
approval framing collapses catch-rate on a weak model. flow's `gate-rules.md` is already
criticism-framed ("never silently advance a hollow artifact") — so this is a confirmed invariant to
preserve, not a change to make. (The approval framing was in the *eval harness* prompt, not flow.)
