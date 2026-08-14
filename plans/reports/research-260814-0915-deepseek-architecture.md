# DeepSeek Harness — Architecture Dissection

**Date:** 2026-08-14 · **Scope:** READ-ONLY deep dive of `/home/manhquy/Downloads/deepseek-harness` (HEAD `47f943859b`, `0.1.0-rc.5`). All paths relative to repo root.

---

## 0. Executive summary

DeepSeek Harness ("dsh") is a plugin-based agent harness built on a vendored copy of **Cordis** (a dependency-injection / plugin runtime, `vendor/`). The founding constraint: **everything is a plugin** — including the model adapter, the tool registry, the session log, and the agent loop itself. There is no privileged core to patch; every capability is a swappable "seam" with three roles (Service Definition / Service Provider / Consumer), and registrations are reversible effects that unwind when their plugin unloads. The session event log is the single source of truth; model-visible input must be reconstructable from it ("Model-visible ⟺ logged", enforced by a runtime invariant).

The stack has three runnable front-ends over one core: the Web GUI (host process + browser client), the one-shot `headless` CLI mode, and out-of-process surfaces (JSON-RPC server, ACP server, Python SDK driving a single-file runtime exe).

---

## 1. Repo map: roles of the top-level directories

| Path | Role |
|---|---|
| `apps/` | Runnable app bins. `apps/cli` = the `dsh` binary (`bin.ts` → profile/plugin/dump-config modes, `profile-boot.ts` boots a profile). `apps/web` = VitePress/React SPA entry — a thin bootstrap over `@deepseek-ai/dsh-client-web` (`apps/web/src/main.ts`). |
| `packages/` | ~47 groups, ~140 packages `@deepseek-ai/dsh-*` (all ESM, `"type": "module"`). Groups: `core/` (product API spine), `api/` (remote BFF + Typert RPC gateway), `llm/`, `fs/`, `shell/`, `subprocess/`, `terminal/`, `code-runtime/`, `sandbox/`, `lsp/`, `skill/`, `web/`, `subagent/`, `jobs/`, `workflow/`, `session/`, `session-query/`, `settings/`, `credentials/`, `storage/`, `workspace/`, `sdk/`, `acp/`, `interaction/`, `host/`, `client/`, `boot/`, `bundle/`, `preset/`, `compaction/`, `context/`, `goal/`, `schedule/`, `feedback/`, `identity/`, `guard/`, `extensions/`, `hooks/`, `mcp/`, `typert/`, `todo/`, `plan/`, `spill/`, `attachment/`, `e2b/` (POC), `examples/`, `test-support/`, `util/`. Full hierarchy table: `packages/README.md`. |
| `native/` | `native/landlock-run` — `@deepseek-ai/node-addon-landlock-run`: a ~300-line C11 statically-linked (musl) Landlock **self-restrict-then-exec** launcher for confining subprocesses on Linux, distributed as prebuilt per-platform npm packages (linux-x64/arm64). Public API: `launcherPath()`, `probe()`, `grantArgs()` (`native/landlock-run/README.md`). |
| `python/` | `python/sdk` = `deepseek-harness-sdk` PyPI client driving dsh over **JSON-RPC stdio** (`DeepSeekHarness`, `Session.run()`). `python/sdk-runtime` = `deepseek-harness-runtime-bin` wheel carrying a single-file Node executable `dsh-jsonrpc-agent` (production) or a dev-only node closure, plus a bundled default `cordis.yml` (stdio JSON-RPC server + agent core + DeepSeek adapter + JSONL persistence + local bash). See `python/sdk/README.md`, `python/sdk-runtime/README.md`. |
| `scripts/` | Repo gates + generators (not product code): `run-gates.ts` (CI orchestration), generators `gen-cordis-catalog.ts`, `gen-tool-catalog.ts`, `gen-module-graph.ts`, `gen-doc-graphs.ts`, `gen-scoped-events.ts`, `gen-persistence-catalog.ts`, `gen-config-catalog.ts`; verifiers `verify-*` (package invariants, cordis-config, export JSDoc, doc budgets, md links/wrap, agent-note format/classification); build tooling `build-exe-for-python-sdk.ts`, `change-scope.ts`, `clean.ts`; translation-pairing machinery; CI workflow specs. |
| `vendor/` | Pinned source copies of Cordis packages (manifest + sync procedure in `vendor/README.md`), rescoped to `@deepseek-ai/cordis*`. |
| `examples/` | Runnable `cordis.yml` leaves over `packages/examples` bundles: `headless-agent`, `web-cordis`, `acp-agent`, `jsonrpc-agent`, `mcp-memory`, `web-schedule`. |
| `docs/` | Architecture + subsystem docs (`docs/architecture.md`, `docs/subsystems/*.md`), generated catalogs (`module-graph.md`, `event-producer-consumer.md`, `config-catalog.md`, `persistence-catalog.md`, `cordis-api/`), cookbook, primer/tutorial. |
| `website/` | VitePress projection of selected bilingual docs. |
| `.agents/` | Agent workflows + Agent Notes (`notes/implemented|proposed|archived`), skills. |
| Root | `package.json` (`dsh` root scripts: build/test/lint/typecheck/hygiene/CI gates), `tsconfig.*.json` (host vs client faces), `vitest*.config.ts`, `knip.json`, `.oxlintrc.json`, `pnpm-workspace.yaml`. |

