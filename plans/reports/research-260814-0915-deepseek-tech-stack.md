# Research: DeepSeek Harness — Infrastructure & Technology Stack

**Mission:** INFRASTRUCTURE & TECHNOLOGY dissection of `/home/manhquy/Downloads/deepseek-harness`
**Date:** 2026-08-14
**Scope:** build system, testing infra, native/python components, benchmark harness, packaging/release pipeline, notable engineering patterns
**Repo state:** `0.1.0-rc.5` (HEAD `47f943859b`, master), read-only investigation

Note: the repo is far ahead of the AGENTS.md snapshot in the project context — it has grown `apps/`, `tsdown`, oxlint, a node-pty patch, GitLab CI, and a public npm publish sequence. Everything below reflects the actual checkout.

---

## 1. Build system

### 1.1 pnpm workspace layout (`pnpm-workspace.yaml`)

- `vendor/*` — 10 vendored Cordis framework packages (rescoped to `@deepseek-ai/*`, pinned source snapshots with upstream SHAs in `vendor/README.md`).
- `packages/*/*` — 219 package.json files across ~50 groups (`core`, `llm`, `shell`, `subprocess`, `fs`, `lsp`, `web`, `compaction`, `session`, `sdk`, `client` (44 pkgs), `host` (11 pkgs), `examples`, `test-support`, etc.).
- `native/landlock-run` + `native/landlock-run/packages/*` — native addon workspace, own build/publication scripts.
- `apps/*` — `apps/cli` (owns the `dsh` bin) and `apps/web` (Vite frontend).
- `website` — VitePress docs site.
- `examples` — joined as **one** workspace member whose package.json declares the union of all leaves' cordis.yml plugins as `workspace:*`; exists for *dependency resolution only*, NOT a build target (tsdown's explicit globs exclude it) — a plain-node `:lib` boot of any leaf resolves plugins through real package `exports`→`lib` by walking up to `examples/node_modules`.
- `python/sdk-runtime` — deploy root of the single-exe build: a pure dependency manifest whose closure is what the exe bundles and the Python runtime distributes.

Key pnpm settings:
- `linkWorkspacePackages: true` — vendored packages keep upstream semver ranges but resolve to this workspace's pinned sources (including from built `lib/`).
- `overrides`: `@deepseek-ai/cosmokit` and `@deepseek-ai/schemastery` → `link:vendor/...`.
- `peerDependencyRules.allowedVersions.typescript: '>=5 <7'`.
- **`allowBuilds` (pnpm 10 strictDepBuilds, deny-by-default):** only `esbuild`, `lefthook`, `node-pty`, `koffi`, and the subprocess-local workspace postinstall are allowed to run lifecycle scripts; `@google/genai`, `protobufjs`, `node-addon-require-builtin` are explicitly denied with documented rationale.
- `minimumReleaseAgeExclude` for fresh pi-ai / node-addon releases.
- `patchedDependencies`: `node-pty@1.1.0: patches/node-pty@1.1.0.patch`.
- Root package.json: `packageManager: pnpm@11.7.0`, `engines: node ^22.19.0 || >=24.0.0`.

### 1.2 tsconfig strategy — the "two faces" architecture

Five root configs (`docs/development.md#typescript-project-layout`):

| File | Role | Forms a ts.Program? |
|---|---|---|
| `tsconfig.json` | Solution root: extends base, `files: []`, references host+client aggregates; also the tsserver entry and the resolution config tsx uses for `examples/`/`scripts/` | No |
| `tsconfig.host.json` | Host aggregate: packages, examples, tests, scripts, website, api/remotes host leaf | Yes |
| `tsconfig.client.json` | Client aggregate: `packages/client/*`, `apps/web`, api/remotes client leaf | Yes |
| `tsconfig.base.json` | Shared compilerOptions + full source `paths` map; **no `include`/`files`** so it doubles as the match-all resolution facade for vite-tsconfig-paths | No |
| `tsconfig.base.client.json` | Browser compiler settings (jsx, DOM libs, `types: []`) | No |

