# Red team R1 — flow upgrade wave1

- **Date:** 2026-08-14
- **Target:** `plans/260814-0948-flow-upgrade-wave1/` (`plan.md` + 8 phases)
- **Lenses:** Security Adversary, Failure Mode Analyst, Assumption Destroyer, Scope & Complexity Critic
- **Prior advisory round:** not relitigated (CI paths-filter, replay-as-staleness-tripwire *mechanism*, tarball parity *mechanism*, PATH-masking) unless a leftover contradicted the applied fix
- **Authority:** findings applied directly to plan files; product code untouched

## Applied findings

### 1. Seam-only replay + probe SKIP = keyless CI false-green — Critical
- **File:** `phase-07-a3-keyless-eval-replay-mode.md`, `plan.md`, `phase-01-start.md`
- **What was wrong:** Phase 7 required replay to live only inside `_eval_engine_run()` (call sites untouched) *and* to dispatch before `_eval_probe`. Probe is in `cmd_eval` at `flow.sh:4203-4211` and SKIP-returns 0 when `claude` is absent. Planned CI asserts `! command -v claude`, then treats exit 0 as green. Nonce is minted at `cmd_eval:4214`; a fresh nonce makes recorded `GATE-EVAL-<old>:` lines parse as INVALID (`flow.sh:3234-3241`).
- **What changed:** Required `cmd_eval` replay prelude before `_eval_probe`: skip probe, pin recorded nonce, skip `claude --version`, fail-closed on missing fixtures. Live `_eval_engine_run` body + `_run_with_timeout` stay byte-identical. STOP only if those must change. CI must assert a replay-ran sentinel and fail on `SKIP:`.

### 2. Phase 8 recorded batch as B1-S measurement — Critical
- **File:** `phase-08-b1-s-ground-truth-evidence-addendum.md`, `plan.md`
- **What was wrong:** Success criteria allowed "Fresh-judge live batch **(or recorded batch)**". ADR / Phase 1: replay verdicts never count toward the eval floor. Phase 7 already admits replay cannot test rules effectiveness.
- **What changed:** Measurement is a live `--n 3` batch only. Replay re-record is a follow-on hard-merge constraint (same commit as the `gate-rules.md` edit) so Phase 7 CI does not stale-fail.

### 3. Wrong engine call-site census / read window — High
- **File:** `phase-07-a3-keyless-eval-replay-mode.md`, `plan.md`
- **What was wrong:** Plan listed call sites `3802/3817/4087` and told implementers to read `3560-4100`. That region is routing/converge. Artifact/wave-1 engine calls are `4315/4345` inside `cmd_eval` (`:4147`). Converge retry `4092` was omitted.
- **What changed:** Full 6-row census; mandatory read window is `cmd_eval` 4147+ plus helpers 3173-3340.

### 4. Manifest rewrite breaks eight registry consumers — High
- **File:** `phase-02-a1-all-checks-ci-manifest-runner.md`
- **What was wrong:** `scripts/check-release-coherence.sh:34` and `tests/test_release_coherence.sh:28` parse `for suite in `; six suites grep `run_all.sh` for their own name. After `while read`, coherence no-ops then prints OK; self-guards go red.
- **What changed:** All eight listed as required Phase 2 edits; point them at `tests/manifest.txt`; empty extract = fail.

### 5. E2E defaults to the repo runner — High
- **File:** `phase-03-a2-pack-install-rehearsal-parity.md`
- **What was wrong:** `tests/e2e-installed-drive.sh:5` takes `$1` = runner path and defaults to `skills/flow/runner/flow.sh`. Plan said "env knobs" / "against that home". Zero-arg invoke drives the checkout and false-greens a broken tarball. Working contract is `azure-pipelines.yml:71-73`.
- **What changed:** Mandate `bash tests/e2e-installed-drive.sh "$INSTALLED/runner/flow.sh"` after `test -f`; assert RUN is not the checkout path; use `--project --dir` or `HOME=` so install cannot write the runner's real skill home.

### 6. Leftover `sync → parity diff → npm pack` pipeline — High
- **File:** `phase-03-a2-pack-install-rehearsal-parity.md`
- **What was wrong:** After the advisory tarball-parity rewrite, Architecture still specified pre-pack sync+diff. `npm-wrapper/.gitignore` ignores `skills/`; `prepack` already runs `sync.mjs`.
- **What changed:** Architecture pipeline now matches Implementation: pack → extract → `shouldShip` compare → install → e2e `$1`.

### 7. `publish-if-changed.sh` gold plate — High
- **File:** `phase-03-a2-pack-install-rehearsal-parity.md`
- **What was wrong:** Research A2 marks idempotent publish as optional follow-on. Phase 3 kept it "if trivial" and would edit the OIDC trusted-publish workflow.
- **What changed:** Cut from wave 1; file as a post-wave card.

