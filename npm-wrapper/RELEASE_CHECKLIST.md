# Release checklist (npm-wrapper)

Dev-only guide (excluded from tarball via `files` allowlist).  
**Canonical product + npm dual-version process:** [`docs/release-process.md`](../docs/release-process.md).

Use this file for **auth/token ops** and a tick-list before each installer publish.

## Version axes (reminder)

| Axis | File | Example |
|---|---|---|
| npm package | `package.json` | `0.1.0-rc.3` |
| Skill shipped in tarball | `skills/flow/SKILL.md` (after `npm run sync`) | `0.22.0` |

CLI must show both after sync: `flow-skill v0.1.0-rc.3 (ships skill v0.22.0)`.

## Account facts (read before debugging any auth failure)

- **npm account `@manhquy` is passkey-only — it has NO TOTP and never will via self-service.**
  Created 2026-07-11, after npm stopped allowing new TOTP enrollments (~Sept 2025). Any
  command/prompt asking for `--otp=<6-digit code>` is a **dead end** for this account — there is
  no authenticator app to read a code from. `npm login` works (passkey via browser), but that
  session alone does NOT authorize write operations (publish, dist-tag, token management) —
  those need a **fresh** 2FA challenge that the npm CLI cannot issue as a passkey prompt on this
  OS/CLI version (confirmed Windows, npm 11.x, 2026-07).
- **The only working write-auth path from a local/dev shell is a Granular Access Token with
  `Bypass 2FA` checked**, minted interactively on the npm dashboard (which does support passkey).
  This is not a workaround-of-last-resort, it is **the only available path** until either (a) TP
  coverage extends to the specific write operation, or (b) the account gets a TOTP-capable 2FA
  method some other way.
- **npm Trusted Publishing (OIDC) covers `npm publish` but NOT `npm dist-tag add`** (confirmed
  live 2026-07-17: `E401 Unable to authenticate` immediately after a successful OIDC-authenticated
  publish in the same job). Every dist-tag promotion (rc→latest, or any manual re-tag) needs the
  bootstrap-token flow below, **every time**, until npm ships OIDC for that endpoint.
- **Security note on the bootstrap token**: it grants write access with a 2FA bypass. Run the
  3 commands (`npm config set` / the actual write / `npm token revoke`) **directly in your own
  shell**, not relayed through an AI agent or pasted into any chat/log — a token pasted into a
  conversation must be treated as compromised and revoked immediately.

## Dist-tag promotion (every future promote)

```
# 1. npmjs.com dashboard -> Access Tokens -> Generate New Token -> Granular Access Token
#    Permissions: Read and write | Packages: @manhquy/flow-skill | check "Bypass 2FA"
# 2. Run directly in your own shell (never relay through an agent/chat):
npm config set //registry.npmjs.org/:_authToken=<token>
npm dist-tag add @manhquy/flow-skill@<version> <tag>
npm token list                              # note the id
npm token revoke <id>                       # immediately
npm config delete //registry.npmjs.org/:_authToken
npm logout                                  # belt-and-suspenders session cleanup
```

**Live dist-tags (as of 2026-07-18):** `rc` → `0.1.0-rc.3` (OIDC publish), `latest` → `0.1.0-rc.2`
until manually promoted. Pre-release publish **never** moves `latest` automatically.

**Hard deadline: ~2027-01** — npm deprecates bypass-2FA tokens for publish; dist-tag may still
need an alternative write path — re-check npm changelog before that date.

## Prereqs (one-time — done)

- [x] Trusted Publisher: `owner=manhquydev`, `repo=flow-skill`, `workflow=publish-npm-wrapper.yml`,
      `environment=npm-publish` (cross-account OK). Confirmed live rc.2+.
- [x] GitHub Environment `npm-publish` with required reviewer.
- [x] Repo public (OIDC audience).
- [ ] Optional: `npm profile get` when diagnosing account issues.

## Local pre-flight (every release)

