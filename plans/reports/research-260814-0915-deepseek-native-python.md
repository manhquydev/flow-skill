# DeepSeek Harness — native/ + python/ + patches/ deep dive

- Scope: `native/`, `python/`, `patches/` of `/home/manhquy/Downloads/deepseek-harness` (read-only).
- Date: 2026-08-14. Sibling research covers architecture, build infra, `packages/`, `apps/`, docs+benchmark.

## 1. native/ — what is implemented natively

**Exactly one first-party native tool exists: `landlock-run`** (`native/landlock-run/`), a Landlock self-restrict-then-exec launcher consumed by the harness sandbox seam. Everything else native in the repo is third-party or built-in (see §3).

### Language / toolchain
- ~300 lines of **C11** (`native/landlock-run/packages/entry/src/main.c`), compiled by `native/landlock-run/scripts/build.ts` with distro `musl-gcc` flags `-std=c11 -Os -Wall -Wextra -Werror -static -s`.
- **Statically linked against musl** → one binary runs on glibc and musl distros, no loader/libc expectations on consumers.
- Raw kernel UAPI: the Landlock structs/syscall numbers (`landlock_create_ruleset` 444, `landlock_add_rule` 445, `landlock_restrict_self` 446) are **self-defined in-file** instead of including `<linux/landlock.h>` — keeps the build independent of toolchain header vintage and doubles as an audit record. No libraries beyond musl libc.
- No cross toolchain on purpose: builds are native-only per architecture; CI per-arch runners are the builders of record (`native/landlock-run/docs/architecture.md` "Build and release model").

### FFI/binding mechanism to JS
- **Not a Node addon** (the `node-addon-` name prefix is historical homage to the packaging model of `@esplus/node-addon-require-builtin`). It is a standalone static executable; JS talks to it by **spawning with argv, reading stdout/stderr, exit codes**.
- The ESM entry package `@deepseek-ai/node-addon-landlock-run` (`packages/entry/src/index.ts`) owns the CLI contract: `launcherPath()` (resolve per-platform package → `<pkg>/bin/landlock-run`), `grantArgs({readOnly, readWrite})` (argv construction), `probe()` (functional enforcement probe via `spawnSync` → `'full' | 'partial' | 'unusable'`), plus constants `LAUNCHER_BIN`, `LAUNCHER_FAILURE_EXIT = 125`.
- Fail-closed everywhere: exit 125 + one `landlock-run: ...` stderr line on any launcher-level failure; kernel without Landlock → refuses to exec at all. A successfully exec'd child may also return 125, so consumers need status **and** the fatal stderr line to attribute failure (`docs/cli-contract.md`).
- Probe is **functional, not version-based**: `--probe` actually builds and enforces a maximal ruleset in a short-lived child, because a kernel can have the syscalls but refuse enforcement.
- No environment-variable inputs anywhere (which binary confines a process must never be decidable by the ambient environment).

### Build + distribution
- Two-layer npm family, one version: entry package (ESM JS, **no install script, no compile fallback** — a host without a platform package probes `unusable` and the consumer falls closed) + per-platform packages `-linux-x64` / `-linux-arm64` (one prebuilt static binary under `bin/`, a `prebuilds.json` manifest, no JS at all).
- npm `os`/`cpu` fields make installers fetch only the matching platform package; entry lists platform packages as `optionalDependencies`.
- `scripts/build.ts` derives targets from checked-in `prebuilds.json`; `scripts/github-matrix.mjs` derives CI/Release matrices from the same metadata. Supported kernels: 5.13+ with Landlock enabled; ABI level decides `full` vs `partial` (`docs/support-matrix.md`).
- Pack gates: platform prepack refuses missing/wrong-ELF binaries and anything undeclared in `bin/`; entry prepack refuses unbuilt `lib/`; `verify-packed-install.mjs` rehearses a throwaway install, byte-pins installed binaries against workspace builds, and runs a real confinement world-proof (`docs/packaging.md`).
- Pack split: platform tarballs via `npm pack`, entry tarballs via `pnpm pack` (pnpm normalizes file modes and strips the executable bit). Release pipeline: `landlock-run.yml` (build/test matrix) + `landlock-run-release.yml` (assemble, verify, publish), tags `landlock-run-vX.Y.Z` (`docs/release.md`).

### Consumer
- `packages/sandbox/sandbox-local` (`src/index.ts`, `src/profiles.ts`): Linux runner chain is `['bwrap', 'landlock']` — bwrap preferred (mount profile closest to the mode vocabulary), Landlock as the second rung where bwrap is unusable (unprivileged userns disabled, no mount). `landlockProfileArgs` grants `--ro /` plus `--rw` on `/dev/null`, `/tmp`, workspace root in `workspace-write` mode. Probe verdicts cached; `full`/`partial`/`unusable` map to `SandboxEnforcement`. `packages/shell/bash-sandbox` consumes the seam and classifies denials from the EACCES stderr dialect.

