# DeepSeek Harness — packages/ Deep Dive

CORE research report (agent loop, model layer, tool system, session state, prompt assembly, code-quality patterns). Read-only audit of `/home/manhquy/Downloads/deepseek-harness/packages`. All findings cite concrete file paths. Sibling agents cover architecture, build infra, apps/, native+python, docs+benchmark.

---

## 1. Package enumeration

**Scale:** 49 groups, **219 npm packages** at `packages/<group>/<pkg>/`, all scoped `@deepseek-ai/dsh-<pkg>`, all ESM (`"type": "module"`), all built on vendored Cordis (`@deepseek-ai/cordis` peerDependency). Groups are documented in `packages/README.md` (group/role table) and `docs/module-graph.md` (generated dependency graph, CI-freshness-gated).

**Dominant pattern — "capability seam" (Service Definition / Service Provider / Consumer):** one abstract Cordis `Service` subclass (definition), one or more concrete provider plugins, and one or more model-facing tool/command plugins. Consumers depend on the definition, never concrete providers (`docs/module-graph.md`, `packages/README.md`). Examples below.

### Core product spine — `packages/core/`
| Package | Purpose | Public API surface |
|---|---|---|
| `core/agent` (`dsh-agent`) | Live agent handle, registry, inbox, initiator scope, event vocabulary | `Agent` interface (`id`, `session`, `inbox`, `status`, `cancel()`, `whenIdle()`, `runMaintenance()`, `send()/followup()/steer()/inject()`), `AgentRegistry` (ctx key `agents`), `Inbox`, `AgentOptions`, events `agent/created|disposed|status|inbox/inserted|claimed|discarded|session-start|error`, waterfalls `agent/pre-step`, `agent/request`, `agent/request-error`, serial `agent/turn-stopping` (`core/agent/src/index.ts`, `runtime-types.ts`, `dispatch.ts`, `inbox.ts`) |
| `core/agent-loop` (`dsh-agent-loop`) | Concrete turn/step driver (`ReactLoopAgent`); creates/resumes agents, owns ordered teardown | `AgentLoop` service (`ctx.agentLoop`, `create`/`resume`), `ReactLoopAgent`, config `maxParallelToolCalls`, `LauncherAgentIdentity`/`CONFIGURED_AGENT_IDENTITIES_KEY` for launcher-owned session ids (`core/agent-loop/src/index.ts`, `agent.ts`, `tool-calls.ts`) |
| `core/session` (`dsh-session`) | Event-sourced session: append-only log, in-memory store, derived LLM history | `Session` class (append-only `SessionEvent` log, `events`, `seq`, `deriveMessages()`, `requestHeader()`, `requestContext()`, fork/restore), `SessionStore` (`ctx.sessions`: `create/prepare/enter/announce/fork/flush`), `SessionEventMap` (merge-extensible), surface mechanism (`surfaceOp`, `sourceEventSeqs`), events `session/created|disposed|event|flush`, `SESSION_FORMAT_VERSION` (`core/session/src/index.ts`, `types.ts`, `surface.ts`, `json.ts`) |
| `core/system-prompt` (`dsh-system-prompt`) | Ordered system sections, dynamic contexts, tool schemas, prompt variables | `SystemPrompt` service (`ctx.systemPrompt`: `section()`, `context()`, `tools()`, `variable()`, `suppressRuntimeContext()`, `assemble()`), `PromptAssembly`, waterfall `system-prompt/assemble`, pure `renderPrompt`/`renderContextSections`/`joinContextSections` (`core/system-prompt/src/index.ts`) |
| `core/tools` (`dsh-tools`) | Tool registry + execution pipeline; code-mode presentation | `ToolRuntime` (`ctx.tools`: `register()`, `restrict()`, `guard()`, `get()`, `schemas()`, `executionMode()`, `presentAs()`, `execute()`), `ToolDefinition`, `defineTool()` typed helper, `ToolRuntimeScheduler` symbol seam, waterfalls `tools/pre-execute|execute|post-execute|code-dispatch-log`, emit `tools/result|change` (`core/tools/src/index.ts`, `schema.ts`, `json-schema.ts`, `ts-types.ts`, `py-types.ts`, `presentation.ts`, `code-mode.ts`) |
| `core/scope` (`dsh-scope`) | Scoped-context primitive: keyed Cordis contexts, routing carriers, scope parent chains | `createScope()`, `scopeTarget()`, `scopeOf()`, `bindScopeParent()`, `scopeChainOf()`, `ScopedLayers`/`NamedEntries`/`AnonymousEntries` (`core/scope/src/index.ts`, `store.ts`) |
| `core/agent-default-model` | Resolve a default provider/model from settings | `agent-default-model` plugin reading `ctx.settings` (`core/agent-default-model/src/index.ts`) |
| `core/agent-tool-presentation` | Per-agent tool presentation override | Small plugin bridging tools presentation mode (`core/agent-tool-presentation/src/index.ts`) |

