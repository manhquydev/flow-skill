---
title: "mid-tier wave2 disclosure"
description: "Make Flash/DeepSeek actually load few-shots and one-stage rules. Dead pointers, examples-in-template, split gate-rules, catalog dispatch, STATUS examples. No runtime."
status: pending
priority: P1
effort: "2-3d"
branch: feat/mid-tier-flow-quality
blockedBy: []
blocks: []
predecessor: 260909-1119-mid-tier-flow-quality (cooked on this branch; not a cook blocker)
created: 2026-09-09
---

# mid-tier wave2 disclosure

## Overview

Wave 1 (`260909-1119`, HEAD `7ef5e7b`) shipped dispatcher SKILL.md, `_scan_midtier`, `law/CODING.md`, `gate-examples.md` §01/§02/§card. **Flash/DeepSeek still miss them:** PTC_ONLY never opens `gate-examples.md`; `gate-rules.md` is a 2968w dump; `law/CLAUDE.md` points at deleted `SKILL.md AUTO PRINCIPLES`; Three-laws still say live URL; OD prose still says there is no mechanical cap.

This wave ports DeepSeek *disclosure* (load the body you need; examples in the artifact being filled; one home per fact) into skill+bash. **HOLD SCOPE.** ADR-0001: no loop, no STATUS parser, no `_eval_engine_run` / `_run_with_timeout` edits, no live-eval CI gate, no C-launder keyword floor, no Independent-test required section, no website/.

Predecessor: `plans/260909-1119-mid-tier-flow-quality/` (cooked on this branch).

## Scope Challenge

- Existing: v0.31.0 + wave1 mid-tier on `feat/mid-tier-flow-quality`
- Requested: P0 dead pointers + P1 disclosure rails from 2026-09-09 scout of `/home/manhquy/Downloads/repo/deepseek-harness`
- Complexity: ~18 files, 0 services, 5 exclusive-ownership phases
- Mode: **HOLD SCOPE** (no `--yagni`). **deep** + parallel-safe ownership

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Dead pointers: AUTO PRINCIPLES, live-URL three-laws, next-PASS **one** extra = `gate-examples.md` (PTC_ONLY), AGENTS.md command home = command-dispatch.md | P1 |
| 2 | Examples-in-template: 01/02/03/card one worked PASS row; gate-examples §03 + §05 from existing fixtures | P1 |
| 3 | Split every existing `gate-rules.md` `##` into files + `gate-shared.md`; delete "no mechanical OD cap"; `_eval_extract_section` maps 01/02/card to those files; sha explicit list | P1 |
| 4 | `command-dispatch.md` catalog-only (file still loaded whole); concierge cites command-dispatch | P1 |
| 5 | Child STATUS filled example + invalid; AutoDecision unique home = auto-run.md | P1 |

## Non-goals

Cordis / agent-loop / session core / flow-orch / parse STATUS or AutoDecision in `flow.sh` / live LLM merge gate / C-class keyword scanner / Independent-test required heading / evidence-token floor that reclassifies fcdd / website/ / raising SKILL.md above 1600w / editing `_eval_engine_run` or `_run_with_timeout`

## File ownership (Herdr wave 1 = phases 1, 2, 4, 5 parallel)

| Phase | Exclusive write set |
|---|---|
| 1 | `skills/flow/SKILL.md`, `skills/flow/law/CLAUDE.md`, `AGENTS.md`, `skills/flow/references/ground-truth-gates.md` |
| 2 | `skills/flow/references/gate-examples.md`, `skills/flow/_templates/01-research.md`, `02-scope.md`, `03-prd.md`, `card.md` |
| 3 | `gate-rules.md` (index), **create** `gate-shared.md` + one file per current `^## ` heading (assess, 00, 01, 02, 03, 04, 05, card, consistency, constitution, debt), `clarify.md`, `docs/doc-budgets.txt`, `skills/flow/runner/flow.sh` **only** `_eval_extract_section` / `_eval_build_prompt` / `_eval_gate_rules_sha` (never `_eval_engine_run` / `_run_with_timeout` / `_eval_heading_pattern` 05 arm), retarget `tests/test_flow_eval.sh` (sha + heading extract), `tests/test_flow_forge_idea.sh`, `tests/test_flow_native_rituals.sh`, `tests/test_flow_claudekit_integration.sh`, `tests/test_flow_gate_wording.sh`, `tests/test_flow_slice_quality.sh` |
| 4 | `skills/flow/references/command-dispatch.md`, `skills/flow/references/concierge.md` |
| 5 | `skills/flow/references/agent-stage-mapping.md`, `skills/flow/references/auto-run.md`, `skills/flow/references/debt-and-halts.md` |

Wave 1 parallel: 1, 2, 4, 5. Wave 2: phase 3.

Shared freeze: AutoDecision only in auto-run.md. SKILL.md ≤1600w. No Commands table in SKILL.md. PTC_ONLY remains one extra file — do not put two paths in one load-table cell.


## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Dead pointers](./phase-01-start.md) | Pending |
| 2 | [Few-shot templates](./phase-02-few-shot-templates.md) | Pending |
| 3 | [Split gate-rules](./phase-03-split-gate-rules.md) | Pending |
| 4 | [Dispatch catalog](./phase-04-dispatch-catalog.md) | Pending |
| 5 | [Child STATUS examples](./phase-05-child-status-examples.md) | Pending |

## Constraints

