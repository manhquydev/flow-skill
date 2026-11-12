# Dogfood journal — building the Codex tier with /flow itself (2026-06-14)

**Run:** released `/flow` (global v0.2 runner) → built flow-skill **v0.4.0** (Codex cross-vendor
tier). Full gauntlet, `skill` type, `work` mode. Outcome: shipped, committed `91d966c`, global-installed.

## What was built
OpenAI Codex (GPT-5.x, `openai-codex` plugin) as a detect-and-degrade **4th agent tier**: two-strikes
rescue · cross-model adversarial review · opt-in primary drafter (research/build). Default stays ck:;
gate identical on every path; absence/unusability never breaks a run. Seam: `references/codex-integration.md`,
wired into `agent-detection`/`agent-stage-mapping`/`auto-run`/`adversarial-review`/`SKILL.md`/READMEs.
Regression guard `tests/test_flow_codex_integration.sh` (19 checks). Suite: **243 dev checks, 0 regressions.**

## Decisions of note
- **Codex is a tier, not a router** (ADR-CODEX-001). One detect-and-degrade contract, no parallel system.
- **Scope expanded mid-run** (operator): from rescue/critic-only → also opt-in primary drafter (F-E).
- **No runner edits** — integration lives at the semantic/reference layer; native `flow.sh` Codex probe
  deferred to v0.5 (forbidden to edit the runner mid-run).

## The headline (why dogfooding paid off)
The new **cross-model Codex review was run live on its own diff** and caught **2 real defects** the
same-model author AND the same-model semantic gate both passed:
1. HIGH — detection routed on "installed" not "usable"; an installed-but-unauthenticated host would
   route into Codex then fail (broke detect-and-degrade). → split INSTALLED vs USABLE + liveness probe.
2. MED — the review-lens added a zero-findings auto-trigger contradicting the 3-trigger cost gate. → opt-in.
Both fixed, re-verified RESOLVED by a live `codex:codex-rescue` call. First-party data point for the
cross-model-catch metric: **2/2 real defects single-vendor review missed.** Then a same-model
code-reviewer pass caught 3 more (1 test-guard looseness + 2 stale README counts) — all fixed.

## Dogfood findings (→ quality-metrics.md, for the next upgrade)
- **DF-1 (HIGH):** `flow coherence` reported "no version fields found" while a real drift existed
  (SKILL 0.2.0 / manifest 0.3.0 / docs v0.2). The anti-drift tool is blind to SKILL frontmatter +
  manifest `version`. Runner fix next release.
- **DF-2 (MED):** the same-model Contract/PRD semantic gates passed inconsistent docs; only the
  cross-model engine caught it → wire the Codex lens into the Contract gate, not just card review.
- **DF-3 (MED):** harness CLI verb inconsistency — `decision add --id` vs `intervention` (no `add`,
  `--description` not `--note`) vs `intake`. 3 usage errors this run. Normalize.
- **DF-4 (LOW):** auto-trace stuck at tier 1/3 on every card (lane 'normal' wants 2) — nags each check.
- **DF-5 (LOW):** card allowed-files containment conflicts with review-driven cross-doc fixes (the
  HIGH finding spanned 3 docs but C-003 owned 1) — needs an escape hatch / honest-drift convention.
- **DF-6 (LOW, new):** running `/flow` on a repo drops run-state files (MODE, PROJECT_TYPE, DESIGN.md,
  RETRO.md, flow/, cards/) at repo root, untracked + not gitignored — pollutes the host repo.
