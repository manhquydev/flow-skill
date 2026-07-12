# Changelog

All notable changes to `@manhquy/flow-skill`. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## [0.1.0-rc.1] — 2026-07-12

Initial release candidate. Ships to the `rc` npm dist-tag.

### Post-implementation audit fixes (before first publish)
- **installer:** `acquireLock` was TOCTOU-racy — switched to atomic `writeFileSync(..., { flag: 'wx' })` so two `npx` runs cannot both acquire.
- **installer:** dropped `EACCES` from `withRetry` — POSIX permission errors are almost never transient; retrying only masked the honest error with ~1.3 s of latency.
- **installer:** dropped the post-copy `assertNoSymlinks(destDir)` walk — it would have rejected legitimate Windows NTFS junctions users may have placed under their skills tree. The source-side scan is the actual security control.
- **detect:** `~/foo` template resolution now uses `path.join(...)` so Windows dests no longer surface mixed separators in `--json` output.
- **cli:** removed the aspirational "hit Ctrl+C twice to hard-exit" branch — synchronous install loop cannot be preempted by signal handlers, and the second-strike `process.exit(130)` would have leaked the current install's advisory lock.
- **workflow:** `npm pack --dry-run --json` now runs with `--ignore-scripts` so `prepack` stdout does not corrupt the JSON audit payload.
- **workflow:** pre-release semver can never be published to dist-tag `latest` (belt-and-suspenders guard alongside the tag-name auto-derivation).
- **workflow:** `child_process` guard narrowed to import statements only — the old verb-based regex false-hit `RegExp.prototype.exec` and code comments containing "exec".
- **docs:** README EN + VN now recommend `@rc` (dist-tag) during the RC window and explain why `@0.1.x` will not resolve to a pre-release. Full JSONL event/field/exit-code contract table added. Troubleshooting section covers `EBUSY`/stale lock/version pin/Node floor.
- **docs:** dropped stale `import.meta.dirname` justification for the Node ≥20.11 floor — the real reasons are `node:util.parseArgs` (stable) and `node:test`.
- **docs:** SECURITY.md reframes `skills-manifest.json` as a completeness signal, not a tamper-detection primitive (that role belongs to npm provenance).
- **package.json:** dropped stale `opencode` keyword — no opencode target is shipped.

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
- Runtime Node version guard (>=20.11.0) — floor is set by `node:util.parseArgs` stable API and `node:test`; `engines` in `package.json` matches.

### Security
- Bundled `skills/flow` synced from upstream `flow-skill` repo via `scripts/sync.mjs`; `skills-manifest.json` records file count + list for post-hoc verification.
- No `postinstall` hook. `prepack` runs `sync.mjs` on the dev machine only and is not in the published tarball.
- GitHub Actions trusted publishing: OIDC-only, required-reviewer environment, `npm publish --provenance` (SLSA Level 2).
- README and docs pin `@0.1.x` semver rather than `@latest`.

### Notes
- v0.1.0-rc.N is a pre-release channel. Test explicitly with `npx @manhquy/flow-skill@0.1.0-rc.1`. Pinning `@0.1.x` does not fetch pre-release versions.
- Promotion criterion from rc → stable v0.1.0: 7 days with no critical bug reports, all success criteria (documented in the project's plan artifact) manually verified across macOS + Linux + Windows, and at least one external tester install.
