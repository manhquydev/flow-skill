# APPS Deep Dive — deepseek-harness `apps/`

Date: 2026-08-14 · Researcher: APPS (apps lane) · Mode: READ-ONLY
Scope: `apps/` = `apps/cli` (@deepseek-ai/dsh, the `dsh` launcher) + `apps/web` (@deepseek-ai/dsh-web-frontend, the Vite web entry). Both are deliberately thin; the product surface lives in `packages/` (bundles, client UI packages, boot glue). Evidence paths are repo-relative.

## 1. Enumeration

### 1.1 `apps/cli` — `@deepseek-ai/dsh` (the `dsh` binary)

- **Purpose**: product launcher / profile booter. "profile boot, plugin management, and the browser UI alias" (`apps/cli/package.json`). Binds only a tiny command grammar; the real apps are *profiles* (plugin-bundle stacks) it boots.
- **Entry points**:
  - `apps/cli/src/bin.ts` — shebang'd `node` entry; `package.json` `bin: { "dsh": "lib/bin.js" }`. Dynamic-imports per mode: `profile` → `profile-boot.ts`, `plugin` → `plugin.ts`, `dump-config` → `dump-config.ts`.
  - `apps/cli/src/args.ts` — commander grammar (`--profile`, repeatable `--patch`, `--dump-config`/`--dump-default-config`, `web` subcommand alias, `plugin` subcommand). **Key design**: launcher parses only its own flags; first unrecognized token starts the app's own argv, handed verbatim via `ctx.cmdlineArgs` (apps/cli/src/args.ts docblock, apps/cli/reference/README.md "App arguments").
  - `apps/cli/src/profile-boot.ts` — the shared boot for every surface: profile resolution, layer stacking, HMR watchers, fail-loud, bounded shutdown.
  - `apps/cli/src/plugin.ts` — `dsh plugin --profile X <pnpm args>`: pnpm forwarder + `dsh.profile.bundles` reconciliation.
  - `apps/cli/src/dump-config.ts` — boot-free composed-tree printer.
  - `apps/cli/src/process-shutdown.ts` — bounded (5 s) escalating process shutdown.
- **Runtime**: Node ESM, `node --import tsx/esm` for source runs (`package.json` `dsh` script), bundled `apps/cli/lib/bin.js` for installs (tsdown, `apps/cli/tsdown.config.ts`). Engines `^22.19 || >=24` (root `package.json`).
- **Shipped data**: `apps/cli/config/agent-presets/` — 4 agent presets (`standard`, `code`, `minimal`, `cordis`) as `preset.yml` + `agent.cordis.yml` agent-plane compositions; injected by `composeProfile()` as the `agent-presets` row's shipped `system` root (apps/cli/src/profile-boot.ts, `SHIPPED_PRESET_ROOT`). Profiles `web`/`headless` auto-initialize from templates (`PROFILE_TEMPLATES` in `packages/boot/app-boot/src/profile.ts`: web = base+web-app; headless = base+headless).
- **Modes it launches**: `dsh web` (= `--profile web`, browser UI on `127.0.0.1:3080` default) and `dsh --profile headless "task"` (one-shot: fresh session, print final answer, exit 0/1). Custom profiles via `dsh plugin`.

### 1.2 `apps/web` — `@deepseek-ai/dsh-web-frontend`