### Build faces (host vs client)

The repo compiles two TypeScript faces (`tsconfig.host.json` / `tsconfig.client.json`): the **host** face (Node-side services, `ctx.*`) and the **client** face (browser-safe subset that must never import Node). `pnpm build` = `tsc -b` both faces + tsdown bundling + `apps/web` build (`package.json` scripts `build:lib:host` / `build:lib:client`).

---

## 2. Core runtime & agent loop: how the harness orchestrates agents/models

### 2.1 Boot / composition

1. `apps/cli/src/bin.ts` parses argv, dispatches to `runProfile` (`profile-boot.ts`).
2. `runProfile` composes the **profile**: `dsh.profile.bundles` in order (each bundle = a `cordis.patch.yml`), then the profile's own `cordis.patch.yml`, then `$DSH_HOME/cordis.patch.yml`, then `--patch` overlays, then the telemetry switch. Patch semantics: each patch targets a row by `id` and replaces its whole config, or `insert`s rows.
3. `packages/boot/app-boot/src/index.ts` `boot()`: creates a Cordis `Context`, installs the Loader plugin, mounts the root include (`cordis:include` over the profile's empty `cordis.yml`), awaits tree settlement, then `assertEntriesActivated()` (fail-loud audit: every enabled entry must be ACTIVE).
4. Bundles: `dsh-base` (first layer: model adapters, tools, persistence, sandbox, approval, settings, credentials, telemetry — see `packages/bundle/base/cordis.patch.yml`), `dsh-web-app` (browser app), `dsh-headless` (one-shot runner, no server).
5. Config rows use `!!js` expressions (e.g. `task: !!js ctx.headlessStartup.task`, `mode: !!js process.env.DSH_TOOLS_MODE`). The loader watches the user patch layer via Cordis HMR for live `cordis.patch.yml` edits.

### 2.2 The agent loop (the heart)

The concrete driver is `ReactLoopAgent` in `packages/core/agent-loop/src/agent.ts`. Vocabulary: a **step** = one model request + its tool calls; a **turn** = ≥0 steps that opens before its first input is claimed and closes when nothing is owed.

Turn flow (durable events in `docs/architecture.md#turn-flow`):

```
turn/start
  claim next-step input + one next-turn message (inbox.claim)
  assemble prompt sections + tool schemas (ctx.systemPrompt.assemble)
  -> agent/pre-step (waterfall: reject | enter(messages))
  step/start
  append entered messages as user/message
  derive model history from the log (session.deriveMessages())
  agent/request (waterfall) -> llm/stream -> assistant/chunk* -> assistant/message
  tool/call* -> tools/pre-execute -> tools/execute -> tools/post-execute -> tool/result*
  step/end
  (tools owe another request -> next step; or agent/turn-stopping serial)
turn/end
```

Key mechanics in `agent.ts`:
- **Inbox** (durable projection): two ordered lists (`InboxTarget = 'next-turn' | 'next-step'`). `send()`/`followup()`/`steer()`/`inject()` route identified `UserMessage`s; every mutation logs `agent/inbox/spliced` and emits `agent/inbox/*` notifications (`packages/core/agent/src/inbox.ts`).
- **Phase machine**: `idle → running → idle` (plus `maintenance` for non-turn tasks via `runMaintenance()`). Status is `'idle' | 'running'`, mirrored on `agent/status`.
- **`preStep()`**: claims the batch, assembles context (workspace instructions, time, injected snapshots via `RuntimeContextProjection`), then runs the `agent/pre-step` waterfall; a `reject` or empty-enter still closes the turn (records the attempt) but spends no model call.
- **`step()`**: `buildRequest()` freezes a request (config from `request/header` epoch, history from log), streams chunks, feeds a `BlockAssembler`, logs raw chunks + the assembled `assistant/message`, then dispatches tool calls.
- **Tool-call scheduler** (`agent-loop/src/tool-calls.ts`): exclusive calls form barriers; concurrency-safe calls run in a bounded rolling pool (`maxParallelToolCalls`). Results commit in **model order**; abort records synthetic error results for skipped calls so replay stays valid.
- **Cancellation**: `AbortSignal` per turn; `Agent.cancel(cause, {keepInbox})` aborts with a typed `AgentCancelCause` (`user|parent|hook|disposed`); durable `turn/end` records coarse `{kind:'aborted'}`. `whenIdle()` resolves after the whole-agent activity settles.
- **`ctx.agents`** (`packages/core/agent/src/index.ts`): live-agent registry; creation via `AgentFactory` registered by `setFactory()` (the loop is the factory); `withInitiator()`/`requireInitiator()` establish the process-local initiating-Agent boundary that tools and downstream code inherit; scoped dispatch (`agent/*` events are scope-filtered to the owning agent via `dsh-scope`).
- **Request-error recovery**: failed steps close, then `agent/request-error` waterfall; a listener may return `{kind:'retry'}` (used by `llm-retry`, `compaction-basic`) to reopen a new numbered turn.

### 2.3 Model layer (`ctx.llm`)

- `LlmRuntime` (`packages/llm/llm/src/index.ts`): adapter registry + `stream()`. `registerAdapter(providers, adapter)` returns a handle with atomic `replace()`. Adapters subclass abstract `LlmAdapter` and implement `stream(options): AsyncIterable<StreamChunk>` (`packages/llm/llm/src/types.ts`).
- Raw protocol: `StreamChunk` — `block-start/text-delta/reasoning-delta/tool-call-delta/block-end/usage/finish`, with `index` correlation; a closed union (switch + `assertNever`).
- `BlockAssembler` folds chunks into `ContentBlock[]` and a final `Message`; the loop logs raw chunks while feeding the assembler (replay fidelity).
- `prepareCall()` binds config resolution + adapter registration across header logging and dispatch; `agent/request` waterfall can replace the frozen `LlmCallConfig` (provider/model/effort/sampling).
- Shipping adapters: `llm-deepseek` (direct fetch) and `llm-pi-ai` (library-backed); `llm-retry` adds `agent/request-error` recovery; `token-meter` meters usage.
- Adapter contract invariants: `usage` before `finish` only; tool arguments raw-JSON end-to-end; one call = one provider attempt (library retries disabled); `LlmFailure` is the single serializable failure type; context-overflow maps to `CONTEXT_WINDOW_EXCEEDED`; every request carries `attributionHeaders()` (User-Agent).

### 2.4 Web GUI: host/client split

- **Host** (`packages/host/`): `webserver` (node:http server + route registries), `apiproxy` (the `/api` RPC gateway and wire contract, `createApiProxy`), `frontend-static` (SPA dist on the fallback seat), `directory-picker*`, `plugin-inventory`.
- **Client** (`packages/client/`): browser half — `connection` (JSON-RPC over HTTP/WebSocket, trust fence `trusted-host | loopback`, `websocket-downlink`, `rpc-host`), `runtime`, `web` (boot kernel `boot.tsx`: loads a BootManifest, builds a client-side module system, mounts a client Cordis Loader tree), `web-react`, plus ~30 `ui-*` plugin packages (React components for goals, jobs, plan, settings, subagent, tool, trajectory, workflow…). `client/modules` = module transport (vite chunks over the wire).
- **RPC**: `packages/api/gateway` — two-sided **Typert RPC** endpoint: Host `ctx.typertGateway` invokes generated descriptors against registered business services; Client `ctx.remote` mounts typed methods calling `ctx.connection.rpc.call('/api', endpoint, …)`. Business services live in `packages/api/remotes` and mark methods with `@Remote`/`@RemoteScope` (from `packages/typert/protocol`); the type graph is generated by `packages/typert/generator`. Incremental session data (chunks/projection frames) uses a separate **named-stream protocol** over the same Connection (per `api-gateway` README's "Known Limitations").
- **Headless**: `dsh-headless` bundle mounts `headless-startup` (parses `dsh --profile headless "<task>"`, publishes `headlessStartup` service) + `headless-runner` (creates an Agent through the core registry, prints the durable result, exits).

---

## 3. Key abstractions, interfaces, and contracts between packages

### 3.1 The session log — single source of truth

- `Session` (`packages/core/session/src/`): **append-only log** of typed `SessionEvent`s (`SessionEventMap` → discriminated union via `keyof`). Each event: `seq` (monotonic), `time`, `type`, `data`; surface-eligible types (`user/message`, `assistant/message`, `tool/result`) may carry `surfaceOp` (`append` | `{op:'replace',start,end}` for compaction) and `sourceEventSeqs`.
- Twelve+ core variants: `turn/start`, `turn/end`, `step/start`, `step/end`, `user/message`, `assistant/chunk`, `assistant/message`, `tool/call`, `tool/result`, `todo/write`, `request/header`, `request/context` (plus `session/end-seed`, plugin-merged `hook/*`, `compaction/*`, `steering/message` historical).
- **`deriveMessages()`** projects LLM history from the log — history is never stored separately. The **reconstructability invariant**: a loop-built request is a pure function of the log (`request/header` epoch + derived history), asserted by a dev invariant (`packages/core/agent-loop/src/invariant.ts`).
- `SessionHeader` (format `version`, `cwd`, lineage `parentSession`/`seedLength`, `origin`, `delegationDepth`, `agentPreset`) travels separately from the log.
- `SESSION_FORMAT_VERSION = 0`, monotonic; backends reject incompatible logs (no migration promise pre-1.0).

### 3.2 The merge-extensible map → derived-union pattern

Six canonical maps plugins extend via **declaration merging** (no edit to the owning package): `ContentBlockMap`, `MessageSourceMap`, `FinishReasonMap` (dsh-llm); `TurnTriggerMap`, `TurnEndReasonMap`, `SessionEventMap` (dsh-session). `switch` on the tag narrows; unknown required event types without `ignorable: true` cause readers to refuse reconstruction.

### 3.3 Branded IDs

`Branded<B>` (type-only, `packages/util/brand`): `SessionId`, `CallId`, `MessageId`, `JobId`, `ProviderRequestId`, `ReasoningEffortId`… Structurally strings, non-interchangeable at compile time.

### 3.4 Capability seams (three roles)

A seam = Service Definition (interface) + Service Provider(s) + Consumer (usually a model-facing tool). One provider swap changes the whole product (fs/subprocess share one execution world; sandbox providers swap confinement; subagent providers range from in-process child to Codex/Claude-Code delegation). Seam template: the `dsh-shell` request/spec split — "defaulting is an explicit `resolve(request): Spec` step, never a hidden `?? default` inside `run()`" (`docs/capability-seams.md`).

### 3.5 Core service surface (`ctx.*`)

| ctx key | Package | Owns |
|---|---|---|
| `ctx.sessions` | core/session | event log + in-memory store |
| `ctx.systemPrompt` | core/system-prompt | prompt-section + tool-schema assembly (`section({name,order,text})`) |
| `ctx.tools` | core/tools | scoped tool registry + guarded execution pipeline |
| `ctx.agents` | core/agent | Agent interface, live registry, `agent/*` events, initiator scope |
| `ctx.agentLoop` | core/agent-loop | concrete driver + factory |
| `ctx.llm` | llm/llm | adapter registry + streaming |
| `ctx.agentPresets` | preset/agent-presets | per-session composition from preset `cordis.yml` files |
| `ctx.agentDefaultModel` | core/agent-default-model | default model selection |
| `ctx.typertGateway` / `ctx.remote` | api/gateway | Typert RPC host/client |
| `ctx.sessionPersistence` | session/session-persistence | durability seam |
| `ctx.sessionProjections` | session/session-projection | projection registry |
| `ctx.skills` | skill/skill | skill provider registry |
| `ctx.subagents` | subagent/subagent | subagent provider registry |
| `ctx.goals` | goal/goal | same-session objectives |
| `ctx.jobs` | jobs/jobs | background jobs |
| `ctx.webServer` | host/webserver | HTTP route server |
| `ctx.apiProxy` | host/apiproxy | host RPC gateway |
| `ctx.connection` | client/connection | transport RPC (client + host halves) |

Services extend Cordis `Service`, registered via `ctx.effect()`; declaration merging adds them to `Context`.

### 3.6 `ToolDefinition` contract

`ToolSchema` (model-facing; declared in dsh-llm) + `output` (canonical JSON-schema declaration with `render`/`presentationMeta`), `execute(args, exec) → Promise<unknown>`, optional `finalizeContent`, `timeoutMs`, `isConcurrencySafe` (parallelism opt-in), `presentCall`/`presentResult` (pure UI render intents, replay-safe). `defineTool` DSL (`packages/core/tools/src/schema.ts`) infers TS args/output types from `ValueSchemaSpec`/`ParameterSchemaSpec` (bounded 16-level inference, falls back to `JsonValue`). `schemas()` builds the model-facing list by explicit allowlist — internal fields never leak. Execution goes through `tools/pre-execute` → `tools/execute` → `tools/post-execute` waterfalls and a runtime `TOOL_RUNTIME_SCHEDULER` (`prepare`/`dispatch`/`finish`/`finalize`) that the loop uses for the parallel pool.

### 3.7 Per-agent scoping (`dsh-scope`)

`packages/core/scope` (dependency-free library): `createScope(ctx, key)` builds an agent-scoped `ctx` whose registrations (tools, prompt sections, services, listeners) are agent-local, unwind on disposal, and reject registration afterward. `ScopeKey`, `bindScopeParent`, `scopeTarget` — registries key layers by scope; agent presets mount standing compositions that children can `composeFrom` (join the exact same generation, not a re-read).

### 3.8 Events dispatch modes

`emit` (observe), `waterfall` (around-middleware — listeners MUST call `next()` or they short-circuit), `parallel`, `serial` (ordered, next-delegating). `docs/event-producer-consumer.md` is the generated producer/consumer matrix.

### 3.9 Persistence contract

`SessionPersistence` seam (`packages/session/session-persistence/README.md`): `create/append/load/inspect/readFrom/list/listSnapshots/prepare` + invariants (append-only; crashed turns closed with synthetic closers, never truncated; contiguous seq; lossless-JSON data; durability on append-return). Backends: **JSONL** (sequential artifact, zstd compression) and **SQLite** (`node:sqlite`, seekable). Shared `PersistenceCoordinator` owns per-session write batching (`writeBatchMaxDelayMs`), `session/flush` quiescence barrier, crash-tail repair, HMR adoption. `session-checkpoint-policy` chooses per-request/tool/step checkpoint durability.

---

## 4. Extension / plugin / skill points

**Everything is a Cordis plugin** — the documented "where new behavior goes" table (`docs/architecture.md`):

| Goal | Mechanism |
|---|---|
| Add a model provider | `ctx.llm.registerAdapter()` |
| Add a model-facing capability | register a `ToolDefinition` on `ctx.tools` |
| Per-session capability sets | agent preset (`isolate` realms for service rows) |
| Shell / PTY / fs / sandbox backends | register on `ctx.shell` / `ctx.terminals` / `ctx.fs` / `ctx.sandbox` |
| Human commands (no model turn) | `ctx.commands` |
| Background work | `ctx.jobs` (+ `job_*` tools) |
| Intercept request/tool/turn | `agent/*` / `tools/*` waterfalls; `agent/turn-stopping` stops a turn |
| Model-facing context | `agent.inject()` → next pre-step |
| UI/editor integration | drive `ctx.agents`, render from `session/event` |
| Durable session state | extend `SessionEventMap`, render from log |
| Session titles | sole `ctx.sessionTitle` provider |
| Fork a live session | `ctx.sessions.fork(source, boundary?, childSessionId?)` |

Additional extension surfaces:
- **Hooks** (`packages/hooks/`): `hook-protocol` (dialect-neutral Claude Code / Codex hook wire protocol library), `hooks-claude-code`, `hooks-codex` bridges — matchers, stdin payload, exit-code/stdout decision decoding, `hook/*` log events. Hook decisions map onto `agent/pre-step`, `tools/pre-execute` (permission), `agent/turn-stopping`.
- **Skills** (`packages/skill/`): `ctx.skills` registry (host + per-scope layered), `SkillProvider` interface, local filesystem provider with ranked discovery roots (project `.dsh/skills`, `.agents/skills`, user home, bundled), `tool-skill` Consumer (catalog/loader tool). Skills are optional instructions injected via pre-step, not session events.
- **Self-modification** (`packages/extensions/`): `tool-cordis` lets the model inspect/mount/unmount its own plugins at runtime (`ctx.typert` inspection, `cordis-host-runner`), with `cordis-client-runner` for the browser half.
- **Subagents** (`packages/subagent/`): `ctx.subagents` registry, one-shot `start()` + continuable children; providers: in-process, fork, ACP, Codex, Claude-Code, dsh-sdk.
- **MCP** (`packages/mcp/mcp-client`): connects external MCP servers (stdio / streamable-http) and registers their tools as `mcp__<server>__<name>` on `ctx.tools`.
- **Out-of-process**: `packages/sdk` (JSON-RPC protocol/server/TS client), `packages/acp` (Agent Client Protocol server, automation-only), `packages/typert` (type graph generator/loader/registry).
- **Workflow/jobs/goal/schedule/plan/todo/compaction**: background worker-thread workflows (`workflow`/`ralph` tools), background jobs, same-session goals (`goal-round-driver` drives rounds through `agent/pre-step`), scheduled follow-ups, plan mode (logged state), `todo_write`, compaction (surface `replace` ops, `compaction-basic` provider, `command-compact`).
- **Approval/interaction** (`packages/interaction/`): `user-approval` waterfall, permission presets, commands, `tool-ask-user`, `user-questions`.
- **Agent presets** (`packages/preset/agent-presets`): per-session Cordis composition from preset files; `mount`/`composeFrom`/`recompose`/`serviceFor`; presets record `agentPreset` in `SessionHeader` so resumes replay under the same composition.
- **Client Chat nodes**: `ConversationNodeDefinition` + keyed renderers (`docs/architecture.md`).

### Pattern rules for extensions
- Registrations are effects (`ctx.effect()`/`ctx.on()`; `register()` returns the disposer).
- Waterfall listeners must call `next()` to delegate.
- Extension plugins depend on **Service Definitions**, never concrete providers (`agent-loop` is swappable behind `dsh-agent`).
- Config-driven tunables, not hardcoded constants; misconfiguration fails loud at load.
- New model-visible input ⇒ new session event + `deriveMessages`/render support.

---

## 5. Data flow & state management

### 5.1 The event-sourced spine

```
plugin/tool → ctx.tools / agent.send() → inbox (durable splices)
    → agent-loop preStep → Session.append(user/message)      [log = source of truth]
    → deriveMessages() → request (frozen, log-derived)
    → llm/stream → assistant/chunk* (raw, logged) → BlockAssembler → assistant/message (logged, cites chunk seqs)
    → tool/call → tools/* waterfalls → tool/result (logged, cites call seq, carries meta for replay UI)
    → step/end → turn/end
```

- **Model-visible ⟺ logged**: everything reaching a model request is reconstructable from the log; `request/header` (EpochHeader: config + adapterDefaults + rendered system prompt + tool order) and `request/context` (route/capacity) snapshots make the request a pure function of the log.
- **UI data flow**: `session/event` broadcast → `dsh-host-apiproxy` → Connection (`/api` RPC; incremental frames via named-stream protocol) → browser `ctx.remote`/`$on` subscriptions → React `ui-*` components. Projections (`ctx.sessionProjections`) compute pure read models (`todo`, trajectory) from committed events; `session-projection-cache` persists `(sessionId, key, ver, seq, val)` rows.
- **Durability**: `session/event` → per-session write controller (bounded batching) → JSONL or SQLite; `session/flush` = quiescence barrier; crash recovery appends synthetic closers for interrupted turns; `session/checkpoint-policy` selects checkpoints.
- **Fork/resume**: `seed` event prefix + `session/end-seed` marker; `SessionHeader` lineage (`parentSession`, `seedLength`); `ctx.sessions.fork()`.
- **Cancellation/error**: `AbortSignal` (turn), typed causes; failures normalized to `LlmFailure` (code/status/retryAfter); `agent/request-error` retry; turn outcome sticky `max-tokens`.
- **Compaction**: rewrites the model-visible surface via `SurfaceOp {op:'replace'}` nodes citing shadowed seqs; `compaction-basic` + `command-compact`.
- **Telemetry/titles**: `session-telemetry` (+OTEL), `session-title` providers, all derived from the log.
- **State discipline**: projections must return the same reference when nothing changed (`Object.is` gate); whole-value event rule (state-carrying events carry complete post-change state, never deltas); projection state is plain JSON with `stateVersion` invalidation anchors.

### 5.2 Cross-process state

- Python SDK: subprocess (single-file exe) ⇄ JSON-RPC stdio; `RunResult` = `(session_id, final_response, finish_reason, events, notifications, session_root)`; activity interval = durable inbox receipt → whole-agent idle.
- ACP: automation-only Agent Client Protocol server over the same core.
- JSON-RPC (`packages/sdk`): protocol + server plugin + TypeScript client — used by the `jsonrpc-agent` example and the Python runtime.

---

## 6. Unresolved questions / follow-up leads

1. **Named-stream protocol**: `api-gateway` README mentions a "separate named-stream protocol over the same Connection" for incremental session data, but the wire envelope/correlation details live in `client/connection` (`websocket-downlink.ts`, `rpc-host.ts`) which I only skimmed — worth a dedicated read for anyone modifying UI streaming.
2. **Typert generation pipeline**: how `typert/generator` is invoked in builds/CI, and the exact `InvocationDescriptor` contract consumed by both gateway halves (I saw the README; the generator source and its build wiring in `scripts/` weren't traced end-to-end).
3. **`api/remotes` shape**: `packages/api/remotes/src/index.ts` is essentially an empty `apply(){}` — the business services must be composed from `remotes/` subpackages or the `client/`/host faces; I didn't enumerate which `@Remote` services ship (agent, session, settings, skills, goals…).
4. **e2b POC status**: `packages/e2b` exists ("POC" release expectation) but was not in the bundle patch; unclear whether any shipped composition mounts it.
5. **Parallel tool-call scheduler edge cases**: `maxParallelToolCalls` config source and the `guard/timeout-policy` interplay (`tools/execute` deadline enforcer) were not fully traced.
6. **Goal round-driver / schedule interplay**: how `goal-round-driver` and `schedule` re-drive turns through `agent/pre-step` and `agent/inbox` (both are listeners per the event matrix; the driving loop details weren't read).
7. **Workflow worker-thread engine**: `packages/workflow` provider internals (worker-thread engine, `ralph` tool) were not inspected beyond README-level knowledge.
8. **Windows support**: CI has wine-gated Windows checks (`check:windows-wine`, `sandbox-windows-acl`, `win32.ts` in JSONL persistence); the actual supported Windows surface (which bundles/platform gates) wasn't established.
9. **`agent-loop` vs `examples/agent-spine-demo`**: the demo bundle is cited as "the default composition that wires this spine into a runnable agent" — I did not read its `cordis.yml` to confirm the exact row set vs. `dsh-base`.
10. **Snapshot testing harness**: `DSH_SNAPSHOT=replay/record/refresh` swaps `cordis.yml` → `cordis.snapshot.yml` at boot (`resolveConfigPath`); the mechanics of `llm-replay` (test-support) weren't traced.

---

## Appendix: evidence index (most-referenced files)

- `docs/architecture.md` — turn flow, extension table, profiles/bundles
- `packages/core/agent-loop/src/agent.ts`, `tool-calls.ts` — the loop and tool scheduler
- `packages/core/agent/src/index.ts`, `types.ts` — Agent/AgentRegistry/AgentHandle, inbox, events
- `packages/core/session/src/types.ts` — SessionEventMap, EpochHeader, SessionHeader
- `packages/llm/llm/src/types.ts`, `index.ts`, `assembler.ts` — LLM seam, StreamChunk, LlmAdapter
- `packages/core/tools/src/index.ts`, `schema.ts` — ToolDefinition, defineTool DSL, scheduler symbol
- `packages/core/scope/src/index.ts` — per-agent scoping
- `packages/boot/app-boot/src/index.ts`, `apps/cli/src/profile-boot.ts` — boot/composition
- `packages/bundle/base|headless|web-app/cordis.patch.yml` — shipped compositions
- `packages/session/session-persistence/README.md` — persistence contract/invariants
- `packages/api/gateway/README.md`, `packages/client/connection/src/rpc.ts` — RPC gateway + transport trust
- `docs/module-graph.md`, `docs/event-producer-consumer.md` — generated dependency/event maps
- `python/sdk/README.md`, `python/sdk-runtime/README.md`, `native/landlock-run/README.md`
