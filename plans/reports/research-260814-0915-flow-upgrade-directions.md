# Flow-skill upgrade directions — deepseek-harness research synthesis (Phase 2)

- **Date:** 2026-08-14 09:30
- **Agent:** EVALUATOR (synthesis lane)
- **Inputs read:** `research-260814-0915-flow-baseline.md` (Phase 1) + six deepseek-harness reports:
  `-deepseek-architecture.md`, `-deepseek-tech-stack.md`, `-deepseek-packages-core.md`,
  `-deepseek-apps.md`, `-deepseek-native-python.md`, `-deepseek-docs-bench.md`.
- **Scope:** analysis only — no product code modified. Ranked upgrade directions for the **flow skill**
  (skill + bash CLI + python durable layer), with explicit do-NOT-adopt list.
- **Framing caveat that governs everything below:** dsh is a **runtime harness** (a plugin platform
  that runs an agent loop, 219 npm packages, event-sourced session core); flow is a **skill + CLI** (an
  instruction-based gated process that shapes what an existing agent model does in a repo). Most of
  dsh's machinery is not portable across that boundary; its *disciplines* (testing, gating, docs,
  evidence integrity) are. Every direction below was filtered through "is this a discipline flow can
  absorb, or is it a platform flow should not rebuild?"

---

## 1. Side-by-side comparison

### 1.1 Architecture

| Dimension | flow-skill (v0.29.0) | deepseek-harness (0.1.0-rc.5) |
|---|---|---|
| Nature | Skill bundle + 4.7k-line bash engine (`runner/flow.sh`) + ~1.3k-line python durable CLI (`harness/flow_harness.py`) + sqlite | Plugin-based agent harness: vendored Cordis DI core, ~49 groups / 219 ESM npm packages, launcher (`apps/cli`) + web GUI + headless + SDK |
| Core idea | **Two-layer gate**: deterministic mechanical layer (flow.sh exit 0/1) + model semantic layer (SKILL.md + `references/gate-rules.md`); a gate passes only when both agree | **Everything is a plugin**: capability seams (Service Definition / Provider / Consumer); session event log is the single source of truth; "Model-visible ⟺ logged" runtime invariant |
| Runtime | None of its own — delegates all execution to the hosting agent's tools (bash/curl/git via the model) | Own agent loop (`ReactLoopAgent`: turn/step machine, inbox, tool-call scheduler, cancellation) over `ctx.llm` adapters |
| State | Markdown artifacts in `flow/` + `cards/`; sqlite durable layer; JSONL usage log; attestation receipts under `.flow/` | Event-sourced append-only `SessionEvent` log with `deriveMessages()`, `request/header` freeze, projections, compaction via surface `replace` |
| Composition | Templates copied per stage; 29 dispatcher verbs; concurrency lock; worktree isolation | Profile/bundle `cordis.patch.yml` layer stacking; agent presets; per-agent scoped `ctx`; `--dump-config` auditable tree |
| Degradation | Everything optional: no python → durable off; no git → worktrees off; no agents → built-in fallback; no engine → plain bash | Fail-loud `assertEntriesActivated()`; deny-by-default builds; no install-time compile fallback; probe→`unusable` fail-closed |
| Evidence files | `deepseek-architecture.md` §2-3, `packages-core.md` §3; flow baseline §2 | dsh architecture §2-4 |

**Read:** both are "gate-first" systems in spirit (dsh's `run-gates.ts` declarative gate graphs vs flow's
mechanical gate scan) — but dsh gates *machines*, flow gates *artifacts written by a model*. Flow's
simplicity (zero deps, bash-3.2-safe, degrade-friendly) is a feature its own docs defend
(`docs/system-architecture.md` "Why this shape"); dsh's complexity buys runtime observability flow
does not need because the model (and its platform) already provides execution.

### 1.2 Extensibility

