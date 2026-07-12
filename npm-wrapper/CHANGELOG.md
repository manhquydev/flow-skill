# Changelog

All notable changes to `@manhquy/flow-skill`. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## [0.1.0-rc.1] — 2026-07-12

Initial release candidate. Ships to the `rc` npm dist-tag.

### Added
- `npx @manhquy/flow-skill` installer for 4 coding-agent targets: Claude Code, Codex CLI, Agents home, Antigravity (CLI + IDE).
- Interactive multi-select prompt via `@clack/prompts` when stdin/stdout are TTY.
- Non-interactive flags: `--yes`, `--target`/`-t` (repeatable + comma form), `--all`, `--project`, `--dir`, `--json`, `--dry-run`, `--help`.
- JSONL streaming (`--json`) with `plan`, `install:start`, `install:done`, and `summary` events.
- Pure Node install path — no shell/PowerShell spawn, single code path across macOS/Linux/Windows.
- Semantic parity with upstream `install.sh:24-27`: clean 6 subdirs (`runner`, `_templates`, `law`, `references`, `harness`, `playbooks`) then merge-copy. User files outside those subdirs are preserved.
- Defense: symlink rejection at sync and install time. Advisory lock to reduce concurrent-run races. `EBUSY`/`EPERM`/`ENOTEMPTY`/`EACCES` retry with 100/300/900 ms backoff.
- `chmod +x` on `runner/flow.sh` (parity with `install.sh:27`; no-op on Windows NTFS).
- `--project` scope enforced to Claude only (agent-contract limitation).
- 26 tests via `node:test` (installer semantics, detection markers, CLI black-box smoke).
- Runtime Node version guard (>=20.11.0); `engines` in `package.json` matches.

### Security
- Bundled `skills/flow` synced from upstream `flow-skill` repo via `scripts/sync.mjs`; `skills-manifest.json` records file count + list for post-hoc verification.
- No `postinstall` hook. `prepack` runs `sync.mjs` on the dev machine only and is not in the published tarball.
- GitHub Actions trusted publishing: OIDC-only, required-reviewer environment, `npm publish --provenance` (SLSA Level 2).
- README and docs pin `@0.1.x` semver rather than `@latest`.

### Notes
- v0.1.0-rc.N is a pre-release channel. Test explicitly with `npx @manhquy/flow-skill@0.1.0-rc.1`. Pinning `@0.1.x` does not fetch pre-release versions.
- Promotion criterion from rc → stable v0.1.0: 7 days with no critical bug reports, all success criteria in [plans/260712-0219-flow-skill-npx-installer/plan.md](../flow/plans/260712-0219-flow-skill-npx-installer/plan.md) manually verified across macOS + Linux + Windows, and at least one external tester install.
