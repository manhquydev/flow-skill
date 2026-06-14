#!/usr/bin/env bash
# Run every /flow test suite. Exit 0 only if all pass. Run: bash tests/run_all.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
rc=0
for suite in test_flow_runner.sh test_flow_harness.sh test_flow_scenarios.sh test_flow_project_types.sh test_flow_gate_wording.sh test_flow_coverage_gaps.sh test_flow_concurrency_lock.sh test_flow_recall.sh test_flow_gate_capture.sh test_flow_propose_audit.sh test_flow_contract.sh test_flow_tokens.sh test_flow_coherence_kb.sh test_flow_assess.sh; do
  echo "==================== $suite ===================="
  bash "$HERE/$suite" || rc=1
  echo
done
if [ "$rc" -eq 0 ]; then echo "ALL SUITES PASSED"; else echo "SOME SUITES FAILED"; fi
exit $rc