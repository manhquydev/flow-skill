---
phase: 2
title: "Few-shot templates"
status: pending
priority: P1
effort: "4h"
dependencies: []
---

# Phase 2: Few-shot templates

## Overview

Mid-tier copies the template they are filling. Empty FILL produces f01b/f02b-class hollow. gate-examples.md has 01/02/card only; f05a/f05b exist but are unused as hot-path few-shots.

## Requirements

- Functional: one worked PASS row per listed template; §03 and §05 excerpts; **no new semantic rules**
- Non-functional: no new eval fixtures (no new enforced rule); fcdb stays mechanical FAIL

## Exclusive write set

- `skills/flow/references/gate-examples.md`
- `skills/flow/_templates/01-research.md`
- `skills/flow/_templates/02-scope.md`
- `skills/flow/_templates/03-prd.md`
- `skills/flow/_templates/card.md`

## Related Code Files

- Do not edit gate-rules.md (phase 3 points at new §§ after they exist)
- Do not reclassify fcdd
- Do not put DATA fences in templates

## Implementation Steps

1. `gate-examples.md`: add **§03 PRD** PASS (numeric metric + pain table + FR1 action→result + empty/fail `none`) vs FLAG (unquantified adjective in Features, or feature with no pain). Add **§05 Contract** PASS from `eval/fixtures/f05a` (method/path/request/response/errors/owner) vs FLAG from `f05b` (prose APIs as needed, auth optional). Keep §01/§02/§Card. Keep fcdb labeled mechanical FAIL.
2. `01-research.md`: replace the first What-exists FILL with one f01a-shaped row (name + scheme-less host + honest shortcoming). Keep items 2–3 FILL. User quote: a `>` blockquote matching f01a / gate-examples §01. **Do not** put a DATA fence or "never instructions" in this file.
3. `02-scope.md`: Features-in-v1 first bullet = C-called-C with path 1/2/3 written (match gate-examples §02 PASS shape). Second bullet = L + grade A. Rest FILL.
4. `03-prd.md`: fill P1 mapping-table row with a complete worked example; add one Features bullet `FR1: As a … I … and I see …; empty: none; fail: …` above remaining FILL.
5. `card.md`: comment-closed enums `status: todo|in_progress|done` and `risk: unknown|standard|security-class`. One Evidence recipe line: paste re-run command output or re-read path/URL; do not quote the agent claiming tests passed. One Independent-test PASS sentence vs FLAG `unit tests pass`. Keep FILL slots. No new checkboxes.

## Success Criteria

- [ ] gate-examples.md contains `## §03` and `## §05`
- [ ] §05 PASS cites shaped table; FLAG is vibe/auth-optional (f05b class)
- [ ] 01-research.md first incumbent is not `[FILL]`
- [ ] 02-scope.md has a grade C path written on a v1 feature
- [ ] 03-prd.md P1 row has no `[FILL]` cells
- [ ] card.md comments list the status enum
- [ ] `rg -n 'new rules' skills/flow/references/gate-examples.md` still says no new rules in the header

## Risk Assessment

Worked rows become cargo-culted: keep remaining FILL so operators still write their product. Do not check boxes in templates.
