---
title: "mid-tier flow quality"
description: "Make flow-skill produce better code and honest gates on Gemini Flash / DeepSeek without growing a runtime."
status: pending
priority: P1
effort: "4-6d"
branch: master
tags: [feature, docs, mid-tier, gates, discipline-layer]
blockedBy: []
blocks: []
created: 2026-09-09
---

# mid-tier flow quality

## Overview

Flow v0.31.0 is a two-layer discipline layer (ADR-0001: gates/receipts, never the runtime). Wave 1 shipped CI/eval/docs plumbing. Mid-tier hosts still fail because `SKILL.md` is a 3669-word Claude dump, `scan_gate` only sees `[FILL]`/`- [ ]` (`flow.sh:172-190`), and semantic challenges have no hot-path few-shots.

This wave ports DeepSeek *disciplines* (progressive disclosure, PTC_ONLY, closed child reports, fail-loud, examples-in-schema) into the existing skill+bash shape. No Cordis, no session log, no `flow-orch`, no `_eval_engine_run` body edit.

## Scope Challenge

- Existing: v0.31.0; wave1 `260814-0948` completed; identity ADR; eval fixtures fcda–fcde; B1-S semantic-only
- Requested: P0 mid-tier upgrade via plan → red-team/validate until clean → cook
- Complexity: ~15 files, 0 new services, 6 exclusive-ownership phases
- Selected mode: **HOLD SCOPE** (no `--yagni`). Mode: **deep** + parallel-safe file ownership

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Dispatcher `SKILL.md`: always-on ≤1600 words; Commands table only in `command-dispatch.md`; no "YOU (Claude)"; keep every test-pinned SKILL.md substring as a one-line pointer | P1 |
| 2 | Hot-path PASS/FLAG excerpts per stage from existing eval fixtures | P1 |
| 3 | Mechanical scanners inside `scan_gate` (all 12 callers agree): web-typed 01 hostnames, joined-bullet L-above-A, PRD adjectives, open-decisions cap; advisory `NEXT_VERB=` from `_next_action` only | P1 |
| 4 | `law/CODING.md` mid-tier coding constitution + card/contract template recipes | P1 |
| 5 | Structured child-report schema in briefs (host-enforced, not runner); auto docs default-deny; no fake actor runtime | P1 |
| 6 | Louder unmeasured-eval SKIP on all 3 sites (exit 0); ratchet SKILL.md budget from measured words | P1 |

## Non-goals

Cordis / event-sourced session / MCP client / `flow-orch` / touching `_eval_engine_run` or `_run_with_timeout` bodies / making live eval a CI merge gate / 100% coverage slogan / evidence-token mechanical floor that reclassifies fcdd (keep B1-S semantic; score ≥2 unchanged) / website/

## File ownership (Herdr wave 1 = phases 1,2,4,5 parallel)
| Phase | Exclusive write set |
|---|---|
| 1 | `skills/flow/SKILL.md`, `skills/flow/references/command-dispatch.md`; retarget-only edits in tests that `grep` SKILL.md (`test_flow_antigravity_integration.sh`, `test_flow_claudekit_integration.sh`, `test_flow_codex_integration.sh`, `test_flow_concierge.sh`, `test_flow_forge_idea.sh`, `test_flow_host_agnostic_parallel.sh` SKILL.md lines only, `test_flow_skill_harness_docs_contract.sh`, `test_flow_attestation_contract.sh`) |
| 2 | `skills/flow/references/gate-rules.md`, `skills/flow/references/gate-examples.md` (create) |
| 3 | `skills/flow/runner/flow.sh`, `tests/test_flow_midtier_scanners.sh` (create), `tests/manifest.txt` (same patch as the suite) |
| 4 | `skills/flow/law/CODING.md` (create), `skills/flow/law/CLAUDE.md`, `skills/flow/_templates/card.md`, `skills/flow/_templates/05-contract.md` |
| 5 | `skills/flow/references/auto-run.md`, `agent-stage-mapping.md`, `agent-detection.md`, `debt-and-halts.md`, `mode-work.md` (auto-run.md lines of `test_flow_host_agnostic_parallel.sh` only if that pointer must move) |
| 6 | `skills/flow/references/gate-eval.md`, `docs/doc-budgets.txt`, `tests/test_flow_eval.sh` (additive: SKIP phrase count==3 + PATH-hidden claude for eval/routing/converge). `eval/fixtures/f01a` only if hostname scanner still fails it after scheme-less match — prefer scanner accept `host.tld` so fixtures stay put |

