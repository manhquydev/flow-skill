# flow xia-upgrade — data-driven decision report (2026-06-15)

**Question:** Which 2025–26 trending tech/repos are worth `xia`-porting into the `flow` skill —
and which are market FOMO? Decision-grade, philosophy-anchored, no rushed integration.

**Method:** 4 parallel `researcher` agents (spec-driven dev · agent orchestration · agent memory ·
coding-agent harnesses & eval). Each candidate scored by the synthesizer (not by averaging agent
verdicts) on a fixed rubric tied to flow's design laws.

> **Data-confidence caveat (read first).** Adoption numbers (GitHub stars, funding, release dates,
> "X% uptime/catch-rate") are researcher-fetched and **NOT independently verified** by the synthesizer
> (model cutoff predates some 2026 claims). Several look embellished. **Recommendations are weighted on
> transferable mechanism + portability fit — things derivable from flow's known architecture — NOT on
> popularity metrics.** This is deliberate: judging on stars is exactly the FOMO we're avoiding.

## Scoring rubric (0–5 each; weighted → /5)
| Criterion | Weight | Rationale (flow law) |
|---|---|---|
| Philosophy fit + portability | 0.30 | Pure bash + optional python, no heavy deps, graceful degrade, two-layer gate |
| Measurable quality lift | 0.25 | Fewer escaped defects / hollow gates / drift (operator-chosen criterion) |
| Novelty (inverse overlap) | 0.20 | flow already absorbed ACE/Reflexion/AGENTS.md/Spec-Kit-/analyze — penalize re-ports |
| Low maintenance & complexity | 0.15 | LOC, deps, schema, test surface added |
| Token / runtime efficiency | 0.10 | Favor deterministic mechanical checks over more LLM calls |

**Thresholds:** ≥4.0 PORT-NOW · 3.0–3.9 PLAN · 2.0–2.9 WATCH · <2.0 SKIP(FOMO).

---

## Master decision matrix (scored by synthesizer)