| Dimension | flow | dsh |
|---|---|---|
| Extension model | Instruction-level: 24 reference playbooks the model reads; agent ladder (ck: → bmad → built-in, + Codex/Antigravity cross-vendor tiers); deep-wired skill whitelist (ck-predict/scenario/security/loop…); harness CLI fixed verbs | Runtime-level: merge-extensible maps + `declare module` (`SessionEventMap`, `ContentBlockMap`, …); scoped `ctx` with effect-disposer registrations; `tool-cordis` self-modification; hooks (Claude Code/Codex wire protocols); MCP client bridge; subagent providers (ACP/Codex/Claude-Code/in-process); skill registry with ranked discovery roots |
| New capability path | Write a reference doc / add a gate rule / register a harness tool (kind-aware: cli\|binary\|mcp\|skill\|http — presence-probed, `harness/tool`) | Register a `ToolDefinition` on `ctx.tools`, a provider on its seam, or a prompt section on `ctx.systemPrompt`; swap via patch layer |
| Swappability | Cross-vendor *model* swappability only; the engine is one file | Provider-level swappability everywhere (fs/shell/sandbox/subagent/LLM) |
| Evidence files | flow baseline §2.1, §7; `deepseek-packages-core.md` §1, §3.3; `deepseek-architecture.md` §3.4, §4 | |

**Read:** dsh's seam pattern (definition/provider/consumer, consumers depend on definitions never
concrete providers — `packages-core.md` §2) is a *documentation/architecture discipline* flow can copy
at the instruction layer (e.g., re-model `agent-stage-mapping.md` and `claudekit-skills.md` as explicit
"definition/provider/consumer" seams), not a runtime to build. Flow's `tool` registry already has the
kind vocabulary; it just probes presence rather than bridging.

### 1.3 Evidence / state model

| Dimension | flow | dsh |
|---|---|---|
| Source of truth | Card `## Evidence` (pasted world-state prose, scored ≥2 of 6 signal categories) + git-blob attestation fingerprints + sqlite story/trace | Event log; **reconstructability invariant**: every model request is a pure function of the log (`request/header` epoch + `deriveMessages()`); raw chunks logged, assembled message cites them |
| Integrity | `flow-attestation/v1` receipts (semantic_gate / live_verify), subject fingerprints, `risk-ack` DEBT-commit checks, author-distinct via `git blame`; honest boundary: not crypto/identity, forgeable by repo owner | `SESSION_FORMAT_VERSION` monotonic, no migration promise; lossless-JSON boundary validation; crash-tail synthetic closers; checkpoint policy (flush before model request / tool dispatch / step end); surface `replace` for compaction |
| Ground-truth rule | "Done = proof in the world"; ground-truth gates: the model never grades its own gate (`references/ground-truth-gates.md`) | "Verify the world, not the self-report" (re-run the command / re-read the file; assert untouched files byte-identical — `tech-stack.md` §2.1) |
| Evidence files | flow baseline §5; `deepseek-packages-core.md` §3.4, §4.8; `deepseek-architecture.md` §3.1, §5.1 | |

**Read:** these are the *same philosophy* at two scales — flow proves world-state at card boundaries
(coarse), dsh proves reconstructability at every model call (fine). Flow's `resume`/`status` already
rebuild a session brief from `.flow/events.jsonl` — a thin echo of dsh's log-derived projections. The
gap worth closing is not "build an event log" (YAGNI) but *making card evidence machine-checkable and
lineage-linked* (structured evidence entries that reference durable records — receipts, events, files).

### 1.4 Testing