```bash
cd npm-wrapper

# 1. Sync skill content from monorepo source of truth
npm run sync
# Confirm dual-version string
node bin/cli.mjs --help | head -3

# 2. Bump installer version only
npm version prerelease --preid=rc    # RC channel
# npm version patch|minor|major      # stable (drops -rc)
# Ensure git tag is npm@X.Y.Z (workflow trigger shape), not vX.Y.Z:
#   git tag npm@$(node -p "require('./package.json').version")

# 3. Tests + guards
npm test
git grep -nE "from ['\"]node:child_process['\"]|require\(['\"]node:child_process['\"]|require\(['\"]child_process['\"]" -- 'src/' 'bin/'
# must be empty
# secret grep (bin/src/skills/docs listed in older checklist) — must be empty

# 4. Tarball audit
npm pack --dry-run --ignore-scripts --json | node -e "const p=JSON.parse(require('fs').readFileSync(0,'utf8'));const s=p[0].unpackedSize;console.log('unpacked',s);if(s>1048576)process.exit(1)"

# 5. Optional local link smoke (no @version on the command)
npm link
flow-skill --yes --all --dry-run --json
npm unlink -g @manhquy/flow-skill
```

- [ ] `npm-wrapper/CHANGELOG.md` has a section for this version.
- [ ] Root `README.md` / `README_VN.md` status table npm line updated.
- [ ] Skill product version coherent if skill content changed (`docs/release-process.md`).
- [ ] `bin/cli.mjs` still `100755` in git (`git ls-files -s bin/cli.mjs`).

## Publish (CI only — never laptop `npm publish` for production)

**Canonical:**

```bash
git push origin master
git push origin npm@<version>
# Approve environment npm-publish when Actions prompts
```

**Optional `workflow_dispatch`:** version must match `package.json`; `dist_tag=rc|latest`;
`dry_run=true` for validation. **`promote_to` ≠ none exits immediately** with manual
instructions — does not publish.

Workflow must show:

- [ ] skills-manifest count matches synced tree
- [ ] `npm publish --provenance` succeeds
- [ ] provenance verify step OK or WARN only
- [ ] No re-introduction of “NODE_AUTH_TOKEN must be empty” guard

## Post-publish verify (mandatory)

```bash
npm view @manhquy/flow-skill versions --json
npm view @manhquy/flow-skill dist-tags --json

# Use @rc or exact version — not bare name if latest lags
npx --yes @manhquy/flow-skill@rc --help
# expect: flow-skill v<new> (ships skill v<product>)

npx --yes @manhquy/flow-skill@rc --yes --all --dry-run --json
# expect skillVersion

npm view @manhquy/flow-skill@<version> dist.attestations.provenance

# Smoke from EMPTY cwd (never from npm-wrapper/):
cd /tmp   # Windows: empty dir under %TEMP%
node /path/to/flow-skill/npm-wrapper/scripts/smoke.mjs <version>
```

- [ ] Dual-version visible on the channel you ship (`@rc` and/or `@latest`)
- [ ] Nightly will pick up new `rc`/`latest` on next cron (or dispatch Nightly manually)
- [ ] If bare `npm view` / untagged install should use this version → **manual** `dist-tag add … latest`

## Promotion criterion (rc → stable v0.1.0)

- [ ] RC window without critical installer bugs
- [ ] External tester path exercised (`npx @manhquy/flow-skill@rc`)
- [ ] CI green including Windows bash-suite
- [ ] `npm version` drops preid → tag `npm@0.1.0` → workflow `dist_tag=latest`
- [ ] Update README to recommend stable pin / drop RC-only messaging

## Historical publish log (condensed)

| Version | When | Notes |
|---|---|---|
| 0.1.0-rc.1 | 2026-07-12 | Manual bootstrap publish (no provenance) |
| 0.1.0-rc.2 | 2026-07-17 | First OIDC + provenance; Cursor target; restart hints |
| 0.1.0-rc.3 | 2026-07-18 | Dual-version UX; smoke cwd fix; `rc` tag points here; `latest` may lag |