| # | Candidate (source) | Phil/Port .30 | Quality .25 | Novelty .20 | LowMaint .15 | Token .10 | **Score** | Verdict |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--|
| 1 | **Project `/constitution`** — operator-authored per-project law enforced at gates (Spec Kit) | 5 | 4 | 4 | 4 | 4 | **4.3** | **PORT-NOW** |
| 2 | **Gate self-eval harness** — inject known-bad artifacts, measure gate catch-rate (OpenHands + SWE-bench method) | 4 | 5 | 5 | 3 | 3 | **4.2** | **PORT-NOW** |
| 3 | **Usage-weighted consolidation** — `accessed_count` + prune (Cognee *memify* idea) | 5 | 3 | 3 | 5 | 4 | **4.0** | **PORT-NOW (small)** |
| 4 | **Settings.json law-enforcement hooks** — e.g. block editing `_templates/` mid-run (Claude/OpenAI hooks idea) | 4 | 3 | 4 | 4 | 5 | **3.85** | **PLAN** |
| 5 | **Temporal validity windows** — `valid_from/valid_until/superseded_by` (Zep/Graphiti idea) | 5 | 2 | 3 | 5 | 4 | **3.75** | **WATCH** |
| 6 | **Durable crash-resume for `/flow auto`** — sqlite step-journal + replay (Temporal/Restate *concept*) | 4 | 3 | 4 | 3 | 3 | **3.5** | **PLAN** |
| 7 | **`/clarify` de-risking interview** — bounded ambiguity pass before a spec gate (Spec Kit) | 4 | 3 | 3 | 4 | 3 | **3.45** | **PLAN** |
| 8 | **Aider repo-map** — tree-sitter PageRank symbol ranking for `assess`/scope | 4 | 3 | 3 | 3 | 4 | **3.4** | **PLAN** (already on flow backlog) |
| 9 | **Langfuse LLM-as-judge confidence** — 0–1 multi-judge score replacing binary gate | 3 | 4 | 3 | 3 | 2 | **3.1** | **WATCH** (token cost vs determinism) |
| 10 | **OpenSpec delta-specs** — proposal-first partial-artifact validation | 3 | 3 | 3 | 3 | 3 | **3.0** | **WATCH** |
| 11 | **Kiro steering files / hooks** — declarative per-agent rules (AWS, IDE-locked) | 2 | 3 | 2 | 2 | 3 | **2.4** | **SKIP** (portability fail) |
| 12 | **BMAD personas** — 12+ specialized roles as gate sub-stages | 2 | 3 | 1 | 3 | 1 | **2.05** | **SKIP** (flow already *detects* bmad-*; persona fan-out = token multiplier) |
| 13 | **Tessl spec registry** — upstream pre-built spec tiles, MCP-native | 2 | 2 | 3 | 2 | 3 | **2.35** | **SKIP** (VC lock-in, registry-disappears risk) |
| 14 | **Temporal/Restate infra** — managed durable-execution engine | 1 | 4 | 3 | 1 | 2 | **2.15** | **SKIP** (K8s/SaaS = portability fail; port the *concept* → row 6) |
| 15 | **Mem0 / Letta / Cognee / Zep (full systems)** — vector-DB/graph/server memory layers | 1 | 3 | 2 | 1 | 1 | **1.6** | **SKIP(FOMO)** (vector DB/embeddings/server; flow's SQLite+ACE already wins on determinism+portability) |
| 16 | **GSD context-rot orchestrator** — atomic-plan-in-fresh-context | 2 | 2 | 2 | 1 | 3 | **2.0** | **SKIP** (solves orchestration, not gating — wrong problem) |
| 17 | **JWT capability-delegation tokens** — signed subagent permission scopes | 2 | 2 | 3 | 2 | 3 | **2.35** | **SKIP** (over-engineering; subagents are same trust domain) |
| 18 | **CrewAI / MS Agent Framework / Braintrust / Honcho / intent-driven.dev** | 1–2 | 1–3 | 1–2 | 1–2 | 1–2 | **<2.4** | **SKIP** (domain mismatch / vendor lock-in / cloud / methodology-not-tool) |

---

## PORT-NOW — the 3 that earn their keep (gain vs loss)

### 1. Project `/constitution` (score 4.3)
- **The idea:** an operator-authored, per-project `flow/constitution.md` of non-negotiable principles
  (e.g. *"no uncontracted API surface"*, *"all PII facility-scoped"* — exactly the CMC Odoo class of rule),
  loaded at init and **checked at every gate**: mechanical (grep for the declared invariants' markers) +
  semantic (Claude challenges each artifact against the principles).
- **Gain:** catches *whole-project* violations today's per-stage gates miss; turns recurring operator
  rules into enforced law. Measurable = # constitution violations caught pre-merge.
- **Loss/cost:** 1 template + ~80–120 LOC in `flow.sh` + one `gate-rules.md` section + a `recall` hook. Low.
- **Why not FOMO:** this *is* flow's two-layer-gate DNA applied one level up. flow already adapted Spec Kit's
  `/analyze`; `/constitution` is the sibling it hasn't taken. **Distinct from flow's fixed `law/*.md`** (those
  are skill-level, immutable; this is project-level, operator-authored).

### 2. Gate self-eval harness (score 4.2)
- **The idea:** a dev-time corpus of known-good and known-hollow artifacts (fabricated competitor quote,
  grade-laundered C→B, uncontracted endpoint, drift). Run the gates over it and **measure catch-rate +
  false-positive rate.** A regression test for flow's own gatekeeping.
- **Gain:** flow's single biggest blind spot — **the gates have never been measured.** This is the literal
  "measurable quality lift" criterion you chose. Lets every future gate change be proven, not vibes.
- **Loss/cost:** fixture corpus to build + maintain, ~150–250 LOC runner. Medium. Runs at dev-time (CI),
  not in operator runs — so no token cost to end users.
- **Why not FOMO:** ground-truth-by-construction; offline; no cloud. SWE-bench/OpenHands supply the
  *methodology* (all-or-nothing grading, reproducible fixtures), not their infra.

### 3. Usage-weighted consolidation (score 4.0, small)
- **The idea:** add `accessed_count` to harness `decision`/`trace`; `recall` increments on read; curator
  prunes/deprioritizes never-recalled items. Complements existing ≥2-count consolidation with a *usage* signal.
- **Gain:** memory hygiene — recall surfaces what's actually reused, not just what occurred twice. Cheap.
- **Loss/cost:** 1 SQL column + a few lines in curator + recall. Trivial.
- **Why not FOMO:** the *idea* from Cognee's memify, implemented in flow's existing SQLite — **zero new deps.**
  We reject the whole Cognee/Mem0/Zep system (vector DB), keep the one transferable signal.

## PLAN — worth a phase when we pick this up later
- **#6 Durable crash-resume for `/flow auto`** — real gap, but **honestly downgraded**: per-card worktrees
  already bound blast radius (a crash loses ≤1 card; re-running is cheap). Build only if auto-runs get long
  enough that replay beats re-run. Ignore the researcher's unverified "70%→99% uptime" framing.
- **#7 `/clarify` interview** — marginal over flow's existing semantic gate + `mode work` interview; nice
  first-pass-rate boost, adds conversation turns. Optional.
- **#8 Aider repo-map** — **already on flow's backlog** ("tree-sitter dep-graph in assess"); Aider is the
  reference implementation to copy (ranked symbols, graceful degrade to globs).
- **#4 Settings.json hooks** — small, real, but **Claude-Code-only** (Codex tier wouldn't get it) → limited.

## SKIP — the FOMO traps (and *why*, so the decision is reusable)
1. **Full memory systems (Mem0/Letta/Zep/Cognee)** — all need a vector DB, embedding API, graph DB, or
   server. flow's local SQLite + ACE + deterministic count-consolidation already beats them **on flow's
   axes** (portable, deterministic, 0ms, verifiable). Vendor benchmark wins (LongMemEval/LoCoMo) are for
   *long conversational* memory; flow's memory is *task-scoped*. Take 1 idea each (rows 3,5), skip the systems.
2. **Temporal/Restate, CrewAI, MS Agent Framework** — heavyweight runtimes / cloud / vendor lock-in. Port the
   *journal concept* (row 6) if ever needed; never the infra.
3. **Kiro steering, Tessl registry, GSD, BMAD personas, intent-driven.dev, JWT tokens** — IDE-lock,
   VC-lock, wrong-problem, cost-multiplier, methodology-not-tool, and over-engineering respectively.
4. **LLM-as-judge replacing mechanical gates** — inverts flow's "deterministic mechanical first, semantic
   second" law and adds per-run token cost. Keep mechanical as ground truth.

## Bottom line
- **Real, philosophy-aligned upgrades that are NOT yet in flow:** project `/constitution` and a
  **gate self-eval harness**. Both extend flow's existing DNA; neither adds a dependency. These are the
  two worth a real `/flow` build when you choose to act.
- **Everything memory-layer is mostly FOMO for flow** — it already absorbed the 2025–26 memory science;
  the trending products mainly add infra flow deliberately avoids. Harvest 2 tiny SQLite ideas, skip the rest.
- **No action taken this session** (research-only, per operator). When ready, the PORT-NOW + PLAN rows map
  cleanly onto a `/flow` plan with their own cards.

## Source reports
- `research/researcher-01-spec-driven-dev-tools.md`
- `research/researcher-02-agent-orchestration-frameworks.md`
- `research/researcher-03-agent-memory-systems.md`
- `research/researcher-04-coding-agent-harnesses-eval.md`
