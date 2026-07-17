---
phase: 2
title: Cursor path spike + target + universal reframe + count fixes (TDD)
status: completed
effort: 0.5-1 day
priority: P1
dependencies:
  - 1
---

# Phase 2: Cursor path spike + target + universal reframe + count fixes (TDD)

## Overview

Live-probe Cursor's REAL skill-discovery path before hardcoding it (red-team H4 — the plan's
premise is web-research, not repo-proven), then add Cursor as a 5th target using a
skills-subdir marker (NOT bare `.cursor` — red-team C1), enumerate all ten "4 targets"
literals, and fold the universal `~/.agents` reframe in as a one-liner. Pure config + tests.

## Requirements

- **Blocking spike (red-team H4/F4):** confirm on a real machine where Cursor actually reads a
  user-level skill from — `~/.cursor/skills/`, `~/.agents/skills/`, or both — and that Cursor
  loads flow's SKILL.md despite its Claude-flavored frontmatter keys (user-invocable,
  when_to_use, argument-hint, keywords) rather than rejecting the file. Method = the Antigravity
  approach: install flow to the candidate dir, open Cursor, confirm it lists/loads the skill.
  Hardcode the destTemplate ONLY to the confirmed path. If Cursor reads `~/.agents/skills/`
  (which flow already targets), the "new" work may be smaller than a new dir.
- Functional (red-team C1): new `TARGETS` entry `cursor` — marker **`.cursor/skills`**
  (skills-subdir, NOT bare `.cursor` which every Cursor user has → would false-positive
  `detected:true` and silently auto-install under `--yes`, the exact `~/.gemini` trap
  antigravity dodges at constants.mjs:32). destTemplate = the Phase-2-confirmed path.
  `alwaysInclude: false`, `projectScopeAllowed: false` (parity with codex/agents).
- Functional (red-team M4): reframe the `agents` target LABEL to name it the universal
  Agent-Skills home + one `--help` note that spec-compliant tools read `~/.agents/skills/`.
  One label string + one help line — not a workstream.
- Functional (red-team H5): update ALL ten "4 targets" literals → 5, or derive from
  `TARGETS.length`. Full list (rt2-failure, verified): `help.mjs:15`, `help.mjs:33`,
  `constants.mjs:1` (comment), `prompt.mjs:6` (comment), `cli.test.mjs:28` (test name),
  `cli.test.mjs:37` (test name), `cli.test.mjs:45` (the real deepEqual assertion),
  `README.md:167`, `README.md:172`, `README_VN.md:31`. **Do NOT touch `README.md:285`**
  ("four independent mode axes" — unrelated to targets).
- Non-functional: zero change to `install()`/`installAntigravity()`/`detect.mjs` LOGIC
  (verified generic — installer.mjs:119, cli.mjs:303-308); zero skill-content change.

## Architecture

`detect.mjs`/`installer.mjs` iterate `TARGETS` and resolve `destTemplates` generically, so
Cursor (single-dest, like codex) rides the existing `install()` path — no new copy logic, and
it inherits the existing `assertNoSymlinks` + lock guards (verified target-independent). The
ONLY code change is the `TARGETS` array + label/help/count text. `resolveDest` already handles
Windows path-join for `~/` templates (detect.mjs:11-15), so the new dest needs no separator
work.

## Related Code Files — AS ACTUALLY MODIFIED

- Modified: `npm-wrapper/src/constants.mjs` (cursor entry w/ `.cursor/skills` marker + confirmed
  path; agents label reframed universal; header comment 4→5)
- Modified: `npm-wrapper/src/help.mjs` (cursor row auto-appears via existing `TARGETS.map`;
  the 2 literal "4" counts replaced with a derived `TARGETS.length` — so this can't drift again;
  added the universal `~/.agents` note)
- Modified: `npm-wrapper/src/prompt.mjs` (comment de-hardcoded to reference TARGETS instead of
  a magic number, same anti-drift reasoning)
- Modified: `npm-wrapper/test/detect.test.mjs` (2 new cases: bare `.cursor`→not detected [C1
  guard]; `.cursor/skills` present→detected, dest = confirmed path)
- Modified: `npm-wrapper/test/cli.test.mjs` (2 test names 4→5; the real deepEqual assertion
  +cursor; a 3rd real-install test added for cursor's own restart-hint — see phase-01 A0 note
  below, this surfaced a real gap)
