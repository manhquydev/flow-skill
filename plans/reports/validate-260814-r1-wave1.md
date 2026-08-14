# Validate R1 — flow upgrade wave1

- **Date:** 2026-08-14
- **Target:** `plans/260814-0948-flow-upgrade-wave1/` (`plan.md` + 8 phases)
- **Workflow:** `ak-plan/references/validate-workflow.md` (Steps 1–7). Operator interview forbidden; every critical question answered from the evidence base.
- **Prior gate:** red-team R1 applied 14 findings (`plans/reports/redteam-260814-r1-wave1.md`). `## Red Team Review` already present — verification limited to leftover contradictions (no `[UNVERIFIED]` tags).
- **Authority:** clarifications applied directly to plan files; product code untouched.

## Evidence used

- Settled decisions: `plans/reports/brainstorm-260814-0933-flow-identity-decision.md`
- Research: `plans/reports/research-260814-0915-*.md` (baseline, directions, tech-stack, docs-bench)
- Code: `skills/flow/runner/flow.sh`, `skills/flow/eval/manifest.tsv`, `tests/run_all.sh`, `tests/test_flow_eval.sh`, `tests/e2e-installed-drive.sh`, `scripts/check-release-coherence.sh`, `scripts/release-preflight.sh`, `.github/workflows/ci.yml`, `.gitattributes`, `npm-wrapper/scripts/sync.mjs`, `npm-wrapper/src/help.mjs`, `npm-wrapper/package.json`, `DEBT.md`, `docs/system-architecture.md`, `skills/flow/references/gate-rules.md`, `install.sh`

## Verification (Full tier, 8 phases)

- Claims checked: 48
- Verified: 40 | Failed: 8 | Unverified: 0
- Failures are the 8 items under Applied findings below (fact/flow/contract). All applied.

## Applied findings (self-answered; written into the plan)

### 1. Stale "~21 calls" re-baseline census
- **Files:** `plan.md`, `phase-01-start.md`, `phase-07-a3-keyless-eval-replay-mode.md`, `phase-08-b1-s-ground-truth-evidence-addendum.md`
- **Evidence:** `skills/flow/eval/manifest.tsv` has 9 artifact rows. 9 × `--n 3` = 27 judge calls + 1 probe. Brainstorm "~21" is a leftover 7×3 figure.
- **What changed:** Pin 27+probe today; Phase 8 re-record is 11 × 3 = 33.

### 2. Phase 6 false `gtimeout`-on-PATH + Test E/H mislabel
- **Files:** `phase-06-macos-debt-bounded-card.md`
- **Evidence:** `flow.sh:2928-2929`, `test_flow_eval.sh:127-128` and header `:2-3` (mock-engine only), `test_flow_status_legibility.sh:15-16`, `DEBT.md`. Test H (`:161-195`) strips timeout; Test E (`:113-132`) does not.
- **What changed:** Do not assume macos-latest ships `gtimeout`. Still mask PATH for diagnosis. Guard is `cmd_eval` non-replay (includes mock suite). Update H always; update E when the darwin cell has no timeout.

### 3. `shouldShip` is not callable from bash
- **Files:** `phase-03-a2-pack-install-rehearsal-parity.md`, `phase-07-a3-keyless-eval-replay-mode.md`, `plan.md`
- **Evidence:** copy `filter` is `sync.mjs:57-63`; `shouldShip` is `:68-74`; neither is exported.
- **What changed:** Phase 3 adds `sync.mjs --compare` (or extracted shared predicate). Phase 7 extends that one JS function. No bash exclusion fork.

### 4. Pack-rehearsal installer contract underspecified
- **Files:** `phase-03-a2-pack-install-rehearsal-parity.md`
- **Evidence:** `npm-wrapper/src/help.mjs` (`--yes --project --dir`); package name `@manhquy/flow-skill` → `manhquy-flow-skill-*.tgz`; repo `install.sh` copies the checkout.
- **What changed:** Pack from `npm-wrapper/`. Required installer: `--yes --project --dir "$DEST"`. `HOME=` and `install.sh` are not the rehearsal path.

### 5. Phase 6 guard and Phase 7 prelude share one insertion window
- **Files:** `phase-06-macos-debt-bounded-card.md`, `phase-07-a3-keyless-eval-replay-mode.md`
- **Evidence:** `--report` returns at `cmd_eval:4185-4195`; `_eval_probe` is `:4203`.
- **What changed:** Compose order is `--report` return → replay prelude → Phase 6 guard (skip if replay flag) → probe. Guard at `cmd_eval` entry would refuse `--report` on darwin.