Wave 1 parallel: 1, 2, 4, 5. Wave 2: phase 3. Wave 3: phase 6.
Shared string freeze: AutoDecision lives only in auto-run.md; command-dispatch `auto` row is a one-line pointer with no enum. `host-agnostic-parallel` pointer stays in both SKILL.md and auto-run.md.

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Dispatcher SKILL.md](./phase-01-start.md) | Pending |
| 2 | [Gate few-shots](./phase-02-gate-examples-few-shot.md) | Pending |
| 3 | [Mechanical scanners](./phase-03-mechanical-scanners.md) | Pending |
| 4 | [Coding constitution](./phase-04-coding-constitution.md) | Pending |
| 5 | [Isolation + auto vocab](./phase-05-isolation-auto-vocab.md) | Pending |
| 6 | [Eval fixtures + budgets](./phase-06-eval-fixtures-budgets.md) | Pending |

## Constraints

- bash-3.2-safe; zero new runtime deps; degrade-friendly
- ADR-0001 process-token invariant
- Fixture-pair rule: any *new* gate-enforced semantic rule adds hollow/sound pair
- Replay never counts toward eval floor
- Do not edit `_templates/` or `flow.sh` *during a user project run* — this wave is product work on the skill repo, allowed

## Success Criteria

- [ ] `SKILL.md` `wc -w` ≤1600; no Commands table; `YOU (Claude)` gone from skill+dispatch+auto-run; every previously grepped SKILL.md test still passes
- [ ] `gate-examples.md` exists; `gate-rules.md` points at one PASS + one FLAG per stage 01/02/card
- [ ] `_scan_midtier` runs inside `scan_gate` before `return $found`; `next`/`status`/`planning_complete`/`_next_action`/`gate` agree; card `gate --card` stays box/FILL only
- [ ] Typed-web `01-research.md` `## What exists already` with <3 hostnames fails `next` on contiguous 00+01; f01a-shaped bare domains PASS; untyped/default-web does **not** apply URL floor (only when `PROJECT_TYPE` file exists and equals `web`)
- [ ] Joined Features-in-v1 bullets: L+B/C FAIL; does **not** claim to catch f02b C-launder (that's gate-examples §02)
- [ ] `NEXT_VERB` is closed `next|card|card-start|check|fix-gate|none` from `_next_action` (flow.sh:1114), printed on status and every resume exit including idx<0. Not catalog `action` parity. Advisory — hosts must not auto-exec `auto`/`skip` from it (ADR-0001)
- [ ] `law/CODING.md` ≤400 words; CLAUDE.md points at it
- [ ] Child brief has structured STATUS; missing STATUS = BLOCKED **in the brief contract**. Runner does not parse STATUS or refuse child `debt`/`skip` this wave
- [ ] SKIP `semantic layer unmeasured on this host` appears exactly 3 times in flow.sh; live eval still exit 0; engine bodies unchanged
- [ ] `tests/manifest.txt` lists `test_flow_midtier_scanners.sh` in the same commit as the suite

## Evidence base

- Scout batch 2026-09-09: 12 JSON reports
- `docs/adr/0001-discipline-layer-identity.md`
- `plans/260814-0948-flow-upgrade-wave1/` (completed)
- Code facts: `scan_gate` `flow.sh:172-191` (`return $found`); `cmd_next` `:1002` rc-only then `:1004` printer; 12 `scan_gate` call sites; `_next_action` `:1114`; SKIP `:3815` `:4126` `:4381`; f01a zero `https://`; `get_project_type` default web `:440-443`; cmd_clarify awk heading `:2416`

## Risks

| Risk | Mitigation |
|---|---|
| SKILL.md cut breaks greps | Inventory tests first; keep pinned substrings as one-liners |
| URL/grade false-fail | Hostname count under `## What exists already` only; type file must exist; join wrapped bullets; awk not pipes |
| Git-Bash hang | Materialize heading slice then grep the string; extend status test H |
| Eval SKIP treated as green | Message + docs only; exit 0 stays; do not claim CI measures Flash |
| Skip still bypasses scanners | Intentional operator DEBT path; do not fake an actor runtime this wave |

## Cook

After gates: Herdr wave 1 = 4 omp panes (phases 1,2,4,5); wave 2 = phase 3; wave 3 = phase 6. `/ak:cook --parallel` only inside a wave whose files do not overlap.

## Red Team Review

### Session — 2026-09-09 (R1, applied)
**Findings:** 28 collected / 15 accepted / 13 rejected (deduped)
**Severity breakdown (accepted):** 6 Critical, 8 High, 1 Medium

| # | Finding | Severity | Disposition | Applied To |
|---|---------|----------|-------------|------------|
| 1 | `_scan_midtier` must live inside `scan_gate` before `return $found`; sibling after `:1004` never runs on ticked-box cheat | Critical | Accept | Phase 3, plan.md |
| 2 | 12 `scan_gate` callers; card `gate --card` must stay box/FILL | Critical | Accept | Phase 3 |
| 3 | `https://` count ≠ opened competitors; f01a has zero https | Critical | Accept | Phase 3, 6 |
| 4 | Per-line L+B misses wraps; does not catch f02b C-launder | Critical | Accept | Phase 3, 2 |
| 5 | SKILL.md tests pin engine essays; 800/1200/1600 caps conflict | Critical | Accept | Phase 1, 6, plan.md |
| 6 | Heading `sed|grep` rehangs Git-Bash | Critical | Accept | Phase 3 |
| 7 | `NEXT_VERB` ≠ catalog `action`; derive from `_next_action` `:1114` not `:697` | High | Accept | Phase 3 |
| 8 | SKIP unmeasured can miss 1 of 3 sites | High | Accept | Phase 3, 6 |
| 9 | Manifest append must be same patch as suite | High | Accept | Phase 3 |
| 10 | `next` tests need contiguous 00+01 | High | Accept | Phase 3 |
| 11 | Default `get_project_type=web` false-fails untyped CLI | High | Accept | Phase 3 |
| 12 | Phase 1/5 auto enum overlap | High | Accept | Phase 1, 5 |
| 13 | Adjective skip-regex double-escaped; PRD checkbox contains `secure` | Medium | Accept | Phase 3 |
| 14 | `FLOW_LAST_GATE_FAIL` must count midtier `[x]` | High | Accept | Phase 3 |
| 15 | Child isolation / skip-launder / auto-merge / attest mint / skip-regex / risk:standard / FLOW_AUTO_OK / skip exit 3 | Crit/High | Reject | ADR-0001 + out of P0. Docs-only for child/auto. Skip remains operator DEBT bypass. |

### Whole-Plan Consistency Sweep
- Files reread: plan.md + phase-01..06 after R1 edits
- Decision deltas checked: 15
- Reconciled stale references: Goal 1 800w; URL https; catalog NEXT_VERB; child MUST NOT runner; skip refuse
- Unresolved contradictions: 0

## Validation Log

### Session 1 — 2026-09-09
**Trigger:** User ordered red-team+validate loops until clean, then cook. Operator interview forbidden; answers from codebase + ADR-0001.
**Questions asked:** 6 (self-answered)

#### Questions & Answers

1. **[Architecture]** Where does `_scan_midtier` run so `next` fails when boxes are ticked?
   - Options: sibling after cmd_next:1004 | inside scan_gate before return $found (Recommended) | cmd_gate only
   - **Answer:** inside scan_gate before `return $found`
   - **Rationale:** `:1002` is rc-only; `:1004` only runs on existing fail

2. **[Assumptions]** URL floor: https count vs hostnames vs skip untyped?
   - Options: ≥3 https anywhere | hostnames under What exists already, only if PROJECT_TYPE file is web (Recommended) | all types
   - **Answer:** hostnames / What exists already / typed-web file required. f01a must PASS

3. **[Tradeoffs]** NEXT_VERB vs flow-catalog.tsv?
   - Options: parse TSV | closed enum from _next_action only (Recommended) | skip token
   - **Answer:** `next|card|card-start|check|fix-gate|none` from `:1114`. Advisory. Not auto/skip

4. **[Scope]** SKILL.md word cap?
   - Options: 800 | 1200 | 1600 fail-closed in phase 1 (Recommended)
   - **Answer:** 1600. Keep test-pinned one-liners

5. **[Risks]** Child MUST NOT skip/debt — runner or docs?
   - Options: FLOW_SESSION_ID operator-class | docs-only brief + ADR residual (Recommended)
   - **Answer:** docs-only. Fake control rejected

6. **[Assumptions]** Live eval skip exit code?
   - Options: exit 3 | keep 0 + unmeasured message on 3 sites (Recommended)
   - **Answer:** exit 0; count==3 phrase; not a merge gate

#### Confirmed Decisions
- scan_gate in-function midtier
- hostname/typed-web URL floor
- NEXT_VERB closed enum advisory
- SKILL.md ≤1600
- child isolation docs-only
- SKIP exit 0 unmeasured ×3

#### Action Items
- [x] Propagated into phase-01..06

#### Impact on Phases
- All six rewritten post-R1

### Verification Results
- **Tier:** Full (6 phases)
- **Claims checked:** 18
- **Verified:** 16 | **Failed:** 0 | **Unverified:** 2 (`cmd_clarify:2416` awk shape to copy; exact `_next_action` prose branches for enum map — cook must read `:1114-1183`)

### Whole-Plan Consistency Sweep
- Files reread: plan.md, phase-01-start.md, phase-02-gate-examples-few-shot.md, phase-03-mechanical-scanners.md, phase-04-coding-constitution.md, phase-05-isolation-auto-vocab.md, phase-06-eval-fixtures-budgets.md
- Decision deltas checked: 6
- Reconciled stale references: 800/1200 caps, catalog NEXT_VERB, child runner MUST NOT
- Unresolved contradictions: 0

<!-- slug: mid-tier-flow-quality -->
