---
phase: 1
title: Eval robustness (raw-on-INVALID + retry + rate-limit visibility)
status: completed
priority: P1
dependencies: []
---

# Phase 1: Eval robustness (raw-on-INVALID + retry + rate-limit visibility)

> **Red-teamed 2026-07-11** (3 hostile lenses, all findings evidence-backed). This phase was
> re-spec'd from the findings — every `[RT-n]` tag below marks an applied fix. See
> `plan.md` → `## Red Team Review` for the adjudication table.

## Overview

Make eval failures diagnosable and cost-safe. The 260710 22:00 batch produced 17/18 INVALID
**despite the existing in-run retry** (`skills/flow/runner/flow.sh:2791-2795`) because the retry
fires immediately into the same transient window, discards the raw output, and the batch keeps
burning billable calls to the end. The storm's only symptom was on **stderr** ("SessionEnd hook
cancelled" ×18), a channel the current code never captures.

## Requirements

- Functional:
  - Persist raw engine output (**stdout + stderr + numeric rc**) on a final-INVALID vote — the
    stderr channel is where the motivating storm's signature lived. [RT-C2]
  - Backoff before the in-run retry, via an **injectable** delay (default 5s, tests set 0). [RT-H6]
  - Best-effort rate-limit detection, **anchored to the `rate_limit_info` record** — documented
    advisory, not authoritative, until a real throttled sample is captured. [RT-H5]
  - Circuit-breaker on **cumulative INVALID pressure** (not first-fixture-all-invalid) so it
    actually catches a 17/18-class storm; `--keep-going` overrides. [RT-C1]
  - Aborted batch must NOT be recorded complete (explicit `aborted` flag guarding the `done`
    trailer). [RT-H3]
  - Results rows gain `retries` and `rate_limited` fields (additive, kept short). [RT-H12]
- Non-functional: bash-3.2/BSD-portable; zero billable calls in tests (mock engine); no jq;
  results line stays < 4096B (PIPE_BUF atomic-append invariant, `tests/test_flow_eval.sh:249`).

## Architecture

All changes inside `cmd_eval` + `_eval_*` helpers in `skills/flow/runner/flow.sh` (vote loop
~2785-2803, `_eval_emit_result` ~2487 with its SINGLE call site at ~2833, `_eval_engine_run`
~2392, batch `done` trailer ~2840, completeness rule `_eval_complete_run_ids` ~2507-2530).

1. **Raw capture (stdout + stderr + rc)** [RT-C2, RT-H4, RT-J, RT-K]:
   - `_eval_engine_run` gains a stderr sink: run the timed command with `2> "$errfile"` so
     stderr is captured per attempt (the storm channel). Keep stdout as the return value.
   - On a vote whose FINAL verdict is INVALID, persist **both attempts** (not just the last —
     the `-a<attempt>` filename schema already implies both, and attempt-1 is the likelier
     carrier of the rate-limit/hook signal): write stdout, stderr, and an `rc` marker to
     `.flow/eval-raw/<run_id>/<fid_safe>-v<vote>-a<attempt>.{out,err,rc}` (anchor = dir of
     `$EVAL_RESULTS_FILE`). `<fid_safe>` = `fid` passed through the nonce sanitizer
     (`tr -c 'A-Za-z0-9' '-'`) so a hand-edited/`FLOW_EVAL_MANIFEST`-override manifest cannot
     traverse out of `eval-raw/` — this write is keyed by `fid`, which the current code only
     `tr -d '\r'`-cleans (`flow.sh:2743`); the documented v1 trust boundary (`flow.sh:63-67`) is
     read-side only, so the new write needs its own containment. [RT-J]
   - **Privacy**: the `--output-format json` envelope is NOT "fixture text + model prose only" —
     it carries `cwd` (embeds the Windows username on this dev OS), a resumable `session_id`,
     plugin/memory paths, `apiKeySource`. Persist ONLY the assistant `result` text + any
     `rate_limit_event` record, stripping the `system`/`init` envelope; AND call
     `_ignore_run_state` from the capture path so `.flow/eval-raw/` is git-ignored even on a
     project where the operator only ever runs `eval` (current `cmd_eval` never ignores run
     state — call sites are `flow.sh:1115/1132/1834` only). [RT-H4]
   - **Loud on failure**: raw capture is diagnostic-critical, NOT a telemetry sink — do NOT use
     the house `>> … 2>/dev/null || true` pattern. On write/mkdir failure print one
     `eval: WARNING raw capture failed for <path>` to stderr; the breaker's abort line reports
     the actual file COUNT written, not just the dir name. [RT-K]

