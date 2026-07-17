# Release checklist

Dev-only guide (excluded from tarball via `files` allowlist + `.npmignore`). Follow every section before triggering the publish workflow.

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
  publish in the same job — see `plans/reports/researcher-260712-1006-npm-trusted-publisher-first-publish-edge-cases-report.md`
  item #12). Every dist-tag promotion (rc→latest, or any manual re-tag) needs the bootstrap-token
  flow below, **every time**, until npm ships OIDC for that endpoint (no date published as of
  2026-07-17).
- **Security note on the bootstrap token**: it grants write access with a 2FA bypass. Run the
  3 commands (`npm config set` / the actual write / `npm token revoke`) **directly in your own
  shell**, not relayed through an AI agent or pasted into any chat/log — a token pasted into a
  conversation must be treated as compromised and revoked immediately even if it still "worked"
  once. This happened once during the 2026-07-17 rc.2 dist-tag promotion; the token was revoked
  within the same turn and the local npm session logged out as a second layer of cleanup.

## Bootstrap-token log (2026-07-12, publish) + dist-tag promotion log (2026-07-17)

The **first publish** of `@manhquy/flow-skill@0.1.0-rc.1` was performed manually because npm Trusted Publisher (OIDC) cannot bind to a package that does not yet exist.

- Method: **Granular Access Token with `Bypass 2FA`** minted on the npm dashboard.
- Token lifetime: **~60 seconds** (created → `npm config set` → `npm publish` → `npm token revoke` → `npm config delete`).
- No token was written to `~/.npmrc` beyond the transient set/delete pair.
- **Partial retire, not full**: once Trusted Publisher was configured (2026-07-17, see Prereqs
  below), `npm publish` itself no longer needs the bootstrap token — confirmed live for
  `0.1.0-rc.2`, OIDC + SLSA L2 provenance. **`npm dist-tag add` still needs it** — see Account
  facts above. Re-check this section's OIDC-coverage claim before assuming any *other* npm
  write command (e.g. `npm deprecate`, `npm unpublish`, `npm access`) works via CI/OIDC; assume
  it does NOT until proven live.
- **Hard deadline: 2027-01-XX** — npm removes publishing capability from bypass-2FA tokens around January 2027 ([GitHub Changelog 2026-07-08](https://github.blog/changelog/2026-07-08-npm-install-time-security-and-gat-bypass2fa-deprecation/)). Since dist-tag operations still depend on this token type, losing it means finding a different write-auth path for dist-tag promotion specifically — not just publish.
- **Dist-tag promotion steps (repeat for every future promotion until OIDC covers this endpoint):**
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
- **2026-07-17 resolved**: `0.1.0-rc.2` promoted to `latest` (previously `latest` pointed at
  `rc.1` since npm auto-populates it on first publish). Both `rc` and `latest` now point at
  `0.1.0-rc.2`.

## Prereqs (one-time)

- [x] npm Trusted Publisher configured for `@manhquy/flow-skill` linking:
      `owner=manhquydev`, `repo=flow-skill`, `workflow=publish-npm-wrapper.yml`, `environment=npm-publish`.
      (Cross-account TP: the GitHub owner `manhquydev` is separate from the npm scope owner
      `@manhquy` — same person, different account names. npm supports this.)
      Docs: https://docs.npmjs.com/trusted-publishers
      **Confirmed live 2026-07-17** — `npm publish --provenance` succeeded via pure OIDC for
      `0.1.0-rc.2`, no manual token. This was flagged `TBD` in the original 2026-07-12 runbook
      and silently never closed out — it was the actual blocker on this release's first 2
      publish attempts (after an unrelated CI guard bug was also fixed). If a future publish
      404s with `PUT .../not found`, re-verify this exact tuple in the npm dashboard first —
      npm does not validate TP config on save, so a typo here fails silently until publish time.
- [x] GitHub → Settings → Environments → `npm-publish` exists with a required reviewer (self at minimum).
- [ ] Publisher npm account 2FA `auth-and-writes` verified: `npm profile get`.
- [x] GitHub repo is public (Trusted Publisher OIDC audience requirement).

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
      - `Verify skills-manifest.json count matches` passes.
      - `npm publish --provenance` succeeds.
      - `Verify published provenance` prints the attestation.
      - Git tag `npm@<version>` is pushed.
      - **There is no "NODE_AUTH_TOKEN must be empty" guard step** (removed 2026-07-17 — it
        never matched real `actions/setup-node@v4` behavior and had a 0% pass rate; see the
        workflow file's inline comment + CHANGELOG `## [0.1.0-rc.2]` for the evidence). A
        non-empty `NODE_AUTH_TOKEN` right after the `setup-node` step is normal — it's the
        OIDC-exchanged token, not a leaked secret. Do not re-add this guard without re-reading
        that history first.
- [ ] **Promoting a dist-tag (e.g. rc → latest) is a SEPARATE manual step** — the
      `promote_to` workflow_dispatch input **exits immediately** (before npm ci/test) with
      copy-paste instructions (`npm dist-tag add` has no OIDC support; live E401 on run
      `29556075144`). Do not expect CI to promote. Use the manual bootstrap-token flow above.
- [ ] **Tag shape is the automation:** `git tag npm@X.Y.Z && git push origin npm@X.Y.Z`
      triggers publish. Skill tags (`v0.22.0`) and GitHub Releases do **not** publish to npm.

## Post-publish

- [ ] `npx @manhquy/flow-skill@<version> --help` from a clean shell.
- [ ] `npm view @manhquy/flow-skill@<version> dist.attestations.provenance` shows SLSA output.
- [ ] Draft a GitHub release note using the CHANGELOG entry.

## Promotion criterion (rc → stable v0.1.0)

- [ ] 7 days elapsed since rc.1 publish with no critical bug report.
- [ ] All success criteria in the project's plan artifact (external — see `README.md` and CHANGELOG) manually verified across macOS + Linux + Windows.
- [ ] At least one external tester ran `npx @manhquy/flow-skill@0.1.0-rc.1` successfully.
- [ ] `npm version minor` (drops rc suffix), then run the workflow with `dist_tag=latest`.
