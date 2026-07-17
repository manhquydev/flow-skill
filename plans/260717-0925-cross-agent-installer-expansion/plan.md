---
title: >-
  flow-skill installer: cross-agent expansion (staleness fix + Cursor +
  universal Agent-Skills)
description: >-
  Fix npm release staleness (no release cut since v0.22) + add Cursor install
  target + reframe ~/.agents/skills as the universal Agent-Skills home. Zero
  skill-content change — Agent Skills is now an open standard flow already
  conforms to. Every claimed agent gated by a live flow.sh runner test.
status: completed
priority: P1
branch: master
tags:
  - flow-skill
  - npm-wrapper
  - installer
  - cross-agent
  - tdd
blockedBy: []
blocks: []
created: '2026-07-17T02:34:57.627Z'
createdBy: 'ck:plan'
source: skill
---

# flow-skill installer: cross-agent expansion (staleness fix + Cursor + universal Agent-Skills)

## Overview

Operator-approved (brainstorm report:
`D:\project\flow\flow-skill\plans\reports\brainstorm-260717-0925-cross-agent-installer-expansion-report.md`).
**Revised after red-team (3 hostile reviewers, 22 raw → 13 accepted, 1 rejected) + 2 operator
decisions** — see `## Red Team Review`. Two workstreams, in order:

- **WS-A** — TWO distinct problems, separated after validation confirmed the symptom:
  - **A0 (the operator's ACTUAL symptom — primary fix, validation V1):** users install to
    Antigravity via `npx`, open Antigravity, type `/flow`, and see NOTHING — because a
    newly-installed skill is not discovered until the agent is restarted/reloaded, and the
    post-install message tells only Claude + Codex users what to do (cli.mjs:350, install.sh:68
    both omit Antigravity entirely). This is a **discovery/UX gap, NOT staleness**. Fix = add
    per-agent "restart/reload to load the skill" guidance to the post-install output for every
    non-Claude target (Antigravity, Codex already partial, Cursor). Small, high-value, and the
    real answer to "cài rồi mà /flow không hiện".
  - **A1 (staleness housekeeping — secondary):** published rc.1 is a functional v0.21, missing
    v0.22 content (concierge etc.). Worth shipping v0.22 so installs are current, but this is
    NOT the fix for the reported symptom. Anti-drift = **gitignore the committed bundle +
    manifest** (validation V2: sync artifacts, `prepack`/publish regenerate them) — kills the
    CI-no-op version-guard red-team found. `npm test` gets a `pretest` sync (validation V3).
    Then cut a v0.22.x release (operator-gated tag).
- **WS-B Cross-agent targets**: add **Cursor** to `TARGETS` and reframe the existing **agents**
  target (`~/.agents/skills/flow`) as the universal Agent-Skills home. **Cursor's real
  skill-discovery path + frontmatter tolerance is live-probed FIRST** (red-team F4/H4: the
  "already conforms → just add a destination" premise is web-research, not repo-proven; only
  name+description are the spec-minimal universal pair, the other 6 frontmatter keys are
  Claude-flavored and a stricter parser's tolerance is unverified). Zero skill-content change.

**KEY FACT that shrinks the whole job**: Anthropic Agent Skills is an OPEN STANDARD
(agentskills.io, 2025-12-18, Agentic AI Foundation); 32–40 tools read the same SKILL.md from
the same dir shape. flow's SKILL.md already conforms (that's why Codex/Antigravity already
work). So "support more agents" = **add install destinations + tests**, never a content
adapter.

**Gating discipline (operator decision)**: the real unknown is NOT file format (solved by the
standard) — it's whether an agent's sandbox lets `flow.sh` execute and return exit codes. So
NO agent is claimed "supported" until a **live runner test** (install → run `flow.sh status`
inside that agent → confirm exit code + the agent reads SKILL.md, exactly as done for
Antigravity via `agy -p`). Un-verified agents get "installs; runner unverified", never a
support claim.

Work root: `D:\project\flow\flow-skill\npm-wrapper` (35 node:test cases across 4 files). TDD:
each phase writes/extends its failing test first, then the config, then green.

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Restart-guidance symptom fix + release freshness via gitignore (TDD)](./phase-01-release-freshness-sync-guard-cut-v0-22-npm-release-tdd.md) | Completed |
| 2 | [Cursor path spike + target + universal reframe + count fixes (TDD)](./phase-02-cursor-target-universal-agents-reframe-tdd.md) | Completed |
| 3 | [Live-runner verification + docs](./phase-03-live-runner-verification-docs.md) | Completed |

Dependency chain: 1 → 2 → 3, but **loosely coupled** (red-team H3): Phase 1 (restart-guidance
symptom fix + staleness housekeeping) is independently shippable and does NOT wait on Phase 2/3
Cursor work. Phase 1's A0 restart-guidance fix is the smallest, highest-value slice and can ship
first on its own. Phase 2 live-probes Cursor's real path before hardcoding it; Phase 3 proves the
runner runs before any support claim.

## Acceptance criteria (whole plan)

