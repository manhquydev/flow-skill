---
phase: 3
title: Live-runner verification + docs
status: completed
effort: 0.5 day
priority: P2
dependencies:
  - 2
---

# Phase 3: Live-runner verification + docs

## Overview

Prove each newly-claimed agent actually RUNS flow (not just receives files), then update docs
with only the evidence-backed claims. This is the operator's hard gate: no "supported" claim
without a live runner test.

**Decoupling (red-team H3/M2):** the Phase 1 staleness release is INDEPENDENT and already
shippable — it does NOT wait on this phase. This phase gates only the CURSOR support claim.
One rule resolves the earlier gate contradiction: a failed Cursor runner test is NOT a
rollback — it downgrades the doc claim to "installs; runner unverified"; it never blocks the
Phase 1 release.

## Requirements

- Functional: **Cursor live-runner test** — with flow installed to the Phase-2-confirmed Cursor
  skill path, drive Cursor to run `flow.sh status` on a scratch project and confirm (a) exit
  code is honored, (b) Cursor reads `SKILL.md` (asks it to describe `/flow`, like the
  Antigravity `agy -p` check). Record the transcript/result as evidence.
- Functional: **universal reach honesty** — for `~/.agents/skills/` reach (Copilot/VS Code,
  Gemini CLI), verify per-tool live OR do not claim them. Docs list only tools with recorded
  evidence; everything else is "installs to the universal home; runner unverified".
- Functional: docs — CHANGELOG entry (npm-wrapper release notes), README EN/VN target table +
  the "just chat / universal Agent-Skills" framing, `--help` already updated in Phase 2.
- Non-functional: the release itself (npm publish via `npm@<ver>` tag) is **operator-triggered**
  — this phase documents the exact command + preconditions, does not run it.

## Architecture

Verification mirrors the proven Antigravity method: build the real install, then use the
agent's own headless/interactive entry to (1) execute the runner and (2) confirm SKILL.md
discovery. Evidence goes in the CHANGELOG + a journal note, same as the v0.22 cross-vendor
spot-check. Docs are updated LAST, after evidence exists, so no claim outruns proof.

## Related Code Files

- Modify: `npm-wrapper/CHANGELOG.md` (release notes + live-runner evidence)
- Modify: `README.md`, `README_VN.md` (target table: add Cursor + universal `~/.agents`;
  evidence-gated support claims)
- Create: `docs/journals/260717-cross-agent-installer-expansion-vi.md` (session journal +
  verification transcripts summary)
- Reference only (not modified here): `.github/workflows/publish-npm-wrapper.yml` (release path)

## Implementation Steps — AS ACTUALLY EXECUTED

1. Installed to Cursor for real (scratch-`$HOME`, `node bin/cli.mjs --yes -t cursor`) — content
   confirmed at `~/.cursor/skills/flow`.
2. **Cursor live-runner test: ATTEMPTED, honestly could not complete headlessly.** `cursor
   agent --help` and `-h` both fall through to the generic IDE-flag help — no `-p`/`exec`
   print-mode subcommand exists on this Cursor version (3.9.16), unlike Antigravity's `agy -p`
   or Codex's `codex exec`. No GUI-automation tool in this session is suited to reliably drive
   a native (non-Chromium) desktop app's chat panel. Per the plan's own §Risk Assessment ("a
   failure here is a documented 'unverified', not a defect"), this is the honest outcome, not a
   defect to paper over — recorded as such in README/CHANGELOG (done proactively during Phase 2
   rather than deferred here, since it was directly load-bearing for those edits).
3. Second-agent (Copilot/VS Code, Gemini CLI) verification: not attempted — out of the operator's
   chosen priority list for this round (brainstorm decision: Cursor + universal-via-`~/.agents`
   only). Docs make no claim about them individually.
4. CHANGELOG + README EN/VN (root + npm-wrapper, EN+VN = 4 files) updated with evidence-backed
   claims only: Antigravity = live-verified (real `agy -p` SKILL.md read, from the v0.22 session);
   Cursor = install-verified via real scratch-HOME test, runner execution explicitly marked
   unverified with the reason given.
5. Journal note written: `docs/journals/260717-cross-agent-installer-expansion-vi.md`.
6. Release command already documented in `npm-wrapper/CHANGELOG.md`'s rc.2 entry
   (`git tag npm@0.1.0-rc.2 && git push --tags`); precondition = `npm test` green (confirmed
   41/41 × 3 repeated runs) + root `tests/run_all.sh` green (confirmed — see journal). Not run.

## Success Criteria

- [x] Cursor live-runner evidence **attempted and honestly recorded as unattainable headlessly**
      on this machine/Cursor version — not silently skipped, not overclaimed.
- [x] README EN/VN (root + npm-wrapper, 4 files) + CHANGELOG updated; every "supported" claim
      has recorded evidence (Antigravity), Cursor explicitly marked "installs; runner
      unverified" with the concrete reason (no headless CLI found).
- [x] Journal note written.
- [x] Operator release command + preconditions documented (not executed).
- [x] No skill-content change (`skills/flow/**` untouched throughout); full `npm test` green
      (41/41 × 3) + root bash suite green.

## Rollback

Docs-only + evidence notes → `git checkout` of README*/CHANGELOG, delete the journal file. No
runtime artifact. If Cursor verification fails, the honest outcome is "installs; runner
unverified" in docs — not a rollback but a truthful downgrade of the claim.

## Risk Assessment

- Cursor runner may not honor exit codes in its sandbox → the plan's whole point is to find
  this BEFORE claiming support; a failure here is a documented "unverified", not a defect.
- Second-agent verification may be impossible locally (no Copilot/Gemini-CLI runner handy) →
  acceptable; claim only what's proven, count verified tools honestly.
- Publishing prematurely → release is operator-gated and out of this phase's scope by design.
