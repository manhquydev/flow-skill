# Release checklist

Dev-only guide (excluded from tarball via `files` allowlist + `.npmignore`). Follow every section before triggering the publish workflow.

## Bootstrap-token log (2026-07-12)

The **first publish** of `@manhquy/flow-skill@0.1.0-rc.1` was performed manually because npm Trusted Publisher (OIDC) cannot bind to a package that does not yet exist.

- Method: **Granular Access Token with `Bypass 2FA`** minted on the npm dashboard.
- Token lifetime: **~60 seconds** (created → `npm config set` → `npm publish` → `npm token revoke` → `npm config delete`).
- No token was written to `~/.npmrc` beyond the transient set/delete pair.
- **Retire path**: once Trusted Publisher is configured (see Prereqs below) the bootstrap-token flow is no longer needed. Publishes from rc.2+ run inside the workflow with OIDC and carry SLSA L2 provenance.
- **Hard deadline: 2027-01-XX** — npm removes publishing capability from bypass-2FA tokens around January 2027 ([GitHub Changelog 2026-07-08](https://github.blog/changelog/2026-07-08-npm-install-time-security-and-gat-bypass2fa-deprecation/)). TP registration must be complete before that, or another manual publish path will be needed.
- **Post-bootstrap TODO** — the `latest` dist-tag was auto-populated by npm on the first publish (points at rc.1). Run `npm dist-tag rm @manhquy/flow-skill latest` from an authenticated shell so unpinned installs (`npx @manhquy/flow-skill`) do NOT return the RC. Re-add `latest` when the first stable version ships.

## Prereqs (one-time)

- [ ] npm Trusted Publisher configured for `@manhquy/flow-skill` linking:
      `owner=manhquydev`, `repo=flow-skill`, `workflow=publish-npm-wrapper.yml`, `environment=npm-publish`.
      (Cross-account TP: the GitHub owner `manhquydev` is separate from the npm scope owner
      `@manhquy` — same person, different account names. npm supports this.)
      Docs: https://docs.npmjs.com/trusted-publishers
- [ ] GitHub → Settings → Environments → `npm-publish` exists with a required reviewer (self at minimum).
- [ ] Publisher npm account 2FA `auth-and-writes` verified: `npm profile get`.
- [ ] GitHub repo is public (Trusted Publisher OIDC audience requirement).

## Local pre-flight

```
# 1. (Monorepo) Sync is done at CI time from ../skills/flow.
#    Dev-only: run locally if you want to smoke-test with the current skill content.
npm run sync                      # optional locally; CI always resyncs
                                   # ../skills/flow is the in-tree source of truth

# 2. Bump version (from the npm-wrapper subdir)
npm version prerelease --preid=rc # for rc; use `npm version patch|minor|major` for stable
# npm version creates a git tag `npm@<version>` — RENAME it to the wrapper-scoped shape:
git tag -d "npm@<version>"
git tag "npm@<version>"           # the workflow triggers on `npm@*` tag pushes

# 3. Full test + anti-regression grep
npm test
git grep -nE "from ['\"]node:child_process['\"]|require\(['\"]node:child_process['\"]|require\(['\"]child_process['\"]" -- 'src/' 'bin/'
                                                     # must be empty (matches the workflow's precise guard;
                                                     # the loose verb-based regex false-positived on `RegExp.prototype.exec` and code comments)
grep -rE '(sk_live|pk_live|ghp_|AKIA|Bearer\s|password|xoxb-)' bin/ src/ skills/ README* LICENSE SECURITY.md CHANGELOG.md
                                                    # must be empty

# 4. Tarball audit
npm pack --dry-run
npm pack --dry-run --ignore-scripts --json | node -e "const p=JSON.parse(require('fs').readFileSync(0,'utf8'));const s=p[0].unpackedSize;console.log('unpacked bytes:',s);if(s>1048576){console.error('EXCEEDS 1MB');process.exit(1)}"

# 5. Local smoke (npm link)
#    NOTE: run the linked binary directly. Do NOT append a version specifier — that would
#    bypass the link and try to fetch from the registry.
npm link
cd /tmp && flow-skill --yes --all --dry-run --json | head
npm unlink -g @manhquy/flow-skill
```

## Publish (via CI, never from dev laptop)

Two triggers are supported:

**Tag-push (canonical release path):**
- [ ] `git push origin main`
- [ ] `git push origin npm@<version>` — the workflow fires on tag shape `npm@*`.
- [ ] Approve the environment gate when prompted.

**`workflow_dispatch` (setup validation + out-of-band):**
- [ ] GitHub → Actions → **Publish npm-wrapper to npm** → Run workflow.
      Inputs:
      - `version` — must match `npm-wrapper/package.json`.
      - `dist_tag` — `rc` for pre-release, `latest` for stable.
      - `dry_run` — set to `true` for setup validation.
- [ ] Approve the environment gate when prompted.
- [ ] Verify workflow log:
      - `Guard — assert no NODE_AUTH_TOKEN present` passes.
      - `Verify skills-manifest.json count matches` passes.
      - `npm publish --provenance` succeeds.
      - `Verify published provenance` prints the attestation.
      - Git tag `npm@<version>` is pushed.

## Post-publish

- [ ] `npx @manhquy/flow-skill@<version> --help` from a clean shell.
- [ ] `npm view @manhquy/flow-skill@<version> dist.attestations.provenance` shows SLSA output.
- [ ] Draft a GitHub release note using the CHANGELOG entry.

## Promotion criterion (rc → stable v0.1.0)

- [ ] 7 days elapsed since rc.1 publish with no critical bug report.
- [ ] All success criteria in the project's plan artifact (external — see `README.md` and CHANGELOG) manually verified across macOS + Linux + Windows.
- [ ] At least one external tester ran `npx @manhquy/flow-skill@0.1.0-rc.1` successfully.
- [ ] `npm version minor` (drops rc suffix), then run the workflow with `dist_tag=latest`.
