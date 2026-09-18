---
title: "constraint pin + AgentKit overlay"
description: "Day-1 value: verbatim PIN v1 on status/resume stdout after NEXT_VERB; JSON stays 7-field state. Land already-green ak:* overlay. ADR-0001. Eval STOP."
status: pending
priority: P1
effort: "4h"
branch: master
tags: [feature, cli, compaction]
blockedBy: []
blocks: []
created: 2026-09-18
---

# constraint pin + AgentKit overlay

## Overview

Internet 2026-06→09 (ConstraintRot, Compaction Cliff): host compact deletes **rules**, not state. `flow.sh status` prints `NEXT ->` / `NEXT_VERB` / optional `flow_context/v1`. It does **not** reprint STOP/HALT/done-evidence.

This plan ships **PIN v1** as a closed stdout block after `_emit_next`, plus the already-written AgentKit `ak:*` alias overlay (hygiene, not the product story).

Contracts: `plans/reports/brainstorm-260918-1651-next-direction.md`, `plans/reports/brainstorm-260918-1749-day1-process.md`.

## Scope Challenge

- Existing: `_emit_next` (`flow.sh:1351`), `_emit_context_json` 7 fields (`flow.sh:1370`), SKILL.md `## STOP` (`SKILL.md:45`), overlay uncommitted (11 files, claudekit tests 54/54).
- Requested: plan → red-team → validate until clean → Herdr cook. Product = pin + overlay. Delivered in full.
- Complexity: ~8 files, 0 services, 2 exclusive-ownership phases.
- Selected mode: **HOLD SCOPE**. Mode **hard** (operator ordered red-team + validate loops). Research already in 1651; skip researcher spawn.

Predecessor `260916-2046-status-json-wire-f05` **completed** (skill 0.33.0). `blockedBy: []`. Pending `260909-2150` listed SKILL.md exclusive — stale vs 0.32 ship; this plan does not reopen wave2 disclosure.

## Cross-Plan Dependencies

None blocking. Do not edit website. Do not reopen ADR-0001. Do not dual-write `.flow/context.*`.

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | PIN v1 on `status` and `resume` prose, byte-identical, after NEXT_VERB | P1 |
| 2 | JSON schema unchanged (no `pin` field) | P1 |
| 3 | Land ak:* Name resolution overlay | P1 |

## File ownership (Herdr cook lock)

| Phase | Exclusive write set |
|---|---|
| 1 | Overlay files already in WT: `claudekit-skills.md`, `agent-detection.md`, `agent-stage-mapping.md`, `gate-04.md`, `gate-05.md`, `adversarial-review.md`, `native-rituals.md`, `flow-catalog.tsv`, `SKILL.md`, `docs/system-architecture.md`, `tests/test_flow_claudekit_integration.sh` |
| 2 | `skills/flow/runner/flow.sh` (**only** `_emit_pin` + call from `_emit_next` or immediately after it in status/resume), **create** `skills/flow/references/pin-v1.txt`, `tests/test_flow_status_legibility.sh`, `skills/flow/references/command-dispatch.md` status/resume rows |

Shared freeze: JSON 7 keys. `NEXT ->` remains first content line after header blank. Eval engine bodies untouched. PIN must not contain the substring `NEXT ->`.

## Phases

| # | Phase | Status |
|---|------|--------|
| 1 | [AgentKit overlay](./phase-01-start.md) | Pending |
| 2 | [PIN printer](./phase-02-pin-printer.md) | Pending |

## Constraints

- ADR-0001: invoked-by-host; no daemon/loop/interposition/server.
- Eval STOP: no `_eval_engine_run` / `_run_with_timeout` body edits.
- bash 3.2; zero new skill runtime deps.
- PIN cap ~80 tokens; verbatim subset of STOP, not a paraphrase essay.
- `NEXT_VERB` / PIN advisory; hosts MUST NOT exec.
- Matching-suite evidence: overlay suite + `test_flow_status_legibility.sh`. Not `run_all.sh` as proof.

## Success Criteria

