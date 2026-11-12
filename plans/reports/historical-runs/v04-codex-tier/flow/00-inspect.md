# Stage 00-inspect — Brownfield assessment (existing codebase)

Run this BEFORE planning when the project ALREADY EXISTS. Goal: an honest current-state map so
planning starts from reality, not a blank page.

## Gate — check ALL before planning
- [x] I detected the stack / build / test / run commands (from real files; listed below)
- [x] I mapped the main components/modules and entry points
- [x] I assessed current functionality state (works / partial / broken) with file evidence
- [x] I assessed UI/UX state vs the product's stated goals (or noted "no UI")
- [x] I listed the top risks / tech-debt / known issues
- [x] I noted the test + quality baseline (what is covered vs not)
- [x] A human reviewed this assessment (brownfield assessment is operator-gated)
- [x] No FILL placeholders remain in this file

## Detected (auto-scan)
- **Type:** `skill` (a Claude Code agent-skill product). done-evidence = installed into
  `~/.claude/skills` + a real `/flow` run reaches its own done-definition.
- **Languages:** Bash (gate engine, 1076 LOC `runner/flow.sh`), Python stdlib (durable layer,
  794 LOC across `flow_harness.py`/`_db.py`/`_domain.py`), Markdown (14 semantic references,
  7 templates, 3 law files, 4 playbooks).
- **Build/run:** no compile step. Install via `install.sh`/`install.ps1`. Run via
  `bash skills/flow/runner/flow.sh <cmd>`.
- **Test:** `bash tests/run_all.sh` (14 dev suites) + `tests/e2e-installed-drive.sh`.
- **CI:** GitHub Actions matrix (ubuntu/macOS/windows), 115 checks/OS.
- **Context files:** README.md, README_VN.md, docs/ (codebase-summary, system-architecture,
  quality-metrics), portable-manifest.json.

## What this product is (from docs/specs/code, not guesses)
`/flow` is a gated build harness: it walks a product from Idea→Research→Scope→PRD→ADR→Contract
→Cards→Build→Review→Deploy→Verify→Retro, with an honest mechanical+semantic gate at each step
(idea → a *deployed URL / installs+runs*, not idea to paperwork). It is two layers: a
deterministic shell runner (`flow.sh`, exit 0/1) and a semantic gatekeeper (Claude via SKILL.md).
For: builders who want discipline + real done-evidence over vibes.

## Current functionality state (evidence)
- **Gate engine** — works. `runner/flow.sh` (1076 LOC): stage lifecycle, FILL/checkbox/evidence
  checks, card validation, `assess`, `tokens`, `coherence`, `contract`, `doctor`, concurrency
  lock. Covered by tests.
- **Durable layer** — works. `harness/flow_harness.py` (521 LOC): intake/story/trace/decision/
  backlog into `.flow/harness.db` (sqlite). 19 harness-suite checks.
- **Agent orchestration** — works, **but vendor-narrow.** `references/agent-detection.md` +
  `agent-stage-mapping.md` define a 3-tier ladder: **ck: agents → bmad-* skills → built-in
  fallback** (`agent-detection.md:15-21`). Every tier is a *Claude-model* drafter. There is **no
  cross-vendor / second-engine path** — when a ck: agent is BLOCKED twice the only escalation is
  "fresh subagent or operator" (`agent-detection.md:31-32`); same model, same blind spots.
- **AUTO run** — works. `references/auto-run.md`: Tier-A/B/C, two-strikes, worktree, AUTO-LOG,
  security-class halt. Tier-B repair = "one FRESH subagent" — again same-model only.

## UI / UX state vs product goals
No GUI. The "interface" is the `/flow` command surface (SKILL.md §Commands) + `flow.sh` stdout.
UX goal = legible gates + honest verdicts; met. N/A for this feature.

## Risks / tech-debt / known issues
1. **Single-vendor reviewer blind spot (the gap this feature targets).** The adversarial Review
   gate (`references/adversarial-review.md`, 3-layer Blind/Edge/Acceptance Hunter) runs entirely
   on the same model that built the card → correlated misses. No independent-model check.
2. **Version coherence drift.** `SKILL.md` metadata says `version: 0.2.0`; git tag is `v0.3.0`;
   `docs/quality-metrics.md` says v0.2. The skill *ships a coherence checker* yet drifts itself.
3. **No real-machine mac/linux run** of the suite (CI matrix covers it; local is Windows-only).

## Test + quality baseline
- 14 dev suites via `tests/run_all.sh`; quality-metrics.md records **93 dev + 22 e2e = 115**
  checks, green on 3 OS in CI. (This session re-runs the suite to confirm the live baseline.)
- Durable metrics scaffold exists (`docs/quality-metrics.md`): gate false-pass/block, card
  first-pass rate, dogfood close rate. This feature must add its own dogfood findings here.

## Verdict
**Healthy — build on it.** No blocking debt. The Codex/cross-engine extension is additive:
it slots a new vendor path into the existing detection ladder + review gate + auto Tier-B
without touching the mechanical runner. Nothing must be fixed first; the version-coherence
drift (#2) is worth correcting opportunistically since this feature bumps the version anyway.

<!-- auto-scan -->
stack:
  - CI: github actions (.github/workflows)
context files present:
  - README.md
  - docs
  - tests
