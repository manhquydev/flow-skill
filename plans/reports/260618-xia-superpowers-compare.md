# Xia Compare: superpowers → flow-skill

**Mode:** `--compare` (research + anti-FOMO evaluation, no implementation)
**Date:** 2026-06-18
**Source manifest:** `D:\project\flow\superpowers` (obra/Prime Radiant Superpowers), branch reflecting v6.0.2 (`b62616f`), local path. 14 skills under `skills/`.
**Local target:** `D:\project\flow\flow-skill` — `/flow` buildflow gated harness v0.10.0.

---

## 1. The core framing (read this first)

Flow and Superpowers are **the same genre** (a gated, subagent-driven build methodology) built from
opposite directions:

| | Superpowers | flow |
|---|---|---|
| Gates | the **agent's own behavior** (Iron Laws, rationalization tables fight the agent cutting corners) | the **artifact + operator** (mechanical `flow.sh` exit code + semantic challenge on the file) |
| Memory | progress ledger file (survives compaction) | `harness/` DB + `/flow recall` |
| Subagents | per-task implementer→reviewer, file-handoff scripts | per-card scoped brief, ck:/bmad/Codex/Antigravity tiers |
| Verification | `verification-before-completion` (evidence before claims) | `ground-truth-gates` + "Done = proof in the world" |
| Philosophy | zero-dependency, eval-tuned prose | zero-dependency, harness-first, multi-vendor |

**Consequence for FOMO control:** ~80% of Superpowers' *structure* already exists in flow, often
more advanced (multi-vendor engines, live-URL verify, debt ledger, usage analytics). Cloning skills
would be redundant. The genuinely missing thing is **one rhetorical asset class** Superpowers is
better at, plus **2–3 concrete techniques**. Everything else is a SKIP.

---

## 2. Decision matrix

| # | Candidate (source) | Flow today | Verdict | ROI | Risk |
|---|---|---|---|---|---|
| P1 | **Anti-rationalization gate-defense** (Iron Law + Rationalization table + Red Flags form, across all skills) | `gate-rules.md` has semantic challenges, but they police the *artifact*, not the agent's temptation to pass a hollow gate / grade-launder / self-assess "done" | **PORT (adapt form)** | High | Low |
| P2 | **"Watch it fail" regression proof** (test-driven-development: revert fix → see red → restore → green) | ZERO red/green discipline anywhere in refs | **ADAPT (narrow)** | Med | Low |
| P3 | **"Never pre-judge a reviewer"** (subagent-driven-development: no "at most Minor", no "don't flag X") | `adversarial-review.md` says reviewer "must find issues" but doesn't forbid the controller from defanging the prompt | **PORT (1 rule)** | Med | Low |
| P4 | **Subagent model-tiering** (cheapest model that fits; turn-count beats token-price; always specify model) | Cost gate exists only for Codex/Antigravity engines | **ADAPT (where flow controls model)** | Med | Low |
| P5 | verification-before-completion (whole skill) | = "Done=proof in world" + `ground-truth-gates` | **SKIP** (steal only its table → folds into P1) | — | — |
| P6 | systematic-debugging (4-phase, root-cause-tracing) | two-strikes rescue + DEBT halt; user already has `ck:debug` + `debugger` agent | **SKIP — reference, don't rebuild** | Low | Med |
| P7 | brainstorming (one-question-at-a-time, 2–3 approaches, HARD-GATE) | Idea/Scope gates already enforce evidence + scope | **SKIP** (optional teach-mode polish only) | Low | Low |
| P8 | writing-plans (No-Placeholders, Global Constraints, Interfaces block) | `[FILL]` mechanical check + `/flow consistency` + contract-is-the-seam | **SKIP — covered** | — | — |
| P9 | dispatching-parallel-agents | `/flow ready` parallel-safety + auto worktrees | **SKIP — covered** | — | — |
| P10 | using-git-worktrees / finishing-a-development-branch | `auto-run.md` worktree loop + deploy/verify-live | **SKIP — covered** | — | — |
| P11 | brainstorming visual-companion (browser mockups) | n/a; flow is CLI/harness-mission | **SKIP — off-mission, heavy** | — | High |
| P12 | using-superpowers bootstrap, `docs/superpowers/` paths, "your human partner" voice | flow has its own install + voice | **SKIP — fork-specific** | — | — |

---

## 3. The three things actually worth doing

### P1 — Port the anti-rationalization *form* into `gate-rules.md` (HIGH)

