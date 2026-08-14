# Red team R2 — flow upgrade wave1

- **Date:** 2026-08-14
- **Target:** `plans/260814-0948-flow-upgrade-wave1/` (`plan.md` + 8 phases)
- **Lenses:** Security Adversary, Failure Mode Analyst, Assumption Destroyer, Scope & Complexity Critic
- **Prior rounds:** R1 applied 14 (`plans/reports/redteam-260814-r1-wave1.md`); validate applied 13 (`plans/reports/validate-260814-r1-wave1.md`). Those *mechanisms* were not relitigated. This pass hunted leftovers from composing the 27 edits, plus anything both rounds missed.
- **Authority:** findings applied directly to plan files; product code untouched

## Applied findings

### 1. `$INSTALLED` undefined; mixed cwds; tarball `package/` prefix omitted — High
- **File:** `phase-03-a2-pack-install-rehearsal-parity.md`, `plan.md`
- **Evidence:** Validate pinned installer `--yes --project --dir "$DEST"` (`help.mjs:21` / `cli.mjs:128` writes `$DEST/.claude/skills/flow`). R1 still said `$INSTALLED/runner/flow.sh`. `e2e-installed-drive.sh:5` takes `$1` and defaults to the repo tree. `npm pack` nests under `package/`. `sync.mjs` and `pack-rehearsal.sh` do not share a cwd.
- **What was wrong:** After Validate, Phase 3 named `$DEST` but never defined `RUN`. Architecture still compared tarball-root `skills/flow/` in two places. Zero-arg e2e still false-greens the checkout.
- **What changed:** Pin `RUN="$DEST/.claude/skills/flow/runner/flow.sh"`; ROOT-anchor pack/extract/e2e; `--compare` walks extracted `package/skills/flow`. plan.md rehearsal SC uses the same path. Zero-arg e2e is a job bug.

### 2. `sync.mjs --compare` cannot sit below the unconditional copy — High
- **File:** `phase-03-a2-pack-install-rehearsal-parity.md`
- **Evidence:** `sync.mjs:43-64` runs `rmSync`+`cpSync` at load with no argv gate. `shouldShip` (`:68-74`) is not exported.
- **What was wrong:** Validate required `--compare` / shared predicate, then offered "a 20-line sibling that imports `shouldShip`". A flag added below today's body still copies first. A sibling cannot import a non-export.
- **What changed:** Early `process.argv` branch (or extract the predicate into a side-effect-free module) **before** any copy. Sibling-import option dropped. Architecture no longer contradicts that drop.

### 3. plan.md sync-parity SC still required committed-tree byte-for-byte — High
- **File:** `plan.md`
- **Evidence:** `npm-wrapper/.gitignore` ignores `skills/`. Phase 3 parity is `shouldShip`-filtered `--compare` of extracted `package/skills/flow` vs repo `skills/flow`.
- **What was wrong:** Wave success still said `sync.mjs` output matches the committed tree byte-for-byte. That is a `git diff` of a gitignored tree (R1 already killed this in Phase 3).
- **What changed:** plan.md SC now matches Phase 3: filtered `--compare`, not an unfiltered tree diff, not `npm-wrapper/skills/` vs git.

### 4. Prelude ending at `:4203` cannot pin nonce `:4214`; reject window must precede `:4173`; no engine mode-arg — High
- **File:** `phase-07-a3-keyless-eval-replay-mode.md`, `phase-06-macos-debt-bounded-card.md`, `plan.md`
- **Evidence:** `cmd_eval` argparse ends `:4160`; routing/converge dispatch `:4173-4179`; `--report` return `:4185-4196`; `_eval_probe` `:4203-4211`; nonce `:4214`; `_eval_cli_version` `:4218` → `claude --version` `:3301`; artifact engine calls `:4315/:4345`. Routing/converge share `_eval_engine_run` (`:3802/:3817/:4087/:4092`).
- **What was wrong:** Validate composed `--report` → prelude → guard → probe, and pinned the prelude as ending at `:4203`. A prelude that stops there never assigns the recorded nonce or skips `_eval_cli_version`. Reject-after-`:4185` is too late (`--replay --stage routing` has already entered `cmd_eval_routing`). "Mode argument passed into the engine" would parameterize the live body (A3 confinement) and leak into routing/converge.
- **What changed:** Two windows: reject after `:4160` before `:4173`; live-entry after `--report` return = Phase 6 guard (skip if replay) then wrap `:4203-4218`. Feed replay text only at `:4315/:4345`. Live `_eval_engine_run` body stays byte-identical and unparameterized. Validation Log Q5 / Confirmed Decisions superseded.

