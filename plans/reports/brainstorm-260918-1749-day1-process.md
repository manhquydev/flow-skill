---
type: brainstorm
date: 2026-09-18
created: 2026-09-18T17:49
skill: v0.33.0
npm: 0.7.3
status: recommended
constitution: docs/adr/0001-discipline-layer-identity.md
reuses: plans/reports/brainstorm-260918-1651-next-direction.md
---

# Brainstorm: day-1 implementation process (value, not completeness)

## Summary

Product direction stays **Constraint Pin** (1651). This report only names **how to ship it today**. "Hoàn thiện flow skill ngày 1" is rejected as a completeness dump. Day-1 **value** = mechanical pin on `status`/`resume` plus the already-green AgentKit overlay. Process is two slices with kill/pivot, not a three-wave program and not a plan-week.

## Reused product contract (1651 — unchanged)

- **Outcome:** verbatim STOP/HALT/done-evidence pin on `status`/`resume` stdout. JSON stays state.
- **Constraints:** ADR-0001, eval STOP, bash 3.2, no SKILL.md growth, no `.flow/context.*`, `NEXT_VERB` advisory.
- **Non-goals:** bug spine, skills-ref Node, SDD clone, owning compaction.
- **Acceptance:** byte-stable pin, `grep -F`, JSON does not duplicate PIN.

## Process contract (this report)

### Outcome

Same calendar day: a mergeable cut that an operator running `flow.sh status` can see PIN v1. If pin is blocked, overlay still lands (value already in the working tree). Process names kill/pivot so a new internet finding or a test invariant can change the cut without shame.

### Constraints

- Matching-suite evidence only (`test_flow_status_legibility.sh` + existing overlay suites). Not `run_all.sh` as proof (AGENTS.md).
- Do not break status invariants already tested: `NEXT ->` is the **first content line after the header blank**; exactly one `NEXT ->`; JSON extras still exit 2; JSON schema unchanged (no `pin` field this cut).
- Eval STOP. If pin implementation would edit `_eval_engine_run` / `_run_with_timeout` → kill pin, ship overlay.
- Overlay already written (11 files, 54/54 claudekit tests). Do not rewrite it.
- Cook HARD-GATE wants a plan. Satisfy with **one phase file**, not `--deep`.

### Non-goals

- Finishing flow-skill as a product (converge/bug/installer Wave 3).
- Full `ak:plan --hard/--deep` red-team/validate interview.
- npm 0.7.4 / skill 0.34 bump **unless** pin is green (overlay-only can ship without a version bump if operator prefers; pin = 0.34 class).
- Parallel file-splitting of `flow.sh` (one owner: status/resume printer).

### Acceptance

1. Process is two named slices with an explicit kill table.
2. Slice 0 (overlay) is already test-green; Slice 1 (pin) has a 1-phase plan then cook `--fast`.
3. Kill rules are observable (token cap, eval STOP, NEXT-> invariant, two-fail).
4. Unresolved last. This brainstorm does not implement.

## Evidence (repo, not re-ranked internet)

- `cmd_status` / `cmd_resume`: prose calls `_emit_next`; `--json` calls `_emit_context_json` (closed 7-field object). Pin belongs **after** `_emit_next`, never before (test A: NEXT-> first content line).
- SKILL.md `## STOP` is 6 bullets — too long to dump. Pin is a **sourced 4–6 line excerpt**, one home, cap ~80 tokens.
- Overlay: uncommitted, tests already run this session.

## Approaches (process, not product)

### P1 — Two-slice same-day (recommended)

```
Slice 0  land overlay as-is (docs+test already green)
Slice 1  1-phase plan → cook --fast pin on _emit_next / resume
Kill     see table; leftover = overlay-only PR
```

**Assumption:** pin is an echo helper + 8–12 assertions in `test_flow_status_legibility.sh`.

**First failure:** NEXT-> first-line invariant or JSON schema drift. Response: revert pin, keep overlay.

**Worst case:** half-day lost on pin, overlay still ships.

### P2 — Plan-week then cook

Full `ak:plan` (research/red-team/validate) then cook. Honors cook HARD-GATE maximally.

**Assumption:** pin has hidden architecture.

**First failure:** day-1 value dies in ceremony. Worst case given the ask.

### P3 — Overlay-only today, pin later

Ship dialect hygiene now. Pin waits a second session.

**Assumption:** day-1 value = whatever is already green.

**First failure:** operator asked for *hoàn thiện / giá trị* against the **internet** leak (rule decay). Overlay does not reprint STOP. Worst case: look busy, leak remains.

## Kill / change table (không ngại thay đổi)

| Signal | Change |
|---|---|
| Pin text >80 tokens or paraphrases STOP | Cut to ConstraintRot-class ~47 tokens; do not "explain" |
| Implementation needs eval-engine body | **Kill pin.** Overlay-only. Report STOP. |
| `NEXT ->` not first content line after header | Move PIN below `_emit_next`; never above |
| JSON gains `pin` / `pin_sha` "to be helpful" | Refuse. State ≠ rules (1651 unresolved #2, lean no) |
| Same pin test fails twice | Stop looping. Overlay-only PR. Pin parked |
| New primary paper says file-pin beats stdout | Reopen 1651. Do not dual-write this cut |
| Temptation to add `/flow bug` "while here" | Refuse. 1651 non-goal |

## Day-1 runbook (P1)

1. **Do not reopen product A/B/C** unless a kill-table row fires.
2. Write `plans/<stamp>-constraint-pin/plan.md` + `phase-01-pin.md` (files: `flow.sh` `_emit_next`/`cmd_resume`, `test_flow_status_legibility.sh`, one SKILL.md/command-dispatch pointer). Then `/ak:cook --fast` that plan.
3. Pin source: closed string in runner **or** `references/pin-v1.txt` if extract-from-SKILL.md is fragile (1651 unresolved #1 — pick `pin-v1.txt` if grep of SKILL.md STOP is unstable; one home, SKILL.md points).
4. Evidence: `bash tests/test_flow_status_legibility.sh` and overlay suite. Not `run_all.sh`.
5. If slice 1 killed: commit overlay only. Value still shipped.

## Recommendation

**P1.** Not P2 (contradicts ngày 1). Not P3 (contradicts internet-ranked value).

"Hoàn thiện skill" on day 1 is a completeness trap. Day-1 **value** is the pin; overlay rides. Change is cheap because each slice is abandonable without a second source of truth.

## Handoff

Process P1 + product A → 1-phase plan then `/ak:cook --fast`. Do not implement from this report.

## Unresolved

1. Pin home: `references/pin-v1.txt` vs inline in `_emit_next` (inline = no second file; txt = one home SKILL.md can point). Lean **txt** if SKILL.md STOP stays the essay and pin stays the 47-token subset.
2. Version bump 0.34 this day vs overlay-only unversioned commit — operator call at ship, not now.
3. Whether `resume` prose (not only status) must print PIN — **yes** (1651: bytes identical). Confirm in phase-01.
