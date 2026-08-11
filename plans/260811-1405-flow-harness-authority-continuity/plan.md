---
title: "flow harness authority continuity"
description: "Post repository-harness EOL: atomic authority reframe (docs+tests), improve-flow-harness ritual, assess claim classes + material-authority stop. Serves usefulness, code quality under agents, multi-session continuity. Standalone; no harness-cli resync."
status: completed
priority: P1
effort: "3-5d"
tags: [flow, harness, authority, continuity, improve-ritual, assess, standalone]
created: 2026-08-11
blockedBy: []
blocks: []
sources:
  - plans/reports/brainstorm-advise-260811-1405-harness-authority-continuity-vi.md
  - plans/reports/advise-260811-1354-repository-harness-latest-vs-flow-upgrade-vi.md
  - plans/reports/advise-260811-1050-flow-upgrade-harness-trust-vi.md
related_completed:
  - plans/260811-1120-flow-hollow-done-trust-eval/
deferred:
  - native strategist ritual R-STRATEGIST (hollow plan phase-04; was "§6" — do NOT reuse number)
  - evidence capsule v2 full port
  - skill three-way self-update
ritual_ids:
  improve: R-IMPROVE-HARNESS
  strategist_reserved: R-STRATEGIST
---

# flow harness authority continuity

## Overview

After **repository-harness ADR 0027** (protocol v1 / `harness-cli` EOL) and **flow v0.26** hollow-done floor, the next harness upgrade is **not** schema sync and **not** another hollow-done mega-pass.

This plan delivers **Wave Authority Continuity**:

1. **Honest product authority** — durable layer is **flow-owned**; dead CLI pins leave the *live* hot path; contract tests stop *requiring* 0.1.14/0.1.17 as current trust.
2. **Improve-flow-harness ritual** — port `$improve-harness` spirit (baseline → one intervention → **fresh-agent rerun** before keep).
3. **Assess claim classes + material-authority stop** — brownfield/planning quality under agents.

**North-star (implementation compass):** skill useful in agent coding → **quality code under agents** + **continuity across sessions/agents**. Every phase must map to at least one axis.

| Axis | This plan |
|------|-----------|
| Usefulness | Clear authority; harness-skill redirects; improve path explicit |
| Quality under agents | Assess tags; material stop at Scope/PRD/Contract |
| Continuity | Improve ritual + external memory honesty; no silent pin rot |

## Constraints

- Standalone: no required Rust `harness` / AgentKit / live `harness-cli`
- **Atomic** docs + `tests/test_flow_skill_harness_docs_contract.sh` + `tests/test_flow_harness_lineage_contract.sh` flip
- No forced DB migration; existing `.flow/harness.db` opens
- YAGNI: no full onboard evidence-capsule v2; no 3-way skill installer
- Durable SQLite remains product (not deleted to “match” repo-harness)

## Non-goals

- Re-integrate harness-cli or port schema 006–013  
- Graph default-on  
- Hollow-done wave 2  
- Native strategist (backlog)  
- Engineering-wisdom pack clone  

## Goals

| # | Goal | Priority | Axis |
|---|------|----------|------|
| 1 | Live hot-path authority = flow durable + runner + semantic gates; EOL CLI historical only | P1 | Usefulness |
| 2 | Contract/lineage tests enforce **new** authority story (not old pins as live trust) | P1 | Continuity |
| 3 | Ritual **R-IMPROVE-HARNESS** (stable id; not fragile "§6") + mandatory native-rituals test update | P1 | Continuity + Usefulness |
| 4 | Assess claim ledger (mechanical min rows) + gate-rules **Brownfield assess** section + material-authority stop | P1 | Quality |
| 5 | Ship: suite green, npm-wrapper sync, version/coherence, CHANGELOG | P1 | Usefulness |

### Non-negotiable trust greps (survive authority flip)

These **must remain** in contract tests after pin flip (only *live pin* greps may be removed/replaced):

1. Ban bare `story update --status implemented` (allow reject/never wording)
2. `story complete` + `proof_source|proof-source` in harness README
3. harness-skill: Forbidden implemented + Required story complete + proof-source list
4. Lineage: rust refuse-forward / flow-lineage behavior still documented or tested
5. Optional smoke pin file: reframe as **historical archive digest**, never “live trust CLI”

## Architecture (target narrative)

```text
BEFORE (stale):
  skill docs → pin harness-cli 0.1.14/0.1.17 as "authority"
  tests → FAIL if pins missing
  GAP → upgrade path illusion

AFTER:
  skill docs → live authority = flow_harness.py + flow.sh + gate-rules
               historical: repository-harness pre-EOL / last archive 0.1.22
  GAP → superseded: no upstream schema sync; bands owned forever
  harness-skill → legacy binary optional OR redirect /flow harness
  native-rituals → § improve-flow-harness (fresh rerun)
  00-inspect + gate-rules → claim class + material stop
```

## Phases

