# Release checklist (npm-wrapper)

Dev-only guide (excluded from tarball via `files` allowlist).
The authority is the [canonical release process](../docs/release-process.md) and
[accepted ADR 0002](../docs/adr/0002-unattended-release-policy.md); this checklist
adds installer-specific verification, not another publish path.

## Version axes

- npm installer version: `npm-wrapper/package.json`.
- Skill product version: `skills/flow/SKILL.md`, mirrored by plugin and portable metadata.
- After sync, CLI help must report both: `flow-skill v<installer> (ships skill v<product>)`.
- Update the selected axes, changelogs, release intent and synchronized EN/VI docs
  through the release-preparation PR described in the canonical runbook.

## Release boundary

- Only `workflow_dispatch` starts the publisher; `scripts/release.sh` is the canonical
  dispatcher. Tags never authorize publication and are created only after verification.
- Eligibility verifies exact master SHA, latest authoritative CI, merged PR, release
  intent and registry state. Live publishing remains default-off behind
  `FLOW_AUTOPUBLISH_ENABLED`, with the master-only `npm-publish` environment.
- Only the publish job receives OIDC. Trusted Publishing covers `npm publish`, not
  separate dist-tag mutation. Stable SemVer publishes directly to `latest`;
  prereleases publish to `next`. Do not manually promote a prerelease to `latest`.
- No required environment reviewer is part of the accepted policy. Do not change
  environment, account, token or activation settings as a checklist step.
- Never publish production packages from a laptop, expose credentials in chat/logs,
  or use a bypass token to work around a failed release gate. Treat exposed tokens
  as compromised and have the owner revoke them.

## Installer preparation checks

From the repository root:

```bash
bash scripts/release-preflight.sh
bash scripts/pack-rehearsal.sh
```

From `npm-wrapper/`:

```bash
npm run sync
node bin/cli.mjs --help
npm test
npm pack --dry-run --ignore-scripts --json | node -e "const p=JSON.parse(require('fs').readFileSync(0,'utf8'));const s=p[0].unpackedSize;console.log('unpacked',s);if(s>1572864)process.exit(1)"
```

- [ ] CLI shows both intended versions; executable mode of `bin/cli.mjs` is preserved.
- [ ] No child-process execution or secrets are introduced into installer sources.
- [ ] Pack rehearsal is green: pack, compare bundled tree, clean temporary install,
      CLI execution and installed-skill e2e. Size audit is a separate gate.
- [ ] Selected changelogs, README pairs and skill mirrors agree with release intent.

## Canonical promotion and verification

After preparation merges and owner-authorized gates pass, from repository root:

```bash
bash scripts/release.sh --dry-run
# Only after owner-authorized gates; not authorization to enable live publishing:
bash scripts/release.sh --yes
```

Dry-run is the default. Keep the release latch disabled until the owner-authorized
activation criteria in ADR 0002 are satisfied. A local preflight PASS alone does
not authorize publication.

- [ ] Exact publisher run and attempt pass eligibility and required verification.
- [ ] Registry version, tarball integrity, provenance identity and expected channel
      match the exact artifact; missing provenance is a failure, not a warning.
- [ ] `node npm-wrapper/scripts/smoke.mjs <exact-version>` verifies install/CLI/skill
      behavior from a clean temporary cwd, never from `npm-wrapper/`.
- [ ] Dual-version output matches the shipped artifact on `next` or `latest`.
- [ ] Tags and selected GitHub Release are verified output of the canonical script.

Existing versions are verify-only. Partial state or failed verification stops for
owner action; do not republish, move dist-tags, or repair tags manually. Follow the
canonical runbook's recovery section rather than historical token/tag procedures.

## Historical publish log (historical only)

These records describe past publications, not current release instructions or
current registry channel state. Use the canonical process above for future releases.

| Version | When | Notes |
|---|---|---|
| 0.1.0-rc.1 | 2026-07-12 | Manual bootstrap publish (no provenance) |
| 0.1.0-rc.2 | 2026-07-17 | First OIDC + provenance; Cursor target; restart hints |
| 0.1.0-rc.3 | 2026-07-18 | Dual-version UX; smoke cwd fix; `rc` tag points here |
| 0.1.0 | 2026-07-19 | GA (first stable); ships skill v0.24.0; auto-routes to `latest` |