### 5. Test H "expect refusal **or** UNBOUNDED" can delete the watchdog — High
- **File:** `phase-06-macos-debt-bounded-card.md`
- **Evidence:** `test_flow_eval.sh:161-192` strips timeout, expects exit 0 / PASS / fast (`elapsed < 25`). That is the `_run_with_timeout` regression.
- **What was wrong:** An "or" let the implementer rewrite H to expect refusal and drop the fast-return assertion. The watchdog would then have no test.
- **What changed:** H keeps PASS via `FLOW_EVAL_UNBOUNDED=1` **only in H** (and E on darwin when timeout is absent). Add a **new** refusal case. Do not rewrite H. No suite-wide unbounded opt-in.

### 6. Phase 5 Requirements still named `git hash-object` — Medium
- **File:** `phase-05-a5-en-vi-blob-hash-manifest.md`, `plan.md`
- **Evidence:** `.gitattributes:8` leaves `*.md` to the platform default. Validate pinned `git rev-parse HEAD:<path>` only. Architecture already forbade `git hash-object --path`.
- **What was wrong:** Requirements Non-functional still said "zero deps (`git hash-object`)". An implementer reading Requirements first would hash the dirty tree.
- **What changed:** Requirements name `git rev-parse HEAD:<path>`. `hash-object` is the forbidden dirty-tree hasher. plan.md EN/VI SC is the committed-edit gate.

### 7. plan.md still required a forced-skip *test cell* — Medium
- **File:** `plan.md`
- **Evidence:** Phase 2 step 6: `if: false` on the whole `no-python-degradation` job. A matrix-cell skip/removal is invisible to `needs.*.result`.
- **What was wrong:** Wave SC still said "forced-skip test cell". That experiment cannot fail `all-checks-passed`.
- **What changed:** plan.md SC matches Phase 2: whole-job skip; cell skip is not the experiment.

### 8. Phase 3/7 CI experiments omitted the master-base PR pin — Medium
- **File:** `phase-03-a2-pack-install-rehearsal-parity.md`, `phase-07-a3-keyless-eval-replay-mode.md`
- **Evidence:** `ci.yml` `on.*.branches: [master]` only. Validate pinned this on plan.md / Phase 2 / Phase 6. This branch's pushes do not run GHA.
- **What was wrong:** Pack-rehearsal and replay `needs` experiments had no PR-base pin. Implementers would "verify on this branch" and see nothing.
- **What changed:** Phase 3 step 5 + SC, Phase 7 CI + SC: demonstrate on a PR whose base is `master`.

### 9. Phase 7 README edits unwired from Phase 5 `record`; help catalog `:4508` omitted — Medium
- **File:** `phase-07-a3-keyless-eval-replay-mode.md`, `plan.md`
- **Evidence:** Phase 5 `record` writes `HEAD:<path>` after a consistency commit. Help catalog `flow.sh:4508-4513` still says "skips cleanly if claude absent" and flags stop at `--report`. Argparse usage is a second surface (`:4157`).
- **What was wrong:** Phase 7 depended on `[2, 6]` only. README `--record|--replay` rows would fail i18n verify. Help catalog would keep advertising SKIP-if-absent after replay lands.
- **What changed:** Dependencies `[2, 5, 6]`. Update both usage surfaces. Stay under Phase 4 budgets or bump `docs/doc-budgets.txt`. plan.md order notes the Phase 5 dep.

### 10. plan.md required a `CLAUDE.md` symlink; Phase 4 allows a stub — Medium
- **File:** `plan.md`, `phase-04-a4-root-agentsmd-word-budgets.md`
- **Evidence:** Phase 4 Architecture: Windows/Git-Bash may fall back to a 3-line stub. Validate: do not touch `skills/flow/law/CLAUDE.md`.
- **What was wrong:** Wave SC and Goal 4 required the symlink to resolve. Phase 4 Requirements said "symlinked to it". A Windows stub would fail the wave box.
- **What changed:** plan.md SC / Goal 4: linux/macOS resolve; Windows stub allowed. Phase 4 Requirements match Architecture.