Why two aggregates: both sides **declaration-merge the cordis `Context` interface under the same keys with different services**; one program seeing both would report a collision. The collision exists only inside a `ts.Program` — module resolution never triggers it — so one solution and one paths facade may span both sides. Disciplines: never add `include` to base; scripts building repo-wide programs seed one aggregate explicitly, never the solution; new packages register in exactly one aggregate. `api/remotes` is the only package with a split host/client pair of its own.

Compiler flags: `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`, `noFallthroughCasesInSwitch`, `noUnusedLocals/Parameters`, `composite` + `incremental` (project references), `allowImportingTsExtensions` + `rewriteRelativeImportExtensions` (source uses explicit `.ts` specifiers, emitted JS gets `.js`).

The `paths` map is enormous (~300 entries): explicit maps for vendored packages, a generic `@deepseek-ai/dsh-*` wildcard over `packages/<group>/*/src` (first-on-disk wins, unambiguous since dir names are unique), plus dedicated wildcards for `*-/invariant` subpath exports and host/client prefixed names. Adding a package under an existing group needs no tsconfig edit.

### 1.3 Build pipeline: tsc -b + tsdown

```sh
pnpm run build          # build:lib (host + client) then build:web (vite)
build:lib:host   = tsc -b tsconfig.host.json && tsdown --env.DSH_BUILD_FACE host
build:lib:client = tsc -b tsconfig.client.json && tsdown --env.DSH_BUILD_FACE client
```

- `tsc -b` emits `lib/types` (declarations + intermediate JS) per package; `tsdown` (vite-based bundler) consumes that JS and writes publish runtime entries to `lib/` — a two-phase "source plane → artifact plane" split.
- `tsdown.config.ts`: workspace globs `vendor/*`, `packages/*/*`, `apps/cli`; ESM only, node platform, es2024, `dts: false`; host face runs the `typertPlugin` (type-graph generation); client face selects browser-bundle packages via their package-local configs.
- Every package is ESM (`"type": "module"`); `@deepseek-ai/cordis` is a peerDependency of every harness package.
- The `dsh` CLI source launch runs through `node --import tsx/esm`; config subprocesses run built `lib/` under plain node.

### 1.4 patches/

One patch: `patches/node-pty@1.1.0.patch` — makes the macOS spawn-helper path overridable (`DSH_NODE_PTY_SPAWN_HELPER` env or an `<execPath>-spawn-helper` sibling), which the single-exe Python runtime distribution needs (the helper cannot sit inside the SEA executable). Applied via `patchedDependencies`.

### 1.5 lefthook (`lefthook.yml`)

Installed automatically by the root `postinstall` (`node scripts/install-lefthook.mjs`). Designed as "fast local checkpoints; CI owns the full matrix":

- **pre-commit:** translation-pairing check on staged `.i18n.yaml`; archived agent-notes verification; staged lint via oxlint with `--fix` + `stage_fixed: true`; third-party notices **regeneration** (`gen-third-party-notices.ts && git add THIRD_PARTY_NOTICES.md` — regenerate rather than reject, with the deletion case falling through to a freshness assertion in CI); `git diff --cached --check` whitespace; vendor manifest guard script.
- **pre-merge-commit:** translation pairing + archived notes.
- **pre-push:** `pnpm run typecheck`.

### 1.6 knip (`knip.json`, 17.5 KB)

- `exclude: ["duplicates"]`; `ignoreBinaries` (bwrap, musl-gcc, sandbox-exec, …); `ignoreWorkspaces: vendor/*, python/sdk-runtime`.
- Per-workspace `entry`/`project` declarations — notably `examples` declares its fixture drivers and `*/tests/**/*.e2e.ts|snapshot.ts` as entries so test-only files are not flagged as unused.
- Config is treated strictly: root script runs `knip --treat-config-hints-as-errors`.
- Lint itself is oxlint (`.oxlintrc.json` + `.oxlintrc.staged.json`): `correctness` category off (they use the type-aware rules), `typeAware: true`, `oxlint-tsgolint` plugin, per-rule overrides for source/test/scripts, ignore patterns for vendor/native/lib. Staged config is lighter for pre-commit speed.

### 1.7 Workspace-constraints gate (`scripts/check-workspace-constraints.ts`)

