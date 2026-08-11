# Code review — flow harness authority continuity (v0.27.0 / npm 0.4.0)

**Date:** 2026-08-11  
**Plan:** `plans/260811-1405-flow-harness-authority-continuity/`  
**Reviewer posture:** production-readiness / Staff Engineer  
**Verdict:** **REQUEST_CHANGES**

## Scope

| Item | Value |
|------|--------|
| Focus | Plan 260811-1405 acceptance criteria 1–7 + trust/regression |
| Primary tree | `skills/flow/**`, `skills/harness-skill/**`, `tests/test_flow_*`, `npm-wrapper/**` |
| Versions claimed | skill **0.27.0**, npm **0.4.0** |
| Note | Review is content-verified against plan + tree; full `run_all.sh` not re-executed in this pass (journal claims green) |

## Acceptance criteria matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Live authority flow-owned; no live Trust/consumer 0.1.17 pin table in harness README or SKILL harness bullet | **PASS** | `skills/flow/harness/README.md:8-20` Live authority table; no `\| Trust / consumer \|` row. `skills/flow/SKILL.md:238` flow-owned + SUPERSEDED gap. Contract bans live pin table: `tests/test_flow_skill_harness_docs_contract.sh:17-21`, `tests/test_flow_harness_lineage_contract.sh:54-58` |
| 2 | Non-negotiable trust: story complete, proof-source, forbidden bare implemented | **PASS** | README story completion `skills/flow/harness/README.md:74-79`; harness-skill `skills/harness-skill/SKILL.md:34-39`; tests sections B/C/D `tests/test_flow_skill_harness_docs_contract.sh:23-51`; runtime reject in `skills/flow/harness/flow_harness.py:208-209` |
| 3 | R-IMPROVE-HARNESS in native-rituals; tests expect 6 Purpose/When/informs | **PASS** | `skills/flow/references/native-rituals.md:137-170`; `tests/test_flow_native_rituals.sh:32-49` (`ck "6"` for Purpose/When/informs) |
| 4 | Brownfield assess ledger + gate-rules section; material stop on 02/03/05 | **PASS** | Template ledger `skills/flow/_templates/00-inspect.md:42-57`; gate-rules `## Brownfield assess` `skills/flow/references/gate-rules.md:22-34`; material stop lines 69-71, 86-87, 113-114; assess tests A/C `tests/test_flow_assess.sh:48-51,26-33` |
| 5 | No DB migration forced; standalone (no required rust binary) | **PASS** | Schema inventory still 001–005 + 009–012 + 014 (`tests/test_flow_harness_lineage_contract.sh:37-47`); rust refuse on flow-lineage (`:60-70`); portable-manifest `cargo: not required` |
| 6 | npm-wrapper synced; versions 0.27.0 skill + 0.4.0 npm coherent | **PARTIAL FAIL** | Skill tree mirror OK (`npm-wrapper/skills/flow/harness/README.md` live authority; SKILL 0.27.0). Machine versions OK: `skills/flow/SKILL.md:11`, `.claude-plugin/plugin.json:4`, `portable-manifest.json:3`, `npm-wrapper/package.json:3` = 0.4.0. **Installer README still says current 0.3.1 / skill 0.26.0** (`npm-wrapper/README.md:13`, `npm-wrapper/README_VN.md:13`) — ships in npm tarball (`package.json` `files`) |
| 7 | No secrets; no regression to hollow-done floor | **PASS** | No secret material in skill ship surface. Hollow-done floor intact `skills/flow/runner/flow.sh:1240-1339` + tests `tests/test_flow_done_evidence.sh`, `tests/test_flow_auto_done_path.sh` |

## Overall assessment

Wave Authority Continuity is **substantively implemented** on the skill hot path: authority reframe is atomic with contract/lineage tests, trust greps preserved, improve ritual + assess claim ledger + material stops landed, skill product mirrors agree at 0.27.0, npm package.json at 0.4.0, and the skill tree under `npm-wrapper/skills/flow` matches the authority narrative.

Ship is **not clean** while the **npm package README still advertises the previous GA** as “current.” That is a version-coherence defect on the published installer surface (AC6), not a historical CHANGELOG entry.

## Critical issues

None (no trust-boundary removal, no hollow-done regression, no forced schema migration, no secret leak).

## High priority

### H1 — npm-wrapper README still advertises 0.3.1 / skill 0.26.0 as current

**Impact:** After tag/publish of 0.4.0, the tarball’s primary human docs contradict package.json + bundled SKILL.md. Users reading npm/GitHub package README get the wrong “current” axes. Undercuts AC6 and phase-05 “version coherence.”

**Evidence:**
- `npm-wrapper/README.md:13` — `# Newest GA — current: v0.3.1, ships skill v0.26.0`
- `npm-wrapper/README_VN.md:13` — same stale current
- `npm-wrapper/README.md:27-28,107` — examples still 0.3.0 / 0.26.0
- Contrast: `npm-wrapper/package.json:3` = `0.4.0`, `npm-wrapper/CHANGELOG.md:5-9` claims 0.4.0 ships skill 0.27.0, `npm-wrapper/skills/flow/SKILL.md:11` = `0.27.0`
- Root README is already correct: `README.md:46,164`

