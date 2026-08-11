# QA Report — flow-skill mechanical test corpus (v0.28.0)

**Date:** 2026-08-11T20:04+07:00  
**Role:** Independent tester (report-only; no product code changes)  
**Commit:** `69a397d` — `feat(flow): attested execution trust control plane (v0.28.0 / npm 0.5.0)`  
**Branch:** `master` (tracks `origin/master`)

---

## Environment

| Item | Value |
|------|-------|
| OS | Linux 6.8.0-137-generic (Ubuntu, x86_64) host `manhquy-Legion-5-15ACH6` |
| Bash | GNU bash 5.2.21(1)-release |
| Git | present; HEAD `69a397d` |
| Python | python3 available (harness suites ran) |
| CWD | `/home/manhquy/Downloads/flow-skill` |

---

## Versions

| Field | Value | Notes |
|-------|-------|-------|
| `skills/flow/SKILL.md` metadata.version | **0.28.0** | product skill |
| `npm-wrapper/package.json` version | **0.5.0** | installer package (intentional separate track) |
| Coherence (`flow.sh coherence`) | **PASS** | declared versions agree: SKILL.md, portable-manifest.json, .claude-plugin/plugin.json all **0.28.0** |

---

## Focused attestation suites

Env: `FLOW_HARNESS_DISABLE=1 FLOW_LOG_DISABLE=1`

| Suite | Result | Counts | wall_s |
|-------|--------|--------|--------|
| `test_flow_attestation_contract.sh` | PASS | 33/0 | 0 |
| `test_flow_card_risk.sh` | PASS | 10/0 | 1 |
| `test_flow_attestation_supervisor.sh` | PASS | 7/0 | 1 |
| `test_flow_attestations.sh` | PASS | 12/0 | 33 |
| `test_flow_auto_attestation_enforcement.sh` | PASS | 13/0 | 4 |
| `test_release_coherence.sh` | PASS | 3/0 | 1 |

**Focused total:** 6/6 PASS (78 checks, 0 fail)

---

## Key lifecycle regressions

Env: `FLOW_HARNESS_DISABLE=1 FLOW_LOG_DISABLE=1`

| Suite | Result | Counts | wall_s |
|-------|--------|--------|--------|
| `test_flow_runner.sh` | PASS | 18/0 | 7 |
| `test_flow_done_evidence.sh` | PASS | 27/0 | 2 |
| `test_flow_auto_done_path.sh` | PASS | 8/0 | 0 |
| `test_flow_card_lifecycle.sh` | PASS | 22/0 | 2 |
| `test_flow_status_legibility.sh` | PASS | 24/0 | 2 |
| `test_flow_resume.sh` | PASS | 29/0 | 2 |
| `test_flow_concierge.sh` | PASS | 31/0 | 0 |
| `test_flow_workspace.sh` | PASS | 43/0 | 11 |
| `test_flow_monorepo_root.sh` | PASS | 10/0 | 1 |

**Lifecycle total:** 9/9 PASS (212 checks, 0 fail)

Note: no dedicated `test_flow_ready*.sh`; ready paths covered via `test_flow_coverage_gaps.sh` (ready block) + auto/ready mentions in attestation + card lifecycle suites.

---

## Full `tests/run_all.sh` (authoritative)

**Env (required clean):**
- `unset FLOW_HARNESS_DISABLE`  ← do **not** set to `0` (string still set → graph poison)
- `unset FLOW_LOG_DISABLE`      ← **must** unset; `=1` poisons usage-log + loop suites

| Metric | Value |
|--------|-------|
| Suites | **54** |
| Passed suites | **53** |
| Failed suites | **1** (`test_flow_coverage_gaps.sh`) |
| Check-level | **1314 passed, 2 failed** |
| TOTAL wall_s | **225** (~3.75 min) |
| Exit | **1** — `SOME SUITES FAILED` |

### Failed suite detail

#### `test_flow_coverage_gaps.sh` — FAIL (40 passed, 2 failed) — **deterministic** (3/3 re-runs identical)

**Fail lines:**
```
FAIL [auto preflight passes with planning + a card] expected 0 got 1
FAIL [auto reports preflight ok]
```

**Last ~30 lines (suite tail):**
```
  ok   [agent-wired: scout appears in agent-stage-mapping.md]
  ...
C-021 language-specialist lens — routing documented and both reviewers wired
  ok   [C-021: typescript-reviewer referenced in adversarial-review.md]
  ...
  ok   [C-021: python-reviewer in agent-detection.md ck: list]

RESULT: 40 passed, 2 failed
```

**Actual `flow auto` under coverage_gaps fixture (planning + card, no git):**
```
flow auto - preflight (attested execution)
FAIL: /flow auto requires a Git repository.
exit=1
```

**With git + risk but no stage receipt (next gate after git):**
```
flow auto - preflight (attested execution)
--- risk set ---
READY C-001 risk=standard: ordinary
--- Stage 05 semantic receipt ---
FAIL: need current accepted semantic_gate receipt for 05-contract.
  mint: flow attest semantic --stage 05-contract --revision HEAD --owner <committed-manifest>
exit=1
```

