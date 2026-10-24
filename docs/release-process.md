# Release process — skill product + npm installer

Canonical runbook for shipping future versions. Release policy: [`docs/adr/0002-unattended-release-policy.md`](adr/0002-unattended-release-policy.md).

## One shared SemVer

Skill product and npm installer share one SemVer, including installer-only and skill-only changes. The canonical source is `skills/flow/SKILL.md`; `npm-wrapper/package.json`, `.claude-plugin/plugin.json` and `portable-manifest.json` are release mirrors. `sync-release --check` requires equality. See the [owner decision](release-owner-decision-unified-version.md) and its [authoritative record](../plans/261025-0023-unified-version/decision.md).

The existing field names, marketplace catalog and banner `flow-skill vX (ships skill vY)` remain compatible; X and Y now agree. Release intent records both versions. Historical releases, including npm 0.8.0 and skill tag `v1.0.0`, remain immutable. The first alignment is npm 1.0.0 with the already-versioned, unchanged skill 1.0.0.

Each release PR updates the common version, changelogs, synchronized docs and release intent. Loop ticks without a version/changelog change do not publish. Breaking compatibility or expanding security/service rights still requires a separate owner authorization in `docs/release-owner-authorization.json`; all provenance, CI and review gates remain fail-closed.

## Flow v1 breaking release gate

The owner-approved v1 contract is not satisfied by a version-number change or a default-flag
flip alone. Before stable skill 1.0, the graph executor must actually own `/flow next`
ordering, Python must be required at the measured floor, and `FLOW_HARNESS_DISABLE` must
refuse product operations without weakening any gate. Require independent review, current
exact-head cross-OS CI, docs/package coherence, and verified migration plus rollback evidence.
The migration path must create and retain a SQLite-consistent pre-migration backup before DDL
for an existing populated DB, refuse on backup failure, preserve linked-worktree DB ownership,
and prove restore/readback. Any rollback must wait until writers are settled, preserve the
newer database separately, and restore only from a named verified backup; reinstalling an old
npm package alone does not undo database changes. No stable 1.0 promotion until all gates pass.

## Automatic release path

A reviewed release-preparation PR merges to `master`; exact-master CI passes; OMP invokes `bash scripts/release.sh --yes`. The canonical script dispatches `.github/workflows/publish-npm-wrapper.yml` using `workflow_dispatch` with exact master SHA/version and unique dispatch UUID. The publisher independently verifies the caller correlation, current master, latest authoritative CI run and `all-checks-passed` job, merged PR base/repository, release intent and selected version axes, SemVer/channel monotonicity, and registry state; only explicit E404 proves absence. The live publish job remains default-off behind `FLOW_AUTOPUBLISH_ENABLED=true`, master-only `npm-publish`, eligibility success and publish-only OIDC. No tag-push trigger exists. The publisher packs once, retains the package artifact before publish and verified audit/SLSA receipts before smoke. The client re-downloads and re-verifies that exact run artifact, registry version/SRI/current dist-tag, npm signatures, Sigstore source identity and full installer smoke before creating/pushing selected tags; a skill tag/Release is created only when `skill_version` is non-null. Inactive release intent is a no-op. Same-owner dispatch is trusted as an accepted policy; actor ID/UUID are correlation, while server-side release gates are the enforcement boundary.

Publisher dispatch defaults to `dry-run`. Live mode requires `FLOW_AUTOPUBLISH_ENABLED=true`, passing eligibility, and master-only `npm-publish` environment. The eligibility job has no OIDC permission or environment; only the publish job has OIDC. There is no tag-push publish trigger. Tags are created after npm registry/provenance/install verification and never authorize publication.

`npm-publish` currently has exactly one branch deployment rule, `master`, no tag rules. Controller verified historical `npm@0.7.11` dispatch rejection before job execution/OIDC: run `39210527539`, job `117922661201`, with zero steps and environment-protection denial annotation. Evidence: `.omp/flow-maintenance/backups/release-remote-20261019T055718Z/`. This historical probe does not prove a new publisher path is safe; implementation review, exact CI, default-off/dry-run proof and controller readback remain required before enabling live publishing.

