---
title: "flow hollow-done trust eval"
description: "Standalone mechanical floor + ready trust for hollow done; atomic suite migration; decoy residual honesty; optional strategist backlog. CI-measurable process-prose catch rate; no AgentKit dep."
status: completed
priority: P1
effort: "5-8d"
tags: [flow, harness, eval, hollow-done, trust, auto, standalone]
created: 2026-08-11
blockedBy: []
blocks: []
sources:
  - plans/reports/advise-260811-1050-flow-upgrade-harness-trust-vi.md
  - plans/reports/research-260811-1050-ai-coding-landscape-flow-upgrade-vi.md
---

# flow hollow-done trust eval

## Overview

Raise trust in `/flow` when agents run auto/parallel by closing **process-prose hollow done** and **hand-edit done that never re-gates**, while remaining **standalone**.

**Honest scope (post red-team):** This plan delivers a **mechanical floor + ready/deps re-validation**, not “auto cannot be lied to.” Decoy URL + 3-line fake logs remain **possible** mechanical PASS; those stay for **offline semantic eval** (fcdc). CI measures **process-only catch rate**, not LLM catch-rate.

### Baseline (verified)

| Fact | Evidence |
|------|----------|
| Empty Evidence on done → FAIL | `flow.sh` ~1284–1291 |
| Non-empty process prose (fcdb) → mechanical PASS | `fcdb` fixture; `test_flow_eval.sh:47-51` requires both fcda+fcdb check exit 0 |
| Billable eval NEVER default CI | `flow.sh:2619` |
| `ready` trusts `status: done` only | `flow.sh:1478-1484` |
| Auto allows hand-edit done | `auto-run.md:42-43`, `flow.sh:1162` |
| `card_done` sets done **before** check | `flow.sh:1174-1183` |

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Process-only hollow Evidence → **mechanical FAIL** on `check` / `card done` | P1 |
| 2 | **Atomic** ship: gate + full test corpus + fcdb contract flip + fcdc in **one** green `run_all` | P1 |
| 3 | `ready` / dep satisfaction **re-validates** world-state signal on done deps (hand-edit hollow cannot unblock) | P1 |
| 4 | Document residual: decoy hollow = offline LLM only; no false “auto proven safe” | P1 |
| 5 | Standalone; no AgentKit/ck hard dep | P1 |
| 6 | Optional native strategist + hooks docs = **backlog P2**, not ship bar | P2 |

## Non-goals

- Hard dep AgentKit / kongming / fable / claudekit
- Making decoy-URL hollow mechanically impossible (arms race)
- Billable LLM eval in default CI
- Graph default-on, Spec Kit import, vector memory
- Replacing semantic gate-rules entirely
- Claiming durable `card_markdown_gate` is stronger than markdown floor (honesty limit documented only)

## Architecture (target)

```
status: done ──► check / card done
                    │
                    ├─ empty/placeholder FAIL (existing)
                    ├─ process-only FAIL (NEW)
                    ├─ multi-signal world-state PASS floor (NEW)
                    └─ decoy+signal may still PASS → semantic offline

ready / dep met ──► for each done dep: re-run evidence signal rules (NEW)
                    hollow hand-edit without valid signal → not buildable

card done ──► dry-check or set-done+trap restore on INT (NEW harden)
```

## Design decisions (locked)

| ID | Decision |
|----|----------|
| D1 | Standalone: bash + optional python only |
| D2 | Mechanical floor: process-only FAIL; multi-signal PASS (see phase 02 table v2) |
| D3 | **Atomic 02+03**: never merge gate without corpus + fcdc + eval test updates |
| D4 | Billable eval opt-in offline; CI = mechanical catch-rate only |
| D5 | **ready re-validates** done deps’ Evidence signal (no stamp file required v1). **Parity:** `harness/graph_executor.py` deps-met (`~868–880`) must use the **same** evidence helper — not status-only |
| D6 | Project type: refuse silent downgrade after planning complete unless `FLOW_FORCE=1` + DEBT note (or document operator lock) |
| D7 | `card_done`: trap restore `orig` on INT/TERM; prefer dry-check-then-set if simpler |
| D8 | Residual decoy = known; success criteria must not claim zero auto hollow |
| D9 | Phase 04 strategist/hooks **out of ship bar** for this plan’s P1 |
| D10 | Durable `story complete` behavior unchanged this slice; docs note markdown-floor limit |

## Phases

| # | Phase | Priority | Depends | Effort |
|---|-------|----------|---------|--------|
| 1 | [Attack-surface map, corpus inventory, honest contract](./phase-01-start.md) | P1 | — | 0.5–1d |
| 2 | [Mechanical floor + ready re-validate + card_done harden](./phase-02-mechanical-hollow-done-hardening.md) | P1 | 1 | 2–3d |
| 3 | [Atomic fixtures, corpus rewrite, auto-path, scorecard](./phase-03-fixtures-auto-path-eval.md) | P1 | 2* | 1.5–2d |
| 4 | [Native strategist + hooks (backlog)](./phase-04-native-strategist-optional-hooks.md) | P2 | 1 | 1d optional |

\*Phase 2+3 **merge as one PR / one cook batch** — phase 2 alone must not be declared done.

## Success Criteria (plan-level, ship bar = phases 1–3)

