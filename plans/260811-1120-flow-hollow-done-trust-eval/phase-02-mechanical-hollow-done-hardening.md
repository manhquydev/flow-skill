---
phase: 2
title: "Mechanical floor + ready re-validate + card_done harden"
status: completed
priority: P1
effort: "2-3d"
dependencies: [1]
---

# Phase 2: Mechanical floor + ready re-validate + card_done harden

## Overview

Implement world-state signal rules (table **v2**), wire into `cmd_check`, re-validate on `cmd_ready` (and any dep checks sharing that logic), harden `cmd_card_done` crash window, optional project-type lock. **Do not merge alone** — must land with phase 03 corpus/fixture updates in the same green suite (D3).

## Requirements

- Functional: done + empty → FAIL; done + process-only → FAIL; done + multi-signal G-PASS → PASS
- Functional: `ready` treats dep as unmet if done card fails signal rules (print WARN with card id)
- Functional: `card_done` restores status on INT/TERM during check (or dry-check then set)
- Functional: after planning complete, `project-type` change requires `FLOW_FORCE=1` (echo DEBT hint) — **or** document-only if implementation cost high; prefer enforce
- Non-functional: bash 3.2 portable; no live network; no new deps
- Non-functional: Phase 2 success ≠ “full suite green” until phase 03 co-lands; local WIP may use `FLOW_TEST_WIP=1` only if needed — prefer single atomic PR

## Architecture

### Table v2 — `_evidence_has_world_signal` (when status=done, after empty check)

**Process-only FAIL** if Evidence matches process lexicon **and** fails signal score below.

**PASS** if **signal score ≥ 2** from distinct categories (multi-signal), OR score ≥ 1 **and** not process-only:

| Category | Patterns (POSIX ERE / case; no GNU `\b`) | Notes |
|----------|------------------------------------------|--------|
| **A URL** | `https?://` host **not** in denylist: `example.com`, `example.org`, `invalid`, `test` TLD alone | localhost/127.0.0.1 allowed only with category B or C |
| **B Command/curl** | line with `curl` **or** `$ ` prompt **or** `exit 0` / `exit code` / `-> 200` / `HTTP/` | unfenced OK |
| **C Test log** | `passed`/`failed` with digits nearby **or** fenced block ≥2 non-empty lines with `ok`/`PASS`/`passed` as whole-word-ish (`[^A-Za-z]ok[^A-Za-z]` style) | avoid matching `look`/`password` via non-alnum neighbors (see `flow.sh:1872` style) |
| **D Path artifact** | repo-relative path to `.png|.jpg|.jpeg|.webp|.gif|.log|.txt` that **`test -f` exists** relative to project root | existence required |
| **E DB row** | `id=` / `rows?=` / `SELECT` / `sqlite` / `inserted` with alnum id | for non-URL world-state |
| **F Install path** | `~/.claude/skills` / `~/.codex/skills` / `~/.agents/skills` / `skills/flow` | skill type |

**Type emphasis (not exclusive):**

| Type | Prefer |
|------|--------|
| web | A+B or A+D or B+D |
| cli | B or C |
| library | C |
| skill | F or C |

Minimum: **score ≥ 2** for web; **score ≥ 1** for cli/library/skill if non-process. If ambiguous, require score ≥ 2 always for all types (simpler) — **prefer always ≥ 2** to reduce type-flip gaming (aligns RT5).

**Locked implement choice:** **all types require signal score ≥ 2** from distinct categories. Type only affects error hint via `done_def_for_type`.

### ready re-validate (+ graph parity)

Extract `_card_done_evidence_ok "$file"` used by check and ready. In `cmd_ready`, for each dep with status done, if not ok → `ok=0` and message `dep C-NNN done but evidence fails world-state signal`.

**Graph executor parity (mandatory):** `skills/flow/harness/graph_executor.py` ~868–880 currently treats deps-met as `status == done` only. After D5, either:
1. Call a shared small script/`flow.sh` internal helper from Python, or
2. Duplicate the signal rules in Python **with the same test vectors** as bash (prefer single source: bash helper invoked as subprocess, or extract rules to a tiny shared data file).

Failing to update graph leaves `FLOW_GRAPH_EXECUTOR=1` auto path with the old hand-edit bypass.

### card_done harden

```bash
# preferred: trap
trap ' _set_card_status "$file" "$orig" ' INT TERM
# then set done; check; clear trap; on fail restore
```

Or: run evidence checks while still todo by temporarily evaluating body (harder for verify boxes). Trap is enough for RT8.

### project-type lock

If `planning_complete` and PROJECT_TYPE file exists and arg differs: require `FLOW_FORCE=1` else FAIL with message.

## Related Code Files

- Modify: `skills/flow/runner/flow.sh` (`cmd_check`, `cmd_ready`, `cmd_card_done`, `cmd_project_type`)
- Modify: `skills/flow/harness/graph_executor.py` (deps-met parity with ready)
- Modify: `tests/test_flow_graph_parallel_cards.sh` / related if deps-met assertions change
- Modify: `skills/flow/references/ground-truth-gates.md`, `auto-run.md` (must use card done or re-check after hand-edit)
- Tests: **phase 03** owns corpus rewrite — implement helpers here with temporary local goldens if developing, but do not claim done until 03

## Implementation Steps

1. Implement helpers + unit-style shell tests in new `tests/test_flow_done_evidence.sh` (process FAIL, multi PASS, denylist URL alone FAIL, URL+curl PASS, path existence, ready dep hollow FAIL).
2. Wire `cmd_check` and `cmd_ready`.
3. Harden `cmd_card_done` trap.
4. Type lock.
5. Update ground-truth-gates + auto-run (hand-edit requires re-check before trust).
6. **Stop** — do not merge until phase 03 corpus/fcdc complete.

## Success Criteria

- [x] Helpers + new focused tests green (may fail full suite until 03)
- [x] ready hollow-dep scenario green in focused test
- [x] card_done trap documented + smoke test if feasible
- [x] ground-truth-gates + auto-run updated
- [x] **Not** claimed “full run_all green” without phase 03

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Score ≥2 too strict for tests | Shared golden snippet helper in tests |
| ready performance | O(cards) fine |
| Type lock breaks scripts | FLOW_FORCE escape |

## Test / validation gate

```bash
bash tests/test_flow_done_evidence.sh
# full suite only after phase 03 co-land:
# bash tests/run_all.sh
```

<!-- Updated: Red Team Session 1 - table v2, ready re-validate, atomic with 03, trap -->