**Hypothesis (not a product fix):**  
`tests/test_flow_coverage_gaps.sh` lines 32–37 still assert pre-attestation auto contract:
- planning complete + ≥1 card → exit 0 + string `preflight ok`

Post-v0.28.0 `cmd_auto` (`skills/flow/runner/flow.sh`) requires:
1. Git repo (`_att_git_ok`)
2. main worktree, non-detached HEAD
3. supervisor capability
4. planning complete + cards
5. risk preflight
6. current Stage 05 semantic receipt
7. success string is `PASS: auto ACTIVE...` (not `preflight ok`)

New suite `test_flow_auto_attestation_enforcement.sh` covers the real contract and **PASSES**.  
coverage_gaps auto block is **stale fixture/assertion drift**, not a regression in attested auto itself.

**Recommended fix (test harness only):** rewrite coverage_gaps auto block to either:
- assert fail without git / without stage receipt (negative), or
- share `setup_green` + stage mint from auto_attestation_enforcement and assert `PASS: auto ACTIVE`, or
- drop auto happy-path from coverage_gaps (owned by enforcement suite).

---

## Flakes observed

| Observation | Verdict |
|-------------|---------|
| coverage_gaps 2 fails | **Not flake** — 3/3 identical |
| usage_log / loop in first polluted run | **Env poison**, not product flake |
| Graph suites | PASS with harness unset |
| Optional harness-cli smoke | SKIP unless `HARNESS_CLI_SMOKE=1` (by design) |

### Env poison incident (tester error on first full run)

First `run_all` used `FLOW_LOG_DISABLE=1` → false fails:
- `test_flow_usage_log.sh` 55/29
- `test_flow_loop.sh` 40/3 (loop-log usage-log capture)

**Clean re-run:** both PASS (84/0 and 43/0).  
**Do not** export `FLOW_LOG_DISABLE=1` for full suite. Focused attestation may use it.

Also: never `export FLOW_HARNESS_DISABLE=0` — presence of the var (even as `"0"`) can break graph tests.

---

## Go / No-Go (mechanical quality)

| Gate | Status |
|------|--------|
| Attestation contract + enforcement | **GO** (all focused attestation green) |
| Lifecycle (runner/done/card/status/resume/concierge/workspace) | **GO** |
| Graph executor / crash-resume / parallel / planning parity | **GO** |
| Release coherence (skill 0.28.0 declared set) | **GO** |
| Full mechanical corpus `run_all` | **NO-GO (soft)** — 1 suite red, 2 stale assertions |

**Overall: CONDITIONAL GO**

- Product attestation plane + lifecycle + graph: mechanically sound under clean env.
- Ship-block only if policy requires **ALL SUITES PASSED** with zero red.
- Single red suite is **test drift** against new `cmd_auto`, not evidence that attested auto is broken (enforcement suite green).

---

## Exact re-runnable commands

```bash
cd /home/manhquy/Downloads/flow-skill

# Versions
grep -E 'version' skills/flow/SKILL.md | head -5
python3 -c 'import json;print(json.load(open("npm-wrapper/package.json"))["version"])'
bash skills/flow/runner/flow.sh coherence

# Focused attestation
export FLOW_HARNESS_DISABLE=1 FLOW_LOG_DISABLE=1
for s in test_flow_attestation_contract.sh test_flow_card_risk.sh \
  test_flow_attestation_supervisor.sh test_flow_attestations.sh \
  test_flow_auto_attestation_enforcement.sh test_release_coherence.sh; do
  bash tests/$s || echo FAIL:$s
done

# Lifecycle
for s in test_flow_runner.sh test_flow_done_evidence.sh test_flow_auto_done_path.sh \
  test_flow_card_lifecycle.sh test_flow_status_legibility.sh test_flow_resume.sh \
  test_flow_concierge.sh test_flow_workspace.sh test_flow_monorepo_root.sh; do
  bash tests/$s || echo FAIL:$s
done

# Full suite — CLEAN env (critical)
unset FLOW_HARNESS_DISABLE FLOW_LOG_DISABLE
env -u FLOW_HARNESS_DISABLE -u FLOW_LOG_DISABLE bash tests/run_all.sh

# Isolate known red
env -u FLOW_HARNESS_DISABLE -u FLOW_LOG_DISABLE bash tests/test_flow_coverage_gaps.sh
```

Raw logs: `/tmp/flow-qa-results/run_all.clean.out` and per-suite `*.out`.

---

## Unresolved questions

1. Should `test_flow_coverage_gaps.sh` auto block be updated in-tree before tagging 0.28.0 as fully green, or is enforcement suite ownership enough for release policy?
2. npm-wrapper **0.5.0** vs skill **0.28.0** — intentional dual versioning confirmed by coherence (skill fields only); any external consumer still coupling them?

---

## Summary counts

| Layer | Suites | Pass | Fail |
|-------|--------|------|------|
| Focused attestation | 6 | 6 | 0 |
| Lifecycle key | 9 | 9 | 0 |
| Full run_all (clean) | 54 | 53 | 1 |
| Check-level full | — | 1314 | 2 |