**Fix:** Update “current” lines and dual-axis examples to **0.4.0 / 0.27.0** before tag. Keep older numbers only in CHANGELOG history sections.

## Medium priority

### M1 — `docs/codebase-summary.md` version axes still 0.24.x / 0.1.x

**Evidence:** `docs/codebase-summary.md:42`  
**Impact:** Internal docs drift; not on npm hot path.  
**Fix:** Align axes to skill 0.27.x / npm 0.4.x (or point only at release-process).

### M2 — Docs-contract ownership assert is non-failing

**Evidence:** `tests/test_flow_skill_harness_docs_contract.sh:59`  
`grep … && ok … || ok …` always passes.  
**Impact:** Weak regression signal if SKILL harness bullet loses ownership/ritual link.  
**Fix:** Make fail branch a real `bad` (or drop the assert).

### M3 — Assess ledger honesty is mostly semantic/test-shaped (by plan YAGNI)

**Evidence:** Plan phase-04 preferred template+tests over runner ledger row count; no mechanical “≥1 non-FILL ledger row” in `flow.sh assess`.  
**Impact:** Agent can check the ledger checkbox and still invent product law; only FILL scan + semantic challenge catch hollow. Acceptable under plan, residual quality risk.  
**Optional harden:** cheap assess re-scan for one non-placeholder ledger data row when section present.

## Low priority

### L1 — Plan phase frontmatter still `status: pending` while plan `status: completed`

Process hygiene only (`phase-0{1-5}-*.md`).

### L2 — Plan success-criteria checkboxes in `plan.md` still unchecked

Does not affect product; update if tracking completion in plan body.

## Edge cases (scout)

| Risk | Status |
|------|--------|
| Live pin greps accidentally deleted with trust greps | **Mitigated** — trust sections B/C/D retained; pin bans replaced with negative asserts |
| npm skill mirror desync | **Mitigated for skill tree** — mirror has ledger, R-IMPROVE, live authority; **not** for installer README |
| Old assess files without ledger | **OK by design** — no retrofit; scan_gate only |
| Fresh-agent keep without rerun | Ritual text forbids keep (`native-rituals.md:163-164`); process-only, not mechanical |
| Rust binary required | **No** — refuse-forward + optional archive smoke only |
| Hollow-done floor regression | **No** — multi-signal score still in `flow.sh` |

## Positive observations (risk calibration only)

- Authority flip kept non-negotiable trust surfaces (complete / proof-source / forbidden bare implemented) in docs, harness-skill, Python reject path, and contract tests.
- GAP SUPERSEDED banner + historical archive pin header cleanly separate history from live trust.
- Native-rituals count test hard-codes 6 — prevents silent ritual drift.
- Dual version axes (skill product vs npm installer) remain intentional and documented in root README / quality-metrics.

## Recommended actions (before APPROVE / tag)

1. **Must:** Fix `npm-wrapper/README.md` + `README_VN.md` current version lines to **0.4.0 / skill 0.27.0**; refresh dual-axis examples.
2. **Should:** Patch `docs/codebase-summary.md` version sentence.
3. **Should:** Tighten docs-contract SKILL ownership assert (M2).
4. **Verify:** Re-run `bash tests/test_flow_skill_harness_docs_contract.sh`, `test_flow_harness_lineage_contract.sh`, `test_flow_native_rituals.sh`, `test_flow_assess.sh`, `test_flow_done_evidence.sh`, then `bash scripts/release-preflight.sh` (and preferably `tests/run_all.sh`).

## Metrics (approximate)

| Metric | Value |
|--------|--------|
| Type coverage | N/A (docs/bash/python skill; not a TS app) |
| Focused AC surface | 7 criteria reviewed |
| Critical findings | 0 |
| High findings | 1 |
| Medium findings | 3 |
| Low findings | 2 |
| Secrets found | 0 |

## Plan task status (recommendation to lead — do not mutate plan files here)

| Phase | Content | Reviewer view |
|-------|---------|----------------|
| 1 inventory | pin-inventory present | complete |
| 2 authority reframe | docs+tests flipped | complete |
| 3 improve ritual | R-IMPROVE + test 6 | complete |
| 4 assess/material | ledger + stops | complete |
| 5 ship/coherence | versions + sync | **blocked on H1** installer README |

## Unresolved questions

- Whether full `tests/run_all.sh` was actually green on this exact tree (journal asserts ~176s; this review did not re-run).
- Publish state: is 0.4.0 already on registry? README “current” must match whatever is about to be tagged.

---

**Verdict: REQUEST_CHANGES** — land H1 (npm-wrapper README current versions), then re-check AC6 for APPROVE.
