## What changed and why

<!-- 1-2 sentences. -->

## Scope

- [ ] Flow skill content (`skills/flow/**`)
- [ ] Runner / harness (`flow.sh`, `flow_harness.py`, `install.sh`, `install.ps1`)
- [ ] npm wrapper (`npm-wrapper/**`)
- [ ] CI / release workflow (`.github/workflows/**`)
- [ ] Docs only

## Test evidence

Skill work:
- [ ] `bash tests/run_all.sh` passes locally on: <!-- OS -->

npm wrapper work:
- [ ] `cd npm-wrapper && npm run sync && npm test` — all tests pass (installer, detect, CLI, lock-atomicity)
- [ ] `npm pack --dry-run --ignore-scripts --json` — under 1 MB, no symlinks
- [ ] `git grep -nE "from ['\"]node:child_process['\"]" npm-wrapper/src npm-wrapper/bin` — empty
- [ ] If TOCTOU / retry / lock behavior touched — `test/lock-atomicity.test.mjs` still green

## Breaking changes

<!-- CLI flags, JSONL events, exit codes, skill invocation contract. Empty is fine. -->

## Release impact

<!-- If `npm-wrapper/package.json` bumped, note the tag to push after merge: `npm@<version>`. -->

## Related issue

Closes #

## Anti-checks

- [ ] No credentials, tokens, `.env`, `.npmrc` in the diff
- [ ] No `--no-verify` or hook bypass