- **Purpose**: the only real "app surface" — a Vite build over the `@deepseek-ai/dsh-client-web` shell library. "dist/ served by apps/cli's dsh web" (`apps/web/package.json` description).
- **Entry points**: `apps/web/index.html` (#root + `/src/main.ts`); `apps/web/src/main.ts` = 10-line bootstrap `new AppWebEntry(el).run()`; `apps/web/src/node-module-stub.ts` (browserization of the vendored loader). Everything else (loader holding, module seeding, AppRoot gate, plugin assembly) lives in `packages/client/web`.
- **Runtime**: browser React 18 SPA built by Vite; `vite.config.ts` aliases `@deepseek-ai/dsh-client-*` workspace packages to **source** so CSS rides the vite pipeline, and refuses standalone serve (`dsh-reject-standalone-web-serve`) — it must be booted by a real `dsh web` host that injects `window.__DSH_BOOT__`. Vendor chunk = math/highlight/markdown families (`vite.config.ts` `VENDOR_PACKAGES`).
- **Non-surface assets**: `apps/web/public/` PWA manifest (fullscreen, SVG icon) + favicon; `apps/web/tests/` 69 browser e2e + 7 snapshot + 1 perf (`complex-history.perf.ts`) + 1 stress (`stress-tests/reasoning-chunks.stress.ts`).

### 1.3 What is *not* an app

There is **no TUI and no desktop app** in `apps/`. The README examples mention `dsh --profile tui` as an installable third-party profile (apps/cli/README.md), but none ships. Terminal *capability* (`packages/terminal`, `terminal-bash`) is an agent tool (persistent PTY), not a user surface. Automation surfaces are `packages/acp` (ACP server) and `packages/sdk` (JSON-RPC), outside apps.

## 2. UI/UX architecture

### 2.1 CLI (the launcher)

Pure dispatcher, not a UI. Grammar is deliberately minimal and "app-arguments after the first unknown token" is the contract (apps/cli/src/args.ts). UX affordances: `--dump-config`/`--dump-default-config` for inspecting composition without booting; `--help` at two levels (launcher's own vs. the booted app's, decided by whether a profile is named — `dsh -h` prints launcher help, `dsh --profile web --help` prints web's and boots nothing). Exit codes: SIGTERM→0, SIGINT→130, usage errors nonzero (apps/cli/src/profile-boot.ts, reference/README.md). CLI test artifacts: `apps/cli/tests/dsh-badge.snapshot.ts` (boots base composition with an overlay; snapshot of session-log content, e.g. skill-badge), `built-bin.e2e.ts` (published-entry acceptance).

### 2.2 Web UI (the product surface)

**Rendering approach**: React 18 SPA, but the *shell is a cordis boot kernel*, not a router app. Two-stage boot ("web2") in `packages/client/web/src/boot.tsx`:
1. module face: build `ClientModuleSystem` over host-pushed `window.__DSH_BOOT__` (module table from `apps/cli`/web-app bundle's `dsh.client` rows), prefetch `immediately` tier;
2. plugin face: mount vendored cordis Loader with the module system injected via its `internal` contract, create one loader entry per graph row **plus a shell-owned pseudo-entry** `@deepseek-ai/dsh-client-app-shell` (`app-shell.ts`), await quiescence, sweep all fibers ACTIVE, then flip one `settled` signal.

`AppRoot.tsx` is the gate: loading card → one-switch full UI, or a **fail-loud per-entry report** (no partial UI, no progressive rendering — explicit deferred work in `packages/client/web/README.md`). Shell self-sufficiency rule: the kernel value-imports no plugin package so the loading/failure page works even when plugins fail. Composition is 100% the host graph's; the shell makes zero composition decisions.

**Layout**: three-column AppFrame (`packages/client/ui-layout`) — sidebar / conversation / details — with drag handles, a concession chain (details shrinks then auto-closes), transient geometry (no localStorage persistence; reload resets). Sidebar collapse leaves a 56px control rail. UI is assembled via a **slot system**: `ctx.slots.renderSlot('root', {})` is the one ctx-level render call (`packages/client/web/src/app.tsx`); every feature registers into declared slots (e.g. `sidebar.workspaces`, `sidebar.settings`, `conversation.input.overlay`, `conversation.input.dock`, `conversation.view` ring, `conversation.session.header.actions`). SlotMap declaration-merge + declaration injection (`packages/client/runtime/README.md`).

**Interaction loop with the agent runtime**:
- Transport: HTTP POST for unary/respond RPCs + **two downlink-only WebSockets** (`/api/events.mux`, `/api/events.host`) — `packages/client/connection`. Loopback trust fence on every `/api` entry (Host header + Origin/Fetch-Metadata checks; DNS-rebinding defense; `--trusted-host` for LAN).
- Host side: `packages/host/apiproxy` gateway over the Typert RPC registry; `packages/client/runtime` owns `SessionRuntime`/`WorkspaceRuntime`, fans the shared host stream into session/workspace owners (`ctx.remote.$dispatch`/`$on`), and assembles the conversation as **event-driven Definitions** (`ConversationNodeAssembler`): plugins register business Definitions mapping one event to `{kind, id}`, folded into renderable nodes with a stable Context index.
- Model-visible ⟺ logged: every session event is durable JSONL (`packages/session`); the browser renders from the same log (seeded-history pattern, zero-model-call e2e).
- Live updates: `session/projection` frames under higher-seq-wins feed a `ProjectionValueStore`; features read via `useProjection` (e.g. goal bar, todo, plan chip) — no per-feature polling.
- Input: composer with `/` and `@` trigger pipeline (`packages/client/ui-input-trigger`, combobox with `aria-activedescendant`), command surface with three dispatch kinds (`execute`/`popupSelect`/`leadingInput`, `packages/client/ui-commands`), fuzzy slash-command discovery, keyboard arbitration (`matchSpace`/`matchEnter` — "a `/` line is never silently downgraded to a plain prompt").
- Human-in-the-loop: approval panel takes over the composer (bounded card geometry so allow/deny stays visible — `apps/web/tests/approval-composer.e2e.ts`), question composer, plan review composer, permission presets.

### 2.3 Headless (one-shot CLI surface)

No UI: creates one Agent through the core registry, awaits quiescence, flushes the Session, prints the last non-empty assistant text + exit by `turn/end` reason (`packages/bundle/headless/src/index.ts`, `startup.ts`). "Prints nothing to stderr, opens no port" on success.

## 3. How apps consume packages/ (composition boundaries)

The boundary is *composition by patch layers*, not library imports:

- **The app owns the launcher grammar and layer stacking**; the *content* of every surface is `packages/bundle/{base,web-app,headless}/cordis.patch.yml` rows. `apps/cli/src/profile-boot.ts` stacks: bundle patches (in `dsh.profile.bundles` order) → profile `cordis.patch.yml` → home `$DSH_HOME/cordis.patch.yml` → `--patch` overlays → telemetry switch → shipped agent-preset root. Later layers win per-row; a patch replaces a row's whole `config` (no deep merge).
- **Boot glue** consumed by the app: `@deepseek-ai/dsh-app-boot` (boot, composeEntries, loadProfile, healProfilesModuleFallback, installFailLoud, watchUserPatches), `@deepseek-ai/dsh-cmdline` (provideCmdline → `ctx.cmdlineArgs`), `@deepseek-ai/dsh-launch-environment` (immutable env snapshot provided pre-mount), `@deepseek-ai/dsh-home-paths` (resolveDshHome). The app's package.json dependency list is essentially "every bundle + boot package + agent preset surface" (apps/cli/package.json).
- **The CLI app's only code-level product logic**: the shipped preset root (assembly fact injected as the `agent-presets` row `roots` — see scaffold.ts comment "AppCLIEntry"), telemetry opt-out switch resolution, HMR watch-only fallback, shutdown. Everything else is row configuration.
- **Web app** (`apps/web`) consumes exactly one runtime package: `@deepseek-ai/dsh-client-web` (plus React). The client UI packages (`ui-*`) are **never imported by the app** — they arrive as runtime bundles through the client module system, and vite aliases them to source only for the shell's own imports. Shell self-sufficiency hard rule (packages/client/web/README.md).
- **Plugins out of tree**: `dsh plugin` installs packages into a profile dir; `dsh.bundle.patch` in a package manifest makes it a patch layer; installed-state reconciliation decides layer membership (apps/cli/src/plugin.ts).
- **Tests reuse the same seam**: `apps/web/tests/scaffold.ts` boots the *real* composition (`base` + `web-app` patches over an empty root through the vendored Loader) and diverges only via include patches after the shipped layers — same tree, never a second yml. `apps/cli/tests/web-agent-presets.e2e.ts` boots base+web-app patches with the *shipped* preset dir.

## 4. Config / settings / session UX

- **Config = cordis.yml patch layers.** Three inspectable layers via dumps; live HMR re-applies valid edits to both user patch files transactionally without reload (profile-boot.ts `watchUserPatches`); `!!js` evaluated only at boot, never in dumps. Misconfiguration fails loud (installFailLoud) or at dump.
- **App flags**: flags beat yml values through an inject-then-read pattern: the `web-startup`/`headless-startup` ordinary provider parses flags, provides a service, and config rows `inject` it and read `!!js ctx.webStartup.port ?? 3080` from lazy config (packages/bundle/web-app/src/startup.ts, cordis.patch.yml). A live patch edit re-evaluates against still-up services so a served port cannot be reset.
- **Settings UX (web)**: modal settings panel (trigger, nav, section switching, both close paths — `settings-chrome.e2e.ts`); sections: General (Appearance theme cascade, Language, busy-state Enter), Models, Plugin inventory, Permissions. Backed by `packages/settings` (namespaces, layered resolution user-over-base, hot commits; file provider `packages/settings-file`). Loopback pages use the Host settings API; remote pages stay in memory mode (runtime README). "Open configuration file" only on loopback, opens native editor (`settings.openDocument`). Onboarding is a *ledger* (`settings.onboarding`) mounting one step at a time; registrants own completion (`ui-settings-general` README). Model providers: add card, dormant catalog, write-only key storage via credential references, merge-patch profiles (`models-settings.e2e.ts`).
- **Session UX (web)**: sidebar workspace/session tree with cold-blank sessions (a truly empty session is a real, tiny artifact — `cold-blank-session.e2e.ts`), New Session reuses a matching blank session, startup auto-selection keeps the hero visible (held-network proof in `startup-auto-selection.e2e.ts`), details column with per-session lifecycle, Trajectory ledger view + details inspector + sidebar search (`navigation-panes.e2e.ts`), archived sessions, queue editing, message actions/feedback (Like/Dislike + note), produced-files "turn tail" cards, stats strip. Persistence: JSONL (zstd-compressed on disk, in-memory raw in tests) + in-memory SQLite content index (opt-in `openAt: first-search`); session titles projected from first prompt or LLM.
- **Headless config**: purely CLI (task positional); settings/credentials resolve from env → `$DSH_HOME/.credentials.yaml` → cwd `.env` → `$DSH_HOME/.env` (reference/README.md "Shared deployment behavior").

## 5. UX patterns for agent interaction worth adopting

1. **One-switch boot gate with fail-loud per-entry report** — no partial/blank UI; loading page is plugin-independent (AppRoot.tsx, boot.tsx). Strong pattern for agent apps that mount many plugins.
2. **Composition as patch layers, inspectable without booting** — `--dump-config` prints the whole tree with source-file comments; every layer override is auditable. Adopt for "why is my agent behaving like this" debuggability.
3. **Flags-over-config through lazy `!!js` expressions** — invocation values beat yml with zero custom merge code; HMR re-evaluation keeps long-lived servers consistent.
4. **Two-plane split (host vs agent preset)** — registries/sandbox/persistence are host rows; per-session tools/persona are agent-plane compositions with `isolate` realms; a "minimal" preset (fixed prompt, 2 tools, no compaction) exists as a first-class, user-visible mode. The cordis preset lets the agent author agents (self-referential tooling with explicit trust warnings).
5. **Event-driven conversation assembly** (Definitions → stable nodes; renderers pure functions of node data) with model-visible ⟺ logged invariant and replay-based testing. UI and tests consume the same durable log (seeded-history, keyless replay e2e).
6. **Projection-first live state** — host computes projections (`goal`, `todos`, `plan`), browser subscribes via `useProjection`; features own no domain stores, so no drift between tab/reconnect/echo.
7. **Composer-takeover interaction primitives** — approval panel, question composer, plan review, goal bar all swap the input dock; geometry bounded (approval buttons must stay in viewport); read-only subagent transcripts get read-only composers; a running continuable child keeps the input but disables Send.
8. **Trigger pipeline (`/` `@`) with keyboard arbitration** — combobox with focus retention in textarea, mousedown picks, exact-match-on-space/enter rule ("never silently downgrade to plain prompt"), fuzzy discovery only.
9. **Browser-trust fence + loopback-only privileged actions** — even without auth, remote access is fenced by Host header/Origin checks and `--trusted-host`; settings document open is loopback-only. Good default posture for a local-first agent server.
10. **Deterministic UX verification** — aria-snapshot goldens with token normalization (`captureStableAria`), fixture-inventory guards, console tripwires for self-healing/reconnect warnings, replay pacing to observe real incremental SSE. A cost-heavy but rigorous precedent for agent-UI regression testing.

## 6. Unresolved questions

1. **`AppCLIEntry`** is referenced in `apps/web/tests/scaffold.ts` and `apps/cli/tests/web-agent-presets.e2e.ts` ("an assembly fact AppCLIEntry resolves") but no `AppCLIEntry` symbol exists in the current tree — appears to be a renamed/removed assembly entry in the CLI app. What was it, and is the shipped-preset root injection now the only place that fact is resolved? (Archived note `2026-07-24-dsh-commander-argument-adapter` may hold history.)
2. **TUI**: the docs/README advertise `dsh --profile tui` only as an installable example; is a first-party TUI planned? `apps/` ships none, and the persistent-terminal packages are agent tools.
3. **Desktop**: no desktop shell exists; the web app is the only interactive surface. PWA manifest (fullscreen display) hints at standalone-window ambitions — any roadmap for that?
4. **App flags are parsed by bundle providers, not the launcher** — for a custom profile the "first unknown token" heuristic means a misspelled launcher flag silently becomes an app argument. Is there any guard for that ambiguity beyond per-app `--help`?
5. **The web bundle's `tools.mode` uses a process-wide `DSH_TOOLS_MODE` env seam** ("TEMPORARY workaround... Remove the env seam once the web UI owns the choice per session" — web-app/cordis.patch.yml). Per-session tool-presentation selection (native vs code mode) is unresolved.
6. **`--host 0.0.0.0` is intentionally unsupported** ("until remote access has an authentication layer" — client/connection README). The trust fence is explicitly "reachability policy, not authentication". What is the planned auth layer?
7. **apps/web tests deliberately mirror client constants** (welcome-notice copy, namespace) because importing client packages would tangle the Host build graph — a manual rule ("Nothing mechanically enforces this; keep it in review"). Fragile; any planned fix (separate client-constants package)?
8. **Locale**: UI copy ships English + Chinese (zh-CN default HTML lang, Chinese welcome notice); i18n yaml files accompany READMEs. No other locales — is zh/en the full target set?
9. **Session search is opt-in** (`openAt: never` shipped; enabled only in e2e) and the content index is in-memory only — full-text search over persisted sessions is unresolved for production.
10. **HMR for the web client is "always mounted but idle"** until `pnpm run dev:web` watcher rewrites bundles; shared module-reload HMR row is disabled for web ("reload lifecycle untested" — web-app/cordis.patch.yml TODO). Development-time hot reload of client plugins is unfinished.

## Evidence index (key files)

- `apps/cli/src/{bin,args,profile-boot,plugin,dump-config,process-shutdown}.ts`
- `apps/cli/reference/README.md`, `apps/cli/composition.md` (generated base-composition graph)
- `apps/cli/config/agent-presets/{standard,code,minimal,cordis}/`
- `apps/web/src/main.ts`, `apps/web/vite.config.ts`, `apps/web/index.html`, `apps/web/public/manifest.webmanifest`
- `apps/web/tests/scaffold.ts`, `apps/web/tests/support.ts`, `apps/web/tests/README.md`, 69 e2e + 7 snapshot tests
- `packages/bundle/{base,web-app,headless}/cordis.patch.yml`, `packages/bundle/web-app/src/startup.ts`, `packages/bundle/headless/src/{startup,index}.ts`
- `packages/client/web/src/{boot.tsx,AppRoot.tsx,app.tsx,app-shell.ts}`, `packages/client/web/README.md`
- `packages/client/{runtime,connection,ui-layout,ui-input-trigger,ui-commands,ui-goal,ui-sidebar,ui-subagent,ui-settings-general,ui-plan,ui-trajectory}/README.md`
- `packages/settings/README.md`, `packages/interaction/README.md`
- `packages/boot/app-boot/src/profile.ts` (PROFILE_TEMPLATES)
