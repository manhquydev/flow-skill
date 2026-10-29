<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/manhquydev/flow-skill/master/brand/brand-lockup-dark.svg">
    <img src="https://raw.githubusercontent.com/manhquydev/flow-skill/master/brand/brand-lockup-light.svg" alt="flow — gated build harness for coding agents" width="560">
  </picture>
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/@manhquy/flow-skill"><img src="https://img.shields.io/npm/v/@manhquy/flow-skill?color=cb3837&style=flat-square" alt="npm version"></a>
  <a href="https://nodejs.org"><img src="https://img.shields.io/badge/node-%3E%3D22.14-brightgreen?style=flat-square" alt="Node.js >= 22.14"></a>
  <a href="https://github.com/manhquydev/flow-skill/blob/master/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License: MIT"></a>
  <a href="https://flowskill.io.vn"><img src="https://img.shields.io/badge/docs-flowskill.io.vn-blueviolet?style=flat-square" alt="Documentation"></a>
</p>

# @manhquy/flow-skill

Official installer CLI for **Flow** — the gated build harness that guides coding agents from idea to verified, production-ready software through honest, evidence-backed gates.

[English](./README.md) · [Tiếng Việt](./README_VN.md)

---

## Quick Start

```bash
npx @manhquy/flow-skill@latest
```

The interactive installer detects your installed coding agents, copies the `/flow` skill bundle into their skill directories, and gets you ready to build in seconds.

---

## Supported Coding Agents & Targets

| Agent | Skill Location | Trigger Command |
|---|---|---|
| **Claude Code** | `~/.claude/skills/flow` | `/flow` |
| **Cursor** | `~/.cursor/skills/flow` | Agent Skills panel |
| **Codex CLI** | `~/.codex/skills/flow` | `$flow` |
| **Antigravity** | `~/.gemini/antigravity-cli/skills/flow` | `/flow` |
| **OMP** | `~/.omp/agent/skills/flow` | `/flow` |
| **Universal Agents** | `~/.agents/skills/flow` | Auto-discovered |

---

## Common Commands & Options

```bash
# Interactive setup (recommended)
npx @manhquy/flow-skill@latest

# Unattended / non-interactive (all detected agents + Claude)
npx @manhquy/flow-skill@latest --yes

# Specific target(s)
npx @manhquy/flow-skill@latest --yes --target claude,cursor

# Project scope (Claude Code only — installs to .claude/skills/flow in current repo)
npx @manhquy/flow-skill@latest --yes --project --dir .

# Preview installation plan without writing files
npx @manhquy/flow-skill@latest --yes --all --dry-run
```

### CLI Options

| Option | Description |
|---|---|
| `-y, --yes` | Install without interactive prompts |
| `-t, --target <name>` | Specific target(s) (comma-separated or repeated) |
| `--all` | Install to all supported targets |
| `--project` | Install to local project repository (`.claude/skills/flow`) |
| `--dry-run` | Preview installation plan without writing files |
| `--json` | Output JSONL events for CI/automation |
| `-h, --help` | Show CLI help |

---

## First Run & Next Steps

After installation completes, restart or reload your coding agent. Codex CLI uses
`$flow`; slash-command agents (Claude Code, Antigravity, OMP) use `/flow`:

- Codex: `$flow`; slash-command agents: `/flow` — check current project stage and blockers
- Codex: `$flow next`; slash-command agents: `/flow next` — evaluate gates and advance to the next stage
- Codex: `$flow doctor`; slash-command agents: `/flow doctor` — verify environment health and installed skill bundle integrity

---

## Release & Compatibility

| | |
|---|---|
| **Release target** | npm **1.0.0** / skill **v1.0.0** — intended channel `latest`; not a publication receipt |
| **Node.js** | `>= 22.14.0` |
| **Documentation** | [flowskill.io.vn](https://flowskill.io.vn) |
| **Repository** | [GitHub: manhquydev/flow-skill](https://github.com/manhquydev/flow-skill) |
| **License** | MIT |

Publication status verified 2026-10-30: GitHub skill release v1.0.0 (2026-10-24) and npm installer 1.0.0 (2026-10-25); registry `latest` is 1.0.0. See the [migration guide](https://github.com/manhquydev/flow-skill/blob/master/docs/migration-v1.md) for the verified pre-v1 rollback pair.

---

## Troubleshooting & FAQ

- **Agent does not show `/flow`:** Make sure you ran the installer via `npx @manhquy/flow-skill@latest`. Running bare `npm install @manhquy/flow-skill` only downloads the npm package into `node_modules` without executing the installer to copy skill files to your agent's directory.
- **Updating Flow:** Re-run `npx @manhquy/flow-skill@latest` anytime to fetch the newest release. Pinning `@latest` ensures `npx` does not reuse an older cached version.
- **Node.js version requirement:** Requires Node.js ≥ 22.14 LTS (`node --version`).
- **Uninstalling:** Remove the skill folder from the agent directories you installed into:
  ```bash
  rm -rf ~/.claude/skills/flow ~/.cursor/skills/flow ~/.codex/skills/flow ~/.agents/skills/flow ~/.gemini/antigravity-cli/skills/flow ~/.omp/agent/skills/flow
  ```

---

## Security & Provenance

Published packages from CI include verifiable [npm provenance](https://docs.npmjs.com/generating-provenance-statements). Threat model, security policy, and supply-chain guarantees: [SECURITY.md](./SECURITY.md).

## License

[MIT](./LICENSE) © 2026 manhquy