### LLM family — `packages/llm/`
| Package | Purpose | Key API |
|---|---|---|
| `llm/llm` | Adapter registry + streaming call API | `LlmRuntime` (`ctx.llm`: `registerAdapter()`, `registerConfigurableProviders()`, `registerModelDiscovery()`, `listProviders()`, `listModels()`, `resolveModelInfo()`, `resolveCallConfig()`, `prepareCall()`, `stream()`), abstract `LlmAdapter` (only required method: `stream()`), `GenerateOptions`, `StreamChunk` protocol, `BlockAssembler`, `LlmError`/`HarnessError`, `PreparedLlmCall`, waterfall `llm/stream` (`llm/llm/src/index.ts`, `types.ts`, `assembler.ts`, `message.ts`, `error.ts`, `retry-policy.ts`) |
| `llm/llm-deepseek` | DeepSeek provider: fetch + SSE chat-completions | `DeepSeekAdapter` (transport-only; connection facts via thunk, key via per-request resolver), `httpErrorCode()`, `translate`/`parseSse`/`serialize` (`llm/llm-deepseek/src/adapter.ts`) |
| `llm/llm-pi-ai` | pi-ai provider (library-backed), replay + discovery + catalog | `llm-pi-ai/src/{adapter,stream,replay,catalog,discovery,config,provider}.ts` |
| `llm/llm-retry` | Provider-routed retry on `agent/request-error` | Policy executor: exponential backoff + jitter, durable-before-wait scheduled retries (`llm/llm-retry/src/index.ts`) |
| `llm/token-meter` | Token estimation + usage projection over session log | `estimate`, `usage-projection`, `surface-projection` (`llm/token-meter/src/`) |

### State & data plane — `packages/session/`, `packages/session-query/`, `packages/storage/`
| Package | Purpose | Key API |
|---|---|---|
| `session/session-persistence` | Durable persistence Service Definition + shared coordinator | Abstract `SessionPersistence` (`ctx.sessionPersistence`: `locate/readRaw/append/load/...`), `PersistenceCoordinator`, `SessionWriteBehind` bounded write batching (`session/session-persistence/src/{index,coordinator,write-behind,revision,preparations}.ts`) |
| `session/session-persistence-jsonl` | JSONL backend (+zstd frames, chunk-run packing) | `session-persistence-jsonl/src/{index,format,zstd,win32}.ts` |
| `session/session-persistence-sqlite` | SQLite backend | `SCHEMA_VERSION = 15` monotonic, `user_version` + `applicationId` checks (`session/session-persistence-sqlite/src/schema.ts`) |
| `session/session-projection` | Projection registry: pure `init/apply/view` units driven by the framework | `SessionProjectionRegistry` (`ctx.sessionProjections`), `ProjectionDefinition` (`session/session-projection/src/index.ts`) |
| `session/session-checkpoint-policy` | Durability checkpoints: flush before model request, top-level tool dispatch, step completion | Plugin on `llm/stream` + `tools/execute` + `agent/pre-step` (`session/session-checkpoint-policy/src/index.ts`) |
| `session/session-title*` | Session titles (seam + LLM providers: first-prompt, all-prompts) | `session-title` client/`normalize`; `session-title-llm`, `-first-prompt-llm`, `-all-prompts-llm` |
| `session/session-telemetry`, `session-telemetry-otel` | Session reporting seam + OTel exporter | coordinator + OTel plugin |
| `session/session-stats`, `session-projection-cache` | Stats projection, cache over persistence | small projection/cache plugins |
| `session-query/session-query` | Retrieval: logical corpus, bounded reads, lineage, event relationships, semantic filter | `SessionQueryEngine` (`ctx.sessionQuery`) + SQLite FTS backend (`session-query-sqlite`), export (`session-log-export`), tool (`tool-session-query`) |
| `storage/*` | Non-session storage hub + domain form + json/sqlite backends | `storage` seam, `storage-domain`, `storage-json`, `storage-sqlite` |