### 11. `--record` is live-mode and hits the Phase 6 guard — Medium
- **File:** `phase-07-a3-keyless-eval-replay-mode.md`, `phase-08-b1-s-ground-truth-evidence-addendum.md`
- **Evidence:** Phase 6 guard is `cmd_eval` after `--report` return with replay flag unset — including mock-engine cases. `--record` wraps a live artifact batch.
- **What was wrong:** Record on darwin-without-timeout (or a PATH-masked host) would refuse. Phase 8's billable `--record` (33+probe) did not name the guard.
- **What changed:** `--record` does not skip the guard. Record on a host with real `timeout`/`gtimeout`, or `FLOW_EVAL_UNBOUNDED=1` for that operator run only. Phase 8 step 4 repeats the pin.

### 12. Phase 4 never updates the "58" count homes; Phase 7/8 can breach pinned budgets — Medium
- **File:** `phase-04-a4-root-agentsmd-word-budgets.md`, `phase-07-a3-keyless-eval-replay-mode.md`, `phase-08-b1-s-ground-truth-evidence-addendum.md`, `phase-02-a1-all-checks-ci-manifest-runner.md`
- **Evidence:** Hardcoded 58 at `README.md:6,19,417,434`, `README_VN.md:6,19`, `docs/system-architecture.md:93`, `docs/codebase-summary.md:70`. Phase 2 adds `test_manifest_runner.sh`; Phase 4/5 add more suites. Phase 4 budgets: README 3880, SKILL.md 3950, gate-rules 2890. Phase 7 edits README + SKILL.md; Phase 8 adds a `gate-rules.md` line.
- **What was wrong:** Phase 4 exists to stop DF-1 count drift, then left the homes stale. Phase 2 SC froze "59 suites" as if wave-end. Phase 7/8 could breach the budgets they depend on.
- **What changed:** Phase 4 step 5 + SC update the homes (or point at `tests/manifest.txt`). Phase 2/plan.md: manifest count == disk `test_*.sh`; do not freeze 58/59. Phase 7/8 stay under pins or bump `docs/doc-budgets.txt` in the same commit.

## Rejected / notes (not applied as findings)

| # | Item | Why not a finding |
|---|------|-------------------|
| N1 | Reorder DEBT before ADR / flip Final resolutions | Relitigates identity; already rejected in R1 |
| N2 | Require offline `npm i` (no `@clack/prompts` fetch) | Already rejected in R1; credentialless ≠ offline |
| N3 | Relitigate paths-filter / tarball / PATH-mask / staleness / 27+probe / master-base *mechanisms* | R1 + Validate pins; leftovers above are compose bugs, not reversals |
| N4 | Add `gate-eval.md` to Phase 4 budgets | YAGNI unless a later phase needs it |
| N5 | Phase 1 ADR-level "cmd_eval prelude" wording | Constitution-level; Phase 7 now owns the wrap. No impl fork |
| N6 | Validation Log Q5 historical answer | Left in place; R2 supersession note + Confirmed Decisions updated |

## Files modified

- `plans/260814-0948-flow-upgrade-wave1/plan.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-02-a1-all-checks-ci-manifest-runner.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-03-a2-pack-install-rehearsal-parity.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-04-a4-root-agentsmd-word-budgets.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-05-a5-en-vi-blob-hash-manifest.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-06-macos-debt-bounded-card.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-07-a3-keyless-eval-replay-mode.md`
- `plans/260814-0948-flow-upgrade-wave1/phase-08-b1-s-ground-truth-evidence-addendum.md`
- `plans/reports/redteam-260814-r2-wave1.md` (this file)

Phase 1 was reread; no R2 edit (ADR-level prelude wording is a note).

## Whole-plan consistency sweep

- Files reread: all 9 plan files after R2 edits
- Decision deltas checked: 12
- Reconciled stale references: 12 (plan.md SCs; Phase 7 deps; `$INSTALLED`; hash-object Requirements; Test H OR; engine mode-arg; prelude-at-4203; 59-as-wave-end; Phase 3 sibling/`package/` leftovers; Goal 4 / Phase 4 Requirements symlink-only; Validation Log compose order; Phase 7 SKILL.md budget + Phase 8 `--record` live-mode)
- Unresolved contradictions: 0

## CLI

`ak plan validate plans/260814-0948-flow-upgrade-wave1` run after edits (structural CK convention check).

VERDICT: FINDINGS_APPLIED n=12