### CI timing and coverage

| Job | Typical duration | Timeout budget |
|---|---|---|
| bash-suite ubuntu | ~8 min | 15m |
| bash-suite macOS | ~11–15 min typical suite; PR88 run 40069912151 killed at 25m18s mid-suite with steady progress (67 suites passed; graph parity 94s on macOS) while the identical tree passed master run 40063546827 in 22m44s — marginal headroom, budget raised with that evidence | **30m** |
| bash-suite Windows | Serial baseline ~54–60 min; three-shard timings not yet measured | **80m / shard** |
| npm-wrapper matrix | ~15–40s / cell | 10m |

`tests/run_all.sh` prints `wall_s` per suite + `TOTAL wall_s` for timeout forensics. Windows runs three isolated matrix cells with `FLOW_SUITE_SHARD=1/3`, `2/3`, `3/3`. The runner sorts the current manifest with `LC_ALL=C` and assigns suites round-robin; no suite count or names are hardcoded. Unset the variable for the unchanged full serial manifest-order run (Ubuntu, macOS and local default). Invalid specifications and empty shards fail closed. The manifest-runner fixture proves exact-once coverage and rejects omissions/duplicates. `all-checks-passed` depends on every shard and rejects any non-success; PowerShell installer tests run once on Windows shard 1. Parallelism is intended to reduce walltime, but measured speedup is not yet claimed.

## Phase 1: release preparation PR

1. Bump the common version for a meaningful change to either skill or installer. Declare it in `skills/flow/SKILL.md`; keep npm package and skill mirrors equal. For initial 1.0.0 alignment only, the skill and its mirrors already have the target version.
2. Add exact release headings/notes in root `CHANGELOG.md` and `npm-wrapper/CHANGELOG.md`. Ensure compatibility classification and no unapproved breaking/security-rights expansion.
3. Synchronize docs and bundled tree; run `node scripts/sync-release.mjs --sync`, `node scripts/sync-release.mjs --check`, `bash scripts/release-preflight.sh`, i18n verification and relevant package tests.
4. Merge through repository review/thread-resolution/required-CI gates. Do not tag, publish or change remote settings in the PR.

## Phase 2: OMP promotion

```bash
bash scripts/release.sh --dry-run
bash scripts/release.sh --yes
```

`--yes` requires clean working tree, local `master == origin/master`, unified-version coherence/changelog entries, zero sync drift, i18n integrity, unused npm tags, exact-HEAD authoritative CI, and read-only verification battery. It dispatches with a unique request UUID through the workflow-dispatch REST endpoint using `return_run_details=true`, validates the returned repository-bound `workflow_run_id` and watches that exact run. A missing or invalid receipt fails closed; never redispatch blindly. Re-verify workflow identity, exact SHA, attempt, eligibility and live publish jobs, then registry integrity/provenance/install smoke. Only then create/push the npm tag and a new skill tag/Release, or preserve an existing identical-subtree skill tag/Release as described below.

When checking whether the skill-axis GitHub Release is absent, `scripts/sync-release.mjs` recognizes only `gh release view`'s exact `release not found` diagnostic (with one optional terminal LF or CRLF); every other lookup error fails closed and must not trigger release creation. Never infer absence from a generic HTTP 404 or a broad `not found` substring.

Stable releases publish to `latest`; prereleases to `next`. Stable versions are never downgraded. A prerelease does not automatically move `latest` backward or promote itself to `latest`.

An existing skill tag is acceptable only when `git rev-parse <tag>:skills` equals `git rev-parse HEAD:skills`. Ship checks this both before promotion and at tagging, skips creation of that immutable skill tag and its existing Release, and logs why. Different or unavailable subtree hashes require the next common bump. Existing npm tags remain a refusal; no tag is moved or recreated.


## Artifact and post-publish verification

The publisher packs exactly once because `npm-wrapper/scripts/sync.mjs` writes nondeterministic `skills-manifest.json.syncedAt`. It publishes that exact `.tgz`; retries must verify the same artifact identity. After publish, require exact public-registry version, SHA-512 integrity, provenance binding repository/workflow/ref/commit, and expected dist-tag. The client pins registry reads to `https://registry.npmjs.org/` and rechecks version, integrity and channel after Sigstore verification and installed-package smoke, immediately before creating tags. Then run:

