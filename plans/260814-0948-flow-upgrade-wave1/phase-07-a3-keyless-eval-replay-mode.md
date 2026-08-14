---
phase: 7
title: "A3 keyless eval replay mode"
status: pending
priority: P1
effort: "1.5-2d"
dependencies: [2, 5, 6]
---

# Phase 7: A3 keyless eval replay mode

## Overview
Make the eval pipeline deterministic and CI-able: a replay mode for `flow.sh eval` that records a
judge batch to fixtures and replays it offline — zero calls, keyless. **Honest scope (red-team F2):**
gate-rules text is embedded in the judge prompt (`_eval_build_prompt`, flow.sh:3201-3220), and
replayed responses are frozen — so replay CANNOT regression-test rules effectiveness (that stays
live + billable). What replay delivers: parse/vote/scorecard code-regression coverage, tamper
detection, and a **staleness tripwire** — replay recomputes the CRLF-normalized gate-rules hash and
hard-fails on mismatch ("fixtures stale — gate-rules changed; re-record live per ADR re-baseline
rule"). Closes the "eval pipeline never in CI" gap; still the wave's best product change.
Pattern source: dsh `DSH_SNAPSHOT=record|refresh|replay` (`research-260814-0915-deepseek-tech-stack.md` §2.1, §6.7).

## Requirements
- Functional: `flow.sh eval --record` writes per-fixture **stripped** transcripts + metadata (judge
  model, gate-rules blob hash, nonce) under `skills/flow/eval/replay/`; `flow.sh eval --replay`
  feeds recorded verdict text through the UNCHANGED parse→majority-vote→scorecard pipeline and diffs
  verdicts against expectations; exit contract is strict all-match **when replay actually ran**.
  Replay verifies the recorded gate-rules hash against `_eval_gate_rules_sha` (flow.sh:3287) and
  hard-fails on mismatch. Do **not** reuse `_eval_print_drift` / `:3528` — that printer is advisory
  and never an exit-code signal (flow.sh:3506-3528), and it only runs from `--report` (4182-4196).
  **Wave-1 modality scope: artifact/gate (`cmd_eval`) only.** `--record|--replay` plus
  `--stage routing|converge` **or** `--report` must usage-exit 1. That reject lives in a
  **second window: after the argparse `while` (`:4160`) and before the `:4173` routing
  dispatch** — not in the prelude. Putting it after `:4185` is too late (`--replay --stage
  routing` has already entered `cmd_eval_routing`; `--replay --report` has already returned).
  Flag-only args (`--record`, `--replay`, `--report`) follow the `--report` pattern: set a
  flag, **no inner `shift`**. Update **both** usage surfaces: argparse `:4157` **and** the
  help catalog `:4508-4513` (today still "skips cleanly if claude absent", flags stop at
  `--report`).
  Today's artifact manifest is **9 fixtures** × `--n 3` = **27 judge calls + 1 probe**
  (brainstorm "~21" is stale). After Phase 8's pair: 11 × 3 = 33.
- Non-functional: **confinement (revised R1):** the *live body* of `_eval_engine_run()` (flow.sh:3191-3193)
  stays byte-identical and `_run_with_timeout` is untouched. Replay **cannot** live only inside that
  function: `_eval_probe` (3173), nonce mint (4214), `_eval_cli_version` (3299/4218), and parse
  (3234-3241) all sit in `cmd_eval` *above* the engine. A required **`cmd_eval` wrap of
  `:4203-4218` plus artifact call sites `:4315/:4345`** is in-scope and is *not* a phase-kill.
  STOP only if the live engine body or `_run_with_timeout` must change. Fixtures are eval-harness-built stripped
  transcripts, NEVER raw `claude --output-format json` envelopes and NEVER captured live traffic
  (process-token invariant; eval-raw comment at 4221-4226). Zero live calls in replay: CI asserts
  no `claude` binary **and** a replay-ran sentinel (fixture count / `replay:` line). `--replay`
  must not inherit live SKIP-exit-0.

## Architecture
- **Two `cmd_eval` windows (do not collapse them):**
  1. **Reject window** (after `:4160`, before `:4173`): `--record|--replay` +
     `--stage routing|converge` or `--report` → usage-exit 1. Pin `replay_mode` /
     `record_mode` here (same shape as `report_mode` at `:4155`).
  2. **Live-entry window** (after `--report` return `:4185-4196`): Phase 6 guard
     (skip if `replay_mode=1`) then the replay wrap of **`:4203-4218`**, not a
     one-liner that ends at `:4203`. If `--replay`: skip `_eval_probe`; assign
     `nonce` from the fixture (**do not** call `_eval_nonce` at `:4214` — a fresh
     nonce makes every recorded `GATE-EVAL-<old>:` line INVALID, test G
     `test_flow_eval.sh:149-158`); skip `_eval_cli_version` (`:4218` → `claude
     --version` at `:3301`); compare recorded `gate_rules_sha` to
     `_eval_gate_rules_sha`; mismatch → exit 1. Missing fixture → exit 1, never SKIP.
- **Engine feed:** live body of `_eval_engine_run()` (`:3191-3193`) stays
  byte-identical and **unparameterized**. Do **not** add a mode argument (routing
  `:3802/:3817` and converge `:4087/:4092` share the function). Replay substitutes
  stripped fixture text **only at the two artifact call sites** (`:4315/:4345`).
  Document: replay verifies parse/vote/scorecard + gate-rules **hash staleness**,
  not rules effectiveness. Do not write "rules-regression".
- Record mode: wraps a LIVE artifact batch (billable, operator-run) and writes **stripped**
  transcripts (verdict line + nonce + rules hash + model id). `--record` is live-mode —
  the Phase 6 guard **applies**. Record on a host that has real `timeout`/`gtimeout`, or
  export `FLOW_EVAL_UNBOUNDED=1` for that operator run only. Do not skip the guard for
  `--record`. Reject/redact envelopes containing `session_id`/`cwd`/plugin paths.
  `--replay` must not append `EVAL_RESULTS_FILE` as a live batch (or must tag
  `source=replay` and exclude those rows from floor/drift/`--report` completeness).
- CI: new keyless ubuntu job running `eval --replay` artifact-modality batch; joins
  `all-checks-passed`. Demonstrate on a PR whose **base is `master`**. Steps:
  `! command -v claude` **and** assert a replay-ran sentinel; fail on `SKIP:`.
- State table: `skills/flow/eval/replay/` = repo-global, read-only in `--replay`, committed,
  excluded from npm via sync.mjs; `EVAL_RESULTS_FILE` = per-project live JSONL; `.flow/eval-raw/`
  = gitignored, INVALID-only, live-only.

## Related Code Files
- Modify: `skills/flow/runner/flow.sh` (`cmd_eval` prelude + argparse for --record/--replay;
  live `_eval_engine_run` body unchanged),
  `skills/flow/references/gate-eval.md` (modes, hash-staleness limitation, refresh protocol),
  `skills/flow/references/command-dispatch.md` (eval skip-if-absent exception for --replay),
  `skills/flow/SKILL.md` (argument-hint + command table; stay under the Phase 4 SKILL.md
  budget 3950 or bump `docs/doc-budgets.txt` in the same commit),
  `README.md` + `README_VN.md` (Phase 5 is now a dependency: edit both, commit, run
  `scripts/check-i18n-pairs.sh record README.md`; stay under Phase 4 word budgets or bump
  `docs/doc-budgets.txt` in the same commit),
  `tests/test_flow_eval.sh` (replay-mode coverage; existing absent-SKIP tests at :62-80 stay live-only),
  `.github/workflows/ci.yml`, `tests/manifest.txt`,
  `npm-wrapper/scripts/sync.mjs` (exclude `eval/replay/` from the shipped artifact)
- Create: `skills/flow/eval/replay/` fixture tree (committed, one recorded **stripped** batch)

## Implementation Steps
1. Read **`cmd_eval` (flow.sh:4147–end) plus helpers 3173–3340** end-to-end before touching
   anything. Do **not** treat 3560-4100 as the artifact map — that region is routing/converge
   (`cmd_eval_routing` / `cmd_eval_converge`). Engine census (6 invocations):
   definition `:3191`; routing `:3802/:3817`; converge `:4087/:4092`; **artifact (wave-1)
   `:4315/:4345`**. Artifact callers use outer `2>"$errfile"` (3195-3198); routing/converge use
   `2>/dev/null`.
2. Add `--record|--replay` to `cmd_eval` argparse (4150-4157) as **flag-only** cases (same
   shape as `--report`, no inner `shift`). In the **reject window** (after `:4160`, before
   `:4173`) refuse those flags with `--stage routing|converge` or `--report`. Update usage
   at `:4157` **and** `:4508-4513`. After the `--report` return, run the Phase 6 guard
   (skip if `replay_mode=1`), then wrap **`:4203-4218`**: skip probe, assign recorded nonce
   (do not call `_eval_nonce`), skip `_eval_cli_version`, hard-fail rules-hash via
   `_eval_gate_rules_sha` (3287). Substitute replay text only at `:4315/:4345`. Keep the
   live `_eval_engine_run` body byte-identical and unparameterized. Live SKIP-exit-0 at
   4203-4211 stays for live mode only.
3. Implement `--record` on the live artifact path (no behavior change when off); the tee must
   respect the outer-stderr-redirect contract at flow.sh:3195-3199 and 4315/4345. Persist
   stripped verdict+metadata only; CI grep fails the tree if replay fixtures contain
   `session_id`/`cwd`.
3b. Exclude `eval/replay/` from the npm artifact: extend the **one** JS predicate in
   `npm-wrapper/scripts/sync.mjs` (`filter` `:57-63` **and** `shouldShip` `:68-74` — keep them
   twins). Replay fixtures are CI/dev artifacts, not skill content. Phase 3's
   `sync.mjs --compare` then agrees automatically; do not add a second exclusion list in
   `pack-rehearsal.sh`.
4. Run one live artifact batch with --record (operator, billable, **9 × `--n 3` = 27 judge
   calls + 1 probe**) → commit stripped replay fixtures → re-baseline number recorded per ADR.
5. Tests: replay artifact-modality batch offline green; tampered recorded response → verdict
   mismatch → exit 1; `--replay` with missing fixture → exit 1, not skip; `--replay` + no
   `claude` + fixtures present → **exit 0 only if replay actually ran** (not SKIP); existing
   live absent-SKIP tests (:62-80, :487-506) remain live-only; `--record|--replay --stage
   routing` usage-exits.
6. CI job + `needs` update on a PR targeting `master`; assert-keyless (`! command -v claude`)
   **and** replay-ran sentinel (fail on `SKIP:`). Edit both READMEs + `record`; stay under
   Phase 4 budgets or bump `docs/doc-budgets.txt` in this commit.

## Success Criteria
- [x] Replay batch green in CI with zero live calls (assert-keyless **and** replay-ran sentinel;
      a SKIP line fails the job).
- [x] A deliberate gate-rules.md edit makes `--replay` exit non-zero with the staleness message
      (demonstrated once, reverted) — rules *hash* drift is detectable, forcing a live re-record;
      rules EFFECTIVENESS testing stays live+billable (stated in gate-eval.md and the ADR).
- [x] Live mode behavior byte-identical when no new flags used (existing eval tests untouched-green,
      including live absent-SKIP exit 0).
- [x] gate-eval.md documents modes + hash-staleness (not "rules-regression") + the
      "replay ≠ fresh-judge anti-gaming" limitation + "replay verdicts never count toward the
      eval floor".
- [x] `--record|--replay --stage routing|converge` and `--record|--replay --report` exit 1;
      replay fixtures contain no `session_id`/`cwd` keys; help catalog `:4508-4513` lists the
      new flags.
- [x] Replay CI evidence is a PR targeting `master`.

<!-- Updated: Red Team R2 - two windows; wrap 4203-4218; feed 4315/4345 only; Phase 5 dep; help :4508 -->

<!-- Updated: Red Team R1 - cmd_eval prelude, nonce pin, fail-closed, stripped transcripts, call-site census -->
<!-- Updated: Validation Session 1 - 9×3=27 calls; argparse flag-only + --report reject; prelude vs Phase 6 guard; shouldShip twin -->

## Risk Assessment
Highest-intricacy area of flow.sh (nonce/verdict/scorecard). Mitigations: additive-only flags,
live-engine-body confinement (hard gate above), required `cmd_eval` prelude so keyless CI cannot
SKIP-green, full read-before-edit of 4147+, and the Phase 6 guard already isolating the macOS
live-path risk. STOP only if the live `_eval_engine_run` body or `_run_with_timeout` must change.
