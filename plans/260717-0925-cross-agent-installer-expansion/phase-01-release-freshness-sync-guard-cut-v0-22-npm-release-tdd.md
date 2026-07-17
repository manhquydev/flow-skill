---
phase: 1
title: Restart-guidance symptom fix + release freshness via gitignore (TDD)
status: completed
effort: 0.5 day
priority: P1
dependencies: []
---

# Phase 1: Restart-guidance symptom fix + release freshness via gitignore (TDD)

## Overview

**Validation V1 confirmed the real symptom: discovery, not staleness.** Users install to
Antigravity, open it, type `/flow`, see nothing — because a freshly-installed skill isn't
discovered until the agent reloads, and the post-install message (cli.mjs:350, install.sh:68)
guides only Claude + Codex. So the PRIMARY fix (A0) is **post-install restart/reload guidance
for every non-Claude target**. SECONDARY (A1, housekeeping): gitignore the bundle+manifest and
cut a v0.22 release so installs are current. Independently shippable; does NOT wait on Cursor.

## Requirements

- **A0 — Post-install restart/reload guidance (PRIMARY, validation V1):** the post-install
  message in BOTH installers must tell non-Claude users how to make `/flow` appear. Currently
  cli.mjs:350 (`Done. Claude Code: type /flow | Codex CLI: type $flow (restart Codex once)`) and
  install.sh:68 mention only Claude + Codex — Antigravity users get nothing and see a silent
  `/flow`-not-found. Add explicit lines: Antigravity → reload/restart the IDE or `agy` to pick
  up the skill; Cursor (once added) → restart Cursor / reload window; keep the Codex restart
  note. Only the FINAL summary message changes (cli.mjs:350, install.sh:68) — no install-logic
  change. This is the actual fix for the reported symptom.
- **Symptom-confirm (validation V1, DONE):** operator confirmed "installed, open Antigravity,
  `/flow` not shown" = discovery/reload gap, NOT staleness (verified: installers omit Antigravity
  guidance). No further gate needed; A1 below proceeds as housekeeping, not as the symptom fix.
- Functional (anti-drift, red-team C2/M1): **gitignore** `npm-wrapper/skills/flow/` and remove
  it from git tracking. `prepack` (package.json:scripts) already runs `npm run sync` so `npm
  pack`/publish materialize it; the published tarball is unaffected (`files:` includes
  `skills/`). No version guard, no grep, no version-compare test (all three were red-team
  defects — H1 anchoring, H2 test-path, C2 CI-no-op).
- Functional: `npm test` must still work locally → document + wire a `pretest`-style `npm run
  sync` (or a README note) so a fresh checkout without the committed bundle can run tests.
- Functional (red-team M3): fix `scripts/sync.mjs` so `skills-manifest.json` `source:` is
  repo-relative (or dropped), not the absolute local Windows path it currently bakes
  (skills-manifest.json:2) — it ships in the tarball (`files:` includes it).