0. **(Primary — the reported symptom)** Post-install output tells non-Claude users how to make
   `/flow` appear: Antigravity + Cursor + Codex each get an explicit "restart/reload the agent to
   load the newly-installed skill" line (cli.mjs:350, install.sh:68). A user who installs to
   Antigravity is no longer left with a silent `/flow`-not-found.
1. `npx @manhquy/flow-skill@rc` installs **v0.22** content (SKILL.md `version: "0.22.0"` +
   `references/concierge.md` present) to a target — verified on the actually-published package.
2. `npm-wrapper/skills/flow/` is **gitignored** (operator decision); `prepack`/publish still
   materialize it via `npm run sync`; `npm test` documents the "run sync first" precondition.
   Drift is structurally impossible — no committed bundle to drift (kills the CI-no-op guard +
   grep-anchoring + test-path bugs red-team found in the version-guard approach).
3. Cursor's real skill-discovery path is **live-confirmed** before it is hardcoded (red-team
   H4 — not assumed `~/.cursor/skills/flow`); detection uses a **skills-subdir marker**
   (`.cursor/skills`, NOT bare `.cursor` — red-team C1), so a Claude-only `--yes` install never
   silently drops flow into an unrelated Cursor config dir.
4. `~/.agents/skills/flow` reframed as the universal Agent-Skills home in `--help`/README/label
   — a one-line reframe folded into Phase 2, not a co-equal workstream (red-team M4).
5. **Every "supported" claim has live-runner evidence** (ran `flow.sh status` inside that agent,
   confirmed it reads SKILL.md — the Antigravity `agy -p` method). No evidence → "installs;
   runner unverified". Count only verified tools, never the 32-40 total.
6. All ten "4 targets" literals updated to 5 / derived from `TARGETS.length` (red-team H5 full
   list); **README.md:285 ("four independent mode axes") left untouched** (unrelated to targets).
7. `skills-manifest.json` no longer ships an absolute local Windows path in `source:` (red-team
   M3) — relative or dropped.
8. No skill-content file (`skills/flow/**`) modified — installer/config/docs only. Existing 35
   tests (across 4 files incl. lock-atomicity) stay green + new Cursor tests pass.

## Dependencies

- None blocking. Related shipped plan: `260712-0219-flow-skill-npx-installer` (the original
  4-target installer this extends). Not re-opened.

## Key source files

- `npm-wrapper/src/constants.mjs` — `TARGETS` array (add cursor; reframe agents label)
- `npm-wrapper/src/detect.mjs` — marker detection (generic; likely no change)
- `npm-wrapper/src/installer.mjs` — `install()` generic copy + `installAntigravity()` multi-dest
- `npm-wrapper/src/help.mjs` — `--help` target list + notes
- `npm-wrapper/bin/cli.mjs` — arg parse, target routing
- `npm-wrapper/test/{detect,installer,cli}.test.mjs` — 35 cases; add cursor cases
- `npm-wrapper/scripts/sync.mjs` — dev sync; `npm-wrapper/skills-manifest.json` (fileCount guard)
- `.github/workflows/publish-npm-wrapper.yml` — publish (already auto-syncs); `.github/workflows/ci.yml` — pre-merge guard home
- `npm-wrapper/package.json` — version bump target
- `README.md`, `README_VN.md`, `CHANGELOG.md` — docs

## Risks (top)

- **Staleness fix doesn't fully explain operator's Antigravity symptom** — the published rc.1
  is functional v0.21, so "doesn't work" may be a different issue. Phase 1 must confirm the
  concrete symptom (ask operator for the exact error / re-run with `--json`) rather than
  assume the release cut alone fixes it.
- **Universal `~/.agents/skills/` reach over-claimed** — research confirms Cursor + Devin read
  it; Copilot/VS Code + Gemini CLI support SKILL.md but their exact discovery path is
  unverified. Claim only tools with live evidence; count verified tools, not the 32–40 total.
- **Cursor runner sandbox** — Cursor runs bash/py/js per docs, but exit-code capture must be
  live-verified (Phase 3), not assumed.
- **Anti-drift = gitignore** (operator decision, red-team C2/M1): the version-guard approach
  was a CI no-op (CI syncs before testing) with a grep-anchoring bug (`version:` is indented
  under `metadata:`) and a test-path bug (`../skills/flow` from test/ hits the bundle not root).
  gitignore sidesteps all three: no committed bundle → nothing to drift.

## Red Team Review

### Session — 2026-07-17
**Reviewers:** Assumption Destroyer, Failure Mode Analyst, Scope/YAGNI+Supply-chain (3×
code-reviewer subagents, Standard tier). **Findings:** 22 raw → 13 accepted after dedup
(2 Critical, 5 High, 6 Medium), 1 rejected. All accepted carried file:line evidence.
**Operator decisions:** (1) anti-drift = gitignore bundle (not version guard); (2) add a
per-phase verify spike (confirm symptom + live-probe Cursor path) before building.