Superpowers' own `CLAUDE.md` states the Rationalization tables / Red-Flags lists / Iron Laws are its
most eval-tuned, behavior-shaping content — "code that shapes agent behavior," not prose. Flow's
weakness is exactly the seam these defend: a gate can mechanically pass while the **agent** is the one
tempted to wave through a hollow artifact, launder a C to a B, or call a card done off an agent's
self-report. Flow already names these failure modes — it just doesn't arm them with the
pressure-tested rhetorical form.

**Adapt, don't transplant:** keep flow's voice ("operator", not "your human partner"). Add to
`gate-rules.md` a compact **"Gate-defense" block** per high-risk stage (Scope, Review, Verify) shaped
as: one Iron Law + a 4–6 row rationalization table aimed at flow's *known* drifts (from RETRO/usage:
grade-laundering, fabricated competitor quotes, "merge ≅ shipped", "agent said it passed"). This is
additive prose, zero dependency, fits flow's existing semantic layer. **No mechanical change.**

### P2 — Adapt "watch it fail" into the Verify/Review gate, NOT a universal TDD law (MED)

Do **not** import the TDD Iron Law ("NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"). It clashes
with flow's contract-/evidence-first philosophy and breaks for `skill` and `library` project types
where test-first is awkward. **That would be FOMO.**

Do import the one narrow, transferable nugget: a **regression test for a bug-fix card is only proven
by red→green** — revert the fix, watch the test fail, restore, watch it pass. Add as a verification
*technique* in `ground-truth-gates.md` / `adversarial-review.md` for bug-fix cards. It strengthens
"Done = proof" with a concrete anti-self-deception move and respects flow's non-TDD stance.

### P3 + P4 — Harden adversarial review + subagent dispatch (MED)

- **P3:** Add one rule to `adversarial-review.md` / `agent-stage-mapping.md`: *the controller never
  pre-judges the reviewer* — no "at most Minor", no "don't flag X", no pasting the plan's own
  example code as proof its weaknesses were chosen. A review told what not to find isn't adversarial.
  One paragraph; directly amplifies flow's existing "review must find issues" rule.
