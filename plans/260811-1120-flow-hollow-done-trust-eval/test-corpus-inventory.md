# Test corpus inventory — weak done Evidence (phase 1)

Rewrite all to multi-signal G-PASS or intentional FAIL.

| File | Site | Current | Target |
|------|------|---------|--------|
| test_flow_card_lifecycle.sh | L46 real proof here | weak PASS | G-PASS |
| test_flow_card_lifecycle.sh | L60 real proof | weak | G-PASS (status-less path still fails status) |
| test_flow_card_lifecycle.sh | L76 real curl proof | weak | G-PASS |
| test_flow_gate_capture.sh | L57 real world-state proof | weak | G-PASS |
| test_flow_harness_strict.sh | L30,44,57 proof here | weak | G-PASS |
| test_flow_coverage_gaps.sh | L24 real | weak | G-PASS |
| test_flow_runner.sh | L54 real proof | weak | G-PASS |
| test_flow_scenarios.sh | L30 `$ curl ... 200 ok` | may score B only | G-PASS multi |
| test_flow_status_legibility.sh | L34 real proof | weak | G-PASS |
| test_flow_graph_parallel_cards.sh | default real | weak | G-PASS |
| test_flow_graph_auto_run.sh | L25 real | weak | G-PASS |
| test_flow_eval.sh | L47-51 fcdb check 0 | contract flip | fcdb check 1; fcdc for LLM |
| test_flow_harness_trust_complete.sh | L78 curl https | likely PASS | keep/ensure ≥2 |
| test_flow_recall.sh | done without Evidence sections | N/A check | leave (recall only) |

Shared golden:
```
$ curl https://x/healthz -> 200
PASS healthcheck
```