### Capability families (each = seam + providers + tool consumers)
- **fs** — `fs` (seam), `fs-local`, `fs-sandbox` (sandbox-enforcing backend), `fs-observation-policy`, tools `tool-fs`, `tool-fs-search`, `tool-str-replace-editor`.
- **shell** — `shell` (seam), `bash-local`/`bash-sandbox`, `pwsh-local`/`pwsh-sandbox`, `shell-env`, tools `tool-bash`, `tool-bash-persistent`, `tool-pwsh`.
- **subprocess** — `subprocess` (seam), `subprocess-local`; process-tree provider.
- **terminal** — `terminal` (PTY seam), `terminal-bash`, `tool-terminal`.
- **sandbox** — `sandbox` (confinement seam), `sandbox-local`, `sandbox-policy`, `sandbox-windows-acl`.
- **code-runtime** — `code-runtime` (seam), `code-runtime-worker-thread` (worker-thread engine).
- **web** — `web` (seam: search+fetch), `web-search-exa`, `web-search-perplexity`, `web-search-deepseek`, `web-fetch-http`, `tool-web`.
- **lsp** — `lsp` (seam), `lsp-stdio`, `tool-lsp`.
- **skill** — `skill` (provider registry), `skill-filesystem`, `skill-badge`, `tool-skill`.
- **subagent** — `subagent` (provider-registry contract + delegation tool), providers `subagent-acp`, `subagent-claude-code`, `subagent-codex`, `subagent-dsh-sdk`, in-process: `subagent-in-process-driver`, `subagent-fork-in-process`, `subagent-spawn-in-process`; tools `tool-subagent`, `tool-subagent-control`, `tool-subagent-report`.
- **workflow** — `workflow` (seam), `workflow-worker-thread` (engine), tools `tool-workflow`, `tool-ralph`.
- **jobs** — `jobs` (registry seam), `jobs-local`, `tool-jobs`.
- **compaction** — `compaction` (seam: `CompactionEngine`), `compaction-basic`, `compaction-tool-result-pruner`, `command-compact`.
- **spill** — `spill` (storage seam), `spill-local`, `spill-policy`.
- **attachment** — `attachment` (durable identity/validation), `attachment-local` (content-addressed storage).
- **guard** — `repeat-tool-reminder` (advisory repeat-call reminders), `timeout-policy` (cooperative `tools/execute` deadline enforcer, `TOOL_TIMEOUT` code).

