# Test-Impact Advisory Playbook

This playbook provides advisory guidance for selecting targeted test suites during
development. It is strictly advisory: it introduces no mechanical gate, does not alter
runner exit contracts, and requires no fixture pairs. Use it to shorten iteration loops
before submitting changes to cross-OS CI.

Suite inventory is owned by `tests/manifest.txt`; detailed behavioral contracts are
documented in each suite's file header.

## 1. Scoping with `git diff --name-only`

Inspect changed files in your working tree or branch to identify impacted subsystems:

```bash
# Working tree changes (staged or unstaged)
git diff --name-only HEAD

# Branch changes relative to upstream master
git diff --name-only origin/master...HEAD
```

Match changed file paths to candidate subsystems:
- `skills/flow/runner/**` -> Runner subsystem (core engine, verbs, and builtins)
- `skills/flow/runner/doctor*` -> Doctor subsystem (`doctor_helper.py`, `doctor-checks.tsv`, `flow.sh:cmd_doctor`)
- `skills/flow/eval/**` -> Eval subsystem (fixtures, replay manifests, and linter)
- `skills/flow/harness/**` -> Harness subsystem (durable SQLite storage and graph executor)
- `skills/flow/adapter-hooks/**` -> Adapter-hooks subsystem (host context and lifecycle adapters)
- `install.sh`, `install.ps1`, `npm-wrapper/**`, `scripts/pack-rehearsal.sh`, `scripts/sync*.mjs` -> Installer subsystem
- `skills/flow/references/**`, `skills/flow/_templates/**`, `skills/flow/law/**`, `docs/**` -> References and templates

Run only the targeted suites for identified subsystems during fast local iteration.

---

## 2. Subsystem to Test Suite Mappings

Execute suites using `bash tests/<suite>.sh`. Each manifest suite is grouped under its primary subsystem:

### Runner (`skills/flow/runner/flow.sh`, `attestations.sh`)
- `test_flow_runner.sh`
- `test_flow_concurrency_lock.sh`
- `test_flow_monorepo_root.sh`
- `test_flow_workspace.sh`
- `test_flow_usage_log.sh`
- `test_flow_project_types.sh`
- `test_flow_coverage_gaps.sh`
- `test_flow_card_lifecycle.sh`
- `test_flow_done_evidence.sh`
- `test_flow_auto_done_path.sh`
- `test_flow_midtier_scanners.sh`
- `test_flow_open_decisions.sh`
- `test_flow_slice_quality.sh`
- `test_flow_converge.sh`
- `test_flow_resume.sh`
- `test_flow_status_legibility.sh`
- `test_flow_rules.sh`
- `test_flow_scenarios.sh`
- `test_flow_loop.sh`
- `test_flow_consistency.sh`
- `test_flow_constitution.sh`
- `test_flow_contract.sh`
- `test_flow_tokens.sh`
- `test_flow_assess.sh`
- `test_flow_parallel_auto.sh`
- `test_flow_card_risk.sh`
- `test_flow_attestation_supervisor.sh`
- `test_flow_attestations.sh`
- `test_flow_auto_attestation_enforcement.sh`
- `test_flow_attestation_harden.sh`
- `test_flow_coherence_kb.sh`

### Doctor (`skills/flow/runner/doctor*`, `flow.sh:cmd_doctor`)
Source lives under runner (`skills/flow/runner/doctor_helper.py`, `doctor-checks.tsv`, `flow.sh:cmd_doctor`).
- `test_flow_doctor.sh`

### Eval (`skills/flow/eval/**`, `flow.sh:cmd_eval`, `references/gate-eval.md`)
- `test_flow_eval.sh`
- `test_eval_fixture_lint.sh`

### Harness (`skills/flow/harness/`)
- `test_flow_harness.sh`
- `test_flow_harness_args.sh`
- `test_flow_schema_migration.sh`
- `test_flow_accessed_count.sh`
- `test_flow_recall.sh`
- `test_flow_propose_audit.sh`
- `test_flow_gate_capture.sh`
- `test_flow_tool_registry.sh`
- `test_flow_journal.sh`
- `test_flow_graph_schema.sh`
- `test_flow_graph_executor.sh`
- `test_flow_graph_crash_resume.sh`
- `test_flow_graph_lint.sh`
- `test_flow_graph_auto_run.sh`
- `test_flow_graph_parallel_cards.sh`
- `test_flow_graph_planning_parity.sh`
- `test_flow_harness_strict.sh`
- `test_flow_harness_trust_complete.sh`
- `test_flow_harness_lineage_contract.sh`
- `test_harness_cli_optional_smoke.sh`

### Adapter-Hooks (`skills/flow/adapter-hooks/`)
- `test_flow_host_hooks.sh`
- `test_flow_windows_lifecycle.sh`

### Installer & Packaging (`install.sh`, `install.ps1`, `npm-wrapper/`, `scripts/`)
- `test_install_safe_update.sh`
- `test_manifest_runner.sh`
- `test_release_coherence.sh`
- `test_sync_release.sh`

### References & Templates (`skills/flow/references/`, `skills/flow/_templates/`, `skills/flow/law/`, `docs/`)
- `test_flow_gate_wording.sh`
- `test_flow_attestation_contract.sh`
- `test_doc_budgets.sh`
- `test_flow_skill_harness_docs_contract.sh`
- `test_flow_antigravity_integration.sh`
- `test_flow_codex_integration.sh`
- `test_flow_claudekit_integration.sh`
- `test_flow_host_agnostic_parallel.sh`
- `test_flow_concierge.sh`
- `test_flow_native_rituals.sh`
- `test_flow_forge_idea.sh`
- `test_i18n_pairs.sh`

---

## 3. When Broader or Full Cross-OS Verification is Recommended or Required

Targeted suites guide local inner-loop development; do not default to running the full
3-OS suite for isolated changes (`AGENTS.md`). Broader verification applies as follows:

1. **Recommended Local Escalation (`bash tests/run_all.sh`)**:
   - **Cross-cutting runner or harness edits**: changes to core dispatch (`_dispatch`,
     `scan_gate`, option parsers in `flow.sh`) or durable database schemas and migrations
     (`_db.py`, `skills/flow/harness/schema/*.sql`).
   - **Cross-platform path or process containment**: changes touching Windows path
     translation (cygpath, UNC, drive letters), macOS symlink resolution (`/private/var`),
     or process supervision/signals in `adapter-hooks/` and attestation supervisors.
   - **Installer and packaging updates**: edits to `install.sh`, `install.ps1`, or
     `npm-wrapper/`.

2. **Required by Existing Project and Branch Policy**:
   - Full 3-OS matrix execution (GitHub Actions `bash-suite` across Ubuntu, macOS, and
     Windows under `all-checks-passed`) is enforced by existing branch policy on PRs
     targeting `master` and release promotions (`docs/release-process.md`).
