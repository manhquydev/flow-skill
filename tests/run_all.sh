#!/usr/bin/env bash
# Run every /flow test suite. Exit 0 only if all pass. Run: bash tests/run_all.sh
# Prints per-suite wall-clock seconds so CI timeouts can be diagnosed (Windows vs Linux).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
rc=0
total_t0=$(date +%s 2>/dev/null || echo 0)
for suite in test_flow_runner.sh test_flow_harness.sh test_flow_scenarios.sh test_flow_project_types.sh test_flow_gate_wording.sh test_flow_coverage_gaps.sh test_flow_concurrency_lock.sh test_flow_recall.sh test_flow_accessed_count.sh test_flow_gate_capture.sh test_flow_propose_audit.sh test_flow_contract.sh test_flow_tokens.sh test_flow_coherence_kb.sh test_flow_assess.sh test_flow_codex_integration.sh test_flow_consistency.sh test_flow_constitution.sh test_flow_antigravity_integration.sh test_flow_claudekit_integration.sh test_flow_card_lifecycle.sh test_flow_usage_log.sh test_flow_workspace.sh test_flow_monorepo_root.sh test_flow_harness_args.sh test_flow_schema_migration.sh test_flow_tool_registry.sh test_flow_loop.sh test_flow_eval.sh test_flow_resume.sh test_flow_status_legibility.sh test_flow_concierge.sh test_flow_native_rituals.sh test_flow_forge_idea.sh test_flow_harness_lineage_contract.sh test_flow_harness_strict.sh test_flow_harness_trust_complete.sh test_flow_skill_harness_docs_contract.sh test_harness_cli_optional_smoke.sh; do
  echo "==================== $suite ===================="
  t0=$(date +%s 2>/dev/null || echo 0)
  bash "$HERE/$suite" || rc=1
  t1=$(date +%s 2>/dev/null || echo 0)
  if [ "$t0" != 0 ] && [ "$t1" != 0 ]; then
    echo "---- $suite wall_s=$((t1 - t0)) ----"
  fi
  echo
done
total_t1=$(date +%s 2>/dev/null || echo 0)
if [ "$total_t0" != 0 ] && [ "$total_t1" != 0 ]; then
  echo "TOTAL wall_s=$((total_t1 - total_t0))"
fi
if [ "$rc" -eq 0 ]; then echo "ALL SUITES PASSED"; else echo "SOME SUITES FAILED"; fi
exit $rc
