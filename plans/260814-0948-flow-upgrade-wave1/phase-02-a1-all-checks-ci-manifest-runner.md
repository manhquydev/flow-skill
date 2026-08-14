---
phase: 2
title: "A1 all-checks CI + manifest runner"
status: pending
priority: P1
effort: "1-1.5d"
dependencies: [1]
---

# Phase 2: A1 all-checks CI + manifest runner

## Overview
Close the GitHub trap (a skipped required check counts as passing) with one required
`all-checks-passed` aggregation job, and convert `tests/run_all.sh`'s hardcoded 58-suite loop into a
manifest-driven runner so local `check-all` and CI share one source of truth.
Pattern source: dsh `run-gates.ts` + `if: always()` aggregation (`research-260814-0915-deepseek-tech-stack.md` §2.3, §6.4).

## Requirements
- Functional: CI fails when ANY job is failed, cancelled, OR skipped; suites listed as data, not code.
- Non-functional: bash-3.2-safe runner; per-suite wall-clock timing preserved (Windows diagnosis);
  zero new deps (no yq/jq requirement — plain-text manifest).

## Architecture
- `tests/manifest.txt`: one suite filename per line, `#` comments allowed; optional ordering groups
  later (B4) — v1 is a flat ordered list matching today's loop exactly.
- `tests/run_all.sh`: reads the manifest, keeps `set -u`, per-suite timing echo, `rc` aggregation,
  final `ALL SUITES PASSED` echo (human-facing; **CI does not grep it** — `.github/workflows/ci.yml:64-65`
  is `run: bash tests/run_all.sh` and the contract is `exit $rc`). Keep the string unless a
  consumer is added. The **registry** contract moves to `tests/manifest.txt`.
- `.github/workflows/ci.yml`: add job `all-checks-passed` with `needs: [bash-suite, no-python-degradation, test]`
  and `if: always()`, failing unless every needed job's `result == 'success'`.

## Related Code Files
- Create: `tests/manifest.txt`
- Modify: `tests/run_all.sh`, `.github/workflows/ci.yml`
- Modify (guard): a small suite `tests/test_manifest_runner.sh` asserting (a) manifest lists exactly
  the suites present on disk (no orphans either way, `test_*.sh` glob vs manifest), (b) runner fails
  when a listed suite is missing.
- Modify (registry consumers — required, or Phase 2 ships a vacuous gate / 6 red suites):
  `scripts/check-release-coherence.sh` (today `:34` greps `for suite in ` then always `ok`s),
  `tests/test_release_coherence.sh` (`:28-31` same grep to stub files),
  self-guards that grep `run_all.sh` for their own name:
  `tests/test_flow_slice_quality.sh:138`, `tests/test_flow_open_decisions.sh:172`,
  `tests/test_flow_native_rituals.sh:78`, `tests/test_flow_converge.sh:148`,
  `tests/test_flow_forge_idea.sh:63`, `tests/test_flow_concierge.sh:100`.
  Point all eight at `tests/manifest.txt`. Empty registry extract = fail (do not `ok` a no-op).

## Implementation Steps
1. Generate `tests/manifest.txt` from the current hardcoded list (order preserved).
2. Rewrite the `for suite in …` loop to `while read` over the manifest (skip blanks/comments);
   verify identical suite count (58) and identical output shape. Same change: retarget the eight
   registry consumers listed above to `tests/manifest.txt` (empty extract = fail).
3. Add `test_manifest_runner.sh`; register it in the manifest (59th suite).
4. Add `all-checks-passed` job:
   ```yaml
   all-checks-passed:
     needs: [bash-suite, no-python-degradation, test]
     if: always()
     runs-on: ubuntu-latest
     steps:
       - name: verdict
         run: |
           results='${{ join(needs.*.result, ' ') }}'
           for r in $results; do [ "$r" = "success" ] || { echo "non-success: $results"; exit 1; }; done
   ```
   This `needs` list is the **Phase 2 initial set**. Phase 3 appends `pack-rehearsal`; Phase 7
   appends the keyless replay job. Do not treat the snippet as the final wave-1 list.
5. **Path-filter fix (blocking — red-team F1):** `ci.yml:3-21` currently triggers only on
   `npm-wrapper/**`, `skills/flow/**`, workflow/template files — NOT `tests/**`, `scripts/**`,
   `docs/**`, root `*.md`. After the required-check flip, a PR touching only those paths would never
   report and sit at "Expected — waiting for status" forever (Phases 1/4/5 themselves!). Fix: delete
   the `paths` filters from both triggers (recommended — concurrency-cancel already bounds cost;
   correctness of the required check beats Windows minutes). Rule for the flip note: the required
   check's workflow must trigger on every PR path the repo gates.
   **Trigger branches stay `[master]`** (`on.push.branches` / `on.pull_request.branches`). A push
   to `research/deepseek-harness-upgrade` does not run GHA. Forced-skip / first-green / pack /
   replay experiments are demonstrated on a PR whose **base is `master`**. Do not add this
   research branch to the trigger list (YAGNI; extra minutes).
6. Verify the trap is closed: temp commit forcing one WHOLE job to skip (e.g. `if: false` on
   `no-python-degradation` — a matrix cell cannot be individually skipped, and removing a cell still
   leaves `needs.*.result == success`); confirm `all-checks-passed` fails; revert. Accepted residual:
   matrix-cell REMOVAL is invisible to `needs.*.result` — a matrix edit is a reviewable ci.yml diff;
   a cell-count assertion is YAGNI.
7. After first green run, note in PR description: flip branch protection required check to
   `all-checks-passed` only (operator action on GitHub settings — record, don't script).

## Success Criteria
- [x] Manifest runner green on 3-OS; manifest count equals on-disk `tests/test_*.sh` (59 after
      this phase's new suite; later phases add more — do not freeze 59 as the wave-end number);
      output contract string unchanged.
- [x] Forced whole-job-skip experiment made `all-checks-passed` fail (evidence: CI run link), then reverted.
- [x] `paths` filters removed (or extended to every gated path) — a docs-only PR reports the required check.
- [x] `tests/test_manifest_runner.sh` catches an orphaned/missing suite (unit-tested both ways).
- [x] The eight registry consumers (coherence + six self-guards) read `tests/manifest.txt`;
      deleting a listed file fails coherence (not a vacuous OK).

<!-- Updated: Red Team R1 - manifest consumers; drop fabricated CI grep claim -->
<!-- Updated: Validation Session 1 - master-only CI trigger; needs list grows in 3+7 -->

## Risk Assessment
Required-check rename can strand open PRs → add job first, flip protection after green (recorded
operator step). Windows quoting: manifest read loop must use plain `while IFS= read -r` (no arrays
needed — bash-3.2-safe).
