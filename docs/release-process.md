# Release process — skill product + npm installer

Canonical runbook for shipping future versions without re-learning CI/OIDC/dist-tag traps.
Ops detail and token hygiene live in [`npm-wrapper/RELEASE_CHECKLIST.md`](../npm-wrapper/RELEASE_CHECKLIST.md).

## Two version axes (do not merge them)

| Axis | Where declared | Bump when | Install / pin |
|---|---|---|---|
| **Skill product** | `skills/flow/SKILL.md` → `metadata.version` | Behavior change in flow runner/harness/refs | Content inside agent homes after install |
| **Skill mirrors** | `.claude-plugin/plugin.json`, `portable-manifest.json` | Same as skill product | `/flow coherence` enforces agreement |
| **npm installer** | `npm-wrapper/package.json` | Installer CLI, targets, sync, publish pipeline | `npx @manhquy/flow-skill@rc` or `@X.Y.Z` |

- CLI help prints both: `flow-skill v<pkg> (ships skill v<skill>)`.
- JSONL `plan` event: `version` = npm package, `skillVersion` = skill product.
- Git tags: **`npm@0.1.0-rc.N`** triggers npm publish; **`v0.22.0`** is skill product history / GitHub Release — **does not** publish npm.

## Pipelines (automation map)

```
skills/flow/**  ──sync──►  npm-wrapper/skills/flow  (prepack / CI Materialize)
       │
       ├── push master (paths) ──► CI: bash-suite 3-OS + npm-wrapper Node matrix
       │                            Windows bash-suite timeout = 30m; others 15m
       │
       └── git tag npm@X.Y.Z + push ──► publish-npm-wrapper.yml
                                         environment: npm-publish (required reviewer)
                                         OIDC + npm publish --provenance --tag rc|latest
                                         dist-tag ADD is NOT automated (manual token)

Nightly (cron) ──► smoke.mjs vs dist-tags rc + latest (clean cwd, no npm-wrapper shadow)
```

### CI facts (measured)

| Job | Typical duration | Timeout budget |
|---|---|---|
| bash-suite ubuntu | ~2–3 min | 15m |
| bash-suite macOS | ~3–4 min | 15m |
| bash-suite Windows | ~18–25 min | **30m** |
| npm-wrapper matrix | ~15–40s / cell | 10m |

`tests/run_all.sh` prints `wall_s` per suite + `TOTAL wall_s` for timeout forensics.

### Publish facts

- Pre-release tag (`npm@0.1.0-rc.N`) → workflow dist-tag **`rc`** only.
- Stable tag (`npm@0.1.0`) → dist-tag **`latest`**.
- `promote_to` workflow input: **manual-only early exit** (prints `npm dist-tag add …`); OIDC cannot dist-tag (E401).
- After every pre-release: decide whether `latest` should follow. If yes → manual promote (checklist).

## Harness preflight (every release — skill and/or npm)

From **repo root** (uses dogfood `.flow/` if present; does not require a clean tree):

```bash
bash scripts/release-preflight.sh
# Expect: PREFLIGHT PASS
# Checks: flow coherence · doctor READY · dual-version help · optional harness.db · live dist-tags
```

| Surface | What preflight checks |
|---|---|
| **Docs versions** | SKILL.md ↔ plugin.json ↔ portable-manifest (must match) |
| **Engine** | `flow.sh doctor` READY + harness path present |
| **Memory** | Soft: `.flow/harness.db`, `.flow/events.jsonl` if dogfood exists |
| **npm-wrapper** | `ships skill v…` on `--help` after sync |
| **Registry** | Soft: compare local package.json vs dist-tag `rc` / `latest` lag |

`marketplace.json` → `metadata.version` is the **catalog** version, not skill product — do not force it equal to `0.22.x`.

## Skill product release (e.g. v0.24.0)

1. **Implement + tests**
   - `bash tests/run_all.sh` green locally (or rely on CI).
   - Touch only needed suites under `tests/test_flow_*.sh`.
2. **Version coherence (harness gate)**
   - Bump **together**:
     - `skills/flow/SKILL.md` → `metadata.version`
     - `.claude-plugin/plugin.json` → `version`
     - `portable-manifest.json` → `version`
   - `bash scripts/release-preflight.sh` (preferred) or
     `bash skills/flow/runner/flow.sh coherence` from repo root.
   - Expect: single agreed version, no drift warning.
3. **Docs**
   - Root `CHANGELOG.md` skill entry.
   - `docs/quality-metrics.md` status line.
   - Optional: `docs/journals/YYMMDD-…-vi.md`.
4. **Ship skill homes**
   - Dev: `bash install.sh global` / `pwsh install.ps1 global`, or
   - Users: next npm-wrapper release that re-syncs and publishes (below).