```bash
node npm-wrapper/scripts/smoke.mjs <exact-version>
npm view @manhquy/flow-skill dist-tags --json
npm view @manhquy/flow-skill@<exact-version> dist.integrity dist.attestations.provenance
```

The smoke runs against the public registry from a clean temporary working directory. Missing/mismatched provenance or failed install/CLI/skill checks is a failed release verification; never republish the immutable version to hide partial state.

## Failure and rollback

- Any non-E404 registry error, incomplete GitHub API/pagination, stale master, failed/newer CI attempt, missing/wrong-base merged PR, version/channel mismatch, integrity/provenance mismatch, or failed smoke stops the release.
- Existing npm version is verify-only. Reconcile only exact artifact integrity, provenance, channel and expected tag/Release target. Missing/mismatched tags/releases require owner action; no automatic repair.
- Verify-only recovery invocation (after `gh run download <run-id> -n npm-package-<run-id>-<attempt> -D <pkg-dir>` and `-n npm-verification-<run-id>-<attempt> -D <ev-dir>`):

  ```bash
  node scripts/sync-release.mjs --reconcile <pkg-dir> <ev-dir> <full-sha> <publisher-run-id> <publisher-run-attempt>
  ```

  It re-verifies the retained tarball digest, npm signatures, Sigstore attestation, registry integrity/channel and existing tag targets; it never publishes, retags or repairs. Partial state stops with an owner-action report. The publisher runtime must provide `gh >= 2.68.0` with `attestation verify`; the release client checks this capability BEFORE dispatching and refuses with instructions to provision a project-local portable `gh` (host tooling is never upgraded in place).
- To pause automation, controller disables `FLOW_AUTOPUBLISH_ENABLED` or disables the publisher dispatch path. Never unpublish or move existing versions/tags.
- Same-owner credentials can change workflow/variable/environment; OIDC/SLSA provides traceability, not an independent identity boundary.

## Harness / durable layer notes

- Runtime telemetry field `flow_version` in usage events comes from the **installed skill** product version, not npm package version.
- Schema migrations live under `skills/flow/harness/schema/` — schema/behavior changes require the next common skill and npm version.
- `flow_harness.py` / schema numbers (009–012, …) are independent of npm semver.

## Historical anti-patterns

| Don't | Why |
|---|---|
| Run nightly smoke / `npx @manhquy/flow-skill@…` with cwd = `npm-wrapper/` | Same package name → local workspace shadows registry |
| Expect `npm dist-tag add` in GHA OIDC | E401; stable releases publish directly to latest; no separate dist-tag mutation |
| Relabel changed skill content with an existing version | Existing skill tags may be reused only when their `skills/` tree equals HEAD; otherwise bump the common version |
| `npm i` alone for end users | No postinstall; must **run** the CLI |
| Assume Windows bash shard < 15m | Serial baseline ~54–64m; shard timings unmeasured, budget remains 80m each |
| Re-add `NODE_AUTH_TOKEN must be empty` CI guard | Breaks setup-node OIDC |
| Tag `v*` expecting npm publish | Tags never authorize npm publication |


## Related files

| File | Role |
|---|---|
| `scripts/release.sh` | Canonical OMP-invoked promotion gate and publisher-run verifier |
| `scripts/sync-release.mjs` | Release coherence and promotion implementation |
| `scripts/release-eligibility.mjs` | Pure fail-closed eligibility evaluator |
| `scripts/release-workflow.mjs` | GitHub/npm adapter and artifact verification |
| `.github/workflows/publish-npm-wrapper.yml` | Master-only OIDC publisher; no tag trigger |
| `.github/workflows/ci.yml` | Cross-OS authoritative CI (`all-checks-passed` job) |
| `npm-wrapper/scripts/smoke.mjs` | Public-registry installed-artifact smoke |
| `docs/adr/0002-unattended-release-policy.md` | Accepted unattended-release decision and gates |
