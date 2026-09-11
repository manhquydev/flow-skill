---
phase: 3
title: "Split gate-rules"
status: pending
priority: P1
effort: "6h"
dependencies: [2]
---

# Phase 3: Split gate-rules

## Overview

`gate-rules.md` is the always-on semantic blob. 02/03/05 triplicate "no mechanical cap" vs OD>5 scanner. After split, the **judge still extracts one heading from one file** (`_eval_extract_section` → `GATE_RULES_FILE`). Index-only without retargeting extract = empty challenge.

## Requirements

- Split **every** current `^## ` heading (assess, 00, 01, 02, 03, 04, 05, card, consistency, constitution, debt). "Do not invent 00/04" = no **new challenge prose**, not "do not emit those files".
- Index ≤800w. `gate-shared.md` unique OD/authority home. Zero "no mechanical cap" in skills/flow.
- `_eval_extract_section` maps 01→gate-01.md, 02→gate-02.md, card→gate-card.md (keep existing heading regexes inside those files). Do **not** add a 05 arm.
- `_eval_gate_rules_sha` concatenates an **explicit** sorted list (index + shared + the 11 section files). Never `gate-*.md` glob (would pull gate-eval.md + gate-examples.md).
- `_eval_build_prompt` inlines the **same files extract reads** into the promptfile **before** `_eval_engine_run`. Engine stays `--tools ''` on one promptfile.
- Never edit `_eval_engine_run` / `_run_with_timeout` bodies. Never add `_eval_heading_pattern` 05.

## Exclusive write set

- `skills/flow/references/gate-rules.md` (index)
- Create: `gate-shared.md`, `gate-assess.md`, `gate-00.md`, `gate-01.md`, `gate-02.md`, `gate-03.md`, `gate-04.md`, `gate-05.md`, `gate-card.md`, `gate-consistency.md`, `gate-constitution.md`, `gate-debt.md`
- `skills/flow/references/clarify.md`
- `docs/doc-budgets.txt`
- `skills/flow/runner/flow.sh` only: `_eval_extract_section`, `_eval_build_prompt`, `_eval_gate_rules_sha`
- Tests: `tests/test_flow_eval.sh` (sha recipe + heading extract), `tests/test_flow_forge_idea.sh`, `tests/test_flow_native_rituals.sh`, `tests/test_flow_claudekit_integration.sh`, `tests/test_flow_gate_wording.sh`, `tests/test_flow_slice_quality.sh`

## Implementation Steps

1. Grep `^## ` in gate-rules.md. Move each section verbatim into `gate-<id>.md`, minus the false "no mechanical cap" sentences (link `gate-shared.md`).
2. Write `gate-shared.md`: material-authority; assumption vs OD; **OD>5 fails scan_gate**; leftover `- [ ]` still fails boxes; clarify opt-in never a next prereq; invent-no-auth/tenancy/retention/billing.
3. Index `gate-rules.md` ≤800w: posture + table `stage | mechanical | file | gate-examples §`. First bullets of 01/02/03/05/card: compare to gate-examples §N. Neutralize `YOU check`.
4. `clarify.md`: `>5 markdown bullets under ## Open decisions fails scan_gate`.
5. `docs/doc-budgets.txt`: `gate-rules.md` 800. Do not ceiling per-stage files. Do not raise SKILL.md.
6. `_eval_extract_section`: case 01/02/card open the matching file then awk the existing `^## Stage` / `^## Card gate` regex. Empty → same FAIL as today.
7. `_eval_gate_rules_sha`: explicit `cat` list (routing analog `_eval_routing_rules_sha`). `test_flow_eval.sh` `grsha=` must use the **same** list, not a second recipe.
8. `_eval_build_prompt`: the challenge block is the extract output (already the judge bytes). Do not claim sha == judge stdin.
9. Retarget the five grep suites to the per-section files or a shared concat.

## Success Criteria

- [ ] `wc -w skills/flow/references/gate-rules.md` ≤ 800
- [ ] `rg -n 'no mechanical cap|there is no mechanical cap' skills/flow` empty
- [ ] `gate-00.md` and `gate-04.md` exist with the **old** challenge text
- [ ] `_eval_extract_section` reads `gate-01.md` / `gate-02.md` / `gate-card.md`
- [ ] `_eval_gate_rules_sha` does not glob `gate-*.md`
- [ ] `git diff` does not change `_eval_engine_run` or `_run_with_timeout` bodies
- [ ] `bash tests/test_doc_budgets.sh` and `bash tests/test_flow_eval.sh` pass (no live claude)

## Risk Assessment

Committed replay `meta` sha will stale. Do not invent transcripts. Operator re-record. Tests that compute sha live stay green.