- **NOT modified: `npm-wrapper/test/installer.test.mjs`** — scope correction from the original
  plan: Cursor rides the exact same generic single-dest `install()` path already exercised by
  the "happy path"/"idempotent"/"symlink"/"missing SKILL.md" tests using target-agnostic dest
  paths. Adding a Cursor-named duplicate of an already-covered generic path would be a DRY
  violation, not new coverage. Confirmed via `git diff --stat installer.mjs` = empty (byte-unchanged).
- Modified: `README.md`, `README_VN.md` (root — target count + list), plus
  `npm-wrapper/README.md`, `npm-wrapper/README_VN.md` (their OWN separate stale "4 target(s)"
  mentions the original red-team line-number citations didn't catch, found by a repo-wide grep)
- Confirmed untouched: `installer.mjs`, `detect.mjs` (logic), `skills/flow/**`, `README.md:285/287`

## Implementation Steps — AS ACTUALLY EXECUTED

1. **SPIKE (blocking, DONE with real evidence, not assumption):** `cursor` binary + IDE data dir
   found installed on this machine. Live-probed `~/.cursor/skills/` — found a REAL pre-existing
   symlink `~/.cursor/skills/find-skills -> ~/.agents/skills/find-skills`, empirically confirming
   Cursor's actual skill-read location is `~/.cursor/skills/<name>` and that it consumes content
   sourced from the universal `~/.agents/skills/` home. Checked for a headless CLI to also probe
   frontmatter-tolerance/runner-execution the way `agy -p` did for Antigravity — **none found**
   (`cursor agent --help`/`-h` both fall through to the generic IDE flag help, no `-p`/`exec`
   print-mode subcommand discoverable). This honestly limits Phase 3 to a mechanical-install
   proof for Cursor, not a full live-runner proof — carried forward, not hidden.
2. **RED** — 2 new detect.test.mjs cases written and confirmed failing (cursor target absent).
3. **GREEN** — added the `cursor` TARGETS entry with the confirmed marker/path; reframed agents
   label; derived help.mjs's target count from `TARGETS.length`; updated prompt.mjs comment;
   updated README EN/VN in both the root repo and npm-wrapper's own copies.
4. Real (non-dry-run, scratch-`$HOME`) install verified: `--target cursor` writes correct content
   to `~/.cursor/skills/flow`. This surfaced an UNPLANNED real bug: the Done-line printed empty
   (`"Done. "`) for a cursor-only install because Phase 1's `RESTART_HINTS` map (added before
   Cursor existed) had no `cursor` entry. Wrote a RED test for it, fixed with a cursor hint that
   honestly notes the missing headless-verification (see step 1) rather than overclaiming.
5. Repo-wide `grep` (via the Grep tool, not raw bash — a project hook blocks overly-broad raw
   `grep`/`find` patterns) for `4 target|four target|all 4\b` → zero remaining hits;
   `README.md:287` ("four independent mode axes") confirmed untouched separately.
6. Full `npm test` green (41/41), repeated 3× for stability (all real-install + concurrency-pin
   changes from Phase 1 still hold with Cursor added).

## Success Criteria

- [x] Cursor's real path live-confirmed via a real symlink on this machine (not web research);
      destTemplate uses only that confirmed path.
- [x] cursor marker is `.cursor/skills` (subdir); bare-`.cursor`→not-detected asserted (C1 guard).
- [x] All count literals updated to 5 / derived from `TARGETS.length` (help.mjs, prompt.mjs
      comment, both root READMEs, both npm-wrapper READMEs — the latter 2 files were an
      additional finding beyond the original red-team citation list); README.md:287 untouched.
- [x] agents target relabeled universal; `--help` + both READMEs note `~/.agents/skills/`.
- [x] `installer.mjs`/`detect.mjs` logic byte-unchanged (`git diff --stat` empty); `skills/flow/**` untouched.
- [x] Full `npm test` green (41/41 × 3 repeated runs, stable).
- [x] **Honesty carried forward, not swallowed:** Cursor has no headless CLI — README/CHANGELOG
      explicitly say "install verified, live runner execution not yet independently confirmed"
      rather than claiming parity with Antigravity/Codex's live-verified status.

## Rollback

Revert = `git checkout` of constants.mjs, help.mjs, prompt.mjs, README*, and the 3 test files.
No state, no publish, no skill content.

## Risk Assessment

- Cursor's real path ≠ assumed → the spike (step 1) resolves this before any hardcode; a
  surprise path just changes one destTemplate string.
- A stale "4" slips through → step 5 grep gate + the enumerated 10-item list.
- README.md:285 corrupted by a blind 4→5 replace → explicitly excluded + grep-verified it still
  reads "four ... mode axes".
- Cursor rejects flow's frontmatter → discovered in the spike, not after shipping a false claim.
