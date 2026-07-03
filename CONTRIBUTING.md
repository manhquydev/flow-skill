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

## Conventions

- kebab-case for shell/markdown filenames; Python uses snake_case.
- YAGNI / KISS / DRY — prefer small focused changes over speculative abstraction.
- Never edit `_templates/` or a live project's `flow/`/`cards/` state by hand during a run —
  those are the runner's contract with the operator.
- Keep `skills/flow/SKILL.md`, `.claude-plugin/plugin.json`, and `portable-manifest.json`
  version fields in sync (`/flow coherence` checks this).

## Pull requests

- Describe what changed and why, not just what.
- Link the issue if one exists.
- Keep the diff scoped to one concern.

## Reporting a security issue

See `SECURITY.md` — do not open a public issue for a vulnerability.

## Code of conduct

Be respectful, assume good faith, no harassment. Issues that don't meet this will be closed.