- [ ] `status` and `resume` print identical `PIN v1` block after `NEXT_VERB=`
- [ ] `NEXT ->` still first content line after header blank (existing test A)
- [ ] `status --json` / `resume --json` still 7 keys; no PIN text in JSON
- [ ] `pin-v1.txt` bytes match the stdout PIN block (`grep -F`)
- [ ] Overlay tests 54/54 still green
- [ ] No `_eval_engine_run` / `_run_with_timeout` body diff

## Kill / change (do not shame-pivot)

| Signal | Response |
|---|---|
| PIN >80 tokens | Cut to ~47 |
| Need eval-engine edit | Kill phase 2; ship phase 1 only |
| JSON gains `pin` | Refuse |
| Same pin test fails twice | Overlay-only PR |
| `/flow bug` while here | Refuse |

## Non-goals

Bug ritual, skills-ref Node, `.flow/CONSTRAINTS.md`, SKILL.md growth for pin (pointer lives in command-dispatch), website, live eval, flow-orch.

## Brainstorm reports

- `plans/reports/brainstorm-260918-1651-next-direction.md`
- `plans/reports/brainstorm-260918-1749-day1-process.md`

## Red Team Review

### Session — 2026-09-18 (specialized: Security + Assumption Destroyer; Light Fact Checker)

Parked `RTSecurity`/`RTAssume` reviewed shipped `260916-2046` — out of scope.

**Session 1 controller:** 4 findings, accepted 2 (idx<0 PIN; fail-loud file).

**Session 2 RtSecurity (this plan):** 8 findings. Applied below.

| # | Finding | Severity | Disposition | Applied To |
|---|---------|----------|-------------|------------|
| 1 | JSON path has no PIN; hosts parse `--json` after compact | Critical | Reject-as-cut | compact recovery = prose status; JSON stays 7 keys |
| 2 | Slogan PIN paraphrases STOP (FLOW_FORCE / HALT) | Critical | Accept | Phase 2 PIN body = exact excerpts |
| 3 | `without DEBT` reads as HALT bypass | Critical | Accept | HALT until operator accepts in DEBT.md |
| 4 | NEXT_VERB printed before PIN | High | Reject | Test A requires NEXT first; dispatch: read full stdout |
| S1-1 | resume idx<0 skips `_emit_next` | Critical | Accept | Phase 2 |
| S1-2 | silent missing pin file | High | Accept | fail-loud |

### Whole-Plan Consistency Sweep
- Files reread: plan.md, phase-01-start.md, phase-02-pin-printer.md
- Decision deltas checked: 4 (idx<0; fail-loud; exact STOP; JSON not recovery)
- Unresolved contradictions: **0**

### Whole-Plan Consistency Sweep
- Files reread: plan.md, phase-01-start.md, phase-02-pin-printer.md
- Decision deltas checked: 2 (idx<0 PIN; fail-loud pin file)
- Reconciled stale references: 1 (step 1 restored)
- Unresolved contradictions: **0**

## Validation Log

### Session 1 — 2026-09-18 (self-answer; operator ordered loops until clean then Herdr cook)

| # | Question | Decision |
|---|----------|----------|
| 1 | Pin home? | **`references/pin-v1.txt`** |
| 2 | JSON `pin` / `pin_sha`? | **No** |
| 3 | `resume` idx<0 PIN? | **Yes** |
| 4 | Version 0.34 this cut? | After pin tests green; not a cook blocker |
| 5 | Fold PIN into `_emit_next`? | **Yes** for 906/1031/1123; **plus** explicit pin on 1010 |

### Verification Results
- Claims checked: 6 (`_emit_next` 906/1031/1123; resume 1010 skip; JSON 7 keys `flow.sh:1400`; SCRIPT_DIR:19; test A:41; SKILL STOP:45)
- Verified: 6 | Failed: 0 | Unverified: 0
- Tier: Light

### Whole-Plan Consistency Sweep
- Unresolved contradictions: **0**. Eligible to cook.


<!-- slug: constraint-pin -->
