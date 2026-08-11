# Journal — v0.26.0 hollow-done + npm 0.3.0 (2026-08-11)

## What shipped
- Skill **0.26.0**: mechanical multi-signal done Evidence floor; ready/graph re-validate;
  card-done fail-closed; fcdc residual fixture; 48 suites.
- npm-wrapper **0.3.0**: re-sync skill tree; publish to **`latest`** so
  `npx @manhquy/flow-skill@latest` installs the new skill.

## How
1. Plan → red-team → validate → cook `--tdd` → independent review `--fix --parallel`.
2. Version coherence: SKILL.md + plugin.json + portable-manifest = 0.26.0; npm package = 0.3.0.
3. Docs: CHANGELOG, README(_VN), quality-metrics, npm CHANGELOG/README, release journal.
4. `bash scripts/release-preflight.sh` + `bash tests/run_all.sh` + `npm test` in npm-wrapper.
5. Commit → push master → tag `npm@0.3.0` → GHA OIDC publish → verify dist-tags + npx.

## Residual honesty
Floor is not a ceiling: staging URL + PASS log can still mechanical-pass (fcdc / semantic offline).
Do not claim “auto cannot hollow-done.”

## Install for users
```bash
npx @manhquy/flow-skill@latest
# help: flow-skill v0.3.0 (ships skill v0.26.0)
```