- [x] `done-path-matrix.md` + test corpus inventory complete
- [x] Process-only Evidence FAIL mechanical; G-PASS multi-signal PASS
- [x] `ready` does not treat signal-invalid done as dep-met
- [x] fcdb no longer required mechanical PASS; fcdc is hollow-with-signal for LLM
- [x] All suite goldens rewritten; `bash tests/run_all.sh` green 3-OS CI
- [x] Scorecard policy: CI metric = process-only FAIL rate on fixture set; LLM offline
- [x] Docs: residual decoy + no “auto proven” claim
- [x] No AgentKit hard dep
- [ ] Phase 4 optional — not required for ship

## Risk summary

| Risk | Mitigation |
|------|------------|
| Mid-slice red CI | Atomic 02+03 |
| False FAIL legitimate short proofs | Table v2 includes DB/curl; per-type goldens |
| False PASS decoy | Multi-signal + denylist; residual documented |
| Hand-edit bypass | ready re-validate |
| Type flip | D6 |

## Handoff

```
/ak:cook /home/manhquy/Downloads/flow-skill/plans/260811-1120-flow-hollow-done-trust-eval/plan.md
```

Cook must implement phases 1→2→3 as one coherent change set (or 1 then 2+3 atomic).

---

## Red Team Review

**Date:** 2026-08-11  
**Reviewers:** Security Adversary · Assumption Destroyer · Failure Mode Analyst (parallel)  
**Findings collected:** 15 → deduped → **10 adjudicated**

| # | Sev | Finding | Disposition | Plan change |
|---|-----|---------|-------------|-------------|
| RT1 | Crit | Bare URL / fence is forge kit; decoy still “trust” | **Accept** | Multi-signal + denylist; residual honesty D8; no “auto proven” |
| RT2 | Crit | Hand-edit `status:done` unblocks ready without check | **Accept** | D5 ready re-validates Evidence signal |
| RT3 | Crit | Phase 2 alone breaks `test_flow_eval` fcdb contract | **Accept** | D3 atomic 02+03 |
| RT4 | Crit | Existing suite “real proof” mass-fail | **Accept** | Phase 1 inventory + phase 3 corpus rewrite mandatory |
| RT5 | High | Type flip to cli weakens gate | **Accept** | D6 type lock after planning |
| RT6 | High | Signal table misses DB/curl; FP/FN | **Accept** | Phase 02 table v2 |
| RT7 | High | Goal “prove hollow cannot stay done” overclaim | **Accept** | Goals rewritten |
| RT8 | High | card_done write-before-check kill window | **Accept** | D7 trap / dry-check |
| RT9 | High | Phase 4 YAGNI on P0; catch-rate undefined in CI | **Accept** | D9; CI metric = process-only |
| RT10 | High | card_markdown_gate launders forgeable floor | **Accept (doc only)** | D10; no harness rewrite this slice |

**Rejected:** none of the above as “no evidence” — all had file:line.

### Whole-Plan Consistency Sweep

- Files reread: plan.md, phase-01..04
- Decision deltas: D3–D10, table v2, ready re-validate, phase 4 demoted, goals honesty
- Reconciled: phase files rewritten below to match
- Unresolved contradictions: **0**

---

## Validation Log

### Verification Results (pre-interview)
- **Tier:** Standard (4 phases)
- **Claims checked:** 12
- **Verified:** 11 | **Failed:** 0 | **Unverified:** 1 (resolved below)

| Claim | Result |
|-------|--------|
| empty evidence FAIL `flow.sh:1284-1291` | VERIFIED |
| fcdb mechanical PASS required `test_flow_eval.sh:47-51` | VERIFIED |
| eval NEVER in CI `flow.sh:2619` | VERIFIED |
| ready status-only deps `flow.sh:1478-1484` | VERIFIED |
| card_done set-before-check `flow.sh:1174-1183` | VERIFIED |
| graph deps-met status-only `graph_executor.py:868-880` | VERIFIED — **added to D5 parity** |
| ak plan directory format | VERIFIED (`ak plan validate` OK) |
| corpus weak evidence sites | VERIFIED (grep sample ≥14 lines) |

### Validation Session 1 (2026-08-11)

| # | Topic | Decision |
|---|-------|----------|
| V1 | D5 ready enforcement | **ready re-validate** Evidence signal (not stamp / not ban hand-edit) |
| V2 | Signal floor | **Always score ≥ 2** all project types |
| V3 | Ship bar | **Phases 1–3 ship**; phase 4 backlog |

### Propagation
- plan.md D5 + goals: confirmed
- phase-02: always ≥2 already locked; ready re-validate confirmed
- phase-02: **graph_executor deps-met parity** added after verification
- phase-04: backlog confirmed

### Whole-Plan Consistency Sweep
- Files reread: plan.md, phase-01..04
- Decision deltas: V1–V3, graph parity
- Reconciled stale references: 1 (graph ready hole closed in plan)
- Unresolved contradictions: **0**

### Cook eligibility
- Red-team applied + validation confirmed + consistency 0 unresolved
- **Eligible for `/ak:cook`** on phases 1–3 (atomic 2+3)
- Phase 4 optional follow-up

<!-- slug: flow-hollow-done-trust-eval -->