| # | Phase | Status | Deps | Effort |
|---|-------|--------|------|--------|
| 1 | [Start — inventory & contract freeze](./phase-01-start.md) | Pending | — | 0.5d |
| 2 | [Authority reframe atomic](./phase-02-authority-reframe-atomic.md) | Pending | 1 | 1–1.5d |
| 3 | [Improve-flow-harness ritual](./phase-03-improve-flow-harness-ritual.md) | Pending | 2 | 0.5–1d |
| 4 | [Assess claims + material authority](./phase-04-assess-claims-and-material-authority.md) | Pending | 2 | 0.5–1d |
| 5 | [Ship docs version coherence](./phase-05-ship-docs-version-coherence.md) | Pending | 2,3,4 | 0.5d |

Phases 3 and 4 may run **in parallel** after phase 2 merges green.

## Success Criteria

- [ ] `rg` live hot path (SKILL.md harness bullet, harness README authority table, harness-skill description): zero “trust pin / live consumer 0.1.17” framing
- [ ] Allowlist for remaining 0.1.x strings: CHANGELOG history, GAP **Historical**, `pins/*.sha256sums` labeled archive, optional smoke reframe
- [ ] GAP supersede + **no schema sync** first-screen
- [ ] Docs/lineage contract tests green; **non-negotiable trust greps** still present
- [ ] `R-IMPROVE-HARNESS` in `native-rituals.md`; `test_flow_native_rituals.sh` expects **6** Purpose/When/informs (or ≥6 open)
- [ ] gate-rules has `## Brownfield assess (flow/00-inspect.md)` (never call it “Stage 00-inspect”)
- [ ] Material-authority stop on Stages 02/03/05
- [ ] `test_flow_assess.sh` covers ledger scaffold + clean fixture with ledger
- [ ] `npm-wrapper/skills` synced before version bump (not optional)
- [ ] `tests/run_all.sh` green; coherence clean on version fields
- [ ] Standalone: no new required binary

## Ship slicing (cook order)

| Wave | Content | May ship alone? |
|------|---------|-----------------|
| **A** | Phases 1–2 (authority atomic) | **Yes** — real debt; preferred first PR |
| **B** | Phase 3 (R-IMPROVE-HARNESS) | After A |
| **C** | Phase 4 (assess + material stop) | After A; parallel B OK |
| **Ship** | Phase 5 | After whichever waves land; CHANGELOG must not claim unshipped waves |

Cook may implement A→B→C in one branch **only if** all mandatory tests listed above stay green; otherwise split PRs.

## Risks

| Risk | Mitigation |
|------|------------|
| Docs change without test flip → CI red | Phase 2 atomic same PR |
| Over-delete historical pins → lose EOL guidance | Keep **Historical archive** section; tests allow history, ban live-authority wording |
| Improve ritual becomes auto ceremony | Explicit-only; never on hot path of `next`/`check` |
| Claim classes bloat assess | Minimal 5 tags + one table row pattern; no capsule |
| Phase-04 hollow strategist confusion | Explicit deferred in this plan frontmatter |

## Implementation workflow

```text
phase-01 inventory
    │
    ▼
phase-02 authority reframe (docs + tests atomic)
    │
    ├──────────────┐
    ▼              ▼
phase-03 improve   phase-04 assess/material stop
    │              │
    └──────┬───────┘
           ▼
     phase-05 ship
```

## Cook readiness

Plan is ready for `/ak:cook` only after:

1. Red-team accepted findings applied  
2. Validation log complete  
3. Whole-plan consistency sweep: zero unresolved contradictions  

## Red Team Review

**Date:** 2026-08-11  
**Reviewer:** adversarial code-reviewer (3 lenses) + orchestrator adjudication  
**Verdict after apply:** cook-ready for Wave A immediately; B/C with locked tests.

### Findings adjudicated

| # | Sev | Disposition | Summary of plan edit |
|---|-----|-------------|----------------------|
| 1 | Critical | **Accept** | Non-negotiable trust greps locked in plan + phase 2 |
| 2 | Critical | **Accept** | Phase 3 must update `test_flow_native_rituals.sh` 5→6 |
| 3 | High | **Accept** | Ritual id `R-IMPROVE-HARNESS`; strategist `R-STRATEGIST` reserved |
| 4 | High | **Accept** | Phase 4 mechanical min: ≥1 real ledger row; extend assess tests |
| 5 | High | **Accept** | Rename to Brownfield assess section; not Stage 00-inspect |
| 6 | High | **Accept** | Pin file + optional smoke reframe policy in phase 1–2 |
| 7 | High | **Accept** | harness-skill complete-only strings mandatory |
| 8 | High | **Accept** | Exhaustive LIVE list; npm sync required phase 5 |
| 9 | Medium | **Accept** | Cite ADR path under repository-harness; 0.1.22 OBSERVED there |
| 10 | Medium | **Accept** | Ship slicing Wave A/B/C |
| 11 | Medium | **Accept** | Improve keep → optional durable backlog/decision note |
| 12 | Medium | **Accept** | Extend `test_flow_assess.sh` |

### Whole-Plan Consistency Sweep