- Functional (red-team M5): record the shipped skill version (0.22.0) in the npm-wrapper
  CHANGELOG entry so an npm release is traceable to its skill content (rc version alone
  doesn't encode it).
- Non-functional: do NOT touch `skills/flow/**`; do NOT weaken the publish-time fileCount guard
  (publish-npm-wrapper.yml:120).

## Architecture

gitignore is the whole anti-drift mechanism: with no committed bundle, there is nothing to
drift from source. `prepack: node scripts/sync.mjs` (already present) regenerates it at pack
time; publish-npm-wrapper.yml:118 also syncs. Local `npm test` needs the bundle present, so a
`pretest` sync (or documented `npm run sync` step) keeps offline testing working — the one
ergonomic cost of gitignore, accepted by operator.

## Related Code Files

- Create/Modify: `npm-wrapper/.gitignore` (add `skills/flow/`) — and `git rm -r --cached
  npm-wrapper/skills/flow` to untrack
- Modify: `npm-wrapper/package.json` (add `pretest` sync or equivalent; version bump)
- Modify: `npm-wrapper/scripts/sync.mjs` (relative `source:` in the emitted manifest)
- Modify: `npm-wrapper/CHANGELOG.md` (release entry records skillVersion 0.22.0)
- Modify: `npm-wrapper/skills-manifest.json` — becomes gitignored too (it's a sync artifact),
  OR keep tracked with a relative source; pick one and state it (recommend: gitignore it
  alongside the bundle since sync regenerates it — removes the second drift artifact)
- Do NOT touch: `skills/flow/**`, `.github/workflows/*` (no CI guard needed — gitignore
  replaces it)

## Implementation Steps (tests first) — AS ACTUALLY EXECUTED

1. **A0 restart guidance (RED→GREEN)** — extended `cli.test.mjs` with 2 real (non-dry-run,
   scratch-`$HOME`) install tests asserting the Done-line mentions Antigravity + restart/reload.
   First draft matched the ✔-checkmark install-confirmation line too loosely (false-negative
   RED); tightened to isolate just the `Done.` summary line. Confirmed genuinely RED (8 pass /
   1 fail) before the fix. GREEN: `bin/cli.mjs` now builds the Done-line from
   `plan.map(p => p.target)` via a `RESTART_HINTS` map (claude/codex/antigravity/agents), same
   pattern mirrored into `install.sh` (`INSTALLED` + `done_line()`) and `install.ps1`
   (`$installed` + `Get-DoneLine`) — all 3 entry points fixed, not just cli.mjs.
   Static-content assertions added to the existing
   `tests/test_flow_antigravity_integration.sh` (Invariant 9) for the 2 bash-family installers.
2. **PLAN CORRECTION (discovered, not executed as originally written):** `npm-wrapper/skills/
   flow/` and `skills-manifest.json` were **already gitignored and untracked**
   (`git ls-files npm-wrapper/skills/flow` → 0 files, confirmed on the real
   github.com/manhquydev/flow-skill repo, 276 tracked files total) — the red-team's "gitignore
   the bundle" fix target did not need creating, it already existed. No `git rm --cached` step
   was needed; no `test/bundle-untracked.test.mjs` was written (would have asserted an
   already-true fact). The REAL remaining gap was narrower than diagnosed: (a) the local
   untracked bundle was stale content on disk, (b) the manifest leaked an absolute path, (c) no
   `pretest` wiring existed, (d) no release had been cut since v0.22.
3. Ran `npm run sync` to refresh the local untracked bundle → confirmed v0.22.0 content present
   (`concierge.md`, `native-rituals.md`, `forge-idea.md`, `SKILL.md` version 0.22.0, 74 files).
4. **RED→GREEN** — `test/sync-manifest.test.mjs` (new) asserts `skills-manifest.json.source` is
   never an absolute path. Fixed `scripts/sync.mjs` to emit `'../skills/flow'` (or a literal
   override marker) instead of the `resolve()`d absolute path.
5. Added `"pretest": "node scripts/sync.mjs"` to `package.json` so `npm test` self-heals a
   missing/stale local bundle on a fresh checkout.
6. **Unplanned fix, found during verification:** running the full suite together
   (`npm test` = 5 files) intermittently failed one pre-existing dry-run test with an
   unexplained exit code 3 — reproduced 100% in parallel, 0% with `--test-concurrency=1`
   across 3 repeated runs (38/38 green each time). Root cause: Windows child-process
   contention between the two new real-install tests and `lock-atomicity.test.mjs`'s own
   spawns, not a logic bug in any of the three files. Pinned
   `--test-concurrency=1` on the `test` script (cost: negligible, ~1-2s).
7. Bumped `npm-wrapper/package.json` to `0.1.0-rc.2`; wrote the CHANGELOG entry (records
   skillVersion 0.22.0, the A0 fix, the two hardening fixes, and the concurrency pin).
   Documented the operator release command (`git tag npm@0.1.0-rc.2 && git push --tags` →
   `publish-npm-wrapper.yml` runs). Did NOT run it — release stays operator-gated.
8. Full `npm test` green (38/38, 3× repeated) + full root `tests/run_all.sh` green (see journal
   for the exact count) after the `install.sh`/`install.ps1` changes.

## Success Criteria

- [x] **A0**: post-install output emits a restart/reload line for Antigravity, keeping the Codex
      note, in all 3 entry points (cli.mjs, install.sh, install.ps1) — asserted by 2 new
      cli.test.mjs cases + 4 new bash-suite assertions. (The reported-symptom fix.)
- [x] `npm-wrapper/skills/flow/` confirmed untracked + gitignored (pre-existing, verified not
      newly done — see plan-correction note above).
- [x] `npm test` green via `pretest` sync from a state where the local bundle was stale/absent.
- [x] `skills-manifest.json` `source:` no longer an absolute local path (`test/sync-manifest.test.mjs`).
- [x] CHANGELOG records skillVersion 0.22.0; version bumped to 0.1.0-rc.2; release command
      documented (not run).
- [x] `skills/flow/**` untouched; test count grew 35→38 (2 A0 tests + 1 manifest test), all green.

## Rollback

Revert = restore tracking (`git add npm-wrapper/skills/flow`), revert `.gitignore`,
`package.json`, `sync.mjs`, `CHANGELOG.md`, delete the new test. No published artifact touched
(release is a separate operator action).

## Risk Assessment

- Symptom is non-detection, not staleness → step 1 blocking gate catches this before any release.
- gitignore breaks a contributor's local `npm test` on fresh checkout → `pretest` sync mitigates;
  documented in README/CONTRIBUTING.
- Publishing prematurely → release stays operator-gated via the `npm@<ver>` tag; this phase only
  documents the command.
