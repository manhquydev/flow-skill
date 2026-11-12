## What changed and why

<!-- 1-2 concise sentences describing the problem solved or feature added. -->

## Pre-submission Checklist

Please verify each of the following before submitting:

- [ ] **Conventional commit / PR title:** Follows standard type (`feat:`, `fix:`, `docs:`, `test:`, `chore:`)
- [ ] **Tests run locally:** All relevant test suites pass locally (list suites run below)
- [ ] **Suite registry:** If a new test suite was added (`tests/test_*.sh`), a corresponding line was added to `tests/manifest.txt` in this PR
- [ ] **Doc budgets:** Ran `bash scripts/check-doc-budgets.sh` and verified `tests/test_doc_budgets.sh` passes
- [ ] **Version fields untouched:** No version bumps in `skills/flow/SKILL.md`, `.claude-plugin/plugin.json`, `portable-manifest.json`, or `npm-wrapper/package.json` (handled exclusively by maintainers during release runs)
- [ ] **No STOP-zone edits:** `_eval_engine_run` and `_run_with_timeout` in `skills/flow/runner/flow.sh` are untouched

## Test Evidence

<!-- Paste relevant local test run output demonstrating your changes pass. -->
```bash
# Example: bash tests/run_all.sh, cd npm-wrapper && npm test, or specific test suite
```

## Related Issue

Closes #