### Interaction, identity, settings, misc
- **interaction** — `user-approval` (one-shot approval seam, `approval/request` waterfall, `ApprovalPolicy`), `user-questions`, `commands` (human-command registry), `permission-presets`, `tool-ask-user`.
- **identity** — `anonymous-user-id`. **credentials** — `credentials` (seam) + `credentials-local` (env-over-`.env`). **settings** — `settings` (seam) + `settings-file`. **feedback** — `message-feedback`, `command-feedback`. **goal** — `goal` (persistence), `goal-round-driver`, `command-goal`, `tool-goal`. **schedule** — `schedule` (session-local scheduled follow-ups). **plan** — `plan-mode`. **todo** — `tool-todo` (`todo_write`). **preset** — `agent-presets` (per-session composition from preset cordis.yml), `persona`. **extensions** — `cordis-host-runner`, `cordis-client-runner`, `tool-cordis` (self-modification), `ui-cordis`. **hooks** — `hook-protocol` (Claude Code/Codex wire protocol), `hooks-claude-code`, `hooks-codex`.
- **context** — `agent-instructions` (workspace AGENTS.md), `time-context`, `tmux-context`, `session-reference` (recall from other sessions).
- **sdk** — `sdk/protocol` (JSON-RPC wire, pure library), `sdk/server` (`jsonrpc` stdio plugin), `sdk/client` (TypeScript client: `DeepSeekHarness`, `HarnessClient`). **acp** — `acp` (Agent Client Protocol server). **api** — `api/gateway` (Typert RPC: `typertGateway` / `ctx.remote`), `api/remotes` (BFF assembly; `createApiRemoteAgentResolver`). **host** — `host/webserver`, `host/apiproxy`, `host/frontend-static`, `host/directory-picker*`, `host/plugin-inventory`. **client** — browser half: `client-connection`, `client-runtime`, `client-web`, `client-web-react`, `client-hmr`, `client-modules`, `client-schema-form`, `client-locale`, ~30 `client-ui-*` plugins. **bundle** — `base`, `headless`, `web-app` (installable `dsh --profile` patch layers). **boot** — `app-boot`, `cmdline`. **typert** — `generator`, `loader`, `registry`, `protocol`. **mcp** — `mcp-client` (MCP server bridge registering `mcp__<server>__<tool>` tools). **workspace** — `workspace` (workspace entity). **e2b** — `e2b`, `fs-e2b`, `subprocess-e2b` (POC). **examples** — `agent-spine-demo`, `acp-demo`, `jsonrpc-demo`. **test-support** — `agent-loop-testkit`, `llm-mock-server`, `llm-replay`, `acp-snapshot`, `loader-smoke`, `client-test-runtime`. **runtime-diagnostics** — `invariants`. **util** — `brand` (`Branded<B>`), `atomic-write`, `home-paths`, `launch-environment`, `native-command`, `output-retention`, `timeout`.

---

## 2. Inter-package dependency graph

Canonical source: `docs/module-graph.md` (generated from `peerDependencies`; every package also depends on `dsh-invariants`).

**Foundation layer (near-leaf, only depend on `dsh-invariants` + each other):** `util/*` (atomic-write, brand, home-paths, launch-environment, native-command, output-retention, timeout), `scope`, `typert/{protocol,registry,generator}`, `identity/anonymous-user-id` (+ home-paths), `storage/*` (+ storage), `sandbox` (+ llm/session for prompt context), `attachment` (+ brand).

**Vocabulary layer:** `llm` depends on `attachment`, `brand`, `timeout`; `session` depends on `brand`, `llm` (Message vocabulary), `scope`, `typert-protocol`. `system-prompt` depends on `llm`, `scope`. `tools` depends on `agent` (Agent type), `code-runtime` (optional), `llm`, `scope`, `session`, `system-prompt`, `user-approval`. `agent` depends on `llm`, `scope`, `session`, `system-prompt`, `typert-protocol`.

**Machine layer:** `agent-loop` → `agent`, `llm`, `scope`, `session`, `session-persistence`, `settings`, `system-prompt`, `tools`.

