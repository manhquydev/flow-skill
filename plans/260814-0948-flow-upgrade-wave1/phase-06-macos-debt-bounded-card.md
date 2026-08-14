---
phase: 6
title: "macOS DEBT bounded card"
status: pending
priority: P1
effort: "0.5-1d (bounded)"
dependencies: [2]
---

# Phase 6: macOS DEBT bounded card

## Overview
One bounded attempt at the open DEBT (macOS `_run_with_timeout` fallback doesn't bound a stuck
`claude` call — unbounded billing risk), plus a guard that ships REGARDLESS of diagnosis outcome:
live eval on macOS without a real timeout binary refuses by default with an explicit opt-in flag.
This is the canary phase kongming required before A3 touches the eval area.

## Requirements
- Functional: (a) diagnosis attempt via macOS CI iteration only (no hardware promise); (b) guard:
  `flow.sh eval` **non-replay / non-report** mode on darwin without `timeout`/`gtimeout` in PATH →
  exit with refusal message naming the risk + the opt-in env **`FLOW_EVAL_UNBOUNDED=1`** (name
  pinned). "Live mode" here means `cmd_eval` after the `--report` early-return and with the
  replay flag unset — **including mock-engine suite cases** that still enter `cmd_eval`.
  Replay mode (Phase 7) NEVER hits this guard.
- Non-functional: bash-3.2-safe; guard is a few lines **before** `_eval_probe` (flow.sh:4203) —
  `_eval_probe` is a billable `claude` call (3173-3176), not a platform probe. Replay/`--report`
  must skip the guard. Degrade message follows house style (loud, actionable, never silent).

