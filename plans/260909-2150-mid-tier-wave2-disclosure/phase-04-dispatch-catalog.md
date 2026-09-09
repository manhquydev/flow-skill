---
phase: 4
title: "Dispatch catalog"
status: pending
priority: P1
effort: "3h"
dependencies: []
---

# Phase 4: Dispatch catalog

## Overview

SKILL.md PTC_ONLY says load that row only. `command-dispatch.md` is still a wall. Concierge still says `SKILL.md's Commands table`. There is **no** fragment loader (ADR-0001). This phase shrinks the wall; the file is still loaded whole. Anchors help humans, not a runtime.

## Requirements

- Functional: verb table remains; Host-duties = one line + pointer; concierge cites command-dispatch
- Non-functional: do not split into per-verb files; do not add AutoDecision; do not claim anchors equal row-only load

## Exclusive write set

- `skills/flow/references/command-dispatch.md`
- `skills/flow/references/concierge.md`

## Implementation Steps

1. Shrink each Host-duties cell to one line + pointer. Delete After-FAIL/PASS/Never if they duplicate SKILL.md STOP/Dispatch.
2. Add `#verb-next` / `#verb-card` anchors (seekable). Do not claim PTC_ONLY becomes real.
3. After-PASS next (one line): examples already the SKILL.md extra; this cell may pointer `gate-examples.md` without being a second always-on file.
4. After-PASS card: pointer `law/CODING.md`.
5. `concierge.md`: both `SKILL.md's Commands table` → `command-dispatch.md` verb row.

## Success Criteria

- [ ] `rg -n "SKILL.md's Commands table" skills/flow/references/concierge.md` empty
- [ ] command-dispatch.md has `#verb-next`
- [ ] Host-duties for `next` mentions gate-examples.md
- [ ] Host-duties for `card` mentions law/CODING.md
- [ ] No AutoDecision enum listed in this file

## Risk Assessment

Tests grep command-dispatch. Run `tests/test_flow_concierge.sh`. Do not restore a Commands table in SKILL.md.
