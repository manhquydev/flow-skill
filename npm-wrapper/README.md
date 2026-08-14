# @manhquy/flow-skill

Install the **flow** skill into coding agents with one command.

| | |
|---|---|
| **Package** | [`@manhquy/flow-skill`](https://www.npmjs.com/package/@manhquy/flow-skill) (installer CLI) |
| **Current GA** | **0.7.0** — ships skill product **v0.30.0** |
| **Platforms** | macOS · Linux · Windows (same Node path) |
| **Requirement** | Node.js **≥ 22.14** |
| **Source** | [github.com/manhquydev/flow-skill](https://github.com/manhquydev/flow-skill) |
| **Website** | [flowskill.io.vn](https://flowskill.io.vn) |

flow is a gated build harness (`/flow`): idea → honest gates → real done-evidence. This package only **installs** that skill into agent skill homes.

---

## Standard install

```bash
# Recommended — always pin the dist-tag so npx does not reuse a stale cache entry
npx @manhquy/flow-skill@latest
```

| Step | Detail |
|------|--------|
| 1 | Fetches **`latest`** from the npm registry |
| 2 | Interactive multi-select of detected agents (Claude is always offered) |
| 3 | Copies `skills/flow` into each selected destination |
| 4 | Prints what to type after reload (`/flow`, `$flow`, …) |

**After install:** restart or reload the agent, then invoke flow (see [After install](#after-install)).

### Confirm versions

```bash
npx @manhquy/flow-skill@latest --help
# expect: flow-skill v0.7.x (ships skill v0.30.x)
```

### Common commands

```bash
# Non-interactive (Claude + detected agents)
npx @manhquy/flow-skill@latest --yes

# One or more targets
npx @manhquy/flow-skill@latest --yes --target claude
npx @manhquy/flow-skill@latest --yes -t claude -t codex
npx @manhquy/flow-skill@latest --yes -t claude,codex

# Every supported target
npx @manhquy/flow-skill@latest --yes --all

# Claude skill inside a project repo (commit-friendly)
npx @manhquy/flow-skill@latest --yes --project --dir .

# Plan only (no disk writes) + JSONL for CI
npx @manhquy/flow-skill@latest --yes --all --dry-run --json
```

### Options

| Flag | Meaning |
|------|---------|
| `-y`, `--yes` | Skip prompts; install default selection (detected + Claude) |
| `-t`, `--target <name>` | Target (repeatable or comma-separated) |
| `--all` | All targets, even if not detected |
| `--project` | Project scope — Claude only → `<dir>/.claude/skills/flow` |
| `--dir <path>` | Project directory (implies `--project`; default: cwd) |
| `--json` | JSONL events (`plan`, `install:*`, `summary`) |
| `--dry-run` | Print plan; do not write |
| `-h`, `--help` | Help |

### Targets

| Name | Destination | Detection |
|------|-------------|-----------|
| `claude` | `~/.claude/skills/flow` | `~/.claude` (always offered) |
| `codex` | `~/.codex/skills/flow` | `~/.codex/skills` |
| `agents` | `~/.agents/skills/flow` | `~/.agents/skills` |
| `antigravity` | `~/.gemini/antigravity-cli/skills/flow` **and** `~/.gemini/config/skills/flow` | either path |
| `cursor` | `~/.cursor/skills/flow` | `~/.cursor/skills` |

`--project` supports **only** `claude`. Other targets with `--project` exit `2`.

### Rules

| Do | Don’t |
|----|--------|
| `npx @manhquy/flow-skill@latest` | Bare `npx @manhquy/flow-skill` (stale npx cache) |
| **Run** the CLI to copy the skill | `npm i` alone (package only; no skill files in agent homes) |
| Pin installer `@0.7.0` if needed | Pin npm `@0.30.0` (skill version ≠ package version) |
| Prefer `@latest` | `@rc` (retired / behind) |

**Two version axes:** `package.json` version = installer; `SKILL.md` metadata = skill product. Both appear in `--help` and in the `plan` JSONL event (`version` + `skillVersion`).

---

## After install

| Agent | Next step |
|-------|-----------|
| Claude Code | Type `/flow` |
| Codex CLI | Restart Codex once → `$flow` |
| Antigravity | Restart IDE / `agy` → `/flow` |
| Agents home | Reload the tool if it does not auto-pick new skills |
| Cursor | Reload Cursor; confirm `flow` in the agent skills panel |
| Any | `/flow doctor` (or run `runner/flow.sh doctor`) |

### Verify on disk (Claude global)

```bash
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

---

## Uninstall

```bash
rm -rf ~/.claude/skills/flow
rm -rf ~/.codex/skills/flow
rm -rf ~/.agents/skills/flow
rm -rf ~/.cursor/skills/flow
rm -rf ~/.gemini/antigravity-cli/skills/flow
rm -rf ~/.gemini/config/skills/flow
# project scope:
rm -rf <project>/.claude/skills/flow
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Agent has no `/flow` after `npm i` | Run `npx @manhquy/flow-skill@latest` (install must **execute**) |
| Old skill after reinstall | Always use `@latest`; avoid bare package name |
| `No matching version found` for `@0.30.0` | That is the **skill** version. Use `@latest` or `@0.7.x` |
| Node too old | Install Node ≥ 22.14 (`nvm install 22`, etc.) |
| Windows `EBUSY` / `EPERM` | Close the agent holding files under the skill dir; re-run |
| Stale install lock | Delete `<parent>/.flow-skill.installing.lock` if reclaim fails |

---

## JSONL (`--json`)

```jsonl
{"event":"plan","version":"0.7.0","skillVersion":"0.30.0","dryRun":false,"scope":"global","targets":["claude"]}
{"event":"install:start","target":"claude","dests":["~/.claude/skills/flow"]}
{"event":"install:done","target":"claude","dests":["~/.claude/skills/flow"],"result":"success","error":null,"warnings":[]}
{"event":"summary","success":true,"total":1,"attempted":1,"installed":1,"failed":0,"skipped":0,"aborted":false}
```

Exit codes: `0` success · `1` target failure · `2` bad usage · `130` SIGINT.

Contract is additive: new optional fields may appear; existing fields are stable.

---

## Provenance & security

Published builds from CI include [npm provenance](https://docs.npmjs.com/generating-provenance-statements). Threat model and reporting: [SECURITY.md](./SECURITY.md).

## License

MIT © 2026 manhquy