- [x] §6 collision → stable ritual ids  
- [x] native-rituals count test mandatory  
- [x] Stage 00-inspect wording removed from success criteria  
- [x] Trust greps vs pin flip reconciled  
- [x] npm-wrapper sync no longer optional  
- [x] Deferred strategist explicitly non-overlapping id  
- **Unresolved contradictions:** none  

## Related code (primary)

| Path | Role |
|------|------|
| `skills/flow/harness/README.md` | Authority section |
| `skills/flow/harness/GAP-MATRIX-0.1.17.md` | Supersede / rename policy |
| `skills/flow/SKILL.md` | Pins line, harness bullet, rituals link |
| `skills/harness-skill/SKILL.md` | Legacy reframe |
| `tests/test_flow_skill_harness_docs_contract.sh` | **Must flip** (keep trust greps) |
| `tests/test_flow_harness_lineage_contract.sh` | **Must flip** |
| `tests/test_flow_native_rituals.sh` | **Must** 5→6 (+ name R-IMPROVE / Improve-flow-harness) |
| `tests/test_flow_assess.sh` | Ledger + clean fixture |
| `tests/test_harness_cli_optional_smoke.sh` | Reframe archive pin; never live trust |
| `skills/flow/harness/pins/harness-cli-v0.1.17.sha256sums` | Label historical archive |
| `skills/flow/references/native-rituals.md` | R-IMPROVE-HARNESS |
| `npm-wrapper/skills/flow/**` | Sync from canonical skills/flow |
| `skills/flow/_templates/00-inspect.md` | Claim classes |
| `skills/flow/references/gate-rules.md` | Material stop + assess challenge |
| `docs/system-architecture.md` | Architecture truth |
| `CHANGELOG.md` / version fields | Ship |

## Sources of truth for implementer

- Brainstorm+advise: `plans/reports/brainstorm-advise-260811-1405-harness-authority-continuity-vi.md`
- Prior advise (EOL): `plans/reports/advise-260811-1354-repository-harness-latest-vs-flow-upgrade-vi.md`
- Vision: flow = agent coding harness for quality + continuity (not repo-protocol installer)
- ADR primary (external tree): `repository-harness/docs/decisions/0027-end-protocol-v1-and-focus-repository-protocol.md`

## Validation Log

### Validation Session 1 — 2026-08-11 (orchestrator, post red-team apply)

**Mode:** critical-path verification against codebase (no user interview — pipeline requested loop-to-clean; decisions locked from vision + prior advise + red-team).

#### Verification Results

| Claim | Result | Evidence |
|-------|--------|----------|
| Docs contract requires 0.1.14/0.1.17 | VERIFIED | `tests/test_flow_skill_harness_docs_contract.sh:13-14,38` |
| Lineage contract requires pins | VERIFIED | `tests/test_flow_harness_lineage_contract.sh:25-26,54-55` |
| native-rituals test hard-codes 5 | VERIFIED | `tests/test_flow_native_rituals.sh:45-47` |
| 00-inspect lacks claim classes | VERIFIED | `skills/flow/_templates/00-inspect.md` |
| gate-rules has Stage 00 Idea only (no assess section) | VERIFIED | `gate-rules.md:22` |
| optional smoke pin file | VERIFIED | `tests/test_harness_cli_optional_smoke.sh:7,26-27`; `harness/pins/harness-cli-v0.1.17.sha256sums` |
| npm-wrapper mirror has live pins | VERIFIED | `npm-wrapper/skills/flow/harness/README.md:13-14` |
| ADR 0027 + archive 0.1.22 | VERIFIED | repository-harness `docs/decisions/0027-…md:26,39` |
| hollow strategist pending | VERIFIED | `plans/260811-1120…/phase-04…:4` status pending |
| sync.mjs exists | VERIFIED | `npm-wrapper/scripts/sync.mjs` |
| plugin.json version 0.26.0 | VERIFIED | `.claude-plugin/plugin.json` |

- Claims checked: 11  
- Verified: 11 | Failed: 0 | Unverified: 0  
- Tier: Full (plan has 5 phases)

#### Decisions locked (from vision + advise + red-team)

1. **Scope = Wave Authority Continuity (B)** not hollow-done, not CLI resync  
2. **Ship slicing** A then B/C allowed; A alone cookable  
3. **Trust greps non-negotiable** across pin flip  
4. **Ritual id** R-IMPROVE-HARNESS; R-STRATEGIST deferred  
5. **Assess** mechanical honesty via tests (+ optional light runner)  
6. **npm sync required** before ship  
7. **Standalone** constraint unchanged  

#### Open questions

None material — cook may proceed Wave A without further interview.

### Whole-Plan Consistency Sweep (post-validate)

- [x] No remaining “Stage 00-inspect” in success criteria  
- [x] native-rituals 5→6 mandatory  
- [x] §6 strategist collision resolved via ritual ids  
- [x] Failed claims: 0  
- **Unresolved contradictions:** none  

**Recommendation:** Ready for `/ak:cook` starting **Wave A (phases 1–2)**. Full A+B+C when capacity allows.