## 2. python/ — purpose, layout, pytest scope, TS interop

### Purpose
Python SDK to drive DeepSeek Harness **as a subprocess** over newline-delimited JSON-RPC 2.0 on stdio (`python/README.md`). The runtime is a bundled single-file Node executable — no Node install needed on the target machine.

### Package layout
| Dir | Dist / module | Role |
|---|---|---|
| `python/sdk` | `deepseek-harness-sdk` / `deepseek_harness` | high-level turns API + lower-level JSON-RPC client (pure Python, pydantic) |
| `python/sdk-runtime` | `deepseek-harness-runtime-bin` / `deepseek_harness_runtime` | bundled runtime executables + checked-in default `cordis.yml`; wheel-only |

- `python/sdk`: `src/` layout (`api.py`, `client.py`, `models.py`, `errors.py`), `pyproject.toml` (hatchling 1.30.1), `uv.lock`, tests in `python/sdk/tests/`. `DeepSeekHarnessConfig` exposes `provider` (default `deepseek-official`), `model` (default `deepseek-v4-flash`), `max_tokens`, `cwd`, `session_root`, `cordis`, `runtime_bin`, `launch_args_override`, `base_url`/`api_key`.
- `python/sdk-runtime`: `src/deepseek_harness_runtime/__init__.py` (resolution API: `resolve_bundled_launch_args(mode)` — explicit arg > `DSH_RUNTIME_MODE` env > automatic; automatic finds the **exe only**, the dev-only node carrier is never auto-selected), `hatch_build.py` (custom Hatch hook: wheel-only, rejects `py3-none-any`, absent/multiple/non-executable payloads, wrong platform tags; assigns `py3-none-manylinux_2_28_x86_64|aarch64` / `py3-none-macosx_14_0_arm64`), `platforms.json` (single source for tag↔executable pairs), `deepseek-harness-runtime.json` metadata.
- Carriers under `src/deepseek_harness_runtime/runtime/`: **exe** (production, `dsh-jsonrpc-agent-pkg-<platform>-<arch>`, macOS also ships the node-pty `-spawn-helper` sibling) and **node** (dev-only full deploy closure, `DSH_RUNTIME_MODE=node`, needs system Node ≥22.19). Both gitignored, injected by `scripts/build-exe-for-python-sdk.ts`. `runtime/cordis.yml` IS checked in — the zero-config default composition (jsonrpc server + agent-core + llm-deepseek + JSONL persistence + checkpoint policy + bash-local + fs-local, with `!!js` env fallbacks).

### pytest.ini scope
Root `pytest.ini` restricts collection to `testpaths = python/sdk/tests` with `norecursedirs = node_modules .git dist-exe`. Rationale (comment in file): recursive collection can pick up ignored worktrees/venvs and collide on same-named modules. The SDK's own `pyproject.toml` sets `addopts = -q`, `testpaths = ["tests"]` for in-package runs. CI: `python-sdk` job runs the complete keyless suite on Python 3.10 (`uv run --project python/sdk --group test pytest`); `python-runtime` job builds one release-shaped Linux x64 exe via the reusable `build-exe-for-python-sdk.yml` workflow. Tests: `test_client.py` (~30 tests, fake runtime peer via a script that speaks the NDJSON protocol), `test_runtime_resolution.py`, `test_bundled_runtime.py` (skips carriers whose artifact wasn't built), `test_release_version.py`, `test_macos_deployment_target.py` (runs `scripts/check-macos-deployment-target.py`), `test_smoke_model.py`, plus `manual_sdk_agent_smoke.py` (source-mode).

