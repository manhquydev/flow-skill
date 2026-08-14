# Research: DeepSeek Harness — docs, examples, and benchmark deep dive

**Date:** 2026-08-14 · **Author:** DOCSBENCH (parallel research op, docs/examples/BENCHMARK lane) · **Repo:** `/home/manhquy/Downloads/deepseek-harness` (read-only)

Scope: `docs/`, `examples/`, `BENCHMARK.md`, `AGENTS.md`/`CLAUDE.md`, `assets/`, plus the doc tooling and website projection that bind them. Sibling lanes cover architecture, build infra, `packages/`, `apps/`, and native+python.

---

## 1. Documentation architecture

### 1.1 Organization: a tiered "one home per fact" taxonomy

`docs/` is governed by `docs/AGENTS.md` ("The documentation standard", budget ≤1,250 words), which defines a tier taxonomy where every fact has exactly one home and everything else links there:

| Tier | Job |
|---|---|
| Root `AGENTS.md` | Standing orders an agent needs every session (1–3 lines each, linking its home) |
| Subtree `AGENTS.md` (`packages/`, `examples/`, `docs/`, `.agents/notes/`) | Subtree-specific orders |
| `docs/architecture.md` | Ordered map: composition, core packages, loop, seams, extension points; read before changing `packages/` |
| `docs/subsystems/` | One reference page per subsystem: type definitions, semantics, generated Cordis API (~50 pages) |
| `.agents/notes/` | Active decision records (the why, what was given up, required verification) |
| `docs/postmortem/` | Incident stories (only tier where war-story narrative belongs; 4 numbered postmortems + README) |
| `docs/cookbook/` | Step-by-step how-tos with numbered verify steps (8 guides) |
| `docs/user/` | Product-facing guides published to the website |
| Package README | Per-package contract: config, semantics, limitations, extension points, **Model Experience** |
| Generated references | `tool-catalog.md`, `config-catalog.md`, `persistence-catalog.md`, `module-graph.md`, `graph-atlas.md`, `cordis-api/`, example `composition.md` — regenerated from source, freshness-gated, never hand-edited |
| Skills (`.agents/skills/`) | Reusable workflows |

Placement rules are explicit: bugs → postmortems; rationale → Agent Notes; procedures → cookbooks; type definitions → subsystems; package contracts → READMEs; standing orders → root `AGENTS.md` with a rationale link. Tutorial vs. reference classification is mandatory for every doc; tutorials order concepts by prerequisite and difficulty.

Key contributor docs: `docs/development.md` (setup, TypeScript two-aggregate layout, Git integrations, CI, TODO markers, `ts type-equiv` mechanics), `docs/testing.md` (5 test tiers), `docs/architecture.md`, `docs/cordis-primer.md`, `docs/defensive-patterns.md`.

Word budgets are enforced by `scripts/doc-budgets.manifest.json` (`AGENTS.md` 1900, `docs/AGENTS.md` 1320, `docs/architecture.md` 2400, `examples/AGENTS.md` 310, `packages/README.md` 994, …) via `verify-doc-budgets`, with a relocate → condense → raise policy.

### 1.2 i18n strategy: bilingual sibling triplets with blob-hash consistency records

The distinctive strategy: **every in-scope document is a three-file sibling triplet** — English `foo.md`, Chinese `foo.zh.md`, and a consistency record `foo.i18n.yaml` — in the same directory. No locale directories, no separate translation repo.

