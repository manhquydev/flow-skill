---
title: "flow upgrade wave1"
description: "Harden flow-skill per settled identity: discipline layer, flow never holds the process token. Identity ADR + A1/A2/A4/A5 disciplines + bounded macOS DEBT + A3 keyless eval replay + B1-S evidence addendum."
status: pending
priority: P1
effort: "6-9d"
tags: [identity-adr, ci-hardening, eval-replay, evidence, docs-discipline]
created: 2026-08-14
blocks: [260726-1718-harness-graph-executor-langgraph-port]
---

# flow upgrade wave1

## Overview

Execute the settled identity decision (see `plans/reports/brainstorm-260814-0933-flow-identity-decision.md`,
built on the 7 research reports `plans/reports/research-260814-0915-*`): flow is a **host-agnostic
discipline layer** — it owns gates and receipts, never the runtime. Wave 1 writes that identity into a
testable ADR, then adopts the deepseek-harness *disciplines* ranked Tier A plus the S-cut of B1.
Branch: `research/deepseek-harness-upgrade` (worktree). Main checkout is on `feat/flow-website` —
never touch it.

**Process-token invariant (governs every phase):** every flow byte executes because a hosting agent or
the operator invoked it, and flow terminates when that invocation returns. No daemons, no resident
processes, no tool-execution wrappers/interposition, no servers.

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Identity ADR merged: invariant, 5 tripwires, eval floor + autopsy + CI-separation, judge-rebaseline rule, fixture-pair rule, monetization cap — one document | P1 |
| 2 | CI verdict hardened: single required `all-checks-passed` job; manifest-driven test runner | P1 |
| 3 | Artifact trust: credentialless pack→install→e2e rehearsal + `shouldShip`-filtered tarball parity on every PR | P1 |
| 4 | Docs discipline: root AGENTS.md (CLAUDE.md symlink or Windows stub), word budgets, EN/VI blob-hash pairing | P2 |
| 5 | Eval: keyless replay via `cmd_eval` prelude + unchanged live `_eval_engine_run` body; macOS live-eval refuses without real timeout binary | P1 |
| 6 | Evidence: ground-truth addendum "every done-evidence item names its artifact/command" + measured fixture pair | P2 |

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Phase 1: Identity ADR](./phase-01-start.md) | Pending |
| 2 | [Phase 2: A1 all-checks CI + manifest runner](./phase-02-a1-all-checks-ci-manifest-runner.md) | Pending |
| 3 | [Phase 3: A2 pack install rehearsal + parity](./phase-03-a2-pack-install-rehearsal-parity.md) | Pending |
| 4 | [Phase 4: A4 root AGENTS.md + word budgets](./phase-04-a4-root-agentsmd-word-budgets.md) | Pending |
| 5 | [Phase 5: A5 EN VI blob-hash manifest](./phase-05-a5-en-vi-blob-hash-manifest.md) | Pending |
| 6 | [Phase 6: macOS DEBT bounded card](./phase-06-macos-debt-bounded-card.md) | Pending |
| 7 | [Phase 7: A3 keyless eval replay mode](./phase-07-a3-keyless-eval-replay-mode.md) | Pending |
| 8 | [Phase 8: B1-S ground-truth evidence addendum](./phase-08-b1-s-ground-truth-evidence-addendum.md) | Pending |