5. **Optional git tag**
   - `git tag v0.24.0 && git push origin v0.24.0` + GitHub Release notes.
   - **Does not** publish npm.

## npm installer release (e.g. 0.1.0-rc.4 or 0.1.0)

### A. Pre-flight (local)

```bash
# From repo root — harness + coherence + dual-version
bash scripts/release-preflight.sh

cd npm-wrapper
npm run sync          # skills/flow → npm-wrapper/skills/flow
npm test              # 41+ tests; pretest re-syncs
# Dual-version sanity
node bin/cli.mjs --help | head -3
# expect: flow-skill vX.Y.Z (ships skill vA.B.C)

# Bump installer only
npm version prerelease --preid=rc   # or patch|minor|major for stable
# Ensure tag shape npm@* (workflow trigger). Prefer:
git tag -d "v$(node -p "require('./package.json').version")" 2>/dev/null || true
# If npm version created wrong tag name, delete and recreate:
# git tag npm@$(node -p "require('./package.json').version")
```

Also:

- Align `npm-wrapper/CHANGELOG.md` Unreleased → versioned section.
- Root README status table: npm package version line.
- Secret grep empty (see RELEASE_CHECKLIST).
- Confirm `bin/cli.mjs` stays mode `100755` in git.

### B. Push code then tag

```bash
git push origin master
git push origin npm@0.1.0-rc.4    # example
```

### C. Approve environment

GitHub Actions → **Publish npm-wrapper to npm** → run for the tag → approve **`npm-publish`**.

### D. Post-publish verify (mandatory)

```bash
npm view @manhquy/flow-skill versions --json
npm view @manhquy/flow-skill dist-tags --json
# Pre-release: expect rc → new version; latest may lag

npx --yes @manhquy/flow-skill@rc --help
# expect: flow-skill v<new> (ships skill v<product>)

npx --yes @manhquy/flow-skill@<exact> --yes --all --dry-run --json
# expect skillVersion field

npm view @manhquy/flow-skill@<exact> dist.attestations.provenance
```

Optional smoke (from **empty temp cwd**, not inside `npm-wrapper/`):

```bash
cd /tmp   # or $env:TEMP empty dir
node /path/to/flow-skill/npm-wrapper/scripts/smoke.mjs <exact-version>
```

### E. Dist-tag policy

| Situation | Action |
|---|---|
| Ship RC for testers | Keep `rc` only; document `@rc` in README |
| Want bare `npm i` / untagged `npm view` on new RC | Manual: `npm dist-tag add @manhquy/flow-skill@VER latest` (token flow in RELEASE_CHECKLIST) |
| Ship stable `0.1.0` | Tag without preid; workflow sets `latest` |

## Harness / durable layer notes

- Runtime telemetry field `flow_version` in usage events comes from the **installed skill** product version, not npm package version.
- Schema migrations live under `skills/flow/harness/schema/` — bump skill product version when schema/behavior changes; do not bump npm-only for pure skill content unless you also want a new tarball on npm.
- `flow_harness.py` / schema numbers (009–012, …) are independent of npm semver.

## Anti-patterns (learned 2026-07)

| Don't | Why |
|---|---|
| Run nightly smoke / `npx @manhquy/flow-skill@…` with cwd = `npm-wrapper/` | Same package name → local workspace shadows registry |
| Expect `npm dist-tag add` in GHA OIDC | E401; use manual bootstrap token |
| Publish skill version as npm version (`@0.22.0`) | Does not exist; confuses users |
| `npm i` alone for end users | No postinstall; must **run** the CLI |
| Assume Windows bash suite < 15m | Full suite ~18m+; budget is 30m |
| Re-add `NODE_AUTH_TOKEN must be empty` CI guard | Breaks setup-node OIDC (0% pass) |
| Tag `v*` expecting npm publish | Wrong tag shape; need `npm@*` |

## Quick reference — next RC

```bash
# 1) skill content already on master, coherent
# 2) installer
cd npm-wrapper && npm run sync && npm test
npm version prerelease --preid=rc
# fix tag to npm@X.Y.Z-rc.N if needed
# 3) docs bump CHANGELOG + README status
git push origin master
git push origin npm@$(node -p "require('./package.json').version")
# 4) Approve npm-publish environment
# 5) Post-publish verify @rc dual-version + provenance
# 6) Optional: promote latest via manual dist-tag
```

## Related files

| File | Role |
|---|---|
| `npm-wrapper/RELEASE_CHECKLIST.md` | Auth, token, step-by-step publish |
| `.github/workflows/publish-npm-wrapper.yml` | OIDC publish |
| `.github/workflows/ci.yml` | Cross-OS gates |
| `.github/workflows/nightly-registry-health.yml` | Live registry smoke |
| `npm-wrapper/scripts/smoke.mjs` | Post-publish / nightly verifier |
| `CONTRIBUTING.md` | Version sync rule for contributors |
