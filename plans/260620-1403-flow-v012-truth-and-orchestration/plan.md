---
title: "flow v0.12 — telemetry truth + orchestration depth + engine hardening"
description: "Six evidence-backed fixes (W1-W6) split into 5 cohesive cards across three theme groups."
status: done
priority: P2
effort: 5 cards
branch: master
tags: [flow-skill, telemetry, orchestration, engine-hardening, v0.12]
created: 2026-06-20
---

> **Retired 2026-07-04**: shipped as v0.12.0/v0.12.1/v0.12.2 (see docs/journals and git history) — this plan's frontmatter status was never flipped after ship. Retired to stop watzup/project-management scans surfacing it as live work.

# flow v0.12 — SCOPE + CARD PLAN

Increment after v0.11.0 (usage-log telemetry correctness). v0.11 made the usage-log honest;
v0.12 closes the **global** telemetry gap + cycle-intent gap (truth), wires **named** orchestration
agents (depth), and tightens two **engine contracts** (correctness). All W1-W6 are pre-verified
against live code (citations in each card). Done-def for the release: installed to
`~/.claude/skills` AND a real `/flow` run reaches its own done-def with all six fixes provable
on world state + new tests green in `tests/run_all.sh`.

## Scope decision (W1-W6)

| W | Item | Verdict | Verified at | Why |
|---|---|---|---|---|
| W1 | GLOBAL dwell blind (compact line omits `stage_from`) | **IN** | `flow.sh:1423` (compact line), consumer `flow_harness.py:567-613` | Precursor exists (per-project dwell shipped v0.11 FR3). Global is the same reconstruction starved of a field. |
| W2 | cycle build-intent gate (diagnostics inflate cycles) | **IN** | `_ensure_cycle` `flow.sh:1376`, universal call `_log_event:1401` | Honesty fix; `_ensure_cycle` already idempotent — only needs an intent guard. |
| W3 | wire `debugger` into two-strikes repair | **IN** | `auto-run.md:25-26` (generic "FRESH subagent"); `debugger` agent in registry | Markdown-layer only; agent already exists. No precursor missing. |
| W4 | security-class review lens (`security-reviewer`) | **IN** | `adversarial-review.md:6,54` (generic `code-reviewer`; security-class trigger already isolates) | The Tier-C HALT / security-class trigger ALREADY exists — only the lens is generic. Pure wire-up. |
| W5 | `lock_acquire` TOCTOU -> atomic `mkdir` | **IN** | `lock_acquire` `flow.sh:274-308` (read `:282` then write `:308`, no atomic claim) | Real race; `mkdir` atomicity is portable (POSIX + Git-Bash). v0.11 FR4 made the lock hard-block but left the claim non-atomic. |
| W6 | `_python()` returns exit 0 when no interpreter | **IN** | `flow.sh:114` (`return 0` on fall-through, empty stdout) | One-line contract tightening. Callers already guard on empty value; fixing exit code prevents future caller bugs. |

**ALL SIX IN.** No item needs an absent precursor. Cost-no-object + every precursor verified present.

### Precursor notes (flagged, not blocking)
- W1 depends on the v0.11 FR3 dwell reconstruction (`flow_harness.py:567-613`) — PRESENT. W1 only feeds it the missing `stage_from` on the global path.
- W4's "security-class card" trigger is referenced in `adversarial-review.md:54` and the auto-run Tier-C HALT — PRESENT. W4 only swaps the generic lens for a security lens at that existing trigger.

## Card breakdown (3 theme groups, 5 cards)

| Card | Title | W-items | Group | Layer | Parallel? |
|---|---|---|---|---|---|
| [C-011](C-011.md) | global per-stage dwell (add `stage_from` to compact line + global reconstruction) | W1 | telemetry-truth | runner + harness | serial w/ C-012 (both touch flow.sh log path) |
| [C-012](C-012.md) | cycle build-intent gate (diagnostics don't start cycles) | W2 | telemetry-truth | runner | serial w/ C-011 |
| [C-013](C-013.md) | name `debugger` in the two-strikes repair loop | W3 | orchestration-depth | references/SKILL md | parallel-safe |
| [C-014](C-014.md) | security-class review lens (`security-reviewer`) | W4 | orchestration-depth | references md | parallel-safe |
| [C-015](C-015.md) | engine-contract hardening: atomic lock + honest `_python` exit | W5, W6 | engine-hardening | runner | serial (touches flow.sh lock + helper) |

## Dependency order

```
Group A (telemetry-truth, SERIAL — shared flow.sh log path):  C-011 -> C-012
Group B (orchestration-depth, PARALLEL — distinct md files):  C-013 || C-014
Group C (engine-hardening, SERIAL w/ Group A — shared flow.sh): C-015  (after C-011,C-012)
```

- **Cross-group:** Group B (C-013, C-014) is fully parallel with Group A and Group C — different files (references/*.md vs flow.sh/harness).
- **Within Group A:** C-011 and C-012 both edit `flow.sh` `_log_event`/cycle region — SERIAL to avoid edit collision.
- **C-015** edits `flow.sh` (`lock_acquire`, `_python`) — disjoint *functions* from A but same *file*; sequence after A to keep one writer per flow.sh at a time (flow law: one card = one cohesive change; concurrent edits to flow.sh by two cards violates single-writer hygiene).

## Parallel-safety summary

| Can build in parallel | Must be serial |
|---|---|
| {C-013} and {C-014} (distinct md files) — and either/both alongside Group A/C | C-011 -> C-012 -> C-015 (all touch `flow.sh`; single-writer per file) |

Recommended wave plan:
- **Wave 1:** C-011, C-013, C-014  (C-011 owns flow.sh; C-013/C-014 own md — no overlap)
- **Wave 2:** C-012  (flow.sh free again)
- **Wave 3:** C-015  (flow.sh free again)
- Then: release card (version bump + CHANGELOG + quality-metrics) — out of this plan's W-scope; add as C-016 at ship time mirroring C-010.

## Key dependencies / facts

- Harness Python: `skills/flow/harness/flow_harness.py` (W1 consumer). Runner: `skills/flow/runner/flow.sh`.
- Every FR needs a test (flow law). New/extended suites must be registered in `tests/run_all.sh:6`.
- "No runner edits mid-run" (PRD §NFR) applies to the *Codex-integration* feature scope; engine-hardening cards C-011/012/015 ARE runner edits and are legitimate flow cards (cf. C-010 note: runner edits are a "separate out-of-band step", here scoped as their own cards with `## Allowed files` = runner/harness).
- All gate parity: 20 existing suites / 413 checks stay green (v0.11 baseline) + new checks.