- **Contract** (`docs/i18n/README.md`): both languages carry equal authority; either side may be the authored source. The `.i18n.yaml` records the git **blob hash** (not commit hash) of each side at last confirmed-consistent state, so consistency is a pure content comparison and out-of-sync pairs are repaired by minimal patching of the counterpart against the edited side's diff, never whole-file re-translation.
- **Rules** (`docs/i18n/translation-rules.md`): RFC 2119 levels; faithfulness (nothing added/dropped); structure preservation — heading depths, list kinds, table row/column counts, link targets, and **byte-identical fenced code blocks** must match one-to-one; typography rules for mixed CJK/Latin (half-width space, full-width punctuation) grounded in MDN/Kubernetes/Vue zh guides and W3C clreq; quality bar is "a bilingual engineer reading either file alone gets everything".
- **Terminology** (`docs/i18n/terminology.md`): a binding bilingual glossary table with per-term "first occurrence" annotation and a "不要译作" (do-not-translate-as) column; decides terms like `agent loop`（智能体循环）.
- **Gate** (`pnpm run verify-translation-pairing`, part of `doc-sync`): checks pair completeness, current blob hash == recorded, language switchers, structural signatures. `--write <pair>` re-records after confirmation (refuses bare `--write`); `--list` prints state without failing.
- **Git integration**: `.gitattributes` sets `*.i18n.yaml merge=dsh-translation-pairing`; a worktree-local merge driver (`scripts/merge-translation-pairing-driver.sh`, `scripts/merge-translation-pairing.ts`) composes a new record on clean text merges and **fails closed** otherwise; `resolve-translation-pairing-conflicts` stages safe records. Installed by `scripts/install-lefthook.mjs` at `pnpm install`; lefthook `pre-commit` verifies staged pairing records against staged owner blobs.
- **Scope**: root CONTRIBUTING, every non-vendor README, `.agents/notes/**`, `docs/**`, `python/**` (case-insensitive basename discovery). Exclusions in `scripts/translation-pairing.manifest.json`: `AGENTS.md` instruction files, `cordis-api/inherited.md` (generated, no zh counterpart), `terminology.md`, `style-samples.md`, `translation-prompt.md`. Frozen `.agents/notes/archived/` is sealed by its own verifier.
- **Scale**: 1,078 `.i18n.yaml` records and 936 `.zh.md` files repo-wide.
- **Division of labor**: routine agent work updates the counterpart directly in one terminology-guided pass (lightweight path, no subagent); the extended `dsh-translate-docs` skill is `disable-model-invocation: true` / `user-invocable: true` — never auto-selected. `pnpm run gen-translation-brief <pair>` assembles the minimal update units; `--apply` splices code-fence-only changes mechanically. Root `README.i18n.yaml`/`CONTRIBUTING.i18n.yaml` follow the same pattern.

### 1.3 Doc tooling: one aggregate gate plus a website as a tested projection