**Provider/tool layers fan out from the machine layer.** Nearly every consumer tool depends on `tools` + `llm` + `system-prompt` (they register prompt sections) + `session`; capability providers depend on their seam + `subprocess`/`sandbox`/`timeout`. Notable deep consumers: `api/remotes` (aggregates ~15 packages: agent, agent-presets, api-gateway, commands, cordis-host-runner, credentials, goal, host-plugin-inventory, llm, message-feedback, session, session-persistence, settings, typert-registry); `subagent` (agent, agent-presets, jobs, llm, sandbox, sandbox-policy, scope, session, session-persistence, session-projection, session-projection-cache, tools, user-approval); `agent-spine-demo` (≈20 packages — the reference composition).

**Layering rules worth copying** (from `packages/README.md` + module graph): extension plugins depend on Service Definitions, never concrete providers; `dsh-agent-loop` is swappable (UI/hook/tool plugins use `dsh-agent`); the graph is acyclic per direction — no provider imports a consumer.

---

## 3. Core abstractions

### 3.1 Agent loop (`core/agent` + `core/agent-loop`)

- **Interface (`dsh-agent`)** is an event vocabulary + handle, not a class: `Agent` interface with `send/steer/inject/followup` inbox boundaries (`next-turn` vs `next-step`), `cancel(cause)` with `keepInbox`, `whenIdle()`, `runMaintenance()`. All extension points are Cordis hooks: waterfalls `agent/pre-step` (reject/replace step input), `agent/request` (replace frozen call config), `agent/request-error` (retry recovery); serial `agent/turn-stopping` (data-driven turn close — listeners can `steer()` to keep going); emits for lifecycle/inbox/errors. (`core/agent/src/runtime-types.ts`)
- **Concrete driver (`ReactLoopAgent`)** is a phase state machine `idle | maintenance | running` with an `AbortController` per phase; `kick()` drives `turn()` → `preStep()` → `step()` loops. Step = assemble prompt → stream model call (logging every raw chunk) → assemble assistant message → execute tool calls → loop or close. `max-tokens` is sticky across steps; every exit path writes a `turn/end` with a structured `TurnEndReason`. (`core/agent-loop/src/agent.ts`)
- **Ownership/teardown:** agent-loop's `FactoryOwnership` tracks live agents + startup tasks; `PreparedAgent.publish/dispose` gives reversed teardown (stop machine → unregister → unwind scope). Session lifecycle is folded into the agent's own `ctx.effect` via `sessions.prepare/enter/announce` so teardown order is one ordered chain (commentary in `core/session/src/index.ts`).
- **Reconstructability invariant:** every model request is derived from the session log; `markAgentLoopRequest` tags loop-built requests as deep-frozen, mutation-throwing.

### 3.2 Model/provider layer (`packages/llm/`)

- **Abstract adapter:** `LlmAdapter` — only `stream(options): AsyncIterable<StreamChunk>` is abstract; `providerInfo`, `providerRetryPolicy`, `listModels`, `resolveModel` have safe defaults. Registration is all-or-nothing, per-provider-route, with `AdapterRegistrationHandle.replace()` for atomic route swaps (no gap observable). (`llm/llm/src/index.ts`)
- **Provider-neutral streaming protocol:** `StreamChunk` = block-indexed deltas (`block-start`, `text-delta`, `reasoning-delta`, `tool-call-delta`, `block-end`), `usage` before terminal `finish`, `replayState` for adapter-private replay. `BlockAssembler` is the single canonical assembly algorithm (delta-only tolerant, ignores stragglers after `block-end`, drops un-executable tool calls on max-tokens). (`llm/llm/src/types.ts`, `assembler.ts`)
- **Failure normalization:** adapter throws are normalized to terminal `error`/`aborted` finish chunks at the boundary (`adapterStream`); provider HTTP errors map to stable codes (`AUTH`, `RATE_LIMIT`, `QUOTA_EXCEEDED`, `CONTEXT_WINDOW_EXCEEDED`, `TIMEOUT`, `TRANSPORT`…) via `httpErrorCode()` (`llm/llm-deepseek/src/adapter.ts`); `LlmError` carries serializable `failure` facts (message/code/status/retryAfter/requestId).
- **Two adapter idioms** (documented in Agent Note `twin-llm-adapters`): `llm-deepseek` = direct fetch+SSE with attribution headers; `llm-pi-ai` = library-backed with catalog/discovery/replay.
- **Retry** is a separate plugin on `agent/request-error` (`llm-retry`): provider-owned policy (codes, maxRetries, jittered exponential backoff), scheduled retries durable before their cancellable wait. (`llm/llm-retry/src/index.ts`)