Walks the reachable Project-Reference graph and checks each referencing project uses the correct compiler face (single-config vs split-leaf for `api/remotes`), enforces package-name → path conventions, and validates the workspace topology.

---

## 2. Testing infrastructure

### 2.1 JS testing: vitest, four configs plus opt-in lanes

- `vitest.config.ts` (default, `pnpm run test`): plugin instances point `vite-tsconfig-paths` at `tsconfig.base.json` so bare workspace imports resolve to `src` — **source plane only**, so stale `lib/` never loads a second copy of module singletons. Two aggregated coverage projects; Windows-specific package/test exclusions; pwsh-availability-driven coverage exclusions; a custom Istanbul reporter (`coverage-uncovered-locations.cjs`) that prints exact `path:line:col` records instead of istanbul's name-only threshold errors.
- **Coverage gate** (`test:coverage`): per-file 100% line coverage on `packages/*/*/src` (CI gate). Rationale in `docs/testing.md`: an uncovered line is often dead code flagged for deletion, not a missing test. Exemptions are *probe-linked* (e.g. pwsh suites self-skip via `hasPwsh`, so the exemption is active exactly when the suites skip; CI runners ship pwsh and enforce the full bar).
- `vitest.e2e.config.ts` (`test:e2e`): real-API with-key suites, each self-skipping without its key so keyless CI stays green.
- `vitest.snapshot.config.ts` (`test:snapshot`): keyless replay — boots real example compositions, replays recorded sessions, diffs normalized JSON-RPC + re-persisted session logs. Modes via `DSH_SNAPSHOT=record|refresh|replay`.
- `vitest.web.config.ts` (`test:web`): Chromium browser snapshots of `apps/web/tests/snapshots/`; CI forces `replay` (read-only), record/refresh stay local.
- `vitest.web.perf.config.ts` and `vitest.web-stress.config.ts`: opt-in, outside CI — manual high-cardinality diagnostics (`apps/web/tests/complex-history.perf.ts`) and stress tests.
- Also: `fast-check` property tests, Testing Library (react/dom), jsdom.
- Test policy highlights (`docs/testing.md`): prefer the real implementation over mocks (mock only LLM/network/clock); **verify the world, not the self-report** (re-run the command/re-read the file; assert untouched files byte-identical); test the real entry path (package `bin` runs built `lib/` under plain node); every non-trivial model-visible change adds a keyless snapshot in the same PR; built-artifact smokes (`built-bin.e2e.ts`).

### 2.2 Python testing: pytest + uv