Order is load-bearing: ADR first (constitution for the wave); A1 second (everything downstream rides
the manifest runner + required check); DEBT card (6) before A3 (7) — preserves the guard's spirit; B1-S
last (depends on the wave's own dogfood exercising the card gate). Phase 7 also depends on Phase 5
(README `--record|--replay` rows must `record` i18n hashes). Phases 3-5 are semantically
independent after Phase 2, but share files (`tests/manifest.txt`, `scripts/release-preflight.sh`
in 4+5; `npm-wrapper/RELEASE_CHECKLIST.md` in 3+5) — merge order **3 → 4 → 5**, conflicts expected
and trivial.

## Constraints (all phases)

- bash-3.2-safe (macOS stock); zero new runtime dependencies; degrade-friendly (missing pieces warn
  loudly, never lower a gate).
- Backward-compatible evidence scoring — old prose-only evidence still passes `check`.
- No mechanical-gate verdict changes outside Phase 8's documented addendum surface.
- All product edits under `skills/flow/`, `npm-wrapper/`, `.github/`, `docs/`, `tests/`, `scripts/`,
  root docs. Nothing in `website/` (other branch owns it).

## Non-goals

MCP client bridge (C4/B2 — deferred, reopen = tripwire-4-class card); event-sourced core (C2);
coverage floors (Q6); website CI (feat/flow-website lifecycle); any other C-tier item from
`research-260814-0915-flow-upgrade-directions.md`; graph-executor default-on reconsideration
(blocked plan `260726-1718` must satisfy the ADR first).

## Success Criteria

- [ ] ADR file merged containing: invariant, 5 tripwires, proportional eval floor ("at most one
      fixture mismatch per batch") + fixture-autopsy clause + strict-CI-exit separation,
      judge-model re-baseline rule, fixture-pair-per-new-gate-rule, monetization cap.
- [ ] 3-OS CI green with `all-checks-passed` as the single required job; a forced **whole-job**
      skip (`if: false` on `no-python-degradation`) makes it fail (verified once, then reverted).
      A matrix-cell skip/removal is invisible to `needs.*.result` — that is not the experiment.
- [ ] PR rehearsal (PR base = `master`): pack → install →
      `tests/e2e-installed-drive.sh "$DEST/.claude/skills/flow/runner/flow.sh"` green,
      credentialless, ubuntu lane.
- [ ] Sync parity: tarball extract `package/skills/flow` vs repo `skills/flow` via
      `sync.mjs --compare` (`shouldShip`-filtered). Not an unfiltered tree diff; not
      `npm-wrapper/skills/` vs git (that tree is gitignored).
- [ ] `AGENTS.md` at repo root; `CLAUDE.md` resolves to the same content on linux/macOS CI;
      Windows stub fallback is allowed if the symlink probe fails (Phase 4). Budget verify
      wired into `scripts/release-preflight.sh` (advisory in-run, enforced in CI/preflight only).
- [ ] EN/VI pairs: a **committed** edit without `record` fails preflight (`git rev-parse
      HEAD:<path>`); dirty working-tree edits are not the gate.
- [ ] DEBT.md updated with confirmed-or-abandoned macOS mechanism; live eval on macOS without a real
      timeout binary exits with refusal + explicit opt-in flag documented.
- [ ] `flow.sh eval --replay` (flag name pinned) runs the artifact-modality batch keyless in CI;
      tampered responses and stale gate-rules (hash mismatch) fail loudly; zero live calls (assert no
      `claude` invocation **and** a replay-ran sentinel — SKIP is a job failure). Replay verdicts
      never count toward the eval floor (ADR rule).
- [ ] `references/ground-truth-gates.md` addendum merged + ≥1 hollow/sound fixture pair added to
      `skills/flow/eval/manifest.tsv`; **live** `--n 3` batch measures the new pair; replay fixtures
      refreshed in the same commit.
- [ ] Manifest count equals on-disk `tests/test_*.sh` (58 today; grows as phases add suites) +
      existing node:test files still pass on 3-OS. Do not freeze "59" or "58" as the wave-end number.

## Evidence base

- `plans/reports/research-260814-0915-flow-baseline.md` (current-state map)
- `plans/reports/research-260814-0915-deepseek-*.md` (6 reports — dsh patterns + file refs)
- `plans/reports/research-260814-0915-flow-upgrade-directions.md` (ranked synthesis)
- `plans/reports/brainstorm-260814-0933-flow-identity-decision.md` (settled decision + final resolutions)
- Confirmed code facts: `_eval_engine_run()` definition `skills/flow/runner/flow.sh:3191`;
  invocations: routing `:3802/:3817`, converge `:4087/:4092`, **artifact/wave-1 `:4315/:4345`**
  (`cmd_eval` starts `:4147`; `_eval_probe` SKIP-exit-0 at `:4203-4211`; nonce mint `:4214`).
  `_run_with_timeout` :2931. CI jobs `bash-suite`/`no-python-degradation`/`test` in
  `.github/workflows/ci.yml` (no aggregation job today). `tests/run_all.sh` hardcoded 58-suite
  loop; eight registry consumers grep that `for suite in` line / filenames in `run_all.sh`.
  npm-wrapper skill tree is SYNCED via `npm-wrapper/scripts/sync.mjs` (not hand-duplicated);
  copy `filter` is `:57-63`, `shouldShip` is `:68-74` (same predicate, **not exported** — Phase 3
  must add a `--compare` invocation, not reimplement in bash). `e2e-installed-drive.sh:5` defaults
  `$1` to the repo runner. Artifact eval manifest is **9 fixtures** (`skills/flow/eval/manifest.tsv`);
  a live `--n 3` batch is 27 judge calls + 1 probe (the brainstorm "~21 calls" figure is stale).
  CI `on.pull_request.branches` is `[master]` only — verification experiments run on a PR targeting
  master, not on a push to this research branch.

## Risks

| Risk | Phase | Mitigation |
|---|---|---|
| A3 touches the most intricate flow.sh area (eval nonce/verdict/scorecard) | 7 | Live `_eval_engine_run` body + `_run_with_timeout` untouched; required `cmd_eval` prelude skips probe and pins nonce so keyless CI cannot SKIP-green. STOP only if the live engine body or timeout helper must change |
| B1-S touches trust floor | 8 | Semantic-gate-enforced only; no mechanical `_evidence_*` scoring change; a **live** `--n 3` batch measures the new pair (replay is not the measurement) |
| Required-check rename can lock PRs if branch protection points at old names | 2 | Add job first, flip branch protection after first green run |
| macOS mechanism cannot be confirmed without hardware | 6 | Bounded card; exit artifact = DEBT.md update either way + refuse-by-default guard ships regardless |
| Windows CI slowness (45m budget) | 2,3 | Rehearsal ubuntu-only; manifest runner keeps per-suite timing output |

## Red Team Review

### Session — 2026-08-14 (R1, applied)
**Findings:** 18 collected / 14 accepted / 4 rejected
**Severity breakdown:** 2 Critical, 9 High, 3 Medium (accepted)

| # | Finding | Severity | Disposition | Applied To |
|---|---------|----------|-------------|------------|
| 1 | Seam-only replay + `_eval_probe` SKIP-exit-0 = keyless CI false-green; nonce lives in `cmd_eval` | Critical | Accept | Phase 7, plan.md, Phase 1 |
| 2 | Phase 8 "(or recorded batch)" treats replay as B1-S / floor evidence | Critical | Accept | Phase 8, plan.md |
| 3 | Engine call-site census inverted; read window 3560-4100 is routing/converge | High | Accept | Phase 7, plan.md |
| 4 | `for suite in` rewrite silently kills coherence + 6 self-guards | High | Accept | Phase 2 |
| 5 | `e2e-installed-drive.sh` defaults to repo runner; "env knobs" do not exist | High | Accept | Phase 3 |
| 6 | Phase 3 Architecture still said `sync → parity diff → npm pack` | High | Accept | Phase 3 |
| 7 | `publish-if-changed.sh` gold-plates research A2 optional follow-on | High | Accept | Phase 3 |
| 8 | Phase 7 Architecture leftover "rules-regression" undoes F2 rewrite | High | Accept | Phase 7 |
| 9 | Phase 6 phantom uname stub; test H detonates on darwin+no-timeout | High | Accept | Phase 6 |
| 10 | `:3528` is advisory drift, not a staleness hard-fail | High | Accept | Phase 7 |
| 11 | `--record` of raw `--output-format json` re-opens eval-raw leak class | High | Accept | Phase 7 |
| 12 | Shared-seam mode leaks into routing/converge | High | Accept | Phase 7 |
| 13 | Phase 5 working-tree hashes vs `.gitattributes` markdown default | Medium | Accept | Phase 5 |
| 14 | "CI grep for ALL SUITES PASSED" is a fabricated contract | Medium | Accept | Phase 2 |
| 15 | Reorder DEBT before ADR / delete "independently" as flip of final resolutions | High | Reject | — |
| 16 | Require offline `npm i` (no registry fetch of `@clack/prompts`) | High | Reject | — |
| 17 | Relitigate paths-filter / tarball parity / PATH-mask / staleness-tripwire *mechanism* | — | Reject | — |
| 18 | Relitigate identity slope-guard sequencing vs Final resolutions #2 | High | Reject | — |

### Whole-Plan Consistency Sweep
- Files reread: plan.md, phase-01-start.md, phase-02-a1-all-checks-ci-manifest-runner.md, phase-03-a2-pack-install-rehearsal-parity.md, phase-04-a4-root-agentsmd-word-budgets.md, phase-05-a5-en-vi-blob-hash-manifest.md, phase-06-macos-debt-bounded-card.md, phase-07-a3-keyless-eval-replay-mode.md, phase-08-b1-s-ground-truth-evidence-addendum.md
- Decision deltas checked: 8 (cmd_eval prelude; live-only B1-S; call-site census; manifest consumers; e2e `$1`; cut publish-if-changed; committed-blob i18n; guard-before-probe)
- Reconciled stale references: 6 (plan.md goal 5 + evidence base + A3 risk; Phase 3 L94 note; Phase 8 live-measurement risk; Phase 1 replay boundary)
- Unresolved contradictions: 0

### Session — 2026-08-14 (R2, applied)
**Findings:** 12 accepted (implementation impact) / cosmetic leftovers listed as notes in the R2 report
**Severity breakdown:** 0 Critical, 5 High, 7 Medium (accepted)

| # | Finding | Severity | Disposition | Applied To |
|---|---------|----------|-------------|------------|
| 1 | `$INSTALLED` undefined; mixed cwds; tarball `package/` prefix omitted | High | Accept | Phase 3, plan.md |
| 2 | `sync.mjs --compare` cannot sit below the unconditional copy | High | Accept | Phase 3 |
| 3 | plan.md sync-parity SC still required committed-tree byte-for-byte | High | Accept | plan.md |
| 4 | Prelude ending at `:4203` cannot pin nonce `:4214`; reject window must precede `:4173`; no engine mode-arg | High | Accept | Phase 7, Phase 6 |
| 5 | Test H "expect refusal **or** UNBOUNDED" can delete the watchdog | High | Accept | Phase 6 |
| 6 | Phase 5 Requirements still named `git hash-object` | Medium | Accept | Phase 5, plan.md |
| 7 | plan.md still required a forced-skip *test cell* | Medium | Accept | plan.md |
| 8 | Phase 3/7 CI experiments omitted the master-base PR pin | Medium | Accept | Phase 3, Phase 7 |
| 9 | Phase 7 README edits unwired from Phase 5 `record`; help catalog `:4508` omitted | Medium | Accept | Phase 7, plan.md |
| 10 | plan.md required a `CLAUDE.md` symlink; Phase 4 allows a stub | Medium | Accept | plan.md |
| 11 | `--record` is live-mode and hits the Phase 6 guard | Medium | Accept | Phase 7 |
| 12 | Phase 4 never updates the "58" count homes; Phase 7/8 can breach pinned budgets | Medium | Accept | Phase 4, Phase 7, Phase 8 |

### Whole-Plan Consistency Sweep (R2)
- Files reread: all 9 plan files after R2 edits
- Decision deltas checked: 12
- Reconciled stale references: 12 (plan.md SCs; Phase 7 deps; `$INSTALLED`; hash-object Requirements; Test H OR; engine mode-arg; prelude-at-4203; 59-as-wave-end; Phase 3 sibling/`package/` leftovers; Goal 4 / Phase 4 Requirements symlink-only; Validation Log compose order; Phase 7 SKILL.md budget + Phase 8 `--record` live-mode)
- Unresolved contradictions: 0

## Validation Log

### Session 1 — 2026-08-14
**Trigger:** Round-1 validate after red-team R1 (14 findings applied). Operator interview forbidden; every critical question answered from the evidence base (identity decision, research reports, codebase).
**Questions asked:** 13 (self-answered). Operator questions: 0.

#### Questions & Answers

1. **[Assumptions]** The ADR/plan says a full re-baseline is "~21 calls". What is the live artifact-batch cost today?
   - Options: Keep ~21 as folklore | Measure from `manifest.tsv` (Recommended) | Defer to impl
   - **Answer:** 9 artifact fixtures × `--n 3` = 27 judge calls + 1 probe. After Phase 8: 11 × 3 = 33.
   - **Rationale:** `skills/flow/eval/manifest.tsv` has 9 rows; brainstorm "~21" is a stale 7×3 figure.

2. **[Assumptions]** Does GitHub `macos-latest` ship `gtimeout` on PATH, so Test E is unaffected by the Phase 6 guard?
   - Options: Assume present (plan R1 text) | Treat as absent per suite/DEBT comments (Recommended) | Operator must probe
   - **Answer:** Do not assume present. `flow.sh:2928-2929`, `test_flow_eval.sh:127`, `test_flow_status_legibility.sh:15-16`, `DEBT.md` all treat macos-ci as the timeout-less lane. Still mask PATH on the diagnostic step.
   - **Rationale:** Suite comments were written against real 3-OS CI; claiming coreutils-on-PATH would skip required Test E edits.

3. **[Architecture]** How does bash `pack-rehearsal.sh` apply `shouldShip` when the function is not exported?
   - Options: Reimplement in bash | Duplicate find/diff | Add `sync.mjs --compare` / extract the predicate (Recommended)
   - **Answer:** Shared JS predicate. Phase 7's `eval/replay/` exclusion must ride the same function.
   - **Rationale:** `shouldShip` is local at `sync.mjs:68-74`; a bash fork false-fails parity after Phase 7.

4. **[Architecture]** What is the exact installer invocation after `npm i` of the local tarball?
   - Options: `HOME=` global | repo `install.sh` | `--yes --project --dir "$DEST"` (Recommended)
   - **Answer:** `<prefix>/node_modules/.bin/flow-skill --yes --project --dir "$DEST"`. Pack from `npm-wrapper/`.
   - **Rationale:** Documented in `help.mjs` / README. `install.sh` copies the checkout (false-green). `HOME=` may touch extra targets.

5. **[Architecture]** Phase 6 guard and Phase 7 prelude share `cmd_eval` space before `_eval_probe`. How do they compose?
   - Options: Phase 7 deletes the guard | Insert both after `--report` return; replay flag skips guard (Recommended)
   - **Answer:** Window is `:4185-4196` → prelude → Phase 6 guard → `:4203`. Replay flag default 0; Phase 7 sets it.
   - **Rationale:** `--report` already returns at 4185; putting the guard at `cmd_eval` entry would refuse `--report` on darwin.
   - **R2 supersession:** compose is `--report` return → Phase 6 guard (skip if replay) → wrap `:4203-4218`. The wrap is the prelude (nonce `:4214`, `_eval_cli_version` `:4218`). Do not insert a one-liner that ends at `:4203`.

6. **[Assumptions]** How should `--record|--replay` parse, and what happens with `--report`?
   - Options: Value-taking like `--stage` | Flag-only like `--report`; reject combo with `--report` (Recommended)
   - **Answer:** Flag-only (no inner `shift`). `--record|--replay --report` usage-exits 1.
   - **Rationale:** Trailing `shift` already consumes the flag; `--report` would otherwise return first and skip replay.

7. **[Scope]** Phase 1 success says "ALL seven bullets" but Step 1 lists nine sections. Which is the contract?
   - Options: Count seven | Name every Step-1 section (Recommended)
   - **Answer:** The named section list is the contract. Drop the numeric "seven".
   - **Rationale:** Brainstorm ADR completeness + plan Goal 1 list more than seven items.

8. **[Architecture]** Phase 5: `HEAD:path` vs index vs `*.md eol=lf`?
   - Options: Add `*.md text eol=lf` | Hash dirty tree | `git rev-parse HEAD:<path>` only (Recommended)
   - **Answer:** HEAD:path only. No `*.md eol=lf` in wave 1. Tests must **commit** the EN edit. Dirty-tree edits are not the gate.
   - **Rationale:** Red-team already chose committed blobs; `eol=lf` is extra scope. Uncommitted edits leave HEAD unchanged.

9. **[Assumptions]** Are `--replay` and `FLOW_EVAL_UNBOUNDED` still "name at impl"?
   - Options: Leave open | Pin `--record|--replay` and `FLOW_EVAL_UNBOUNDED=1` (Recommended)
   - **Answer:** Pinned. plan.md success criteria no longer says "name final at impl".
   - **Rationale:** Phase 7 already used those flag names; leaving them open invites docs drift.

10. **[Scope]** What ids/class for the Phase 8 fixture pair?
    - Options: Invent a new prefix | Clone fcdb (mechanical fail) | `fcdd`/`fcde`, fcdc-class mechanical pass (Recommended)
    - **Answer:** `fcdd` sound PASS, `fcde` hollow FLAG; both pass `flow.sh check`; add to test A loop.
    - **Rationale:** Next free `fcd*`. fcdb fails mechanical check and cannot prove a semantic-only catch.

11. **[Risks]** This worktree's pushes do not run GHA (`on.*.branches: [master]`). Where do verification experiments run?
    - Options: Add the research branch to triggers | Run experiments on a PR targeting master (Recommended)
    - **Answer:** PR base = master. Do not expand triggers.
    - **Rationale:** Existing contract; extra branch triggers are YAGNI minutes.

12. **[Scope]** Root `CLAUDE.md` vs `skills/flow/law/CLAUDE.md`?
    - Options: Symlink both | Rewrite law file | Root only; law file untouched (Recommended)
    - **Answer:** Root `CLAUDE.md` only. Law file stays.
    - **Rationale:** Different homes; one-home-per-fact.

13. **[Assumptions]** Must a human re-read EN/VI before recording initial i18n hashes?
    - Options: Block on a translation audit | Record current HEAD blobs as the initial state (Recommended)
    - **Answer:** Record today's committed blobs. A5 is a drift detector, not a translation rewrite.
    - **Rationale:** Pairs already ship; wave 1 stops undetected drift.

#### Confirmed Decisions
- Re-baseline cost: 9×3=27 (+probe); Phase 8 re-record 11×3=33 — measured, not ~21
- macos-ci: do not assume `gtimeout` on PATH; still mask PATH for diagnosis
- Pack parity: shared JS `shouldShip` via `--compare`; installer `--yes --project --dir`
- cmd_eval compose: `--report` return → Phase 6 guard (skip if replay) → wrap `:4203-4218`
  (R2: the wrap *is* the prelude and includes nonce `:4214` / `_eval_cli_version` `:4218`.
  Session 1 "prelude → guard → probe" is superseded — do not insert a one-liner that ends at `:4203`)
- Argparse: flag-only `--record|--replay`; reject `--report` combo
- ADR success: named sections, not "seven bullets"
- i18n: `HEAD:path` only; committed-edit gate; no `*.md eol=lf`
- Names pinned: `--record|--replay`, `FLOW_EVAL_UNBOUNDED=1`
- Phase 8 fixtures: `fcdd`/`fcde`, fcdc-class
- CI experiments: PR targeting master
- Phase 4: do not touch `skills/flow/law/CLAUDE.md`; budgets from measured `wc -w` + 10%
- i18n initial record: current HEAD blobs, no translation audit

#### Action Items
- [x] Propagate all 13 decisions into plan.md + affected phase files
- [x] Whole-plan consistency sweep after propagation

#### Impact on Phases
- Phase 1: re-baseline census; drop "seven bullets"
- Phase 2: master-only trigger note; `needs` list is initial (3+7 append)
- Phase 3: `--compare` / shared predicate; pack cwd; pin installer flags
- Phase 4: law/CLAUDE.md out of scope; measured budgets
- Phase 5: HEAD:path only; tests must commit
- Phase 6: timeout-PATH facts; mock≠live-claude; insert window; pin env
- Phase 7: 27-call census; argparse; prelude vs guard; shouldShip twin
- Phase 8: `fcdd`/`fcde`; 11×3 re-record

### Verification Results
- **Tier:** Full (8 phases → all 4 roles)
- **Claims checked:** 48
- **Verified:** 40 | **Failed:** 8 | **Unverified:** 0
- Red Team Review already present; this pass resolved leftover contradictions (no `[UNVERIFIED]` tags existed).

#### Failures (applied)
1. [Fact Checker] "~21 calls" — `manifest.tsv` has 9 rows; 9×3=27 (+probe)
2. [Fact Checker] Phase 6 "gtimeout is present" — contradicted by `flow.sh:2928-2929`, `test_flow_eval.sh:127`, `test_flow_status_legibility.sh:15-16`, `DEBT.md`
3. [Fact Checker] Phase 6 "Test E is the same live path" — E does not strip timeout; both H/E are mock-engine (`test_flow_eval.sh:2-3`)
4. [Fact Checker] Phase 1 "ALL seven bullets" — Step 1 lists 9 sections
5. [Fact Checker] `shouldShip` `:57-63` — that is the copy `filter`; `shouldShip` is `:68-74` and is not exported
6. [Flow Tracer] Phase 3 "apply shouldShip" from bash — no call path; would fork the predicate
7. [Flow Tracer] `--record|--replay --report` would hit the `--report` return at `:4185` and never replay
8. [Contract Verifier] plan.md still said `--replay` "(name final at impl)" after Phase 7 pinned the flags

#### Sample verified (non-exhaustive)
- Engine census 3191 / 3802 / 3817 / 4087 / 4092 / 4315 / 4345; `_eval_probe` SKIP `:4203-4211`; nonce `:4214`; `_eval_gate_rules_sha` `:3287`; `_run_with_timeout` `:2931`
- 58 `run_all.sh` suites; 8 registry consumers; 41 node `test(` calls (10+9+12+9+1)
- `e2e-installed-drive.sh:5` `$1` default; `azure-pipelines.yml:71-73`; `--project --dir` in `help.mjs`
- `.gitattributes:8` markdown default; `ci.yml` paths `:3-21`; no `docs/adr/` yet; no root `AGENTS.md`/`CLAUDE.md`
- Card-gate section `gate-rules.md:167`; DEBT.md macOS entry; `cmd_coherence` exists

### Whole-Plan Consistency Sweep
- Files reread: plan.md, phase-01-start.md, phase-02-a1-all-checks-ci-manifest-runner.md, phase-03-a2-pack-install-rehearsal-parity.md, phase-04-a4-root-agentsmd-word-budgets.md, phase-05-a5-en-vi-blob-hash-manifest.md, phase-06-macos-debt-bounded-card.md, phase-07-a3-keyless-eval-replay-mode.md, phase-08-b1-s-ground-truth-evidence-addendum.md
- Decision deltas checked: 13 (call census; macos PATH; shouldShip --compare; installer pin; cmd_eval compose; argparse; ADR sections; HEAD:path; flag/env names; fcdd/fcde; master-only CI; law/CLAUDE.md; measured budgets)
- Reconciled stale references: 8 (`~21` leftovers now marked stale; `--replay` name pinned; gtimeout-on-PATH claim removed; Test E/H characterization; seven-bullets; shouldShip line cites; HOME= demoted; Phase 8 fixture ids)
- Unresolved contradictions: 0

### Session 2 — 2026-08-14
**Trigger:** Round-2 validate after red-team R2 (12 findings applied). Operator interview forbidden. Convergence: impl-impact only.
**Questions asked:** 0 new decision forks. R2's 12 fixes checked against Validate R1 pins (no reversals).
**Operator questions:** 0.

#### R1 pin vs R2 fix
All 13 R1 pins hold. R2 refined three of them (not reversed): DEST/`RUN` path; `--compare` must argv-branch before `sync.mjs` copy; cmd_eval compose is guard-then-wrap `:4203-4218` (Session 1 "prelude → guard → probe" already superseded in the log).

#### Action Items
- [x] Phase 6 Related Code Files still said Test H "will hit the new refusal" (contradicts R2 F5 / Implementation Steps). Aligned.

#### Impact on Phases
- Phase 6: Related Code Files now matches "H keeps PASS via UNBOUNDED; new refusal case"

### Verification Results (Session 2)
- **Tier:** Full (compose + leftover sweep; no `[UNVERIFIED]` tags)
- **Claims checked:** 24 (R2 deltas + R1 pins + DEST/`RUN` + cmd_eval windows + COOK-READY surfaces)
- **Verified:** 23 | **Failed:** 1 | **Unverified:** 0

#### Failures (applied)
1. [Contract Verifier] Phase 6 Related Code Files — Test H "will hit the new refusal" vs Implementation/SC "do not rewrite H"

### Whole-Plan Consistency Sweep
- Files reread: all 9 plan files after Session 2 edit
- Decision deltas checked: 13 R1 pins + 12 R2 fixes + 1 Session 2 leftover
- Reconciled stale references: 1 (Phase 6 Related Code Files Test H)
- Unresolved contradictions: 0

<!-- slug: flow-upgrade-wave1 -->