### 8. Leftover "rules-regression" wording — High
- **File:** `phase-07-a3-keyless-eval-replay-mode.md`
- **What was wrong:** Overview correctly said replay cannot test rules effectiveness; Architecture still said "parse/vote/scorecard + rules-regression".
- **What changed:** Replaced with gate-rules **hash staleness**; forbidden to write "rules-regression" into `gate-eval.md`.

### 9. Phase 6 phantom uname stub + test H detonation — High
- **File:** `phase-06-macos-debt-bounded-card.md`
- **What was wrong:** Plan cited "existing uname stub" patterns in `test_flow_eval.sh` (zero `uname` hits). Guard "near the existing platform probe" — `_eval_probe` is a billable `claude` call. Test H (`:161-189`) already runs live eval on a timeout-less PATH and expects PASS; on `macos-latest` that is the new refusal path.
- **What changed:** Guard before `_eval_probe`; `FLOW_EVAL_FORCE_DARWIN=1` or one `uname -s`; required edits to tests H/E; no suite-wide unbounded opt-in.

### 10. `:3528` is not a staleness gate — High
- **File:** `phase-07-a3-keyless-eval-replay-mode.md`
- **What was wrong:** Cited "batch metadata comparison :3528" as the hard-fail. That line is an advisory echo in `_eval_print_drift` (`:3506-3508`: never an exit-code signal), only reached from `--report`.
- **What changed:** New hard-fail against `_eval_gate_rules_sha` (`:3287`) in the replay prelude.

### 11. Raw JSON record re-opens eval-raw leak class — High
- **File:** `phase-07-a3-keyless-eval-replay-mode.md`
- **What was wrong:** `--record` would commit raw `claude --output-format json` under `skills/flow/eval/replay/`. `flow.sh:4221-4226` exists because those envelopes carry session ids / cwd / plugin paths.
- **What changed:** Record stripped verdict + nonce + rules hash + model only; CI grep fails the tree if fixtures contain `session_id`/`cwd`. `--replay` must not append `EVAL_RESULTS_FILE` as a live batch.

### 12. Shared-seam mode leaks into routing/converge — High
- **File:** `phase-07-a3-keyless-eval-replay-mode.md`
- **What was wrong:** A mode branch inside `_eval_engine_run` applies to all three modalities. Argparse finishes before `:4173-4179` dispatch. `--record --stage routing` would capture live traffic (identity-forbidden) or stale-fail artifact replay against the wrong rulebook.
- **What changed:** `--record|--replay` + `--stage routing|converge` usage-exits 1.

### 13. Phase 5 working-tree hashes vs markdown `.gitattributes` — Medium
- **File:** `phase-05-a5-en-vi-blob-hash-manifest.md`
- **What was wrong:** `.gitattributes:8` leaves `*.md` to the platform default. `git hash-object --path` on a Windows working tree is not `HEAD:path` blob identity. The new suite rides the 3-OS `bash-suite` matrix.
- **What changed:** Hash the committed blob (`git rev-parse HEAD:<path>`) or add `*.md text eol=lf`.

### 14. Fabricated "CI grep for ALL SUITES PASSED" — Medium
- **File:** `phase-02-a1-all-checks-ci-manifest-runner.md`
- **What was wrong:** `ci.yml:64-65` runs `bash tests/run_all.sh` and uses `exit $rc`. Nothing greps the string.
- **What changed:** Contract = exit code; echo is human-facing; registry lives in `manifest.txt`.

## Rejected findings

| # | Finding | Why rejected |
|---|---------|--------------|
| 15 | Reorder wave to DEBT → ADR → A3 | Relitigates settled Final resolutions #2; wave already has Phase 6 before 7. Tightened ADR wording instead. |
| 16 | Offline `npm i` (no `@clack/prompts` fetch) | "Credentialless" already means no `NPM_TOKEN`; Phase 3 already names registry hits. Full offline is YAGNI. |
| 17 | Relitigate paths-filter / tarball / PATH-mask / staleness *mechanism* | Prior advisory fixes; leftovers (pipeline text, `:3528` citation, "rules-regression") were accepted as *new* wording bugs, not mechanism reversals. |
| 18 | Flip identity slope-guard over Final resolutions | Final resolutions win. Confinement was clarified (prelude allowed; live engine body not). |

## Files modified

- `plans/260814-0948-flow-upgrade-wave1/plan.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-01-start.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-02-a1-all-checks-ci-manifest-runner.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-03-a2-pack-install-rehearsal-parity.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-05-a5-en-vi-blob-hash-manifest.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-06-macos-debt-bounded-card.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-07-a3-keyless-eval-replay-mode.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-08-b1-s-ground-truth-evidence-addendum.md`
- `plans/reports/redteam-260814-r1-wave1.md` (this file)

Phase 4 was reread; no R1 edit.

VERDICT: FINDINGS_APPLIED n=14
