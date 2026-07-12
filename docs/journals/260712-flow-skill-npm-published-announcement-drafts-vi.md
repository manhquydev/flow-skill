# Announcement drafts — `@manhquy/flow-skill` v0.1.0-rc.1

**Prepared**: 2026-07-12 · **Publish target**: sau khi manhquy accept repo transfer + npm publish thành công.

## 1. GitHub Release notes (dán vào `Releases → New release → tag npm@0.1.0-rc.1`)

```markdown
# @manhquy/flow-skill v0.1.0-rc.1

Bootstrap release candidate của installer npm cho skill `flow`. Chạy một lệnh, xong.

## Cài

```bash
npx @manhquy/flow-skill@rc
```

Prompt hỏi cài vào agent nào (Claude Code / Codex CLI / Agents / Antigravity CLI+IDE). Multi-select. Xong.

Non-interactive cho CI:
```bash
npx @manhquy/flow-skill@rc --yes --all --dry-run --json
```

## What's in

- Pure Node ESM — chạy giống nhau trên macOS + Linux + Windows (cmd / PowerShell / Git Bash)
- 4 install target, 5 destination (Antigravity = CLI + IDE)
- Parity semantics với `install.sh:24-27` — preserve user files outside 6 owned subdirs
- Defense-in-depth: symlink rejection, EBUSY retry backoff, advisory lock
- Non-interactive fallback: `--yes / -t / --all / --project / --json / --dry-run`
- JSONL streaming event contract for CI consumers

## Requirements

Node.js **≥22.14.0**. Node 20 reached end-of-life in April 2026.

## What's NOT in this version

- **npm provenance attestation**: v0.1.0-rc.1 was published manually to bootstrap npm's Trusted Publisher registration. All subsequent versions (rc.2+) publish through GitHub Actions with OIDC and SLSA Build Level 2 provenance. If provenance is a hard requirement, wait for rc.2.

## Docs

- [README](./npm-wrapper/README.md) · [README (Tiếng Việt)](./npm-wrapper/README_VN.md)
- [SECURITY.md](./npm-wrapper/SECURITY.md) — WILL / WON'T contract + supply chain
- [CHANGELOG](./npm-wrapper/CHANGELOG.md)

## Report issues

- GitHub: https://github.com/manhquy/flow-skill/issues
- Email: manhquy.mqy@gmail.com (subject: `[flow-skill]`)
```

## 2. Twitter/X thread (1 tweet + optional follow-ups)

```
Ship: @manhquy/flow-skill v0.1.0-rc.1

npx @manhquy/flow-skill@rc

One command installs my "flow" coding-agent skill into Claude Code, Codex CLI, and Antigravity. Cross-OS pure Node — no bash, no PowerShell, no Git Bash requirement.

35 tests. Repo: github.com/manhquy/flow-skill
```

Follow-up if you feel like it:

```
The interesting bit isn't the CLI itself — it's the security posture:

- OIDC trusted publishing (from rc.2 onward)
- SLSA L2 provenance
- Zero postinstall hook
- No shell/PowerShell spawn
- Symlink rejection at sync + install
- Atomic-ish semantics matching install.sh:24-27

SECURITY.md documents the trade-offs. Honest > convenient.
```

## 3. Hacker News post (Show HN)

Title: `Show HN: One-command npx installer for a coding-agent skill (Claude, Codex, Antigravity)`

Body:

```
Hi HN — I've been building a "flow" skill for coding agents (gated build process, done-evidence, knowledge loop). Distributing it manually was painful, so I wrapped install.sh in an npm package.

npx @manhquy/flow-skill@rc

Interactive multi-select of the target agents (Claude Code / Codex CLI / Agents home / Antigravity CLI + IDE), or non-interactive for CI.

Design notes:

- Pure Node — no shell/PowerShell spawn from the installer. Same code path on macOS/Linux/Windows regardless of terminal.
- Semantic parity with the reference install.sh: rm 6 cleanup subdirs, cpSync merge, chmod +x runner. External user files outside the owned subdirs are preserved.
- Defense: symlink rejection (source + post-copy), EBUSY retry (100/300/900 ms), advisory lock via O_EXCL to avoid concurrent-install races.
- JSONL streaming event contract for CI: plan / install:start / install:done / summary with total/attempted/installed/failed/skipped/aborted counts.
- Runtime Node guard >=22.14 (Node 20 EOL April 2026, and npm OIDC needs 11.5.1+).
- CI: matrix ubuntu/macos/windows × Node 22/24, tarball size + child_process import guards.
- Publish: GitHub Actions Trusted Publisher, OIDC only, required-reviewer environment gate, SLSA L2 provenance from rc.2 onward.

Would love feedback on the SECURITY.md posture or the JSONL contract.

npm: https://www.npmjs.com/package/@manhquy/flow-skill
Repo: https://github.com/manhquy/flow-skill
```

## 4. GitHub Discussions (Announcements)

Title: `v0.1.0-rc.1 — first RC of the npm installer is live`

Body:

```markdown
### What just shipped

`@manhquy/flow-skill@0.1.0-rc.1` is on the npm registry:

```bash
npx @manhquy/flow-skill@rc
```

### Why RC (not stable)

Two reasons.

1. Real-user validation window. I want at least a week of external installs across macOS + Linux + Windows before flipping the `latest` dist-tag.
2. Provenance bootstrapping. rc.1 was published manually (npm Trusted Publisher requires the package to already exist before binding). rc.2 will be the first workflow-published, provenance-signed release.

### How to help

If you install it, please:
- Tell me which OS + shell + target agent (`npx @manhquy/flow-skill@rc --yes --all --dry-run --json` output is perfect).
- Open [an issue](https://github.com/manhquy/flow-skill/issues/new/choose) if anything fails — the template asks for exactly what I need.
- Try Ctrl+C mid-install and let me know if it leaves your `~/.claude/skills/flow` in a weird state.

### Promotion criterion to `v0.1.0` stable

- [ ] 7 days elapsed with no critical bug report.
- [ ] All success criteria in the project plan artifact verified across macOS + Linux + Windows.
- [ ] ≥1 external tester confirms a clean install.
- [ ] rc.2+ carries a valid SLSA L2 provenance attestation (`npm view @manhquy/flow-skill@<v> dist.attestations.provenance`).

Thanks!
```

## Distribution checklist (dán vào `plans/reports/publish-setup-runbook-*.md` sau publish)

- [ ] GitHub Release: paste section 1 → tag `npm@0.1.0-rc.1`
- [ ] Twitter/X: section 2 (optional follow-up thread)
- [ ] HN Show: section 3 (best time zone Bay Area morning)
- [ ] GitHub Discussions Announcements: section 4
- [ ] Update `docs/journals/260712-flow-skill-npm-wrapper-v0.1.0-rc.1-shipped-vi.md` với "published" note + npm URL
