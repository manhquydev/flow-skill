---
phase: 1
title: "Attack-surface map, corpus inventory, honest contract"
status: completed
priority: P1
effort: "0.5-1d"
dependencies: []
---

# Phase 1: Attack-surface map, corpus inventory, honest contract

## Overview

Map every path to `status: done` and **inventory every test** that currently PASSes `check` with weak Evidence. Lock honest success claims (process-prose floor, not auto-proof). No runner behavior change yet except optional baseline XFAIL notes.

## Requirements

- Functional: `done-path-matrix.md` with paths including **hand-edit without re-check** and **ready dep unblock**
- Functional: `test-corpus-inventory.md` listing every suite/file that uses done+weak evidence (grep-driven)
- Non-functional: Document residual decoy class for operators
- Non-functional: No production behavior change

## Architecture

Matrix columns: path | invoker | mech today | semantic | ready impact | target (phase)

Inventory columns: test file:line | current evidence snippet | expected after ship (PASS signal / FAIL)

## Related Code Files

- Read: `skills/flow/runner/flow.sh` (`cmd_check` ~1229–1318, `cmd_card_done` ~1166–1187, `cmd_ready` ~1460–1490)
- Read: `skills/flow/references/auto-run.md`, `ground-truth-gates.md`
- Read: `skills/flow/eval/fixtures/fcda|fcdb/cards/C-001.md`, `tests/test_flow_eval.sh:47-51`
- Grep: `tests/**/*.sh` for `status: done` / weak Evidence
- Create: `plans/260811-1120-flow-hollow-done-trust-eval/done-path-matrix.md`
- Create: `plans/260811-1120-flow-hollow-done-trust-eval/test-corpus-inventory.md`

## Implementation Steps

1. Trace and document paths: check, card done, hand-edit+check, hand-edit **without** check, auto step 4→6, ready deps.
2. Run baseline: copy fcdb/fcda into tmp project; record exit codes.
3. Grep inventory (minimum suites known from red-team):  
   `test_flow_eval.sh`, `test_flow_card_lifecycle.sh`, `test_flow_gate_capture.sh`, `test_flow_harness_strict.sh`, `test_flow_scenarios.sh`, `test_flow_runner.sh`, `test_flow_graph_parallel_cards.sh`, `test_flow_graph_auto_run.sh`, `test_flow_status_legibility.sh`, `test_flow_coverage_gaps.sh`, `test_flow_harness_trust_complete.sh`, `e2e-installed-drive.sh` — expand if grep finds more.
4. Define goldens: G-PASS multi-signal, G-FAIL-PROCESS, G-DECOY-PASS-MECH (fcdc class).
5. Write honest claim paragraph for README/CHANGELOG draft bullets (not ship yet).

## Success Criteria

- [x] Matrix includes hand-edit→ready path as gap closed by phase 02 D5
- [x] Inventory lists ≥10 concrete test sites (or all if fewer) with rewrite target
- [x] Residual decoy documented as out-of-mechanical-scope
- [x] No runner edits

## Risk Assessment

- Inventory incomplete → phase 3 CI red → treat inventory as blocking gate for phase 2 start of coding

## Test / validation gate

```bash
rg -n "status: done" tests/ --glob '*.sh' | tee plans/260811-1120-flow-hollow-done-trust-eval/_grep-done.txt
```

<!-- Updated: Red Team Session 1 - corpus inventory + ready path mandatory -->