| # | Finding | Severity | Disposition | Applied |
|---|---------|----------|-------------|---------|
| C1 | bare `.cursor` marker → false-positive auto-install into every Cursor user's config (matches the `~/.gemini` bare-marker trap antigravity already dodges) | Critical | Accept — marker `.cursor/skills` | Phase 2 |
| C2 | sync-freshness guard is a CI no-op (CI runs `npm run sync` before `npm test`) — triple-confirmed by all 3 reviewers | Critical | Accept — gitignore bundle instead | Phase 1 |
| H1 | `version:` grep anchoring (`^version:` matches nothing — indented under `metadata:`) | High | Accept — mooted by gitignore (no grep guard) | Phase 1 |
| H2 | RED test path `../skills/flow` from test/ resolves to bundle not root → never RED | High | Accept — mooted by gitignore (no version test) | Phase 1 |
| H3 | staleness release (blocker) coupled to Phase 3 Cursor verify (which may be locally impossible) → users stuck on v0.21 | High | Accept — release decoupled, ships after Phase 1 | Phase 1 |
| H4 | core premise (agentskills conformance + Cursor's `~/.cursor/skills/flow` path) unverified, presented as fact | High | Accept — Phase 2 live-probes Cursor path first | Phase 2 |
| H5 | "4→5" count: only 1/10 consumers enumerated | High | Accept — full 10-item list, README:285 excluded | Phase 2 |
| M1 | version guard over-engineered for a non-runtime concern | Medium | Accept — gitignore, no bespoke guard | Phase 1 |
| M2 | gate contradiction between phase-01 and phase-03 | Medium | Accept — one rule: release not gated on Cursor verify | Phases 1,3 |
| M3 | `skills-manifest.json` ships an absolute local Windows `source:` path in the tarball | Medium | Accept — relative or dropped | Phase 1 |
| M4 | universal `~/.agents` reframe inflated to a co-equal workstream (it's one label string) | Medium | Accept — folded into Phase 2 | Phase 2 |
| M5 | wrapper-version vs skill-version disjoint → drift can recur under a new rc | Medium | Accept — record skillVersion in CHANGELOG/manifest | Phases 1,3 |
| M6 | operator's Antigravity symptom unconfirmed; rc.1 is functional v0.21 so symptom may be non-detection, not staleness | Medium | Accept — Phase 1 blocking symptom-confirm gate | Phase 1 |
| — | rt2-scope F2 "concierge.md does not exist" | — | **Reject** — file exists at `skills/flow/references/concierge.md` (reviewer Glob'd the stale v0.21 bundle); path-precision noted → acceptance cites the references/ path | — |

### Whole-Plan Consistency Sweep
- Files reread: plan.md, phase-01…03 (being rewritten to match)
- Decision deltas: 13 findings + 2 operator decisions (gitignore, verify-spike)
- Reconciled: guard→gitignore everywhere; `.cursor`→`.cursor/skills`; release decoupled from
  Cursor; count-fix enumerated (10, minus README:285); manifest source-path fix; premise
  re-labeled unverified-pending-spike
- Unresolved contradictions: 0 (phase files updated in same pass)

## Validation Log

### Session 1 — 2026-07-17 (post-red-team interview, 3 questions)

- **V1 Symptom = discovery/restart, NOT staleness (reframes Phase 1).** Operator: users install
  to Antigravity, open it, type `/flow`, see no skill — "hay họ phải restart thiết bị nhỉ?".
  VERIFIED: both installers' final message (cli.mjs:350, install.sh:68) tell only Claude + Codex
  users what to do; Antigravity gets no post-install guidance, and a newly-installed skill is not
  discovered until the agent reloads. → Phase 1 PRIMARY fix = add restart/reload guidance for
  non-Claude agents. The v0.22 release is demoted to secondary housekeeping (does NOT fix the
  reported symptom). This is exactly the non-detection diagnosis red-team F5/M6 predicted; the
  "confirm symptom first" gate paid off.
- **V2 Manifest = gitignore.** `skills-manifest.json` (currently leaks an absolute local Windows
  `source:` path into the npm tarball) is a sync artifact like the bundle → gitignore both;
  `prepack`/publish regenerate them. Removes two drift/leak artifacts at once. → Phase 1.
- **V3 Local test = `pretest` sync.** gitignoring the bundle means `npm test` needs it present;
  add `pretest: npm run sync` so contributors just run `npm test` (≈1s sync cost) rather than
  remembering a manual step. → Phase 1.

### Verification Results
- Covered by Red Team Review 2026-07-17 (guard: verification-pass skipped, evidence present).
- Additional this session: installer post-install messaging omits Antigravity — VERIFIED
  (cli.mjs:350, install.sh:68). Claims checked: 1 | Verified: 1 | Failed: 0.

### Whole-Plan Consistency Sweep (post-validation)
- Files reread: plan.md, phase-01…03.
- Decision deltas: V1 (symptom reframe → Phase 1 primary = restart guidance), V2 (manifest
  gitignore), V3 (pretest sync).
- Reconciled: WS-A split into A0 (restart guidance, primary) + A1 (staleness housekeeping,
  secondary); acceptance criterion 0 added; Phase 1 title/body updated to lead with the
  restart-guidance fix; "blocker/staleness" language throughout softened to "housekeeping".
- Unresolved contradictions: 0 (Phase 1 file updated same pass).
