---
phase: 4
title: "A4 root AGENTS.md + word budgets"
status: pending
priority: P2
effort: "0.5-1d"
dependencies: [2]
---

# Phase 4: A4 root AGENTS.md + word budgets

## Overview
Give the multi-engine repo (Claude/Codex/Antigravity contributors) a single word-budgeted agent-context
file, and put budgets on the longest reference docs — the structural fix for the recurring
stale-docs/counts drift class (RETRO + quality-metrics DF-1).
Pattern source: dsh root AGENTS.md ≤1,900 words + `CLAUDE.md` symlink + one-home-per-fact
(`research-260814-0915-deepseek-docs-bench.md` §1.1, §2).

## Requirements
- Functional: root `AGENTS.md` (standing orders, layout map, command reference, conventions,
  test-evidence protocol, pointer to identity ADR); `CLAUDE.md` symlink **or** the Windows stub
  fallback in Architecture; word-budget verify step in release-preflight.
- Non-functional: budgets are advisory during runs (flag, never hard-fail a flow run — same posture
  as `constitution`); enforced only in repo CI/preflight. One home per fact: AGENTS.md points, never
  duplicates.

## Architecture
- `AGENTS.md` at repo root, ≤1,200 words (flow is smaller than dsh; tighter budget).
- **Root** `CLAUDE.md` → symlink (or stub). Do **not** touch `skills/flow/law/CLAUDE.md` (UI/build
  law; different file, different home). Windows/Git-Bash caveat: verify `git config core.symlinks`
  behavior in CI; if symlink is risky for Windows contributors, fall back to a 3-line stub
  CLAUDE.md that includes AGENTS.md by reference and is checked for staleness by the budget script.
- `scripts/check-doc-budgets.sh`: plain-text manifest `docs/doc-budgets.txt` (`path max_words` per
  line); `wc -w` compare; exit 1 on breach. Wired into `scripts/release-preflight.sh` and the CI
  bash-suite (via manifest from Phase 2).

## Related Code Files
- Create: `AGENTS.md`, `CLAUDE.md` (symlink or stub), `docs/doc-budgets.txt`, `scripts/check-doc-budgets.sh`,
  `tests/test_doc_budgets.sh`
- Modify: `scripts/release-preflight.sh`, `tests/manifest.txt`

## Implementation Steps
1. Inventory current agent-context duplication (README sections, docs/codebase-summary.md) — AGENTS.md
   points at each home, absorbs only standing orders that have no home today.
2. Write AGENTS.md; set initial budgets from a 2026-08-14 `wc -w` + 10% headroom (ratchet down
   later; wave 1 just stops growth):
   | path | measured | budget |
   |---|---:|---:|
   | `AGENTS.md` | (new) | 1200 |
   | `README.md` | 3519 | 3880 |
   | `skills/flow/SKILL.md` | 3590 | 3950 |
   | `skills/flow/references/gate-rules.md` | 2621 | 2890 |
   | `skills/flow/references/attestations.md` | 1428 | 1580 |
3. Implement check script + test suite; register suite in manifest.
4. Wire into release-preflight; run full preflight to confirm.
5. Update the hardcoded suite-count homes (README.md / README_VN.md / docs/system-architecture.md
   / docs/codebase-summary.md still say 58) to the **current manifest count**, or replace them
   with a pointer at `tests/manifest.txt`. This is the DF-1 class this phase exists to stop.

## Success Criteria
- [x] `AGENTS.md` exists ≤ budget; `CLAUDE.md` resolves to same content on linux/macOS CI and a
      documented Windows behavior.
- [x] Budget breach on any listed doc fails preflight + the new suite (tested with a temp breach).
- [x] No fact duplicated into AGENTS.md that already has a home (reviewed against one-home-per-fact).
- [x] Hardcoded "58 suites" homes updated to the current manifest count (or pointed at the manifest).

<!-- Updated: Red Team R2 - update stale suite-count homes -->

## Risk Assessment
Symlink on Windows is the only real hazard — decided by a CI probe, with the stub fallback specified
above so the phase cannot dead-end.

<!-- Updated: Validation Session 1 - law/CLAUDE.md out of scope; pin measured word budgets -->