- `pytest.ini`: `testpaths = python/sdk/tests`, `norecursedirs = node_modules .git dist-exe` (prevents recursive collection from sweeping ignored worktrees/venvs).
- `python/sdk/pyproject.toml`: `[dependency-groups] test = ["pytest>=8.0"]`, `[tool.uv.sources]` maps the runtime-bin dependency to `../sdk-runtime` editable for dev.
- Tests: `test_client.py`, `test_runtime_resolution.py`, `test_bundled_runtime.py` (skips carriers whose artifact isn't built), `test_macos_deployment_target.py`, `test_release_version.py`, `test_smoke_model.py` + a manual smoke script.
- Keyless end-to-end verification of the *packaged* runtime uses `scripts/smoke-python-runtime.py` with a mock OpenAI-compatible server (scenarios: `sdk-default`, `sdk-custom`, `sdk-minimal`, `sdk-snapshot`, `direct`) — runs in GitLab CI against every built wheel and again inside a manylinux docker image.

### 2.3 CI workflows (`.github/workflows`, 17 files, ~2.7k lines)

**`ci.yml` (937 lines)** — the primary matrix:
- Required PR jobs: `node-24` (static), `node-24-coverage`, `node-24-consumers` (owns the only Linux build), `node-compat` (Node 22 lane + per-major compat smokes: worker-thread, zstd, source-launch, vitest-jsdom), `python-sdk`, `python-runtime`, `windows` (Wine-gated Windows gates on Linux).
- `windows-native`: real Windows kernel job on a hosted larger runner, deliberately **absent** from `all-checks-passed.needs` so its result never delays the verdict.
- **Failover design:** `DSH_CI_FAILOVER_LINUX` / `DSH_CI_FAILOVER_WINDOWS` repository variables retarget the required jobs onto in-house self-hosted pools (`vm-backup`, `dsh-win-ci`); the pools' readiness is re-proven by `serial-linux-selfhosted` / `serial-windows` **hot-standby drills that run the complete unsharded aggregate on every master push**.
- `all-checks-passed`: single required check aggregating all blocking jobs via `needs`; `if: always()` is load-bearing (a failed dependency would otherwise *skip* the job, and GitHub counts a skipped required check as passing).
- Manual `workflow_dispatch` runner benchmarks: `larger-runner-benchmark` (4→96 cores × linux typecheck / windows docs-build) and `consolidated-runner-benchmark` (bounded in-runner parallelism) — evidence for runner sizing.
- Cache strategy: master push seeds the pnpm-store and Playwright caches; PRs restore-only (keeps paid latency off the critical path); the Wine apt cache is composed keyed by image version.

**`e2e.yml`** — real DeepSeek API: `DEEPSEEK_API_KEY_EXTERNAL` secret, URL pinned to `https://api.deepseek.com` so a stray repo `.env` can't redirect it; job-level `if:` skips fork/Dependabot PRs (secrets withheld); **explicit security note: never change to `pull_request_target`** (key-leak vector for public repos); nightly schedule at 00:17 UTC.

**Other workflows:** `release.yml` / `release-vendor.yml` (pack-on-every-PR + manual publish), `python-release.yml` (GitHub-side docs/exe build), `build-exe-for-python-sdk.yml`, `landlock-run.yml` (per-arch native matrix) + `landlock-run-release.yml`, `docs-pages.yml`, `e2b-e2e.yml`, `pi-ai-provider-e2e.yml`, `sandbox.yml`, `issue-lifecycle.yml`, `issue-policy.yml` (policy.mjs validates PR metadata against `config.json`), `expected-filenames.yml` (blocks "golden"/"golden file" naming — a correctness trap in snapshot tooling).

### 2.4 The gate runner (`scripts/run-gates.ts`) — notable

13 named aggregates (`ci-primary`, `ci-static`, `ci-coverage`, `ci-snapshot`, `ci-artifacts`, `ci-consumers`, `ci-windows-*`, `node-compat`, `check-all`, `doc-sync`, …) are **declarative gate graphs**: each gate carries `needs` (dependency ordering), env overrides, and allow-failure flags; the runner executes with bounded concurrency (`DSH_GATE_CONCURRENCY` env or `availableParallelism()` with a local cap of 4 for doc gates to avoid memory blowups), prints per-gate durations, and spawns pnpm through `process.execPath + npm_execpath` so it works on Windows without shell shims. CI modes are subsets of the local `check-all` aggregate — one source of truth.

---

## 3. native/ and python/ components

### 3.1 `native/landlock-run` — Linux sandbox launcher

- **What:** `landlock-run`, a self-restrict-then-exec Landlock launcher (~300 lines of C11 over the raw kernel UAPI, statically linked against musl). Installs a ruleset on itself, then `exec`s the wrapped command; the ruleset is inherited across `execve`, so the command and its whole process tree run confined while the invoker stays unrestricted. Fail-closed: no enforcement → exits 125 without running.
- **Bindings:** distributed as npm packages — a thin JS entry `@deepseek-ai/node-addon-landlock-run` (resolves the binary, exposes `launcherPath()`, `probe()` → `'full'|'partial'|'unusable'`, `grantArgs()`, plus CLI-contract constants `LAUNCHER_BIN`/`LAUNCHER_FAILURE_EXIT`) plus platform optional packages `-linux-x64`, `-linux-arm64`. npm `os`/`cpu` fields make installers fetch only the matching platform package; **no install-time build fallback on purpose** — consumers fall closed when the path doesn't exist.
- **Distribution/CI:** own version line (0.1.1), own release scripts (`bump-release.mjs`, `assemble-prebuilds.mjs`, `verify-release.mjs`, `pack-release.mjs`, `publish-release.mjs`) and two workflows; per-arch runners build binaries natively (builders of record, binaries git-ignored); kernel-enforcement tests fail rather than skip on unenforcing kernels (`NALR_REQUIRE_LANDLOCK`). Binary contract pinned in `docs/cli-contract.md`, support matrix in `docs/support-matrix.md`.

### 3.2 `python/` — SDK + bundled runtime

Two distributions, both versioned from the root `package.json`:

- **`python/sdk` → `deepseek-harness-sdk`** (pure Python, py3-none-any): pydantic-based synchronous client (`DeepSeekHarness`, `DeepSeekHarnessConfig`, `RunResult`) that launches the runtime subprocess lazily, owns it across `run()` calls, speaks JSON-RPC, exposes `client.py`/`models.py`/`errors.py`. Dependency: `deepseek-harness-runtime-bin==<same version>`.
- **`python/sdk-runtime` → `deepseek-harness-runtime-bin`** (platform wheel): carries the **single-file executable** `dsh-jsonrpc-agent-*` plus a default `cordis.yml` and a node-mode carrier for development. Built by `scripts/build-exe-for-python-sdk.ts` using `@yao-pkg/pkg --sea` (Node 24, SEA mode) from the `python/sdk-runtime` deploy-root package; the staged closure is symlink-free and includes whole-tree asset globs because Cordis has runtime bare-package imports pkg's static analysis can't see. The node-pty patch (see 1.4) lets the SEA exe find its macOS spawn-helper.
- **Wheel tagging:** `hatch_build.py` custom build hook reads `platforms.json`, assigns native tags (`manylinux_2_28_x86_64/aarch64`, `macosx_14_0_arm64`) via `DSH_RUNTIME_PLATFORM_TAG`, and **rejects sdist builds** (wheel-only distribution).
- **Quality gates on the binary:** GitLab CI checks the exe's maximum glibc version ≤ 2.28 via `readelf`, installs and smokes the wheel inside `quay.io/pypa/manylinux_2_28_*` docker images, checks the macOS deployment target, and re-verifies the executable bit on the spawn-helper via a workspace postinstall.
- Supported: linux x64/arm64, macos arm64 (macOS 14+). Windows is a documented non-goal.

### 3.3 Build/release owner: GitLab CI (`.gitlab-ci.yml`)

Python wheels are built and published to the **GitLab Package Registry (PyPI)** — trigger is a `python-v<version>` tag that must exactly match root `package.json` version. Jobs: `sdk-wheel` (pure wheel) + three `runtime-*` platform jobs (each builds the SEA exe, smokes it against the mock model server, checks glibc/macOS constraints, then stages its wheel) → `publish-python` (twine, asserts exactly 4 wheels with exact filenames, `twine check`). GitHub workflows handle the npm side; GitLab handles the PyPI side.

---

## 4. Benchmark harness (BENCHMARK.md)

`BENCHMARK.md` (root, 4 lines) is a *pointer, not a harness*:

> Follow [Get started with the Python SDK](docs/user/guide/python-sdk.md) to install the SDK and run the `jsonrpc-agent` minimal variant. Use separate workspaces and session IDs for independent benchmark tasks.

Methodology as documented: install `deepseek-harness-sdk` (bundled runtime, no system Node needed), run the checked-in `examples/jsonrpc-agent/minimal.py` against an isolated workspace + session root + session id, collect the final response and the JSONL session log. Isolation guidance is "separate workspaces and session IDs per benchmark task." There is **no dedicated model-benchmark suite, scoring harness, or transcript-evaluation framework** in the repo (grep for benchmark hits only the CI runner benchmarks, a web perf file, and docs mentions).

What does exist that a benchmark could build on:
- Deterministic keyless replay infrastructure: recorded session JSONL (`test:snapshot`), the canonical packed-row session-format (`.agents/notes/.../simplify-session-log-representation`), JSONL durability with zstd.
- The mock LLM server (`packages/test-support/llm-mock-server`, `pnpm run mock:llm`) and the mock-model smoke in `scripts/smoke-python-runtime.py` for offline pipelines.
- CI's "benchmarks" are infrastructure benchmarks: `larger-runner-benchmark` / `consolidated-runner-benchmark` (runner sizing evidence, workflow_dispatch only, bounded 15 min, fail-fast: false, max-parallel 12).

---

## 5. Packaging / release / distribution pipeline

Four independent release sequences, each with its own version line, tags, and owner:

1. **dsh family** (`packages/*/*` + `apps/*`) — `release.yml` + `scripts/release/*`:
   - `bump.ts` (`release:dsh`) bumps the family; `verify.ts` validates version/tag state; `pack.ts` builds tarballs (`release:pack --out dist/npm`); `verify-packed-install.ts` installs the packed tarballs in a consumer project — including the vendored family and Landlock entry tarballs, because harness packages peer-depend on the vendored framework and one PR may bump both before either publishes.
   - **Pack runs credentialless on every PR and master push** (proves the publish set still packs); **publication is a manual dispatch from a `dsh-v*` tag** gated by the `npm-publish` GitHub environment (required reviewers), consuming exactly the packed artifact bytes (no rebuild).
   - `publish.ts` is idempotent by integrity: per-package decision against the registry — absent → publish; present with same sha512 integrity → skip (safe re-run); present with different integrity → fail (content changed without a version bump). Transient registry codes (`E409`, `E429`, `E500`, …) retried 4× with backoff, re-reading the registry first since `E409` can answer a write that landed; prerelease versions go to the `next` dist-tag.
   - Also: `publish-npm-baseline.ts` builds/publishes/verifies a commit-addressed baseline to a separate registry (`registry.npm.harnessment.com`) with payload validation (`publication-payload.ts`).
2. **vendor family** (`vendor/*`) — `release-vendor.yml`: 9 packages each on its own version line, `vendor-*` tag family; rescoping to `@deepseek-ai/*` avoids squatting upstream names.
3. **landlock-run** — `native/landlock-run` own workflows + scripts (per-platform prebuilds published as optional-dependency packages).
4. **Python** — GitLab CI `python-v*` tags → wheels (SDK + 3 platform runtime wheels) → GitLab PyPI registry; same-version pinning between SDK and runtime-bin.

Cross-cutting: `pnpm run hygiene` = rescope check + knip + publint + constraints + license/invariant/cordis-config/node-next-types/runtime-closure/vendor-links verification; `verify-built-package-invariants` validates built `lib/` against source invariants; `verify-node-next-types` / `verify-runtime-closure` guard the ESM-only and no-runtime-imports contracts. npm publication is additionally guarded by `publint` and the `verify-package-invariants` gates.

---

## 6. Notable engineering techniques & patterns worth adopting

1. **Two-face TypeScript aggregates (host/client).** Split repo-wide type-checking into two `ts.Program`s to dodge a real declaration-merging collision (cordis Context), while one solution file and one paths facade span both. Extremely clean answer to "two sides merge the same interface differently."
2. **Source plane vs artifact plane, never mixed.** tsconfig `paths` → `src` for all test/build-time resolution (via a match-all facade with no `include`); built `lib/` is consumed only by explicit built-smoke tests. Eliminates the stale-artifact double-singleton class of bugs.
3. **Declarative gate graphs (`run-gates.ts`).** CI modes as data (gates with `needs`), one runner, bounded concurrency, Windows-safe process spawn. CI and local `check-all` share the same definitions.
4. **Single-required-check CI verdict with `if: always()`.** Aggregating `all-checks-passed` job that fails on any non-success (including `cancelled`/`skipped`) — avoids the "skipped required check passes" GitHub trap; new lanes join via `needs`, not branch-protection edits.
5. **Failover as repository variables + hot-standby drills.** `DSH_CI_FAILOVER_LINUX/WINDOWS` vars retarget jobs to in-house pools with zero merge; every master push re-runs the full unsharded aggregate on the standby pool to prove it can take over. Writer-manageable, PR-safe.
6. **Evidence-based runner sizing.** Manual `workflow_dispatch` benchmarks compare 4→96-core hosted runners on real critical lanes before committing to larger runners (`.agents/notes/implemented/process/2026-07-22-evidence-based-larger-hosted-runners.md`).
7. **Keyless snapshot testing with recorded sessions.** ACP/headless/web replays of real recorded transcripts (JSONRPC + JSONL + browser) are the primary model-visible regression net; record/refresh are local-only, CI is read-only replay.
8. **Real-API e2e discipline:** self-skip without key (keyless CI stays green) but hard-fail preflight when a secret *is* expected; never `pull_request_target`; pinned base URL so stray `.env` can't redirect; secrets checked out only under trusted events.
9. **Vendoring with rescope + linkWorkspacePackages + exhaustive modification log.** Pinned upstream sources under `@deepseek-ai/*`, preserved semver ranges resolving to workspace links, a manifest with SHAs, and a numbered local-modification log that is the sync surface. Solves auditable-framework + registry-squatting in one.
10. **Deny-by-default install scripts (pnpm `allowBuilds`).** Every lifecycle-script dependency is explicitly reviewed; denied ones are documented no-ops. Strong supply-chain hygiene.
11. **Idempotent integrity-based publishing.** Publish decisions per-package against the registry with sha512 comparison; retry only transient codes; re-running is always safe. Distinctive and directly portable.
12. **Per-file 100% coverage gate + custom reporter + probe-linked exemptions.** The gate treats uncovered lines as dead-code candidates; exemptions activate exactly when the probe says the suites self-skip (pwsh), so no silent green.
13. **Regenerate-don't-reject pre-commit** for generated artifacts (THIRD_PARTY_NOTICES.md), with the deletion edge case caught by a CI freshness assertion — fast local feedback without nagging.
14. **Single-file executable distribution** (pkg SEA) with whole-tree asset globs for statically-invisible runtime imports, platform manifest, native wheel tags via a hatch build hook, and binary-level glibc/deployment-target verification before publishing.
15. **Mock-model smoke of the packaged artifact.** `smoke-python-runtime.py` runs the *published wheel's* exe against a local OpenAI-compatible mock server in multiple scenarios — verifies the artifact, not the source tree.
16. **Docs-as-code enforcement:** doc budgets, markdown wrap/link checks, doc typecheck against built output, generated catalogs with `--check` freshness gates, bilingual pairing verification — a docs pipeline treated with the same rigor as code.
17. **Agent Notes system** (`.agents/notes`): classified implemented/proposed/rejected/archived with format/classification verification gates and frozen archives; keeps design rationale reviewable and stale notes out of circulation.
18. **Issue/PR policy enforcement via `policy.mjs` + `config.json`**, and a trivial-but-clever "expected filenames" workflow banning golden/golden-file names (a known correctness trap in snapshot tooling).
19. **CI hygiene details:** pnpm store restore-only on PRs (master seeds), Wine apt cache keyed by image version, checkout pinning (`actions/checkout@3d3c42e…`), least-privilege `permissions`, telemetry disabled in CI via env.

---

## Open questions / unresolved

1. **Benchmark methodology is thin.** BENCHMARK.md points at the Python SDK guide and gives isolation advice; there is no in-repo scoring harness, evaluation transcript set, or methodology doc for agent-task benchmarks. Is a fuller harness planned (this is the primary gap if the upgrade intends benchmark-driven development)?
2. **`minimumReleaseAgeExclude` + patched `pi-ai`** suggest the model-catalog dependency (`@earendil-works/pi-ai`) is updated aggressively; unclear how upstream drift is gated (only the fresh-release exclusion is visible).
3. **GitHub vs GitLab split:** npm publishes via GitHub Actions, Python wheels via GitLab CI with tag-version cross-checks. There is a GitHub `python-release.yml` too — the relationship/trigger division between the two Python paths is not fully documented in this pass.
4. **`publish-npm-baseline.ts` targets `registry.npm.harnessment.com`** — an internal registry; whether baselines are part of normal release flow or a private verification channel is unclear.
5. **Two `serial-*` hosted jobs are `if: false`** (temporarily disabled) pending a "hosted-serial-ci" TODO; the self-hosted standby lanes remain active. Timing of re-enablement is an open risk for hosted CI readiness.
6. The `dsh-*` invariant subpath-export wildcard machinery (`.ts` specifier rewriting, `@deepseek-ai/dsh-*/invariant` paths) is intricate; how much of it is required by NodeNext consumers vs. legacy compatibility was not investigated in depth.
7. Windows PTY support relies on `koffi` (MoveFileExW write-through) and node-pty's ConPTY; the patch only covers the macOS helper path — any Windows-specific patching needs are undocumented beyond that.