### 3.3 Tool system (`core/tools` + `core/agent-loop/tool-calls.ts`)

- **Registration:** `tools.register(ToolDefinition)` — schema (`name/description/parameters` JSON Schema) + mandatory `output` contract (`schema`, pure `render`, optional `presentationMeta`) + optional `timeoutMs`, `isConcurrencySafe`, `presentCall`/`presentResult` (pure, replay-safe UI intents). `defineTool()` compiles a typed schema DSL into JSON Schema + inferred TS argument types with hard validation at execute and soft validation for presenters. (`core/tools/src/schema.ts`)
- **Scoped layers:** `ScopedLayers` — scoped registrations shadow globals; `tools.restrict()` (allow/deny masks), `tools.guard()` (monotonic denials that no listener can re-allow). (`core/tools/src/index.ts`)
- **Execution pipeline (ordered):** `createExecution` (token minting, lossless-JSON + deep-freeze of args) → `tools/pre-execute` waterfall (allow/deny/ask) → approval seam (`ctx.approval`, fails closed) → monotonic guards → `tools/execute` around-dispatch waterfall (signal fusion) → tool body → `tools/post-execute` waterfall (accept/block/replace) → `finalizeContent` → lossless materialization → `tools/result` emit. Cancellation is canonicalized to `ABORTED`/`ABORTED_BEFORE_DISPATCH` error results. (`core/tools/src/index.ts`)
- **Scheduling (`agent-loop/tool-calls.ts`):** exclusive calls form barriers; parallel calls use a bounded rolling pool (`maxParallelToolCalls`); policy/results/context commit in model order while dispatch overlaps; abort records synthetic error results for skipped calls so replay stays valid.
- **Code Mode:** `run_code` reserved transport + generated TS/Python SDK renderers; `mode: native|code|both` per scope via `presentAs()`. (`core/tools/src/code-mode.ts`, `ts-types.ts`, `py-types.ts`)

### 3.4 Session / state / persistence (`core/session` + `packages/session`)

- **Event-sourced append-only log:** `Session` is a plain class (not a Service); `append(type, data, surfaceIntent)` validates lossless JSON, deep-freezes, assigns `seq = log.length` contiguity, synchronously notifies `session/event` observers (hot path never blocks on I/O). Merge-extensible `SessionEventMap`; per-event `ignorable` guard for vocabulary growth; `SESSION_FORMAT_VERSION = 0` monotonic, no migration promise. (`core/session/src/index.ts`, `types.ts`)
- **Surface mechanism:** message-producing events (`user/message`, `assistant/message`, `tool/result`) carry `surfaceOp` (`append` or `{op:'replace', start, end}` for compaction) + `sourceEventSeqs`; `deriveMessages()` walks the surface with an incremental cache (`derived` array, `replaceGeneration` invalidation). Compaction replaces a node range with one summary node. (`core/session/src/surface.ts`)
- **Store:** `SessionStore` (`ctx.sessions`) with `create/prepare/enter/announce/fork/flush`; `prepare+enter+announce` split exists so the agent factory can fold session lifecycle into ONE ordered effect. `fork` supports subagent lineage with `parentSession`/`seedLength`/`delegationDepth` header fields.
- **Persistence:** `SessionPersistence` abstract seam; `PersistenceCoordinator` shares buffering/serialization/adoption/repair/disposal; `SessionWriteBehind` gives bounded per-session write batching (200 ms default deadline, quiescence barrier). JSONL backend stores header + contiguous events verbatim with zstd frame compression and chunk-run packing; SQLite backend uses monotonic `SCHEMA_VERSION` (currently 15) + `applicationId`. Durability is enforced by `session-checkpoint-policy`: flush before each model request, before top-level tool dispatch, after step completion.
- **Projections:** `SessionProjectionRegistry` drives pure synchronous `init/apply/view` units over committed events; whole-value event rule (state events carry complete post-change state, never deltas).