## Architecture
- Diagnosis surface: `skills/flow/runner/flow.sh:2931` `_run_with_timeout` — DEBT.md records 3 failed
  fixes (empty-array `_cleanup_tds`, `wait $PID` variants, pipe vs redirect); remaining hypotheses:
  `kill -TERM` not reaching the child through `sh -c` process group, or `wait` not unblocking on
  signal-killed child. Bounded attempt: add a temporary macOS CI diagnostic step (spawn mock-slow
  child, kill, assert return latency). **The step must mask PATH first**: GitHub macOS runners ship
  coreutils **keg-only** on some images, so `gtimeout` **must not be assumed on PATH**. Evidence
  the DEBT lane is the default macos-ci path: `flow.sh:2928-2929` ("macOS ships neither by
  default"), `tests/test_flow_eval.sh:127-128` ("on the macos-ci lane neither `timeout` nor
  `gtimeout` is on PATH"), `tests/test_flow_status_legibility.sh:15-16`, `DEBT.md` (ubuntu+windows
  have real timeout; macOS is the debt). **Still mask PATH** on the diagnostic step so a runner
  that *does* ship `gtimeout` cannot silently take the bounded lane. Bound: 2 iterations max;
  **iteration = one PR-to-master-triggered macOS run of the diagnostic step** (auditable; this
  branch's pushes do not run GHA).
- Exit artifact either way: DEBT.md entry updated to name the CONFIRMED mechanism + fix, or the
  ABANDONED state ("mechanism unconfirmed after bounded CI diagnosis") + shipped guard as the
  permanent boundary.

## Related Code Files
- Modify: `skills/flow/runner/flow.sh` (guard near live-eval entry; possible `_run_with_timeout` fix),
  `DEBT.md`, `skills/flow/references/gate-eval.md` (document refusal + opt-in), relevant suite
  `tests/test_flow_eval.sh` — **required edits, not just new cases.** Both H and E are
  **mock-engine** (`mkmock`) cases that still enter `cmd_eval` (header: "this suite NEVER calls
  a live LLM"). They are not "live claude" — they **are** "live mode" for the guard (replay flag
  unset).   Test H (`:161-195`) strips `timeout`/`gtimeout` and expects exit 0 / PASS / fast — that is
  the `_run_with_timeout` watchdog regression. After the guard, H **keeps that contract**
  via `FLOW_EVAL_UNBOUNDED=1` **only in H** (do not rewrite H to expect refusal). Add a
  **new** case for the unguarded darwin+no-timeout refusal. Test E (`:113-132`) does **not**
  strip timeout (`PATH="$MOCKBIN:$PATH"`); set the opt-in in E only when the runner itself
  has no `timeout`/`gtimeout` (the suite comment at `:127` says macos-ci does not). There is
  **no** `uname` stub in this suite.

## Implementation Steps
1. Write the guard first (independent of diagnosis). **Insertion window:** after the `--report`
   early-return (`cmd_eval` `:4185-4196`) and immediately before `_eval_probe` (`:4203`).
   `--report` is then structurally skipped. Condition: darwin + no `timeout`/`gtimeout` +
   replay flag unset (default 0 — Phase 7 sets it). Detect darwin via one `uname -s` (or
   `FLOW_EVAL_FORCE_DARWIN=1` for Linux CI). Do **not** invent an eval-suite uname stub —
   none exists. **Test H keeps its current contract** (`test_flow_eval.sh:161-192`: timeout-less
   PATH, exit 0 / PASS / fast). Set `FLOW_EVAL_UNBOUNDED=1` **only in H** (and E on darwin when
   timeout is absent) so the watchdog regression stays tested. Add a **new** case for the
   unguarded darwin+no-timeout refusal. Do not rewrite H to expect refusal. Do not
   blanket-export `FLOW_EVAL_UNBOUNDED=1` for the whole suite. Phase 7 wraps `:4203-4218`
   after this guard — leave the `replay_mode` skip so 7 does not delete the guard.
2. Bounded diagnosis: add temp diagnostic step to macOS CI cell; run ≤2 iterations; capture behavior.
3. If mechanism confirmed → minimal fix + regression test; if not → abandon cleanly.
4. Update DEBT.md (exit artifact) + gate-eval.md.

## Success Criteria
- [x] Guard: refusal path + opt-in path both covered by tests; replay mode unaffected.
- [x] DEBT.md names confirmed-or-abandoned mechanism with CI-run evidence links.
- [x] Diagnosis effort did not exceed 2 macOS CI iterations (bounded promise kept).
- [x] Test H still expects PASS on the timeout-less path (via `FLOW_EVAL_UNBOUNDED=1` in H
      only); a new case covers unguarded refusal; no suite-wide unbounded opt-in.

<!-- Updated: Red Team R2 - H keeps PASS via UNBOUNDED; new refusal case; do not rewrite H -->
<!-- Updated: Validation Session 2 - Related Code Files no longer says H "will hit the new refusal" -->

<!-- Updated: Red Team R1 - guard before probe; drop phantom uname stub; update test H -->
<!-- Updated: Validation Session 1 - no gtimeout-on-PATH assumption; mock≠live-claude; pin env; insert after --report -->

## Risk Assessment
The diagnosis may (again) fail — acceptable by design; the guard converts the open risk from
"unbounded billing" to "explicit operator opt-in", which is the real close-before condition in
DEBT.md. Do not let diagnosis scope-creep past 2 iterations.

## Operator CI diagnostic (do not run from this branch's pushes)

This worktree's GHA triggers are `master` + PRs targeting `master`. Paste the step below into
the `bash-suite` macos cell (or a one-off macos-latest job) on a PR whose **base is master**.
Mask PATH inside the helper — do not assume `gtimeout` is on PATH. **≤2 iterations.**

Helper: `scripts/macos-timeout-watchdog-diag.sh`

```yaml
      - name: macOS timeout-watchdog diagnosis (PATH-masked)
        if: matrix.os == 'macos-latest'
        run: bash scripts/macos-timeout-watchdog-diag.sh
        shell: bash
```

After each run: paste the job URL + `RESULT:` line into the DEBT.md evidence field. Stop after
2 iterations whether the mechanism is confirmed or still unconfirmed.