### 6. `--record|--replay` argparse footgun + `--report` combo
- **Files:** `phase-07-a3-keyless-eval-replay-mode.md`
- **Evidence:** argparse `:4148-4160` uses a trailing `shift`; `--report` is flag-only then returns at `:4185`.
- **What changed:** Flag-only (no inner `shift`). `--record|--replay --report` usage-exits 1. Update usage string at `:4157`.

### 7. Phase 1 "ALL seven bullets" vs nine listed sections
- **Files:** `phase-01-start.md`
- **What changed:** Success criteria names every Step-1 section. The numeric "seven" is not the contract.

### 8. Phase 5 success criteria vs `HEAD:path`
- **Files:** `phase-05-a5-en-vi-blob-hash-manifest.md`
- **Evidence:** `.gitattributes:8` leaves `*.md` to the platform default. Uncommitted edits do not change `HEAD:<path>`.
- **What changed:** Hash `git rev-parse HEAD:<path>` only. No `*.md eol=lf` in wave 1. Tests must commit the EN edit. Dirty-tree edits are not the gate. Initial record = today's committed blobs (drift detector, not a translation audit).

### 9. Flag / env names still "at impl"
- **Files:** `plan.md`, `phase-06-macos-debt-bounded-card.md`
- **What changed:** Pin `--record|--replay` and `FLOW_EVAL_UNBOUNDED=1`.

### 10. Phase 8 fixture ids and mechanical class unset
- **Files:** `phase-08-b1-s-ground-truth-evidence-addendum.md`
- **Evidence:** existing card fixtures `fcda`/`fcdb`/`fcdc`; test A loop is `fcda fcdc`; fcdb fails mechanical `check`.
- **What changed:** `fcdd` (sound, PASS) + `fcde` (hollow, FLAG), both `fcdc`-class mechanical pass; add to test A. No artifact row-count pin exists.

### 11. CI trigger is master-only
- **Files:** `plan.md`, `phase-02-a1-all-checks-ci-manifest-runner.md`, `phase-06-macos-debt-bounded-card.md`
- **Evidence:** `ci.yml` `on.push.branches` / `on.pull_request.branches` = `[master]`.
- **What changed:** Forced-skip / first-green / pack / replay / macOS diagnosis experiments run on a PR whose base is `master`. Do not add this research branch to the trigger list.

### 12. Root `CLAUDE.md` vs `skills/flow/law/CLAUDE.md` + unmeasured budgets
- **Files:** `phase-04-a4-root-agentsmd-word-budgets.md`
- **Evidence:** no root `AGENTS.md`/`CLAUDE.md`; `skills/flow/law/CLAUDE.md` is build law. `wc -w` 2026-08-14: README 3519, SKILL.md 3590, gate-rules 2621, attestations 1428.
- **What changed:** Do not touch the law file. Pin budgets at measured + 10% (3880 / 3950 / 2890 / 1580) plus AGENTS.md 1200.

### 13. Phase 2 `needs` snippet looks final
- **Files:** `phase-02-a1-all-checks-ci-manifest-runner.md`
- **What changed:** Snippet is the Phase 2 initial set. Phase 3 appends `pack-rehearsal`; Phase 7 appends the replay job.

## Operator questions

None. Recorded operator *actions* already in the plan (not questions): flip branch protection to `all-checks-passed` after first green; billable Phase 7 `--record` (27+probe); billable Phase 8 live `--n 3` on `fcdd`/`fcde` plus full re-record (33+probe).

## Whole-plan consistency sweep

- Files reread: all 9 plan files after edits.
- Decision deltas checked: 13.
- Reconciled stale references: 8.
- Unresolved contradictions: 0.
- Leftover "~21" / "seven bullets" / "HOME=" / "rules-regression" strings are now explicit stale/forbidden notes, not live instructions.

## CLI

`ak plan validate plans/260814-0948-flow-upgrade-wave1` run after edits (structural CK convention check).

## Recommendation

Plan is eligible to proceed to cook after the operator reviews this report. Verification Failed count is 0 remaining (8 failures applied). Do not cook until the operator accepts the applied pins — especially the 27-call billable `--record` and the master-base PR requirement for CI experiments.

VERDICT: FINDINGS_APPLIED n=13
