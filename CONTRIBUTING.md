# Contributing to flow

`flow` is a solo-maintained project right now. Issues and PRs are welcome; there is no
formal governance process yet — it will grow if/when contribution volume needs it.

## Running the test suite

```
bash tests/run_all.sh
```

Add new coverage as `tests/test_flow_<area>.sh` (see existing files for the pattern) when
you touch `runner/flow.sh` or `harness/`. The suite must pass on Windows (Git Bash), macOS,
and Ubuntu — avoid GNU-only flags (`grep -P`, `\b` in `grep -E`) since macOS ships BSD grep.

CI runs the full suite on three OSes; **Windows Git Bash is much slower** (~18–25 min for the
full matrix cell). Prefer not adding multi-second `sleep` loops unless the test is specifically
about timeouts. Per-suite timing is printed as `wall_s=` in `run_all.sh` output.

npm-wrapper tests:

```
cd npm-wrapper && npm test
```

## Conventions

- kebab-case for shell/markdown filenames; Python uses snake_case.
- YAGNI / KISS / DRY — prefer small focused changes over speculative abstraction.
- Never edit `_templates/` or a live project's `flow/`/`cards/` state by hand during a run —
  those are the runner's contract with the operator.
- Keep **skill product** versions in sync:
  - `skills/flow/SKILL.md` → `metadata.version`
  - `.claude-plugin/plugin.json` → `version`
  - `portable-manifest.json` → `version`  
  `/flow coherence` checks this. Do **not** set npm package version equal to skill product
  version by default — they are separate axes (see below).

## Two version axes

| Axis | Bump when | Example |
|---|---|---|
| Skill product | runner / harness / references behavior | `0.22.0` in SKILL.md |
| npm installer (`npm-wrapper/package.json`) | installer CLI, targets, publish pipeline | `0.1.0-rc.3` |

End users install with `npx @manhquy/flow-skill@rc` (not bare `npm i` alone).  
Full release procedure: [`docs/release-process.md`](docs/release-process.md).  
npm auth / dist-tag ops: [`npm-wrapper/RELEASE_CHECKLIST.md`](npm-wrapper/RELEASE_CHECKLIST.md).

## Pull requests

- Describe what changed and why, not just what.
- Link the issue if one exists.
- Keep the diff scoped to one concern.
- If you change skill content that ships in the npm tarball, note that a later **npm-wrapper**
  release (`npm run sync` + tag `npm@…`) is required for registry users to receive it.

## Reporting a security issue

See `SECURITY.md` — do not open a public issue for a vulnerability.

## Code of conduct

Be respectful, assume good faith, no harassment. Issues that don't meet this will be closed.
