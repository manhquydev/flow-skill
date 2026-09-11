---
phase: 1
title: "Dead pointers"
status: pending
priority: P1
effort: "3h"
dependencies: []
---

# Phase 1: Dead pointers

## Overview

Flash searches SKILL.md for AUTO PRINCIPLES and never opens auto-run.md. Three-laws still demand a live URL for CLI. Load table never names gate-examples.md or CODING.md. AGENTS.md still says Commands live in SKILL.md.

## Requirements

- Functional: every listed pointer is current; SKILL.md ≤1600w; no YOU(Claude); no Commands table restored
- Non-functional: bash 3.2; no runner edits in this phase

## Exclusive write set

- `skills/flow/SKILL.md`
- `skills/flow/law/CLAUDE.md`
- `AGENTS.md`
- `skills/flow/references/ground-truth-gates.md`

## Related Code Files

- Modify: the exclusive set only
- Do not touch: gate-rules.md, command-dispatch.md, auto-run.md, flow.sh

## Implementation Steps

1. `law/CLAUDE.md`: replace `SKILL.md AUTO PRINCIPLES` with `references/auto-run.md`. Keep teach/work. Do not dump the auto enum here. Runner line may stay `bash …/runner/flow.sh` (install-home detail is SKILL.md).
2. `SKILL.md` Three laws heading: drop `(law/CLAUDE.md)`. Law 3: world-state done-evidence — deployed URL for web; install+run for cli/library/skill. Load table: `next PASS / check semantic` → **one extra** `gate-examples.md` (PTC_ONLY forbids a two-file cell). `card / build session` stays `law/CLAUDE.md` only; CODING.md stays a pointer inside CLAUDE.md. One STOP line: `NEXT_VERB=` is advisory; never auto-exec `auto`/`skip`.
3. `AGENTS.md` one-home table: Command table home = `skills/flow/references/command-dispatch.md`. Drop or demote the live website commands URL from standing orders.
4. `ground-truth-gates.md` Card DONE row: per-type world-state, not `live URL verified as a user`. Keep rule 8 semantic.

## Success Criteria

- [ ] `rg -n 'AUTO PRINCIPLES' skills/flow/law/CLAUDE.md` empty
- [ ] SKILL.md load table next-PASS extra is **only** `gate-examples.md` (not also gate-rules.md)
- [ ] SKILL.md has no "Verify on the live URL as a user"
- [ ] `wc -w skills/flow/SKILL.md` ≤ 1600
- [ ] AGENTS.md Command table home is command-dispatch.md
- [ ] `bash tests/test_doc_budgets.sh` pass (SKILL.md cap)

## Risk Assessment

Load-table growth vs 1600w: cut Seams bullets first. Do not raise the cap.
