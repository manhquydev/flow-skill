# @manhquy/flow-skill

One-command installer that copies the [flow](https://github.com/manhquy/flow-skill) skill into your coding agent(s).

- Pure Node — works on macOS, Linux, and Windows (cmd, PowerShell 5.1/7, Git Bash) with the same code path.
- Interactive multi-select or non-interactive CI mode.
- Preserves any user-added files in the destination outside the 6 subdirs the skill owns.
- Ships with [npm provenance](https://docs.npmjs.com/generating-provenance-statements) via GitHub Actions trusted publishing (from rc.2+).

## Status — 2026-07-12

- ✅ Code complete, 35/35 tests green, CI matrix green (ubuntu/macos/windows × Node 22/24).
- ⏳ Not yet on npm registry. Repo public + renamed; transfer to `manhquy` account pending accept; first publish (`v0.1.0-rc.1`, manual, no provenance) queued.
- ➡️ Once published, this section will disappear and `npx @manhquy/flow-skill@rc` becomes the canonical install path.

## Install

**A. From the git repo (works today, no npm registry needed)**

```bash
git clone https://github.com/manhquydev/flow-skill.git
cd flow-skill/npm-wrapper
npm install
npm run sync          # materializes skills/flow from ../skills/flow
npm link              # exposes `flow-skill` as a global command

flow-skill --yes --all --dry-run --json   # smoke check
flow-skill                                # interactive install
```

To remove: `npm unlink -g @manhquy/flow-skill`.

**B. Via npx (once published)**

```
# Pre-release channel (RC candidate — will exist after first publish)
npx @manhquy/flow-skill@rc
```

An interactive prompt asks which agents to install to. Pick one or more, confirm, done.

> **RC phase**: pin `@rc` (dist-tag) or a specific version like `@0.1.0-rc.1`. `npx @manhquy/flow-skill@0.1.x` will start working after stable `0.1.0` is published — semver ranges do **not** match pre-release tuples by default. See [SECURITY.md](./SECURITY.md).

## Non-interactive

```
# Default selection (Claude + anything detected)
npx @manhquy/flow-skill@rc --yes

# Explicit targets
npx @manhquy/flow-skill@rc --yes -t claude -t codex
npx @manhquy/flow-skill@rc --yes -t claude,codex           # comma form OK

# Force all four targets even if not detected
npx @manhquy/flow-skill@rc --yes --all

# Project scope (Claude only — see below)
npx @manhquy/flow-skill@rc --yes --project --dir .

# CI-friendly JSONL output
npx @manhquy/flow-skill@rc --yes --all --dry-run --json
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
# Global installs
rm -rf ~/.claude/skills/flow
rm -rf ~/.codex/skills/flow
rm -rf ~/.agents/skills/flow
rm -rf ~/.gemini/antigravity-cli/skills/flow
rm -rf ~/.gemini/config/skills/flow

# Project scope (only Claude)
rm -rf <project>/.claude/skills/flow
```

## Troubleshooting

- **Windows `EBUSY` / `EPERM` mid-install**: an agent (Claude Code, Codex, Antigravity IDE) is holding a file inside the destination. Close the agent and re-run. The installer already retries with 100/300/900 ms backoff before surfacing the error.
- **Stale advisory lock**: a prior run crashed. The next run detects the dead PID and reclaims the lock automatically. If it does not (very rare — the recorded PID was recycled by another live process), delete `<parent-of-dest>/.flow-skill.installing.lock`.
- **`No matching version found` on `@0.1.x`**: you are trying to install a pre-release version through a stable range. Use `@rc` (dist-tag) or an explicit `@0.1.0-rc.N` until stable `0.1.0` ships.
- **Node too old** (`requires Node.js >=20.11.0`): upgrade with your preferred version manager (`nvm install 20`, `fnm install 20`, or Node's official installer).

## JSONL contract

`--json` streams one JSON object per line:

```jsonl
{"event":"plan","version":"0.1.0-rc.1","dryRun":false,"scope":"global","targets":["claude","codex"]}
{"event":"install:start","target":"claude","dests":["~/.claude/skills/flow"]}
{"event":"install:done","target":"claude","dests":["~/.claude/skills/flow"],"result":"success","error":null,"warnings":[]}
{"event":"summary","success":true,"total":2,"attempted":2,"installed":2,"failed":0,"skipped":0,"aborted":false}
```

`--json --dry-run` emits only the `plan` event. `--json` implies non-interactive; do not combine with a TTY prompt session.

### Event contract

| Event | Required fields | Notes |
|---|---|---|
| `plan` | `version` (string), `dryRun` (bool), `scope` (`global`\|`project`), `targets` (string[]) | Always the first event. |
| `install:start` | `target` (string), `dests` (string[]) | One per selected target. |
| `install:done` | `target`, `dests`, `result` (`success`\|`failed`), `error` (string\|null), `warnings` (string[]) | Fired after each target. `error` is `null` on success. |
| `summary` | `success` (bool), `total`, `attempted`, `installed`, `failed`, `skipped`, `aborted` (bool) | Always the last event. Counts sum: `attempted = installed + failed`; `skipped = total - attempted`. |
| `error` | `message` (string), `exitCode` (int) | Emitted only when the process crashes before completing a normal flow (e.g. missing bundled skill). Then exits with `exitCode`. |

Exit codes: `0` success · `1` at least one target failed · `2` invalid usage (bad target name, `--project` with a non-Claude target, missing bundled skill) · `130` `SIGINT` (Ctrl+C).

The contract is additive within `0.1.x`. New optional fields may appear; existing fields will not be renamed or removed.

## Requirements

- Node.js **>= 22.14.0** — Node 20 reached end-of-life in April 2026, and the publish workflow requires npm >=11.5.1 (bundled with Node 22.14+) for OIDC Trusted Publisher support

## Provenance

Every version published from the CI workflow carries an [npm provenance](https://docs.npmjs.com/generating-provenance-statements) attestation (SLSA Build Level 2). Verify with:

```
npm view @manhquy/flow-skill@<version> dist.attestations.provenance
```

> **RC-window exception**: `v0.1.0-rc.1` was published manually from a developer machine to bootstrap npm's Trusted Publisher registration (Trusted Publisher cannot bind to a package that does not exist yet). npm does not generate provenance for publishes outside supported CI. All subsequent versions (`v0.1.0-rc.2` onward) publish through the workflow and are attested.

## Security

See [SECURITY.md](./SECURITY.md) for the threat model, what the installer will and will not do, and how to report issues.

## License

MIT © 2026 manhquy