### How python interops with the TS side
- **Wire**: NDJSON JSON-RPC 2.0 on the subprocess stdio. Methods: `initialize` (`{cwd, provider, model, maxTokens?}`) → `InitializeResponse`; `session/prompt` (`{sessionId, contentBlocks}`) → `{messageId}` (queues a user message, returns immediately); notifications `session.event` (every durable fact), `session.status` (whole-agent lifecycle; `idle` marks an owned run interval), `subagent.started`/`subagent.finished` (SDK tracks parent→child ancestry to filter notifications to a session tree); `shutdown` (graceful close, flushes response, exits 0). Client is synchronous, threaded reader + write lock, per-request `queue.Queue` waiters, timeout diagnostics that include the stderr tail (`client.py`).
- **Server side (TS)**: `packages/sdk/server` (`@deepseek-ai/dsh-sdk-jsonrpc-server`) is a Cordis plugin mounting `HarnessSdkJsonRpcServer` + stdio transport; wire types in `packages/sdk/protocol`; app bin `packages/examples/jsonrpc-demo` (`dsh-jsonrpc-agent`). Stdout is the protocol — no stdout loggers allowed in the composition.
- **Build bridge**: `python/sdk-runtime/package.json` (`dsh-jsonrpc-agent-pkg`) is a **dependency-only deploy manifest** whose closure IS the plugin set bundled into the exe and materialized into the node carrier. `scripts/build-exe-for-python-sdk.ts` runs `pnpm --filter dsh-jsonrpc-agent-pkg deploy --legacy --prod` into the runtime dir, materializes symlinks, injects pkg config (`bin` → `packages/examples/jsonrpc-demo/lib/packaged-bin.js`, whole-tree `assets` globs because dynamic imports are invisible to pkg's static analysis), then one `@yao-pkg/pkg@6.21.0 --sea` invocation per target (Node 24, linux/macos × x64/arm64). `scripts/verify-runtime-closure.ts` (run in `pnpm run hygiene`) walks the manifest's workspace deps and requires every non-optional peer to be present at the runtime root.
- **Versioning/release**: root `package.json` version is authoritative; `scripts/build-python-release.py` stages both wheels at that version (PEP 440 normalization for prereleases) and pins the SDK to the exact same `deepseek-harness-runtime-bin` version. Windows is a documented non-goal.

## 3. Other native surfaces (in packages/, not native/)

- **node-pty 1.1.0** (patched, see §4): native PTY addon — `pty.node` (Linux, built from source at install), prebuilds + `spawn-helper` on macOS, ConPTY on Windows. Used by `packages/subprocess/subprocess-local/src/terminal.ts` (local PTY terminal for the subprocess seam); `allowBuilds: node-pty: true` in `pnpm-workspace.yaml`.
- **koffi** (Win32 FFI library, loaded lazily so non-Windows processes never open it):
  - `packages/session/session-persistence-jsonl/src/win32.ts` — `MoveFileExW` with `MOVEFILE_WRITE_THROUGH` for durable JSONL publish (Windows has no parent-dir fsync in Node).
  - `packages/sandbox/sandbox-windows-acl/src/ffi.ts` + `win32-abi.ts` + `spawn.ts` — the whole Win32 ACL sandbox: `CreateRestrictedToken`, `CreateProcessAsUserW`, ACL/SID APIs, anonymous pipes; signatures verified against MinGW headers, struct layouts asserted against `verify/abi-probe.cpp`. The runner itself is a JS argv-prefix wrapper (`runner.ts`, stable argv contract, exit 127).
  - `packages/host/directory-picker-native/src/win32-dialog*.ts` — `IFileOpenDialog` COM conversation via koffi in a spawned child process (per-monitor-v2 DPI, `WM_CLOSE` abort).
- **node:sqlite** (`DatabaseSync`, built into Node): `packages/session/session-persistence-sqlite` (monotonic `SCHEMA_VERSION` 15) and `session-query-sqlite`.
- **E2B** (`packages/e2b/*`): **remote cloud sandboxes**, not native — `e2b` npm SDK against the E2B API; FS/subprocess adapters share one remote Linux world (`packages/e2b/e2b/src/index.ts`); CI workflow `e2b-e2e.yml` is opt-in (`workflow_dispatch` only, needs `E2B_API_KEY`).
- **`node-addon-require-builtin` ^0.1.4**: declared dependency of `apps/cli/package.json`, and named in `native/landlock-run/docs/architecture.md` as the packaging model's inspiration — no direct `import` found in `apps/cli/src` (unresolved question, §6).

## 4. Performance-critical paths and why they went native

- **Process confinement (bash tool)**: kernel-enforced filesystem allow-list via Landlock (in-process ruleset inherited across `execve`), or external bwrap/Seatbelt binaries. Cannot be done as an in-process JS fence — a JS check is policy, not a security boundary (the repo's own `dsh-fs-sandbox` in-process fence explicitly frames itself as "a policy fence, not a kernel boundary"; kernel-grade isolation of untrusted code stays `ctx.shell`'s job).
- **PTY terminal I/O**: node-pty native addon — PTYs require kernel terminal emulation (`forkpty`/`openpty`, termios, `TIOCSWINSZ`), ConPTY on Windows; not expressible in JS.
- **Session-log durability**: JSONL publish via parent-dir fsync (POSIX) / `MoveFileExW` + `MOVEFILE_WRITE_THROUGH` via koffi (Windows) — OS write-through semantics Node fs does not expose; SQLite backend uses native `node:sqlite`.
- **Windows ACL restricted-token sandbox**: entire Win32 token/ACL surface (CreateRestrictedToken, ACL ACE materialization, SID derivation) via koffi FFI — no JS equivalent exists.
- **Python interop throughput**: NDJSON over stdio (no network/TLS); lazily started runtime subprocess **reused across calls** (no per-turn spawn); one-time functional probes cached; single-file exe removes Node installation cost; `maxTokens` caps request output. Process-tree inspection deliberately stays non-native: `/proc` (Linux) / `ps` (via `execFileSync`) in `packages/subprocess/subprocess-local/src/process-inspector.ts`.

## 5. Techniques worth adopting

1. **Per-platform optional-dependency package family for native binaries** (esbuild model): entry JS package owns the CLI contract + argv construction; platform packages carry only the binary + `prebuilds.json`; npm `os`/`cpu` select at install; checked-in matrix metadata drives CI/release matrices via one generator script.
2. **No install-time compile fallback** for native artifacts — a missing platform package probes `unusable` and the consumer fails closed; no environment-dependent maybe.
3. **Functional probe instead of version checks** — `--probe` really enforces a maximal ruleset; version checks would miss kernels that have syscalls but refuse enforcement. Probe verdicts cached once.
4. **Fail-closed binary contract pinned in docs** (`docs/cli-contract.md`): exit-code constants, exact stderr lines, argv grammar; JS entry and binary version together in one package family so contract drift is structurally impossible.
5. **Static musl builds** for Linux: one artifact for glibc+musl; no cross toolchain — per-arch CI runners as builders of record; pack gates verify ELF `e_machine`, executability, and byte-pin installed binaries vs workspace builds.
6. **Wheel-only native runtime package** with a build hook that rejects wrong platform tags / mixed payloads / missing executables at build time; `platforms.json` as single source of truth; same-version pin SDK↔runtime; **dev-only carrier explicitly opt-in** (`DSH_RUNTIME_MODE=node`), production never silently rides a source build; acquisition strategy separated from lookup interface (downloadable exe later without touching callers).
7. **Zero-config as explicit injection, not hidden fallback**: the runtime binary always demands a config; the SDK wrapper injects the checked-in default `cordis.yml` via `DSH_CORDIS_CONFIG` only for bundled launches.
8. **Single-file exe via pkg `--sea`** over a **dependency-only deploy manifest** (the closure manifest IS the plugin set): real package tree inside the VFS (no transpilation, config decides everything), `pnpm deploy` + symlink materialization, whole-tree asset globs for invisible dynamic imports, per-platform native-addon staging (node-pty), worker entries kept CJS in VFS.
9. **Lazy FFI loading** (koffi imported only on win32) so non-Windows processes never load native libs; signatures verified against real headers, struct layouts asserted at load.
10. **Repo-root `pytest.ini` that pins collection scope** (`testpaths = python/sdk/tests`, `norecursedirs = node_modules .git dist-exe`) to avoid venv/worktree collisions in a monorepo; uv-managed venv kept outside the repo.
11. **Threaded reader + per-request queues + write lock** for stdio subprocess IO; timeouts produce diagnostics including the stderr tail (a small, high-value UX touch).
12. **Pack-split rule**: platform tarballs via `npm pack`, entry tarballs via `pnpm pack` (pnpm strips executable bits) — a subtle packaging footgun others will hit.

## 6. Unresolved questions

- `node-addon-require-builtin@0.1.4` is a declared dependency of `apps/cli` but no direct import exists in `apps/cli/src` (grep found none). It may be loaded at runtime by a transitive dependency (e.g. node-pty 1.1.0's prebuild loader). Confirm where it is actually consumed and whether `apps/cli` is the right home for it.
- node-pty on Linux is compiled from source at install time (`allowBuilds` + the exe build script copies the built `pty.node` from the workspace install). This means a plain npm consumer of the harness packages on Linux needs a C++ toolchain; the wheel/exe distribution sidesteps it. Check whether node-pty 1.1.0 ships Linux prebuilds that could be used instead.
- The `node-addon-` name prefix on a non-addon standalone binary is a deliberate historical homage, but readers new to the repo may assume a real Node ABI surface; confirm the naming decision is worth keeping.
- macOS wheel tag `macosx_14_0_arm64` is deliberately conservative versus the Node 24 executable's 13.5 deployment target — confirm the CI actually validates the OTool `LC_BUILD_VERSION` (there is a checker + test, but the link to CI is in the release workflow).
- The e2b sandbox CI is manual-dispatch only; no periodic/PR signal for E2B regressions. Deliberate (external dependency), but worth flagging if the upgrade plans to touch `packages/e2b/*`.
- Landlock ABI negotiation caps at ABI 5 (`MAX_ABI 5`); kernels with ABI 6+ (e.g. `ioctl` refinements) are reported as `full` with the known ABI-5 access set — the semantics of "full" relative to future kernels are defined by this build's vocabulary, not the kernel's. Confirm consumers understand "full" means "full for what this build knows".
- Python requires >=3.10; CI only exercises 3.10 (and release validation mentions 3.10/3.14). Verify the SDK runs on 3.11–3.13 (no typing/`slots` issues) since only the edges are CI-tested.