2. **Backoff (injectable)** [RT-H6]: `FLOW_EVAL_RETRY_BACKOFF` env, default 5, before the in-run
   retry only. Tests set it to 0 (no wall-clock). The retry emits a greppable line
   `  <fid>: retrying vote <i> after <N>s` so the test asserts the backoff PATH via text, not a
   stopwatch (the existing suite's timing asserts are already fragile — `test_flow_eval.sh:118`).
   **Skip the retry entirely when the rate-limit signal fired on this attempt** — the retry is
   documented for "a formatting slip, not infra" (`flow.sh:2792`); retrying into a live
   rate-limit window just doubles spend. [RT-H8]

3. **Rate-limit detection (advisory, anchored)** [RT-H5]: helper `_eval_parse_rate_limited`
   matches the `rate_limit_event`/`rate_limit_info` record specifically, then reads THAT record's
   `status`. **Empirical note (raw captured 260710):** the real shape on cli 2.1.201
   `--output-format json` stdout is
   `"rate_limit_event"…"rate_limit_info":{"status":"allowed",…,"overageStatus":"rejected",…}` —
   an *allowed* event already contains the substring `"rejected"` in a DIFFERENT field
   (`overageStatus`). A bare `grep '"status":"' | grep -v allowed` or `grep rejected` therefore
   FALSE-POSITIVES on a healthy event, and fixture prose (the adversarial input this eval judges)
   can also mint the string. Anchor to the `rate_limit_info` object's own `status` value only.
   Only `allowed` has ever been observed; a genuinely-throttled shape is UNVERIFIED → the field
   is documented best-effort/advisory (absence ≠ not-throttled), and a real throttled sample
   must be captured (via item 1) before any drift logic trusts it.

4. **Circuit breaker (cumulative pressure)** [RT-C1, RT-H3]: the storm was 17/18 — one vote
   parsed — so a first-fixture-`invalid_count==n` test would NOT have fired. Trip instead on the
   **first fixture that comes back UNRELIABLE** (reuse the existing floor `invalid_count*3 > n`,
   `flow.sh:2812`), which the 17/18 case satisfies at fixture 1. `--keep-going` overrides. Abort
   path is EXPLICIT: compute verdict → print the UNRELIABLE line → emit the result row →
   set `aborted=1` → `break`. The `done` trailer at `flow.sh:2840` is then guarded by
   `[ "$aborted" -eq 0 ]` (a bare `break` would still reach it and write a trailer, and on a
   `--fixture`/`--stage` filtered run `n_written==n_expected` would mark the junk batch COMPLETE —
   poisoning `--report`/drift, `flow.sh:2507-2530`). Keep `trap - INT TERM` on the shared path
   (do NOT early-`return` — that leaks the eval INT/TERM trap into the rest of the process).
   Abort exits nonzero with a distinct message. Update the invariant comments at
   `flow.sh:2469-2472` / `2837-2839` (which currently claim absence-of-trailer is the ONLY
   incompleteness path) in the same change.

5. **Emit fields** [RT-H12]: `_eval_emit_result` gains `"retries":N,"rate_limited":true|false`
   at its **single call site (`flow.sh:2833`)** — there is no second call site; the tests' two
   hand-printed synthetic rows (`tests/test_flow_eval.sh:253`) stay old-shape and double as the
   backward-tolerance fixtures. All FIVE internal readers extract by field NAME and are additive-
   tolerant by construction — verify, don't rewrite: `_eval_complete_run_ids` (2507-2530),
   `_eval_print_scorecard` (2535-2580), `_eval_flag_rates` (2584-2600), `_eval_print_drift`
   (2605-2649), plus test asserts (2242-2257). Keep both new fields short (PIPE_BUF < 4096B).

## Related Code Files

- Modify: `skills/flow/runner/flow.sh` (cmd_eval vote loop, `_eval_engine_run` stderr sink,
  `_eval_emit_result` single call site, `_eval_parse_rate_limited` new helper, `_ignore_run_state`
  wiring, usage line, arg parser for `--keep-going`, trailer guard, invariant comments)
- Modify: `skills/flow/SKILL.md` (eval verb doc: `--keep-going` + raw-capture note)
- Modify: `skills/flow/references/gate-eval.md` (failure-modes: INVALID-storm playbook incl.
  no-lock caveat + best-effort `rate_limited`)
- Modify: `tests/test_flow_eval.sh` (new cases; existing mock-engine pattern; update tests D/G
  expectations for the new UNRELIABLE-breaker single-fixture behavior)

## Implementation Steps

1. `_eval_engine_run`: add `2> "$errfile"` stderr sink (caller passes an errfile path).
2. `_eval_parse_rate_limited` helper next to `_eval_parse_model` (~2443), anchored to the
   `rate_limit_info` record's own `status`.
3. Vote loop: injectable `FLOW_EVAL_RETRY_BACKOFF` before retry; skip retry if rate-limit fired;
   on final INVALID persist attempt-1 AND attempt-2 stdout+stderr+rc (stripped `result` text +
   rate_limit record only), loud-warn on failure; emit the `retrying …` text line.
4. Pre-batch prune of `.flow/eval-raw/` by the **epoch embedded in run_id** (nonce already
   contains `_now`, `flow.sh:2341-2343`) — deterministic, mount-independent; keep newest by
   epoch, NEVER prune a dir whose embedded epoch is within `FLOW_LOCK_TTL` (900s) of now (guards
   a concurrent/stuck lock-free run — `cmd_eval` takes no lock); rm failure warns, not silent.
   [RT-H9]
5. `_eval_emit_result`: append `retries` + `rate_limited` at the single call site; wire
   `_ignore_run_state` for `.flow/eval-raw/`.
6. Circuit breaker per Architecture item 4: first-UNRELIABLE trip, `aborted` flag, guarded
   trailer, `--keep-going` in arg parser + usage string, nonzero abort exit.
7. Tests (mock claude in PATH): (a) invalid-then-valid retry with `FLOW_EVAL_RETRY_BACKOFF=0`
   asserting the `retrying` line + `retries` in row; (b) **mock writes to stderr + exits 1 with
   empty stdout** → assert the `.err` file is non-empty and rc captured [RT-C2]; (c) first-fixture
   UNRELIABLE (2 INVALID + 1 valid at n=3) → assert abort + raw files exist + **no done trailer**
   incl. a `--fixture`-filtered case [RT-H3]; (d) `--keep-going` → full batch; (e) extra-fields
   tolerance of `--report`; (f) rate_limited stays FALSE on a mock `allowed` event that contains
   `overageStatus":"rejected"` [RT-H5]; update tests D/G for the breaker.
8. `bash tests/test_flow_eval.sh` then full `tests/run_all.sh` (with `FLOW_EVAL_RETRY_BACKOFF=0`
   so degraded-path cases don't add wall-clock across the 3-OS matrix).

## Success Criteria

- [ ] Final-INVALID vote → `.flow/eval-raw/<run_id>/` holds stdout+stderr+rc for BOTH attempts;
      stderr-only-failure mock test proves the `.err` file is captured.
- [ ] Persisted content is `result` text + rate_limit record only (no cwd/session/plugin
      envelope); `.flow/eval-raw/` is git-ignored via `_ignore_run_state`.
- [ ] Backoff injectable (`FLOW_EVAL_RETRY_BACKOFF`), asserted via emitted text not stopwatch;
      retry skipped when rate-limit fired.
- [ ] `rate_limited` anchored to `rate_limit_info`; FALSE on an `allowed` event carrying
      `overageStatus":"rejected"`.
- [ ] First-UNRELIABLE fixture aborts batch, nonzero exit, `aborted`-guarded trailer → batch
      NOT recorded complete (incl. a filtered-run case); `--keep-going` runs full batch.
- [ ] `retries` + `rate_limited` at the single call site; `eval --report` output unchanged on
      pre-v0.21 rows; line < 4096B.
- [ ] Raw-write failure prints a loud warning; prune keyed by run_id epoch with 900s TTL guard.
- [ ] test_flow_eval.sh + run_all.sh green; no `grep -oP`, BSD-sed-safe.

## Risk Assessment

- Retry-mask risk: retry stays capped at 1/vote, is COUNTED (`retries`), and is SKIPPED on a
  rate-limit hit — drift in retries is itself visible.
- Breaker false-positive (a genuinely unparseable model on the first fixture aborts a real run):
  `--keep-going` is the escape hatch; raw capture makes the abort diagnosable rather than blind.
- Rate-limit field is advisory until a real throttled sample lands — documented as such so it is
  never mistaken for authoritative drift signal.
- Cost: worst case with retained retry = probe + n×2 = **≤7 calls** at `--n 3` (NOT "~3");
  `--keep-going` in a full storm ≈ 6×3×2 + probe = **37 calls** — stated next to the flag so the
  operator cannot mis-budget. [RT-H8]