| Dimension | flow | dsh |
|---|---|---|
| Scale | 58 bash suites (3-OS GH Actions matrix; windows 45m) + 41 node:test (npm wrapper) | vitest (4 configs: unit/coverage, e2e with-key, snapshot replay, web), pytest for python, fast-check property, Testing Library, 17 GH workflows + GitLab CI |
| Coverage gate | Functional net only; no line-coverage gate | **Per-file 100% line coverage on every `packages/*/*/src`** as a CI gate; uncovered line = dead-code candidate; probe-linked exemptions (pwsh self-skip ⇔ exemption active) |
| Determinism | `flow.sh eval` = live-LLM behavioral judge (3 modalities: gate/routing/converge; nonce-protected; **billable, opt-in, never in CI**); offline mock-engine unit tests for eval plumbing | **Keyless snapshot replay** (`DSH_SNAPSHOT=record|refresh|replay`): boots the real composed system, replays scripted model streams, diffs normalized JSON-RPC + re-persisted logs — CI runs read-only replay |
| World-verify | `tests/e2e-installed-drive.sh` drives the *installed* skill; ground-truth gates demand real curl/DB proof | Real-API e2e self-skips without key; mock-model smoke of the *packaged wheel's exe*; built-artifact smokes (`built-bin.e2e.ts`) |
| Gate orchestration | `tests/run_all.sh` hardcoded linear loop | Declarative gate graphs (`run-gates.ts`: gates with `needs`, bounded concurrency, Windows-safe spawn); CI = subsets of local `check-all`, one source of truth; single `all-checks-passed` required job with `if: always()` |
| Evidence files | flow baseline §9; `deepseek-tech-stack.md` §2.1-2.4, §6.3-4 | |