### 3.5 Prompt / context assembly (`core/system-prompt` + `core/agent-loop` + `context/`)

- **Registry:** `SystemPrompt.section()/context()/tools()/variable()` — ordered (conventions: -100 harness identity, 0 persona, 100–199 tool guidance), scope-aware via `ScopedLayers`, `complete` section support. Assembly runs `system-prompt/assemble` waterfall, then `renderPrompt()` interpolates `{{variables}}`.
- **Context assembly:** loop's `preStep` claims inbox messages → `systemPrompt.assemble(assembleContextFor(...))` → `RuntimeContextProjection.project()` renders context sections with semantic `ContextForm` (`instructions|catalog|snapshot|notice|relay|recall`) and folds them as a durable `user/message` context snapshot. `core/agent-loop/src/runtime-context.ts`, `llm/llm/src/message.ts`
- **Per-request header:** `request/header` event logs the frozen config + rendered system + tool schemas (initial/resume/change reasons); `requestProposal()` strips adapter-derived defaults before plugins propose the next config. `core/agent-loop/src/agent.ts`, `core/session/src/request-header.ts`

---

## 4. Code-quality patterns worth adopting

1. **Branded opaque ids.** Cross-boundary ids are `Branded<'SessionId'>`, `CallId`, `ProviderRequestId`, `RetryId` (`packages/util/brand`, `llm/llm/src/brand.ts`) — never bare strings; compile-time-only casts, no runtime cost.
2. **Merge-extensible maps + declaration merging for all extensible vocabularies.** `SessionEventMap`, `ContentBlockMap`, `MessageSourceMap`, `FinishReasonMap`, `TurnEndReasonMap`, `ModelModalityMap`, `SessionProjectionMap`, `JobKindMap`; plugins extend via `declare module`. Consumers `switch` on discriminant `type`/`kind` and fall through a documented default (`assertNever` for closed unions) — new blocks require adapter, UI, and compaction support (noted in `types.ts`).
3. **Boundary validation, not defensive checks.** Lossless-JSON validation (`snapshotJsonValue`) at every durable/wire/seed boundary; deep-freeze + `structuredClone` at ownership transfer; validate at parser/config/worker/process/wire boundaries, never redundantly inside typed same-process code. Trust TypeScript at typed same-process boundaries (explicit repo rule, `AGENTS.md`).
4. **Structured error taxonomy.** `HarnessError` with stable machine `code` strings; typed errors carry serializable facts (`LlmError.failure`, `ToolErrorInfo`, `ToolNotFoundError` with `UNKNOWN_TOOL`); error normalization happens exactly once at the adapter boundary into terminal failure chunks; `errorChain()` flattens cause chains for diagnostics.
5. **Contained listener dispatch.** Cordis emits that must not be vetoed by one broken listener re-dispatch manually per-listener with try/catch (`emitAdaptersUpdated`, `invokeContainedSessionObservers`); `session/flush` uses `Promise.allSettled` and throws the first failure after all settle. Commented rationale at each site.
6. **Registrations are effects; disposers returned.** Every contribution goes through `ctx.effect()`/`ctx.on()`; `register()` returns the exact disposer; ordered teardown via generator effects (`yield disposer` before later steps so a throw rolls back prior yields). `FactoryOwnership` + memoized `dispose()` for composite resources.
7. **Cancellation discipline.** AbortController per activity; `AbortSignal.any`-style manual signal fusion (`fuseToolSignals` avoids `AbortSignal.any` for dispatch-scoped cleanup); `raceAbort` helpers; cooperative `timeoutMs` deadlines (`dsh-timeout` `deadline()`/`timeoutOf()` scoped by classification code); streams use an idle watchdog (`idleWatchdog`) plus consumer abort controller; every async operation honors `signal` and settles promptly.
8. **Streaming with replay fidelity.** Raw chunks are logged (`assistant/chunk`) and the assembled message cites them (`sourceEventSeqs`); `BlockAssembler` is the single canonical algorithm; `usage` travels with the assistant message; adapter `replayState` enables response replay only when the same adapter instance owns both historical and target providers.
9. **Concurrency with ordered commits.** Parallel tool-call pool commits results/contexts in model order (`agent-loop/tool-calls.ts`); write-behind batching with fixed deadline + quiescence barrier; monotonic guards that cannot be re-allowed; `tools/execute` wrapper pattern (around-dispatch) for timeout/retry/sandbox cross-cutting concerns without touching the loop.
10. **Runtime invariants registry.** Each package ships a `./invariant` companion registered into `ctx.invariants` (allowlist/blocklist config, `INVARIANT` failure code); invariant checks assert owned relationships (authoritative event streams / mutable data), and CI gates per-file 100% coverage (`test:coverage`).
11. **One canonical implementation of a mechanism.** Single `BlockAssembler`, single tool-output contract, single flush entry point (`sessions.flush`), single header fold (`foldRequestHeader` incremental cache); duplicated logic is extracted (e.g. `requestProposal`, `httpErrorCode`), and cross-package drift is prevented by sharing the predicate (e.g. code-mode `collapses()` shared by view + execution).
12. **Explicit resolve steps at config boundaries.** Adapter connection facts resolved through an explicit thunk per operation (`DeepSeekConnectionOptions`), credential resolved from the same snapshot as the endpoint — never `?? default` hidden inside run paths; deployment-varying tunables are validated `Config` fields, protocol/security constants stay fixed.

