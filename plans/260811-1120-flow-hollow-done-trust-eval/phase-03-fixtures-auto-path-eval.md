---
phase: 3
title: "Atomic fixtures, corpus rewrite, auto-path, scorecard"
status: completed
priority: P1
effort: "1.5-2d"
dependencies: [2]
---

# Phase 3: Atomic fixtures, corpus rewrite, auto-path, scorecard

## Overview

Co-ship with phase 02: rewrite **entire** weak-evidence test corpus; flip fcdb mechanical contract; add fcdc decoy for LLM; auto-path scenarios including **hand-edit→ready**; scorecard policy with **CI-measurable process-only catch rate**.

## Requirements

- Functional: Every inventory row from phase 01 rewritten to multi-signal G-PASS or intentional FAIL
- Functional: `test_flow_eval.sh` A-loop: fcda check 0; **fcdb check 1** (or fcdb removed from mechanical-PASS loop); fcdc for semantic FLAG mocks
- Functional: Auto-path tests: process FAIL; G-PASS; card_done revert; **hand-edit done+hollow → ready does not list dependent as buildable**
- Functional: Scorecard policy doc: CI metric definition
- Non-functional: No billable eval in GHA required checks
- Non-functional: Same PR / cook batch as phase 02

## Architecture

### Fixtures

| ID | Role | Mech | LLM |
|----|------|------|-----|
| fcda | sound multi-signal | PASS | PASS |
| fcdb | process-only | **FAIL** | not used for hollow-clean |
| fcdc | decoy URL denylist-bypass? use non-denylist host + process prose without cat B/C — actually need **mech PASS + semantic FLAG**: e.g. `https://staging.realapp.example` **wait denylist** — use `https://httpbin.org/status/200` + process prose without second category → score 1 → FAIL. For mech PASS decoy: URL (allowed host) + fake fence with `PASS` token (score 2) + hollow meaning | PASS | FLAG |
| fcdd optional | process-only alias | FAIL | — |

Update `manifest.tsv`. Update `test_flow_eval.sh` mock paths that assumed fcdb mechanical PASS and LLM FLAG on fcdb — point FLAG tests at **fcdc**.

### Shared test helper

`tests/lib/done_evidence_golden.sh` or inline function:

```bash
EVIDENCE_GPASS='$ curl https://ci.example.invalid/healthz -> 200
```
PASS healthcheck
```'
```

Note: `example.invalid` denylist — use `https://httpbin.org/get` + fence PASS or `https://x.test` careful. Prefer `https://project.local/health` + `$ curl ... -> 200` as two categories (A+B) without relying on public network (no fetch). Host `project.local` not in denylist.

### Scorecard policy

`skills/flow/references/gate-eval.md` section:

| Metric | Definition | CI |
|--------|------------|-----|
| process_fail_rate | # process-only fixtures with check exit 1 / total process fixtures | Yes (shell tests) |
| decoy_mech_pass | fcdc-class still exit 0 | Documented residual |
| llm_flag_rate | flow eval offline on fcdc | No default CI |

## Related Code Files

- Modify: all inventory test files (phase 01 list)
- Modify: `skills/flow/eval/manifest.tsv`, fixtures fcdb/fcdc
- Modify: `tests/test_flow_eval.sh` (fcdb mechanical + fcdc LLM mock)
- Create: `tests/test_flow_auto_done_path.sh`, `tests/test_flow_done_evidence.sh` (if not in 02)
- Modify: `tests/run_all.sh`
- Modify: `skills/flow/references/gate-eval.md`, `auto-run.md`
- Graph tests using `real` default: `test_flow_graph_parallel_cards.sh`, `test_flow_graph_auto_run.sh`

## Implementation Steps

1. Add fcdc fixture + manifest; change fcdb expectation docs.
2. Fix `test_flow_eval.sh:47-51` and any fcdb FLAG mock sections → fcdc.
3. Rewrite corpus goldens using shared snippet.
4. Auto-path + ready hand-edit scenario.
5. Scorecard policy section.
6. `bash tests/run_all.sh` full green.
7. Coherence/version bump only when shipping skill version.

## Success Criteria

- [x] Full `run_all.sh` green
- [x] fcdb not required mechanical PASS
- [x] fcdc exists for semantic FLAG
- [x] ready hand-edit hollow scenario asserted
- [x] gate-eval scorecard policy present
- [x] GHA workflows unchanged re: no forced billable eval

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Missed test file | Re-run phase 01 grep before merge |
| Eval mock breakage | Update all fcdb references in test_flow_eval.sh |

## Test / validation gate

```bash
bash tests/run_all.sh
grep fcdc skills/flow/eval/manifest.tsv
```

<!-- Updated: Red Team Session 1 - atomic with 02, ready scenario, fcdc, corpus -->