- **P4:** Flow already has a cost gate for the Codex/Antigravity engines. Extend the *principle*
  ("use the least-capable model that fits the task; specify it explicitly; turn-count beats
  token-price") wherever flow controls dispatch model. Where model is fixed by the host harness
  (most ck: agents), it's inapplicable — don't fabricate a knob. Low effort, aligns with the
  operator's standing cost-discipline + numbers-over-FOMO preference.

---

## 4. Explicit anti-FOMO rejections (and why)

- **Whole-skill cloning** — flow is self-contained and more advanced on structure; importing
  superpowers skills as deps violates flow's zero-dependency design and duplicates gates.
- **TDD as iron law** — philosophy clash (contract/evidence-first; skill/library types). Take the
  technique (P2), reject the law.
- **A debugging skill** — the operator already runs `ck:debug` + `debugger` agent; flow should add at
  most a one-line pointer at two-strikes rescue, never a parallel 4-phase engine.
- **Visual companion / brainstorming browser** — token-heavy, GUI-first, off-mission for a
  harness/CLI skill.
- **Bootstrap/auto-trigger, path conventions, "human partner" voice** — fork-specific; would dilute
  flow's identity for no behavioral gain.

---

## 5. Risk score

**Overall port risk: LOW.** All three recommended items (P1–P4) are **additive reference prose** to
existing files (`gate-rules.md`, `ground-truth-gates.md`, `adversarial-review.md`,
`agent-stage-mapping.md`). No runner/`flow.sh` change, no new dependency, no mechanical-layer change,
no template edits. Reversible by deletion. Net new maintenance surface: ~3 doc sections.

## 6. Recommended next step

These are doc-layer behavior-shaping edits — flow's own seam. Run them through flow's normal change
discipline (they touch `references/`, not `_templates/` or `runner/`). Suggested order: **P1 first**
(highest ROI, sets the rhetorical form P2/P3 reuse), then P3+P4 (one review pass), then P2.

If you want this as an executable plan with cards: `/flow` on flow-skill itself, or `/ck:plan` from
this report. No `/ck:cook` handoff is warranted yet — scope is small and you may want to hand-author
behavior-shaping prose rather than delegate it.

---

## 7. Red-team reconciliation (3 independent reviewers, 2026-06-18)

Three adversarial reviewers (architect/skeptic, missed-opportunity, YAGNI/cost) re-checked §1–6
against real files. All SKIP verdicts (P5–P12) held up with file:line evidence — no hand-waving
found. But the red team **converged on two corrections backed by NEW evidence**, which revise the
blue team's priority (not its facts):

**Correction A — P1 was over-ranked.** All three flagged it. The "from RETRO/usage" citation for P1
is **unverifiable** — no retro entry or harness record backs it. And `gate-rules.md` **already
operationalizes** the cited drifts: grade-laundering (Stage 02), fabricated quotes (Stage 01,
"highest fabrication risk"), merge≠shipped (card gate), agent self-report (`ground-truth-gates.md`
rules 1&3). P1 reinforces a rule flow *already enforces mechanically via `flow.sh` exit codes* — so
its behavioral delta is the **weakest** of the four, not the highest. → **P1 downgraded High→DEFER**
(a maintenance form-tightening, ~25 lazy-loaded lines, not a priority).

**Correction B — P3 is the true #1.** Architect + YAGNI both independently: P3 closes a *real
structural gap* — flow's `adversarial-review.md` governs the reviewer's **output** ("must find
issues, zero findings halts") but nothing governs the controller's **input** (nothing forbids
handing the reviewer a defanged "don't flag X / at most Minor" prompt). A poisoned reviewer prompt
defeats flow's last gate before merge. ~6 lines, cheapest, real. → **execution order flips to P3 →
P2 → … (P1/P4 deferred).** P4 also deferred: flow owns no model knob on most ck: dispatch paths, so
the principle has no binding point yet.

**New items the blue team missed (verified gaps, not FOMO):**

| ID | Item (source) | Why it's a real gap (evidence) | ROI | FOMO-guard |
|---|---|---|---|---|
| M1 | **Adversarial behavioral eval of the gates** (`writing-skills/testing-skills-with-subagents.md`) | flow's 22 suites are `grep -q` substrate/wording unit tests — they prove the prose *exists*, never that an agent *obeys* the gate under pressure. flow's OWN research note: "no harness measures whether flow's gates catch what they should." A wording edit can pass all 22 suites while silently regressing real compliance. | **High** | Adopt **only the cheap tier** — markdown pressure-scenarios + 5-rep micro-test vs a no-guidance control. **NOT** the drill/SWE-bench harness (that *would* be FOMO). |
| M2 | **"Recipe beats prohibition / match-form-to-failure"** empirical finding (`writing-skills/SKILL.md`) | flow's gates are written almost entirely as prohibitions; some police *output shape*, where Superpowers' head-to-head tests show a prohibition *backfires* (produced MORE unwanted output than no-guidance control). No meta-authoring guidance exists in flow. | **High** | It's the multiplier on P1 — porting P1's table *without* M2 risks making some gates worse. Empirical (N-backed), matches "numbers over FOMO". |
| M3 | **Anti-sycophancy clause** (`receiving-code-review/SKILL.md`) | flow has no ban on performative agreement to review findings ("You're absolutely right!"); a known LLM failure at flow's "apply your own decision rules" seam. ~2 lines, same file as P3. | Med | Folds into the P3 edit. |
| M4 | **`task-brief` / `review-package` handoff scripts** (`subagent-driven-development/scripts/`) | flow routes context via file *pointers* (good) but has no mechanic to package a **diff as a file** for the reviewer → controller pastes diffs (a real session hit 42k chars, 99% pasted history). Two ~40-line zero-dep bash scripts, fit flow's `runner/` convention. | Med | Cherry-pick the review-package mechanic; don't clone the SDD workflow. |
| M5 | persuasion-principles.md + 3 prompt-template clauses (don't-trust-the-report, self-review-before-handoff, reviewer-read-only) | enabler/justification layer; flow uses these patterns intuitively without documenting why | Low | Most skippable; cherry-pick only. |

**Reconciled execution order (evidence-ranked, all zero always-on cost — lazy-loaded refs only):**

1. **Tier 1 (do-now, converged, ~10 lines):** P3 + M3 → `adversarial-review.md` / `agent-stage-mapping.md`.
2. **Tier 2 (cheap, real, scoped):** M2 (form-selection meta-rule, makes all future gate edits safer) + P2 (red→green for bug-fix cards, CLI/library only) → `gate-rules.md` authoring note + `ground-truth-gates.md`.
3. **Tier 3 (highest-leverage, real commitment):** M1 cheap-tier behavioral eval — the "test behavior, not substrate" gap. Bigger scope; this is the one genuine product decision.
4. **Defer (maintenance pass):** P1 (form-tighten, guided by M2), M4 (handoff scripts), P4 (until a model knob exists), M5.

**Net:** the red team did not overturn a single fact in §1–6, but it **re-pointed the project**: the
highest-leverage move is not *more* gate prose (P1) — it's **P3 (close the reviewer-poisoning hole)
now**, and **M1+M2 (make gate prose testable and well-formed)** as the real upgrade. Both M1/M2 are
zero-dependency markdown and survive the operator's anti-FOMO bar because they're backed by flow's
own research note and N-backed empirical results, not trend.