- **`pnpm run doc-sync`** runs ~26 leaf gates (`scripts/run-gates.ts` `docSyncLeafGates()`), each a small script with a label: `doc-typecheck` (compiles fenced ` ```ts ` blocks; ` ```ts type-equiv ` and ` ```ts public-api ` fences are verified against source by the TypeScript parser via `verify-type-equiv` and registered in `scripts/type-equiv.manifest.json`), generated-catalog freshness (`verify-{cordis,client,tool,config,persistence}-catalog`, `verify-doc-graphs`, `verify-scoped-events`), `verify-export-jsdoc`, `verify-md-wrap` (one physical line per paragraph), `verify-md-links` (relative paths + `#fragment` anchors), `verify-public-repository-links`, `verify-doc-refs` (docs citations in TS comments), `verify-package-paths`, `verify-config-source-ownership`, `verify-package-readme-model-experience`, `verify-package-readme-limitations`, `verify-mermaid`, `verify-agent-note-{classification,format}`, `verify-archived-agent-notes`, `verify-skill-invocation-metadata`, `verify-translation-{prompt,pairing}`, `verify-doc-budgets`, docs-site-projection tests, and a VitePress build that doubles as a dead-link check.
- **Website** (`website/`): VitePress 1.6.4 with `srcDir: .generated` (disposable, gitignored). `website/docs.ts` (524 lines) is the **canonical publication manifest**: a `DocsPage[]` allowlist mapping each canonical source → route for both locales (zh at root routes, en under `/en/`), with sidebar collection/section/order/outline metadata; `pairedPages()` derives the `.zh.md` sibling and content locales; `mirroredPages()` handles English-only fallback (e.g. `inherited.md`). `scripts/project-doc-site.ts` rewrites canonical Markdown into `.generated/` and rewrites links (manifest targets → site routes; other repo targets → GitHub source links; images copied; missing targets fail projection). `website/AGENTS.md` forbids any maintained Markdown under `website/` except itself. `docs:check` and `docs:dev` (watch-and-reproject) wrap the flow. Only the user-invoked `dsh-doc-site-sync` skill edits the manifest.
- **CI**: doc gates are scheduled per-lane in `.github/workflows/ci.yml` via `run-gates.ts`; `doc-typecheck` variants run against built output where fences need contracts (`doc-typecheck:contracts-ready`).

### 1.4 Content conventions worth noting

- Slop checklist in `docs/AGENTS.md` + `dsh-trim-cot-leakage` skill hunt reasoning-transcript leakage ("previously/now/no longer", PR citations in durable prose, spec-speak in implemented notes, status annotations, hand-restated catalogs).
- Every non-trivial change MUST include an Agent Note in the same PR; 1,372 notes across `proposed/implemented/rejected/archived` with path-encoded `{lifecycle}/{class}/yyyy-mm-dd-topic-title.md` and a uniform gated in-file format (`Status:` line + `## Problem` skeleton).
- Package READMEs end with a mandatory **Model Experience** section (What the model sees / Token effect / KV Cache effect) gated by `verify-package-readme-model-experience` — model-visible prose is treated as a contract.

## 2. Agent-context engineering (AGENTS.md / CLAUDE.md)

- **`CLAUDE.md` is a symlink to `AGENTS.md`** at root, `packages/`, `examples/` (and `.agents/notes/implemented/CLAUDE.md`) — one source of truth, no drift.
- Root `AGENTS.md` (149 lines; ≤1,900 words): pre-release stance ("foundation over blast radius" — rename/repackage freely, no compatibility shims); repository layout map; command reference; **host-sandbox-failure protocol** (retry with narrowest host escalation before diagnosing failure); "run relevant checks locally" (match evidence to surface, never default to the full suite); secrets policy; 25+ conventions (registrations are effects, model-visible ⟺ logged, plugins-not-loop-changes, capability seam = Service Definition/Provider/Consumer, no hardcoded tunables, branded ids, trust TypeScript at typed boundaries, empty catch names what it swallows, tests describe behavior not correctness, snapshot requirement for model-visible changes, PR labels `kind/*`+`area/*`, TODO/FIXME/XXX semantics, exactly one trailing newline); defensive patterns; type-safety rules (strict, `@param`/`@returns` enforced by `verify-export-jsdoc`, no metaphors, "contract" reserved for obligations).
- Subtree AGENTS.md files specialize: `docs/AGENTS.md` (doc standard, see §1), `examples/AGENTS.md` (e2e smoke requirements, config-comment rules), `website/AGENTS.md` (no content in the site tree), `.agents/notes/AGENTS.md` + `implemented/AGENTS.md` (note lifecycle discipline).
- **Skills as executable agent context**: 11 skills in `.agents/skills/` (dsh-doc-standards, dsh-prose-standard, dsh-translate-docs, dsh-doc-site-sync, dsh-archive-agent-notes, dsh-code-review, dsh-find-simplifications, dsh-merging-stacked-prs, dsh-pre-push-checks, dsh-trim-cot-leakage, record-browser-gif) with frontmatter `name`/`description` and invocation-metadata gating. The GUI-evidence skill (`record-browser-gif`) mandates a real-server, real-model GIF on every product-UI-visible PR.
- The i18n scope deliberately excludes AGENTS.md instruction files (English-only), and docs/AGENTS.md is the rare doc with an explicit word budget — agent-context is treated as a first-class, budgeted artifact.

## 3. examples/: usage patterns showcased

`examples/` is a workspace member and the module-resolution root for runnable/test Cordis configs (not a build target); `examples/package.json` declares every plugin package so plain Node resolves `exports → lib`; each leaf's private `package.json` is metadata only. Every example ships the bilingual README triplet plus e2e smokes (keyless Loader boot + with-key real-model).

| Example | Pattern showcased |
|---|---|
| `headless-agent/` | One-shot CLI agent (`pnpm dsh --profile headless "task"`); replay + real-model test composition; variants `advanced.cordis.yml`, `goal.cordis.yml`, `ralph.cordis.yml`, `retry.cordis.yml`, `compaction.cordis.yml`, `semantic-checkpoint.cordis.yml`, `e2b.cordis.yml` (E2B sandbox POC overlay swapping fs/subprocess providers); unexported JSONL test driver `tests/fixtures/headless-driver.ts` |
| `jsonrpc-agent/` | **The benchmark-relevant composition**: unattended coding agent over Python SDK JSON-RPC; no terminal UI on stdout; tools = persistent `bash` + `str_replace_editor` (+ `subagent`, `todo_write` in the full variant); `minimal.cordis.yml` = standalone benchmark/headless variant with `DSH_*` env config, `danger-full-access`, uncompressed JSONL, no compaction; `minimal.py` is the SDK entry |
| `acp-agent/` | Agent Client Protocol automation server over JSON-RPC stdio; per-session workspaces + permissions, one-shot approval policy, repeat guard; ~40 scenario `cordis*.yml` files (fs, pty, code-mode, image, subagent, retry, web…) each with a pinned `.cordis.snapshot.yml` twin |
| `web-cordis/` | Self-referential agent: inspects and mounts/unmounts model-authored plugins in-memory (`@deepseek-ai/dsh-tool-cordis`); `pnpm run demo:cordis` |
| `web-schedule/` | Opt-in overlay (`dsh web --patch examples/web-schedule/cordis.yml`) adding durable session-local reminders; precise delivery/recovery boundary semantics in README |
| `mcp-memory/` | Three default-off reference overlays bridging third-party memory servers (Memorix, MCP Reference Memory, Engram) through the generic MCP client, with pinned versions and an explicit non-endorsement disclaimer |

Recurring mechanics: **overlay composition** (`--patch` rows), `cordis.yml` comments restricted to non-obvious wiring/security/replay facts, generated `composition.md` mermaid diagrams (from `gen-doc-graphs.ts`, "do not edit by hand"), and a **snapshot harness** — scripted model streams (`tests/snapshots/*/replay.override.json`) replayed against the real composition with deterministic normalizers (`normalizeSessionLog`, `scrubRequestHeaders`, `tokenizeSessionFixtureCwd`, `stabilizeRefreshLog`) diffing against `result.expected.json`; with-key e2e asserts external state, never the model's self-report.

## 4. BENCHMARK.md: current state

- **Content**: 3 lines total (added 2026-08-11, commit `d5cab00e4e` "docs: add benchmark SDK entry point"; reworded in `04fe477e7e`): point to the Python SDK guide and run the `jsonrpc-agent` minimal variant with separate workspaces/session IDs for independent tasks.
- **De-facto benchmark path** (`docs/user/guide/python-sdk.md`): install `deepseek-harness-sdk`, run `python examples/jsonrpc-agent/minimal.py --workspace … --session-root … --session-id <id> "task"`; isolated workspace + fresh session ID per task; JSONL session log records assembled requests and tool calls (a raw transcript artifact); `DeepSeekHarness` reuses a bundled runtime lazily per process.
- **What exists but is not wired to BENCHMARK.md**:
  - *Reproducibility infrastructure*: keyless snapshot replay of the real compositions (scripted model responses + session fixtures + expected outputs, `DSH_SNAPSHOT=replay`); deterministic normalizers; `pnpm run test:snapshot` / `test:snapshot:record`.
  - *Cost/limit knobs*: `maxTokensAsSuccess` (`true` default in the full JSON-RPC variant — token-limited turns count as accepted evaluation results; `false` in `minimal.cordis.yml`), `DSH_MAX_TOKENS`/`max_tokens` (49,152 in the SDK example), `DSH_CONTEXT_WINDOW`.
  - *Isolation semantics*: fresh session id = independent task; reuse = continue conversation + persistent shell state.
- **What is absent**: no benchmark directory, no task suite, no methodology doc, no metrics (pass rate, cost, tokens, wall time), no harness code, no scoring, no leaderboard, no Agent Note proposing one (no `proposed/` note mentions a benchmark). BENCHMARK.md is a pointer, not a methodology.

## 5. Practices worth adopting

**Documentation**
1. Tiered "one home per fact" taxonomy with per-doc word budgets enforced by a manifest gate — prevents both duplication and runaway docs (`docs/AGENTS.md`, `scripts/doc-budgets.manifest.json`).
2. Bilingual sibling triplets with blob-hash consistency records + a fail-closed Git merge driver — a pragmatic, reviewer-owned i18n contract that survives merges (`docs/i18n/README.md`, `.gitattributes`).
3. Generated catalogs + freshness gates; never hand-edit generated references (`tool-catalog.md`, `composition.md` diagrams).
4. Machine-checkable everything: relative links with fragment verification, compilable fenced code blocks, source-equivalence pastes (`ts type-equiv`), one-physical-line-per-paragraph, mermaid validation.
5. Slop checklist + anti-reasoning-transcript-leakage skill as an explicit audit pass (`dsh-trim-cot-leakage`).
6. Agent Notes as the decision-record layer with lifecycle, uniform gated format, and archive freeze.
7. Website as a *tested projection* from repository Markdown: single explicit allowlist manifest, link rewriting, disposable generated tree, build = dead-link gate.
8. `CLAUDE.md` symlinked to `AGENTS.md`; skills with invocation metadata; AGENTS.md files kept English-only and word-budgeted.

**Benchmark-relevant**
9. Keyless snapshot replay of the *real* assembled composition (not mocks) as the deterministic, CI-able regression layer; with-key e2e that verifies external world state, not model self-report.
10. Per-task isolation contract (fresh session ID, isolated workspace, JSONL transcript output) as the baseline for any future evaluation harness.
11. Explicit cost/limit semantics (`maxTokensAsSuccess`, `max_tokens`, context window) already available as evaluation knobs.

## 6. Unresolved questions

1. **Benchmark scope**: BENCHMARK.md has no methodology, metrics, harness, or task suite. Is a real evaluation harness planned (task corpus, scoring, cost tracking, leaderboard)? No `proposed/` Agent Note exists — is this intentionally deferred to the Python SDK side, or a gap?
2. **maxTokensAsSuccess divergence**: the full `jsonrpc-agent/cordis.yml` defaults it to `true` (token-limited turns are accepted results) while `minimal.cordis.yml` sets `false`. Which semantic should a benchmark adopt for a fair pass/fail?
3. **Reproducibility tie-in**: the snapshot/replay infrastructure and normalizers are currently framed as *testing*, not *benchmarking*. Would a benchmark mode reuse `DSH_SNAPSHOT=replay`-style fixtures, or is live-model scoring the only intended path?
4. **i18n scalability**: 1,078 pairing records with a reviewer-owned quality half of the contract — does the pairing gate stay tractable as the corpus grows, and are there plans to relax "equal authority" for high-churn generated catalogs?
5. **Website projection gap**: `docs/user/` pages are projected, but BENCHMARK.md, postmortems, testing guides, and AGENTS.md are deliberately unpublished (`dsh-doc-site-sync`). Is a public benchmark page intended once a methodology exists?
6. **assets/**: only 3 community QR/promo images — no diagram assets, no architecture figures. Are diagrams intentionally kept as inline mermaid only?
