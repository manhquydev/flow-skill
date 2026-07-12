# @manhquy/flow-skill

One-command installer that copies the [flow](https://github.com/manhquy/flow-skill) skill into your coding agent(s).

- Pure Node — works on macOS, Linux, and Windows (cmd, PowerShell 5.1/7, Git Bash) with the same code path.
- Interactive multi-select or non-interactive CI mode.
- Preserves any user-added files in the destination outside the 6 subdirs the skill owns.
- Ships with [npm provenance](https://docs.npmjs.com/generating-provenance-statements) via GitHub Actions trusted publishing.

## Install

```
# Pin the semver range (recommended)
npx @manhquy/flow-skill@0.1.x
```

An interactive prompt asks which agents to install to. Pick one or more, confirm, done.

> **Note**: pin `@0.1.x` (or a specific version) rather than `@latest`. See [SECURITY.md](./SECURITY.md).

## Non-interactive

```
# Default selection (Claude + anything detected)
npx @manhquy/flow-skill@0.1.x --yes

# Explicit targets
npx @manhquy/flow-skill@0.1.x --yes -t claude -t codex
npx @manhquy/flow-skill@0.1.x --yes -t claude,codex           # comma form OK

# Force all four targets even if not detected
npx @manhquy/flow-skill@0.1.x --yes --all

# Project scope (Claude only — see below)
npx @manhquy/flow-skill@0.1.x --yes --project --dir .

# CI-friendly JSONL output
npx @manhquy/flow-skill@0.1.x --yes --all --dry-run --json
```

## Targets

| Name | Label | Destination | Detection marker |
|---|---|---|---|
| `claude` | Claude Code | `~/.claude/skills/flow` | any presence of `~/.claude` (Claude is always pre-checked) |
| `codex` | Codex CLI | `~/.codex/skills/flow` | `~/.codex/skills` |
| `agents` | Agents home | `~/.agents/skills/flow` | `~/.agents/skills` |
| `antigravity` | Antigravity (CLI + IDE) | `~/.gemini/antigravity-cli/skills/flow` **and** `~/.gemini/config/skills/flow` | `~/.gemini/antigravity-cli` **or** `~/.gemini/config/skills` |

`--project` scope writes to `<dir>/.claude/skills/flow` and supports only the `claude` target. Combining `--project` with a non-Claude target exits with code `2`.

## After install

- Claude Code: type `/flow`.
- Codex CLI: type `$flow` (restart Codex once to load).
- Antigravity: `/flow` in the IDE.
- Diagnostics: run `/flow doctor` from your agent.

## Uninstall

Delete the target directories:

```
rm -rf ~/.claude/skills/flow
rm -rf ~/.codex/skills/flow
rm -rf ~/.agents/skills/flow
rm -rf ~/.gemini/antigravity-cli/skills/flow
rm -rf ~/.gemini/config/skills/flow
```

## JSONL contract

`--json` streams one JSON object per line:

```jsonl
{"event":"plan","version":"0.1.0-rc.1","dryRun":false,"scope":"global","targets":["claude","codex"]}
{"event":"install:start","target":"claude","dests":["~/.claude/skills/flow"]}
{"event":"install:done","target":"claude","dests":["~/.claude/skills/flow"],"result":"success","error":null,"warnings":[]}
{"event":"summary","success":true,"total":2,"attempted":2,"installed":2,"failed":0,"skipped":0,"aborted":false}
```

`--json --dry-run` emits only the `plan` event. `--json` implies non-interactive; do not combine with a TTY prompt session.

## Requirements

- Node.js **>= 20.11.0** (uses `import.meta.dirname` and `node:util.parseArgs`)

## Provenance

Every published version has [npm provenance](https://docs.npmjs.com/generating-provenance-statements) attestations:

```
npm view @manhquy/flow-skill@<version> dist.attestations.provenance
```

## Security

See [SECURITY.md](./SECURITY.md) for the threat model, what the installer will and will not do, and how to report issues.

## License

MIT © 2026 manhquy