---

## 5. Unresolved questions

1. **`llm-pi-ai` internals** (catalog/discovery/replay, 1.5k+ LOC) were not read in full depth — sibling-level understanding of how the library-backed adapter implements replay state and model discovery is incomplete here.
2. **SQLite backend performance characteristics** (schema v15, FTS usage in `session-query-sqlite`) need a separate pass to answer "how fast is session resume / query" questions.
3. **Compaction semantics depth**: `CompactionEngine.compactIfNeeded/compactNow/compactRegion` contracts and the `compaction-basic` provider's trigger policy were only skimmed; the surface `replace` mechanics are understood but end-to-end compaction correctness (token budget, tool-result pruning) is not fully verified.
4. **MCP bridge (`mcp-client`) tool lifecycle** (server connection mgmt, tool refresh, sandboxing of MCP tools) was not examined — relevant if the upgrade targets MCP.
5. **`client/` (browser half) and `host/` (Typert RPC, apiproxy) wire contracts** were out of lane per mission (sibling covers apps/); the `api/remotes` aggregation is the main cross-reference point to coordinate on.
6. **Whether the `dsh-timeout` deadline/watchdog utilities are the recommended pattern for new long-running work** (vs bare `setTimeout` + `AbortSignal`) — codebase consistently uses them, but there is no written policy note found.
7. **Agent Note coverage**: many design decisions live only in `.agents/notes/implemented/*` (capability seams, twin adapters, event-sourced sessions, session surface, session-log version mechanism, approval seam, sandbox, parallel tool calls, code-mode language dispatch, package regrouping). For an upgrade project these are required reading; a decision-value index is worth producing.
8. **`FIXME` count** — e.g. `timeout-policy` carries a rename FIXME (`dsh-timeout-guard`) pending first tagged release; worth confirming no other pre-release renames are in flight before building on package names.