**Read:** dsh's three most transferable testing ideas: (a) single-required-check CI aggregation with
`if: always()` (skipped required check silently passes otherwise — a real GitHub trap flow doesn't yet
defend against), (b) keyless replay of recorded model streams (would make flow's semantic-layer
regression deterministic and CI-able, addressing the documented "eval is billable/never in CI" gap in
`references/gate-eval.md`), (c) pack-and-install rehearsal of the *published artifact* (dsh packs
credentialless on every PR; flow's equivalent is `scripts/release-preflight.sh` + the npm-wrapper
RELEASE_CHECKLIST — but they're not wired into every-PR CI).

### 1.5 Distribution

| Dimension | flow | dsh |
|---|---|---|
| Channels | npm installer CLI `@manhquy/flow-skill` (Node ≥22.14, 5 agent targets, dry-run/JSONL), `install.sh`/`install.ps1`, Claude plugin marketplace, OIDC trusted publish on `npm@*` tags, nightly registry-health | pnpm monorepo; **4 independent release sequences** (dsh family / vendored Cordis family / landlock-run native prebuilds / python wheels via GitLab PyPI); single-file Node exe (pkg `--sea`) bundled in python wheels; per-platform optional-dep packages for native binaries |
| Publish safety | Release preflight script (version coherence, registry `rc` match), OIDC provenance, dist-tag guards (`next`/`latest`, prerelease→`next`), post-publish verify steps in RELEASE_CHECKLIST | **Idempotent integrity-based publishing** (`publish.ts`: per-package decision vs registry sha512 — absent→publish, same-integrity→skip, different→fail; retry only transient codes, re-reading registry first); credentialless pack on every PR; verify-packed-install rehearsal; deny-by-default install scripts (`allowBuilds`); publint + package invariants |
| Vendor mgmt | None (no vendored deps; single pkg depends on `@clack/prompts`) | Vendored Cordis with rescope `@deepseek-ai/*`, SHA manifest, numbered modification log, `linkWorkspacePackages` |
| Evidence files | flow baseline §6; `deepseek-tech-stack.md` §1.1, §1.4, §5, §6.11 | |

**Read:** flow's distribution is already appropriately simple for a one-package product. The transferable
pieces are the *safety loops*, not the machinery: pack+install rehearsal in every-PR CI (cheap,
credentialless), and optionally flow's own idempotent publish (skip-if-same-integrity) to make
re-running a publish safe. Vendoring discipline is N/A. Deny-by-default build scripts are N/A (flow
ships no native deps).

### 1.6 Docs / benchmark practice

| Dimension | flow | dsh |
|---|---|---|
| Doc structure | README (+README_VN), docs/ (architecture, quality-metrics, release-process, journals), 24 reference playbooks (the semantic layer's code), CHANGELOG; `flow.sh coherence` catches version drift; plans/reports/ decision artifacts per change | Tiered "one home per fact" taxonomy with **enforced per-doc word budgets**; 1,078 bilingual `.i18n.yaml` blob-hash pairing records across 936 `.zh.md` files; **generated catalogs** (module-graph, config-catalog, tool-catalog, persistence-catalog) with freshness gates, never hand-edited; **doc-typecheck** (compiles fenced code blocks, verifies `type-equiv`/`public-api` fences against source); website as a **tested projection** (allowlist manifest + link rewriting + build = dead-link gate); **Agent Notes** decision records (1,372, lifecycle-gated); skills with invocation metadata; `CLAUDE.md` symlinked to `AGENTS.md` |
| i18n | Manual EN + VI (README_VN, npm-wrapper/README_VN); drift risk acknowledged in RETRO/quality-metrics (recurring stale-count class) | Blob-hash (not commit-hash) consistency records + fail-closed git merge driver; structural-signature checks; bilingual glossary with do-not-translate column |
| Benchmark | **`/flow eval`**: behavioral proof for the semantic gate — fresh-judge lower bound, 3 modalities (gate/routing/converge), nonce-protected verdicts, scorecards + drift, offline `--report`; documented authorship-bias limitation | **`BENCHMARK.md` is a 3-line pointer** — no task suite, no scoring, no methodology; what exists: keyless snapshot replay infra, mock LLM server, cost knobs (`maxTokensAsSuccess`, `DSH_MAX_TOKENS`, context window), per-task isolation contract (fresh session id + workspace + JSONL transcript) |
| Evidence files | flow baseline §8-9, §11; `deepseek-docs-bench.md` §1, §4-5 | |

**Read:** surprising inversion — on *benchmarking the semantic/agent layer*, flow is ahead (dsh has no
benchmark; flow has a measured, nonce-protected gate eval with honest limits). On *docs-as-code
engineering*, dsh is far ahead and its patterns are directly portable at low cost: word budgets
(`docs-bench.md` §1.1), blob-hash i18n pairing (flow's EN/VI pair is exactly the failure class this
prevents), generated catalogs with freshness gates (flow already pins `flow-topology.json` — the
pattern exists), and `CLAUDE.md = AGENTS.md` symlink (flow is multi-engine; a root AGENTS.md serves
Codex/Gemini contributors the same context).

---

## 2. Ranked upgrade directions for the flow skill

Tiers: **A = adopt** (high value / low-mid effort, fits KISS), **B = adopt selectively** (real value,
bigger surface or trade-offs), **C = do NOT adopt** (YAGNI or contradicts flow's product shape).

### Tier A — adopt

#### A1. CI: single `all-checks-passed` required job + `if: always()` + manifest-driven gate runner
- **What:** aggregate flow's CI jobs under one required check that fails on any non-success
  (including skipped/cancelled), via `needs` + `if: always()`; convert `tests/run_all.sh`'s hardcoded
  linear loop into a thin manifest of suites (with optional `needs` groups), run by one runner so
  local `check-all` and CI share a single source of truth.
- **Why:** dsh treats CI modes as *data* (`run-gates.ts` declarative gate graphs, `check-all` subsets)
  and singles out the GitHub trap: a failed dependency *skips* a required check and a skipped check
  counts as passing — their `if: always()` aggregation is load-bearing (`tech-stack.md` §2.3, §6.4).
  Flow's CI has one bash-suite job on a 3-OS matrix plus publish/nightly; today a skipped cell could
  quietly pass, and adding suites means editing a hardcoded loop (`tests/run_all.sh`).
- **Effort:** S–M. **Risk:** low (pure CI plumbing; local parity preserved).
- **Do not over-build:** no 13-aggregate graph, no failover-pool drills — one required job + a
  manifest is the KISS slice.

#### A2. Credentialless pack-and-install rehearsal on every PR (artifact-level trust)
- **What:** wire flow's existing release tooling into every-PR CI: run `npm-wrapper`'s `npm pack` +
  a fresh install of the packed tarball into a temp skill home + the installed-drive smoke
  (`tests/e2e-installed-drive.sh`) — no publish, no secrets.
- **Why:** dsh packs credentialless on every PR to prove the publish set still packs, and runs
  `verify-packed-install.ts` byte-pinning the installed artifact (`tech-stack.md` §5.1, §6.11). Flow's
  own checklist already does `npm pack --dry-run --json` + installed-drive e2e
  (`npm-wrapper/RELEASE_CHECKLIST.md` L94, `tests/e2e-installed-drive.sh`) — they just aren't joined
  into one always-green gate; the install-time failure class (retry-on-EBUSY, symlink rejection,
  Node-version guard) is exactly what the installer's own tests target.
- **Effort:** M. **Risk:** low-mid (windows cell is slow; keep the rehearsal in the ubuntu lane only).
- **Optional follow-on:** idempotent publish (skip-if-registry-integrity-equal) from `publish.ts`
  (`tech-stack.md` §5.1) — makes manual re-runs of `npm@*` publishes safe; small standalone script.

#### A3. Keyless replay/snapshot mode for the semantic layer (close the "eval is never in CI" gap)
- **What:** extend `flow.sh eval` with a **replay mode**: record a judge run (fixture + gate-rules
  text + model output + verdict) to `.flow/eval-raw/…`-style fixtures, then replay deterministically
  offline (scripted model stream) to diff verdicts — CI-able, zero calls, keyless; gate-rules edits
  become regression-testable instead of re-billable.
- **Why:** flow's eval is the product's proof that the semantic gate works, but it is live-LLM,
  billable, opt-in, and never in CI (`references/gate-eval.md`; baseline §9, §11). dsh's keyless
  snapshot replay is the exact deterministic regression net for model-visible behavior — scripted
  model streams against the *real* composition with normalized diffs (`tech-stack.md` §2.1, §6.7;
  `docs-bench.md` §5.9). The mock-engine plumbing already exists in flow's eval tests (CHANGELOG:
  "fully offline-tested (mock engine)"); this makes it a first-class mode. Pair with dsh's
  "verify the world, not the self-report" as an explicit testing convention (`tech-stack.md` §2.1).
- **Effort:** M–L. **Risk:** medium — touches the eval verb, the most intricate part of flow.sh
  (nonce/verdict/scorecard machinery); scope strictly as a *replay mode added beside* live mode.
- **Deliberately not included:** a dsh-style whole-pipeline model benchmark (see C5).

#### A4. Root `AGENTS.md` (symlinked `CLAUDE.md`) + one-home-per-fact budget pass over references/
- **What:** add a root `AGENTS.md` for the flow repo (standing orders, layout map, command reference,
  conventions, test-evidence protocol) and symlink `CLAUDE.md` to it; add a tiny word-budget manifest
  for the longest reference docs (SKILL.md, `gate-rules.md`, `references/attestations.md`,
  `README.md`) with a verify script in release-preflight.
- **Why:** dsh treats agent-context as a first-class, word-budgeted artifact — root AGENTS.md ≤1,900
  words, subtree AGENTS.md, `CLAUDE.md` symlinked so one source can't drift (`docs-bench.md` §2, §1.1).
  Flow is a multi-engine product (Claude/Codex/Antigravity) whose repo has no AGENTS.md, and its own
  RETRO repeatedly records the stale-count/stale-doc drift class (baseline §11, RETRO.md) — budgets +
  one-home-per-fact is the cheapest structural fix, and it is the *same spirit* as flow's existing
  `coherence` verb applied to prose.
- **Effort:** S. **Risk:** low. **Boundary:** budget enforcement is advisory-ish (like `constitution`)
  — flag, never hard-fail a run; only the repo CI verifies.

#### A5. Blob-hash i18n consistency for EN/VI docs (light adoption)
- **What:** for the few VI pairs (README_VN, npm-wrapper/README_VN), record each side's git **blob
  hash** in a small manifest and add a `verify` step (same pattern as dsh's `.i18n.yaml`, minus the
  merge driver and glossary machinery); refresh the hash on confirmed-consistent edits.
- **Why:** dsh's key insight is blob-hash (content) consistency rather than commit-hash, making
  out-of-sync detection a pure content comparison with minimal-patch repair (`docs-bench.md` §1.2).
  Flow's EN/VI pair is the exact small-scale case this fits; drift has already been a recurring
  release-checkbox item (baseline §11).
- **Effort:** S. **Risk:** low.
- **Do not adopt:** the fail-closed git merge driver, 936-file scale, or equal-authority rule — overkill
  for two manually maintained files.

### Tier B — adopt selectively (bigger surface or real trade-offs)

#### B1. Structured, lineage-linked card evidence (the "reconstructable evidence" discipline)
- **What:** extend card `## Evidence` with an optional *structured block* — per-evidence-item entries
  `(category, artifact-path|URL, command, ref: attestation-receipt | event-seq | commit-oid)` —
  validated mechanically by `flow.sh check` (additive only; no schema migration of gated frontmatter;
  old prose-only evidence still passes). Surface it in `recall`/`status` and let `consistency`/`usage`
  aggregate evidence coverage.
- **Why:** dsh's core invariant — model-visible ⟺ logged, everything reaching a decision is
  reconstructable from durable state (`architecture.md` §3.1, `packages-core.md` §3.4) — maps to flow's
  weakest spot: evidence is pasted prose scored by regex (`_evidence_signal_score`), and the
  hollow-done residual (`fcdc` decoy class) is closed only by billable offline eval (baseline §5.1,
  §11). Machine-checkable, lineage-linked evidence makes the mechanical floor stronger without the
  multi-signal game being the end of the line, and gives the harness trace/attestation layers a typed
  hook (the attestation receipt schema already defines the projection fields to reuse).
- **Effort:** M–L (touches `cmd_check`, `_evidence_*`, templates, tests). **Risk:** medium (evidence is
  the trust floor — any regression in the done-rule is high-visibility; keep scoring backward-compatible).
- **Alternative if too big:** adopt only the *invariant as a discipline* — a `ground-truth-gates.md`
  addendum "every done-evidence item must name its artifact/command" — and enforce via the existing
  semantic card gate rather than new mechanical code (S effort).

#### B2. MCP client bridge for the harness tool registry (evaluate, likely defer)
- **What:** add a real MCP *client* (stdio/streamable-http) to the harness `tool` registry so a card
  can register+probe+call an external MCP server's tools, mirroring dsh's `mcp-client`
  (`packages-core.md` §1; `architecture.md` §4).
- **Why:** MCP is the ecosystem trend; dsh shows the seam cleanly (`mcp__<server>__<tool>` names on the
  registry, connection mgmt, refresh). Flow's `tool register --kind mcp` already *probes* MCP by path
  but never connects.
- **Effort:** L. **Risk:** medium-high — new runtime dependency surface (an MCP SDK) and a new tool
  execution path inside an instruction-based skill, where the hosting agent (Claude/Codex/Antigravity)
  **already ships native MCP support**.
- **Verdict:** likely **do NOT adopt** (see C4) unless a concrete card needs a server the host agent
  cannot reach — the duplication argument is strong. Listed here only because the harness registry
  already names the kind, so the cost of a *probe-only → connect* step is smaller than it looks.

#### B3. Per-card scoped context as an explicit capability-seam discipline
- **What:** rewrite `references/agent-stage-mapping.md` + `claudekit-skills.md` in the
  definition/provider/consumer vocabulary (the seam table + "consumers depend on definitions, never
  concrete providers" — `packages-core.md` §2, §1) so every stage names its interface, its providers
  (ck:/bmad/codex/antigravity/built-in), and what a consumer must not assume.
- **Why:** no code needed; it makes flow's existing swappable tiers structurally legible the way dsh
  makes its providers swappable, and directly supports the "gate is identical on every path" promise
  (baseline §7). Also adopt dsh's scoped-ctx idea *as a ritual*: each card already gets a worktree —
  declare the card's scope boundary (tools allowed, files allowed, prompt sections) explicitly at
  dispatch, which `workspace add` + `ready` already half-do.
- **Effort:** S (docs) / M (if the card-scope declaration becomes a checked field). **Risk:** low.

#### B4. Declarative test manifest with `needs`-style ordering (see A1) — same item, sized down
Listed separately to note the *only* dsh testing machinery worth copying beyond A1/A3: gate-graph
`needs` for serial-only suites (e.g. e2e-installed-drive after npm-wrapper tests). Everything else in
dsh's testing stack (per-file 100% coverage, property tests at scale, aria-snapshot goldens) is C-tier
for flow (see C3, C6).

### Tier C — do NOT adopt (with reasons)

| # | dsh feature | Why not for flow |
|---|---|---|
| C1 | **Cordis plugin platform / 219-package architecture** | Flow is a skill+CLI, not a runtime. Rebuilding composition would replace the auditable 4.7k-line engine with a platform flow has no host for (the hosting agent *is* the runtime). YAGNI; contradicts degrade-friendly design (baseline §2, §10). |
| C2 | **Event-sourced session core (deriveMessages, compaction, projections)** | Flow's artifacts are markdown the operator reads; a second machine-log source of truth would split authority with `flow/`+`cards/`. Flow's `events.jsonl` + `resume` is already the thin echo that serves its need. Adopt the *invariant* (B1), not the machinery. |
| C3 | **Per-file 100% line-coverage CI gate** | Bash coverage is impractical; the python harness could adopt it, but value is low against flow's 58-suite functional net (baseline §9) and it would gate every tiny schema PR. dsh's own rationale ("uncovered line = dead code") assumes a TS toolchain flow doesn't have. |
| C4 | **Flow-owned hooks (Claude Code/Codex wire protocol bridges)** | The hosting agents already run platform-native hooks. Flow owning a hook protocol duplicates platform features and adds a maintenance surface. |
| C5 | **Whole-pipeline model benchmark harness** (dsh's is a 3-line pointer anyway) | Flow's `/flow eval` is *more* mature than dsh's benchmark (nonce-protected, scorecards, drift — docs-bench §4 admits dsh has none). Direction of travel should be *strengthen flow's eval* (A3), not copy a thinner system. |
| C6 | **Web GUI / host-client split / Typert RPC / browser trust fence** | Flow is a skill, not an app. The only relevant slice is "website as tested projection" when `feat/flow-website` lands (A4/A5-adjacent; docs-bench §1.3, §5.7). |
| C7 | **Native binaries (landlock-run), node-pty/koffi FFI, single-file exe, python SDK distribution, wheel tagging** | Flow's sandbox/PTY/execution is the hosting agent's job; flow ships zero native deps and should stay that way. Python SDK distribution would fork the durable layer into a second product. (native-python.md §1, §3) |
| C8 | **Self-modification (`tool-cordis`)** | Flow's safety model *forbids* editing `runner/flow.sh`/`_templates` mid-run (SKILL.md Forbidden). Model-authored runtime self-modification contradicts it. |
| C9 | **Vendoring (rescope + modification log)** | Flow has one dependency (`@clack/prompts`). No vendor surface exists; adopting the machinery would be process theater. |
| C10 | **Full i18n triplet machinery (merge driver, glossary, equal-authority)** | Overkill for two files; A5's blob-hash record captures the real value. |
| C11 | **Failover pools / hot-standby drills / runner benchmarks** | Flow's CI is a 3-OS matrix on free minutes; dsh's runner-sizing evidence game is irrelevant at this scale. |
| C12 | **Agent Notes system at dsh scale (1,372, lifecycle gates, format verifiers)** | Flow already has dated `plans/<id>-<slug>/` phase artifacts + `plans/reports/<role>-<timestamp>-<topic>.md` + journals — the decision-record layer exists in spirit. Formalizing to dsh's ceremony adds maintenance without new information. Adopt only the *uniform frontmatter* habit if desired (S). |

---

## 3. Top 3 recommended next actions

1. **Harden the CI verdict + prove the artifact packs (A1 + A2).** Add a single required
   `all-checks-passed` job (needs + `if: always()`, fails on skipped/cancelled), convert
   `tests/run_all.sh` to a manifest-driven runner, and add an every-PR credentialless
   pack→install→`e2e-installed-drive` rehearsal in the ubuntu lane. Smallest effort, immediate trust
   gain, no product-code change. *(Evidence: tech-stack §2.3, §6.4, §5.1, §6.11; flow RELEASE_CHECKLIST L94.)*
2. **Make the semantic gate deterministic in CI (A3).** Add a keyless replay/snapshot mode beside
   `flow.sh eval`'s live judge so a `gate-rules.md` edit is regression-tested offline and CI-able —
   closing the documented "billable, opt-in, never in CI" gap (gate-eval.md). This is the single
   highest-leverage *product* upgrade: it turns flow's signature proof from an operator-run ritual
   into a continuous gate. *(Evidence: gate-eval.md; tech-stack §2.1, §6.7; docs-bench §5.9.)*
3. **Docs/context discipline pass (A4 + A5).** Root `AGENTS.md` (symlinked `CLAUDE.md`), word budgets
   on the top reference docs, and blob-hash EN/VI pairing — the structural fix for flow's most
   recurrent self-found defect class (stale counts/docs, RETRO + quality-metrics DF-1). Cheap, low
   risk, and it models for contributors the "one home per fact" rule before the website lands.
   *(Evidence: docs-bench §1.1-1.3, §2; flow baseline §11; RETRO.md.)*

Then, if the evidence layer is the priority after those: B1 (structured lineage-linked evidence)
before B2 (MCP bridge — likely defer), and B3 (seam vocabulary for the agent map) as a docs-level
step anytime.

---

## 4. Unresolved questions (for the operator / next phase)

1. **Product-identity anchor:** is flow's 5-year horizon "the discipline layer on top of commodity
   agents" (→ keep instruction-based, adopt disciplines only) or "grow its own runtime" (→ C1/C2
   reopen)? The answer changes every C-tier item's status.
2. **Evidence depth vs KISS:** how much structure should `## Evidence` carry before it stops being
   operator-friendly prose? The right cut between B1 and its S-effort alternative (invariant-as-
   discipline) is an operator judgment, not an analytic one.
3. **Eval economics:** if A3 ships, do we keep the live billable judge as the *authoritative* signal
   (replay = regression net only), or move replay to primary with live as spot-check? Cost/trust
   trade-off is unresolved.
4. **MCP:** does any near-term flow card need an MCP server the hosting agent can't already reach
   natively? If yes, B2 stops being deferrable.
5. **Website timing:** when `feat/flow-website` lands, should it adopt dsh's tested-projection model
   (allowlist manifest + link rewrite + build-as-dead-link-gate) wholesale, or the light version
   (build + link check only)?
6. **Python harness coverage:** does the durable layer deserve its own coverage floor (C3) once the
   graph-executor/attestation surface grows past its current ~3.3k lines — or is the 58-suite
   functional net enough?
7. **Attestation substrate:** flow's receipts are git-blob fingerprints; dsh's persistence is a durable
   JSONL/SQLite log. If card evidence becomes lineage-linked (B1), should receipts migrate toward
   log-anchored records (hybrid), or stay git-only for portability?
8. **i18n:** is EN+VI the permanent pair set? If a third language appears, A5's light record stays
   fine, but the glossary/terminology discipline (docs-bench §1.2) would start to earn its keep.

---

*End of Phase 2 synthesis. Analysis only — no product code modified. Companion inputs: the six
deepseek-harness reports; baseline: research-260814-0915-flow-baseline.md.*