- bash-3.2-safe; zero new runtime deps
- ADR-0001 process-token invariant
- Fixture-pair rule: only if a *new gate-enforced* semantic rule is added (this wave adds none)
- Replay never counts toward eval floor
- Locate by content, not plan line numbers
- No billable live `claude` calls

## Success Criteria

- [ ] `law/CLAUDE.md` has no `AUTO PRINCIPLES`; auto points at `references/auto-run.md`
- [ ] SKILL.md Three laws type-aware; load table next-PASS **single extra** = `gate-examples.md`; card/build extra stays `law/CLAUDE.md` (CODING.md is a pointer inside it); `wc -w` ≤1600
- [ ] AGENTS.md Command table home is `references/command-dispatch.md` (not SKILL.md Commands)
- [ ] `gate-examples.md` has §03 and §05 PASS/FLAG; no new rules; fcdb stays mechanical FAIL
- [ ] Templates 01/02/03/card each have one worked PASS-shaped row above remaining FILL
- [ ] `gate-rules.md` is an index ≤800w; per-section files exist for every current stage heading; grep of skill+refs has **zero** "no mechanical cap" / "there is no mechanical cap" for open decisions
- [ ] `clarify.md` names OD>5 `scan_gate` fail
- [ ] command-dispatch Host-duties cells are one line + pointer; concierge cites command-dispatch not SKILL.md Commands table
- [ ] agent-stage-mapping has one filled STATUS report and one missing-STATUS = BLOCKED example; VN copy is opt-in
- [ ] AutoDecision enum body only in auto-run.md; debt-and-halts halt template points, does not list the five tokens
- [ ] `tests/test_doc_budgets.sh` still 8/8; any eval sha test still green without live claude
- [ ] No `_eval_engine_run` / `_run_with_timeout` body diff

## Risks

- Extract still points at GATE_RULES_FILE after split → empty challenge. Response: phase 3 exclusive-owns `_eval_extract_section` with 01/02/card → file map; inline into `_eval_build_prompt`; engine untouched.
- SHA glob `gate-*.md` pulls gate-eval/examples. Response: explicit file list. SHA is not judge stdin (`_eval_prompt_sha` is).
- PTC_ONLY two-file cell never opens the second. Response: next-PASS extra is **only** gate-examples.md.
- Cookers edit shared files. Response: exclusive table is the lock; phase 3 after wave 1.

## Red Team Review

### Session — 2026-09-09 (specialized scopes R1)
**Findings:** 15 cap (6 reviewers). **Accepted 10, rejected 5.**

| # | Finding | Severity | Disposition | Applied To |
|---|---------|----------|-------------|------------|
| 1 | DATA-fence in 01-research is inverted injection | Critical | Accept | Phase 2 |
| 2 | Engine `--tools ''` cannot open split files | Critical | Accept | Phase 3 |
| 3 | `_eval_heading_pattern` is not a file map | Critical | Accept | Phase 3 |
| 4 | Extract still awks GATE_RULES_FILE | Critical | Accept | Phase 3 |
| 5 | SHA glob leaks gate-eval/examples | Critical | Accept | Phase 3 |
| 6 | Phase 3 exclusive omitted flow.sh helpers + grep suites | Critical | Accept | Phase 3 / plan ownership |
| 7 | PTC_ONLY two-file cell never opens examples | Critical | Accept | Phase 1 |
| 8 | Split-each vs drop 00/04/Debt | High | Accept | Phase 3 |
| 9 | Anchors ≠ row-only load | High | Accept | Phase 4 |
| 10 | blockedBy pending predecessor blocks cook | Medium | Accept | plan.md blockedBy [] |
| 11 | Wrap DATA fence in `_eval_build_prompt` this wave | High | Reject | extra eval scope |
| 12 | Heading-map 05 | High | Reject | P2 non-goal |
| 13 | Per-verb dispatch files | Medium | Reject | HOLD SCOPE |
| 14 | C-scanner / Independent-test required | Medium | Reject | non-goals |
| 15 | SHA == judge stdin | High | Reject (claim deleted; prompt_sha stays the receipt) | Phase 3 |

### Whole-Plan Consistency Sweep
- PTC_ONLY one extra: SKILL.md next-PASS = gate-examples.md only (phase 1 + goals + freeze).
- Phase 3 extract maps 01/02/card; 00/04/debt files exist; no 05 heading arm.
- No DATA fence in templates.
- blockedBy empty; predecessor note only.
- Unresolved contradictions: **0**.

## Validation Log

### Session 1 — 2026-09-09 (self-answer; operator ordered cook after clean gates)

| # | Question | Decision |
|---|----------|----------|
| 1 | next-PASS extra file? | **gate-examples.md only** (PTC_ONLY) |
| 2 | Split 00/04? | **Yes, move existing prose; invent none** |
| 3 | Parse STATUS in flow.sh? | **No** (ADR-0001) |
| 4 | Live eval CI? | **No** |
| 5 | DATA fence location? | **Not in templates**; not in eval builder this wave |
| 6 | Predecessor cook blocker? | **No** — already on branch |

### Verification Results
- Claims checked: 12 (GATE_RULES_FILE:74, extract:3328, sha:3476, heading:3316, AUTO PRINCIPLES CLAUDE.md:13, Commands concierge.md:22, OD cap gate-rules.md:89, f05a exists)
- Verified: 12 | Failed: 0 | Unverified: 0
- Tier: Full

### Whole-Plan Consistency Sweep
- Unresolved contradictions: **0**. Eligible to cook.


<!-- slug: mid-tier-wave2-disclosure -->
