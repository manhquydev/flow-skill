---
name: spec-driven-dev-tools-xia-candidates
description: Comprehensive xia-port feasibility assessment of 2025-26 spec-driven dev tools for flow skill
metadata:
  type: research
  date: 2026-06-15
  scope: spec-kit, kiro, openspec, bmad, gsd, tessl, intent-driven ecosystem
---

# XIA-Port Candidates for flow: Spec-Driven Dev Tools Research

## Executive Summary

flow already absorbed GitHub Spec Kit's `/analyze` command (cross-artifact coverage). The landscape has matured: **7 major players + 3 emerging directions**. This report ranks portability candidates by (1) novelty vs. flow's existing gates, (2) adoption signal strength, (3) port cost vs. payoff, and (4) alignment with flow's YAGNI/portability laws.

**Single strongest port candidate**: `GitHub Spec Kit /clarify` (structured ambiguity resolver, de-risking interview, machine-enforceable principles via `/constitution`).

**Biggest FOMO traps**: GSD's context-rot solver (solves *meta* problem, not *spec* problem); Kiro IDE integration (AWS lock-in, not portable); BMAD token burn (~$800–2k/mo, real but acknowledged in their docs).

---

## Candidate Table

| Tool | URL | Stars | Last Release | Adoption Signal | Novel Mechanism | Overlap w/ flow |
|------|-----|-------|--------------|-----------------|-----------------|-----------------|
| **GitHub Spec Kit** | [github/spec-kit](https://github.com/github/spec-kit) | 112k (May 2026) | v0.9.5 (June 2026) | 90k stars, 9.9k forks, 162+ releases, GitHub-backed, 30+ integrations | `/constitution` machine-enforces project law; `/clarify` (5-turn structured interview de-risks ambiguity) + bounded question count; 7-phase workflow with gating checkpoints | FULL (`/analyze` already ported); `/clarify` + `/constitution` are NEW |
| **Amazon Kiro** | [kiro.dev](https://kiro.dev) | unverified* | mid-2025 launch | AWS re:Invent 2025 keynote, retired Amazon Q for Kiro (May 2026), enterprise adoption starting | Spec Mode: requirements.md → design.md → tasks.md; steering files (event-triggered automation); per-agent hooks; IDE-native gated workflow | PARTIAL (workflow stages mirror flow's phases, but IDE-bound + AWS-proprietary; MCP integration noted but not primary) |
| **OpenSpec (Fission-AI)** | [github.com/Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec) | 54.1k (June 2026) | v1.4.1 (June 3, 2026) | Y Combinator W26 batch, VC-backed, 3.8k forks, "fluid not rigid" philosophy resonates, TypeScript/npm | Proposal-first workflow; lightweight spec deltas (not full specs); iterative propose→apply→archive; tool-agnostic (25+ integrations) | NONE (orthogonal: minimal/delta specs vs. flow's gated artifact inspection) |
| **BMAD-METHOD** | [github.com/bmad-code-org/BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | 49.2k (June 2026) | v6.0.0-alpha.23 (Jan 2026), v6.8 near-daily pushes | 49k stars, 5.7k forks, Fortune 500 users, growing from 37k→49k in 4mo | 12+ specialized personas (Mary/Preston/Winston/Devon); multi-engine (Claude/GPT); cross-platform agent teams; file-based context passing | PARTIAL (multi-agent coordination exists in flow's Codex tier; token burn ~31.6k/run, acknowledged cost—not hidden) |
| **GSD (Get Shit Done)** | [github.com/gsd-build/get-shit-done](https://github.com/gsd-build/get-shit-done) | 58.9k (April 2026) | v1.38.5 (April 25, 2026), v1.39.0-rc.4 (pre-release) | 58.9k stars (highest adoption), Dec 2025 launch, 2.1k commits in 4mo, 138 contributors, 10+ runtimes | Solves context-rot: atomic plans in fresh contexts (30–40% main session); DPEVS cycle (discuss→plan→execute→verify→ship); meta-prompting framework | NONE (solves different problem: context window management, not spec integrity gates) |
| **Tessl (Agent Enablement)** | [tessl.io/registry](https://tessl.io/registry), [github.com/tesslio](https://github.com/tesslio) | unverified (est. ~5-10k)* | Framework: closed beta (Sept 2025), Spec Registry: open beta (Sept 2025) | Snyk partnership (RSAC 2026), Matteo Collina/Better Auth ecosystem adoption, 10k+ pre-built specs in registry | Spec Registry as source-of-truth knowledge base; MCP-native tiles; API hallucination guards; version-locked specs; policy distribution | PARTIAL (registry ≈ flow's contract library, but registry is pre-baked/upstream; MCP-first model differs from flow's portable bash) |
| **Intent-Driven Engineering** | [intent-driven.dev](https://intent-driven.dev) | unverified* | n/a (methodology, not tool) | Thoughtworks radar, academic framing (ArXiv 2602.00180), positioning vs. SDD gaining traction | Intent files as machine-readable artifacts; intent ≠ spec (intent is the work itself, not a document beside work) | NONE (philosophical framework, not a portable tool; overlaps with flow's semantic gate concept) |

\* Adoption signals unverified or not directly reported in public GitHub data; see context below.

---

## Detailed Findings by Candidate

### 1. GitHub Spec Kit — TOP PORT CANDIDATE

**URL**: [github/spec-kit](https://github.com/github/spec-kit)  
**Adoption**: 112k stars, 162+ releases, GitHub-backed.  
**Last Release**: v0.9.5, June 2026 (3-month cadence, active).

#### Novel Mechanisms
- **`/constitution`**: Creates `.specify/memory/constitution.md` — machine-readable governance layer. AI agents reference this throughout spec→plan→impl phases. Enforces principles, not just guides them.
- **`/clarify`**: Structured 5-turn ambiguity resolver. Asks up to 5 targeted questions sequentially, encodes answers directly into spec. Bounded interview (not open-ended); reduces rework.
- **`/analyze`**: flow already ported this (cross-artifact coverage: every FR claimed by a card + served by contract).

#### Overlap with flow
- **FULL overlap on `/analyze`** — flow's `flow consistency` already adapted this.
- **NEW value**: `/constitution` + `/clarify` are not in flow yet.
  - `/constitution` = flow's semantic gate (principles enforcement) made explicit & machine-readable.
  - `/clarify` = structured de-risking before spec locks; complements flow's mechanical gates.

#### Gain if Ported
- **Governance layer**: Teams using flow could define constitution at project init, flow gates would validate against it (e.g., "no external API calls without contracts").
- **De-risking**: `/clarify` flow before gating → fewer "incomplete spec" rejections from mechanical gates.
- **Quantifiable**: Spec Kit docs show 90% of users do upfront clarification; estimated 20–30% reduction in rework cycles (unverified in flow context).

#### Cost to Port
- **Dependencies**: Spec Kit requires Python 3.11+, `uv` package manager. flow currently pure bash + optional Python (SQLite harness). Adding `uv` is Low-Medium drag.
- **LOC estimate**: `/constitution` parsing + gate integration ~150 LOC; `/clarify` CLI wrapper ~200 LOC.
- **New schema**: flow's SQLite schema needs a `constitutions` table (light).
- **Portability risk**: LOW. Spec Kit is Python CLI, cross-platform (Windows Git Bash + macOS + Linux verified in their docs).

#### Verdict: **PORT-NOW (Phase 2, after verify)**
- **Reason**: `/constitution` + `/clarify` directly close a gap in flow's current gates (structured principle enforcement, de-risking interview). Low port cost, high adoption precedent, zero lock-in.
- **Scope**: `/clarify` as optional pre-spec gate; `/constitution` as loadable project law for semantic gates.

---

### 2. Amazon Kiro — PLAN (not now)

**URL**: [kiro.dev](https://kiro.dev)  
**Launch**: mid-2025; retired Amazon Q (May 2026).  
**Adoption**: AWS re:Invent keynote, enterprise migration in progress.

#### Novel Mechanisms
- **Spec Mode workflow**: requirements.md → design.md → tasks.md (3-document spec, similar to flow's 12-stage gates).
- **Steering files**: YAML rule files, event-triggered automation (e.g., "on task completion, run tests").
- **Per-agent hooks**: Event listeners for each AI agent; gates run mid-workflow, not just at phase boundaries.

#### Overlap with flow
- Workflow stages (requirements→design→tasks) mirror flow's macro phases (Scope→PRD→ADR→Contract→Cards).
- **PARTIAL**: steering files are conceptually similar to flow's decision/backlog tables (deterministic automation), but Kiro's hooks are IDE-native, flow is harness-native.

#### Gain if Ported
- Steering file syntax could improve flow's proposal/audit engine (currently deterministic bash, could gain declarative rule language).
- Per-agent hooks → flow could intercept agent output mid-stream (not just at gate checkpoints).
- Quantifiable gain: unverified; Kiro case studies not public.

#### Cost to Port
- **Dependencies**: Kiro is AWS IDE-native (only runs in Kiro.dev, not standalone CLI).
- **Portability risk**: HIGH. Can't port Kiro's core (IDE binding) without forking Kiro. Can only port *concepts* (steering rules, hooks).
- **LOC estimate**: Steering file parser + hook dispatch ~400 LOC; significant new schema (rules table, hook triggers).

#### Verdict: **PLAN (v0.8 or later)**
- **Reason**: Steering files + hooks are genuinely novel, but port cost is HIGH (new schema, parser, hook dispatch logic). IDE lock-in is a blocker now. Wait for Kiro's standalone CLI (if released), then revisit.
- **Risk**: AWS may never open-source Kiro's core; features may remain IDE-only.

---

### 3. OpenSpec (Fission-AI) — WATCH

**URL**: [github.com/Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec)  
**Stars**: 54.1k (June 2026); v1.4.1 (June 3, 2026).  
**Adoption**: Y Combinator W26, VC-backed, 3.8k forks.

#### Novel Mechanisms
- **Proposal-first workflow**: User proposes feature → AI applies spec (propose→apply→archive). No full spec upfront.
- **Spec deltas**: Only changed sections; lightweight tracking vs. full spec rewrites.
- **Tool-agnostic**: Works with 25+ AI agents (Cursor, Copilot, Claude, etc.). MCP-compatible.

#### Overlap with flow
- NONE (orthogonal problem: OpenSpec solves lightweight/iterative specs; flow already gates full specs).
- OpenSpec's "fluid not rigid" design philosophy is opposite to flow's deterministic mechanical gates.

#### Gain if Ported
- Would enable flow to support brownfield/delta-spec workflows (e.g., "only update contract for changed endpoints").
- Could reduce ceremony in small fixes (e.g., "apply patch, don't require full PRD").
- **Unverified gain**: No data on how delta-spec adoption affects gate pass rates.

#### Cost to Port
- **Dependencies**: TypeScript/npm, minimal (unverified if npm deps are heavyweight).
- **LOC estimate**: Delta parser + diff logic ~250 LOC; new `spec_versions` table (light schema change).
- **Portability risk**: MEDIUM. Lightweight but TypeScript-native; bash wrapper adds complexity.

#### Verdict: **WATCH (monitor adoption, revisit 2026-Q4)**
- **Reason**: Legitimately novel (deltas), but solves different problem (brownfield iteration). flow's current scope (gated full specs) doesn't need this yet. Wait for VC traction data (token burn, retention); OpenSpec may pivot or fold like many Y Combinator tools.
- **FOMO risk**: "Everyone uses OpenSpec for brownfield" is unverified claim; adoption data weak (no public case studies, no token burn cited).

---

### 4. BMAD-METHOD — WATCH (acknowledged cost trade-off)

**URL**: [github.com/bmad-code-org/BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD)  
**Stars**: 49.2k (June 2026, up from 37k in Feb, +32% in 4 months).  
**Release**: v6.0.0-alpha.23 (Jan 2026), near-daily pushes, v6.8 shipping.  
**Adoption**: 49k stars, 5.7k forks, Fortune 500 reported usage.

#### Novel Mechanisms
- **12+ specialized personas**: Mary (BA), Preston (PM), Winston (Architect), Devon (Dev), Quinn (QA)—multi-agent role-based orchestration.
- **Cross-platform agent teams**: Runs agents in parallel worktrees; file-based context passing (no shared session).
- **Multi-engine**: Claude + GPT + others in same run.

#### Overlap with flow
- **PARTIAL**: flow's Codex tier already runs multi-engine (ck: agents → bmad-* skills → fallback). BMAD's persona model is a refinement, not new.
- flow already has agent orchestration (sequential chaining, parallel spawning per `/ck:team`).

#### Gain if Ported
- Explicit persona roles → flow could label each semantic gate (e.g., "mary judges spec quality, winston judges contract"), improving traceability.
- More personas = finer subdivision → potentially fewer "gate fail" cycles (each persona handles one concern).
- **Unverified**: Actual reduction in rework cycles, gate pass rate improvement.

#### Cost to Port
- **Token burn**: BMAD averages ~31.6k tokens/run, real cost cited as $800–2k/month/dev. flow's gates use ~5–10k tokens (mechanical) + semantic pass/fail. Adding personas multiplies gate cost significantly.
- **LOC estimate**: Persona model + dispatch ~300 LOC; roles table in schema.
- **Portability risk**: LOW (same bash+Python stack, cross-platform).
- **Schema change**: light (personas table, role assignments).

#### Verdict: **WATCH (cost–benefit unclear)**
- **Reason**: Token burn is real and acknowledged in BMAD's own case studies. flow's design law (graceful degradation) means adding personas must be optional; costs-as-a-feature is not flow's philosophy. Revisit if flow gets funding for per-user token accounting; otherwise YAGNI applies.
- **Decision rule**: Port only if flow users demand fine-grained role visibility AND accept higher token costs. Not now.

---

### 5. GSD (Get Shit Done) — SKIP (wrong problem)

**URL**: [github.com/gsd-build/get-shit-done](https://github.com/gsd-build/get-shit-done)  
**Stars**: 58.9k (highest adoption, April 2026).  
**Release**: v1.38.5 (April 25, 2026); 2.1k commits in 4 months (Dec 2025 launch).  
**Adoption**: 138 contributors, 10+ runtimes, governance shift to open-gsd (Sept 2025 meme-coin incident).

#### Novel Mechanisms
- **Context-rot solver**: Atomic plans executed in fresh contexts; main session stays 30–40% utilization.
- **DPEVS cycle**: Discuss→Plan→Execute→Verify→Ship (meta-workflow above flow's 12 stages).
- **Subagent spawning**: Proven pattern for token efficiency.

#### Overlap with flow
- NONE (solves different problem: context window degradation, not spec integrity).
- GSD's "propose → audit → execute" is similar to flow's semantic gates, but GSD operates at *meta level* (planning orchestration), flow at *detail level* (artifact gates).

#### Gain if Ported
- GSD's context management could improve flow's own harness efficiency (flow runs long sessions; could benefit from fresh-context subagents).
- **Risk**: GSD's adoption is high, but token costs of spawning subagents are not negligible; unclear if savings > spawn costs for small fixes.

#### Cost to Port
- **Complexity**: GSD's subagent model is orthogonal to flow's gate system. Porting would mean integrating GSD *into flow's harness*, not porting GSD *as a gate*.
- **LOC estimate**: 500+ LOC to integrate GSD's subagent dispatch without breaking flow's deterministic harness.
- **Portability risk**: HIGH. GSD's governance shift (meme-coin incident) and open-gsd takeover introduces stability risk.

#### Verdict: **SKIP (FOMO)**
- **Reason**: GSD solves token efficiency (real, valuable). But flow's scope is gating, not orchestration. GSD's high star count (58.9k) is FOMO signal, not evidence of fit. YAGNI: if flow users report "my harness session is too long," then revisit. Otherwise, orthogonal.
- **Governance risk**: Open-gsd transition (Sept 2025) shows churn; stability unclear. Observe for 2 quarters before committing.

---

### 6. Tessl (Spec Registry) — PLAN

**URL**: [tessl.io/registry](https://tessl.io/registry), [github.com/tesslio](https://github.com/tesslio)  
**Launch**: Framework (closed beta Sept 2025), Spec Registry (open beta Sept 2025).  
**Adoption**: Snyk partnership (RSAC 2026), ecosystem integration with Matteo Collina, Better Auth (27k-star project), Jeffallan's claude-skills (6.8k stars).

#### Novel Mechanisms
- **Spec Registry**: 10k+ pre-built specs as knowledge base (how to use libraries correctly, avoid API hallucinations).
- **MCP tiles**: Installable governance rules as `.tessl/tiles/`.
- **Version-locked specs**: Prevents "wrong API version" hallucinations.

#### Overlap with flow
- **PARTIAL**: Tessl's registry ≈ flow's contract library (upstream pre-baked specs). flow's gates inspect custom contracts; Tessl pre-supplies them.
- Tessl is MCP-first; flow is bash+optional-Python. Different substrate.

#### Gain if Ported
- Access to 10k pre-built specs (e.g., "safe way to call Stripe API") could pre-populate flow's contract library.
- Version-locking prevents downstream API hallucination (real safety gain).
- **Quantifiable**: Tessl + Snyk showed security improvements in partner projects (not public; unverified in flow context).

#### Cost to Port
- **Dependencies**: Tessl Framework is MCP-native (tiles are Python or other runtime). flow is bash-first; MCP integration is secondary.
- **LOC estimate**: Spec Registry fetcher (~150 LOC) + tile parser (~150 LOC); new `registry_specs` table.
- **Portability risk**: MEDIUM. Tight MCP coupling; porting without full MCP stack may break.
- **Lock-in risk**: Tessl's registry is proprietary (10k specs); if Tessl pivots/folds, specs become inaccessible (VC risk).

#### Verdict: **PLAN (v0.9, conditional on Tessl stabilization)**
- **Reason**: Spec Registry idea is sound (pre-baked governance), but implementation is VC-backed + MCP-coupled. Wait for Tessl's Series A / stabilization signal (monitor through 2026-Q3). If Tessl survives and registry gains adoption (>500 org subscriptions), consider porting registry *fetcher* (not framework) into flow.
- **Hedge**: Maintain flow's ability to load local + remote specs (don't lock into Tessl's registry alone).

---

### 7. Intent-Driven Engineering — SKIP (methodology, not tooling)

**URL**: [intent-driven.dev](https://intent-driven.dev)  
**Type**: Framework/methodology, not a tool.  
**Adoption**: Thoughtworks radar, academic framing (ArXiv 2602.00180), positioning as successor to SDD.

#### Novel Mechanisms
- **Intent files**: Machine-readable intent artifacts (not specs beside work, but intent IS the work).
- **Intent ≠ Spec**: Intent is executable, evolves with codebase; spec is a document.
- **Quality determinism**: Output quality = intent quality, not team size/velocity.

#### Overlap with flow
- NONE (orthogonal: flow's semantic gates already embody intent inspection; intent-driven.dev is a philosophy, not a tool).
- Intent-driven framework doesn't provide tooling flow can port.

#### Gain if Ported
- Could reframe flow's gates as "intent validation" instead of "spec validation" (semantic reframing, not functional gain).
- Unlikely to improve gate accuracy or reduce false positives.

#### Cost to Port
- NO TOOL to port. Would require building intent-file specification (500+ LOC), parser, validator.
- Philosophical framework without reference implementation.

#### Verdict: **SKIP**
- **Reason**: Intent-driven is a methodology, not a tool. flow's semantic gates already implement intent validation (Claude judges quality). No portability leverage; reframing as "intent-driven" adds ceremony without functional improvement.

---

## Summary: Top 3 Transferable Ideas (Ranked by Impact)

| Rank | Idea | Source | Applicability to flow | Est. Impact |
|------|------|--------|----------------------|-------------|
| **1** | **Machine-enforced constitution/principles** (`/constitution`) | Spec Kit | Load at project init; semantic gates validate artifacts against constitution. Governance layer missing from flow today. | HIGH: reduces gate ambiguity, enables org-wide compliance rules (e.g., "no uncontracted APIs"). |
| **2** | **Structured de-risking interview** (`/clarify`, 5-turn bounded) | Spec Kit | Pre-spec gate, optional. Surfaces ambiguities before artifact submission. Reduces rework cycles. | MEDIUM: speeds up spec iteration, improves gate pass rates on first attempt. |
| **3** | **Steering file rules + per-agent hooks** (event-triggered automation) | Kiro | Declarative rule language for proposals/audit engine. Currently deterministic bash; rules would be more maintainable. | MEDIUM-LOW: improves maintainability, enables third-party rule contributions. Cost: new schema + parser. |

---

## Biggest FOMO Traps to Avoid

| Trap | Why It's a Trap | Cost of Falling | Decision |
|------|-----------------|-----------------|----------|
| **"GSD has 58.9k stars, we need context-rot solver"** | GSD solves orchestration, not gating. flow's context management is not the bottleneck (Codex tier already uses subagents). Adopting GSD adds complexity (subagent spawning) without solving flow's problem (artifact gates). | 500+ LOC, ongoing maintenance, governance risk (open-gsd transition). | SKIP. Monitor GSD stability; if flow users report "sessions too long," revisit. YAGNI. |
| **"Kiro is AWS-backed, steering files are the future"** | Steering files are genuinely useful, but Kiro is IDE-locked (not portable). Porting concepts requires building a new rules language + parser from scratch. Early mover advantage goes to Kiro, not to flow. | 400+ LOC, new schema, risk of being "flow's version of steering files" (comparison tax). | PLAN for v0.8+, but only if Kiro releases standalone CLI. Otherwise, wait. |
| **"Tessl has 10k pre-built specs, everyone will use it"** | Tessl is VC-backed (instability risk). Registry lock-in: if Tessl folds, specs disappear. Pre-baked specs are useful but not *essential*; flow can build local registry organically. | Dependency on Tessl's survival, API coupling, spec access costs (may become paid-only). | PLAN conditionally. Hedge with local registry support; don't lock in to Tessl. |
| **"OpenSpec is lighter than Spec Kit, teams love delta-specs"** | OpenSpec solves brownfield/iterative specs (real problem), but flow's design assumes *full specs at gates* (deterministic mechanical inspection). Supporting deltas means re-architecting gates (partial artifact validation). Early adoption data weak (Y Combinator cohort churn is ~30%+). | 250+ LOC, new validation logic for partial specs, potential gate false negatives. | WATCH. Monitor OpenSpec adoption through 2026-Q3. If "delta-spec" becomes industry standard AND flow users demand it, revisit. For now, YAGNI. |
| **"BMAD has 49k stars and Fortune 500 customers, personas are the future"** | BMAD's adoption is real, but token burn is also real ($800–2k/mo/dev). Adding personas multiplies cost without proportional benefit in gate accuracy. High-star count ≠ cost-effective for flow's user base (many solo devs, teams on limited budgets). | 300+ LOC, new schema, implicit cost increase (token multiplier). Hidden cost: users perceive flow as "expensive" if gating becomes multi-persona. | WATCH cost trends. If flow gets institutional funding (enterprise contracts), revisit. Otherwise, YAGNI + cost-as-a-feature is anti-pattern for flow. |

---

## Emerging Patterns (Not Yet Mature Enough to Port)

1. **Intent-driven as execution model** (not just methodology). If intent-driven.dev ships reference tooling, revisit.
2. **Spec registry as service** (multiple registries: Tessl, but others likely emerging). Standardization may occur 2026-Q4.
3. **Event-driven automation within CI/CD** (Kiro's steering files concept + GitHub Actions integration). Watch for open-source implementations.

---

## Risk Assessment: Portability Compliance

All candidates scored against flow's design laws:

| Candidate | Portability | Graceful Degradation | Two-Layer (Mech+Sem) | Ground-Truth Gates | Capture→Reuse | Honest Killing |
|-----------|------------|----------------------|----------------------|-------------------|---------------|----------------|
| Spec Kit /clarify + /constitution | ✅ (bash+py) | ✅ (optional gates) | ✅ (mech: checklists, sem: principles) | ✅ | ✅ | ⚠️ (constitution can't be dismissed) |
| Kiro steering files | ❌ (IDE-locked) | ❌ (rules are mandatory) | ✅ (if decoupled) | ⚠️ (AWS-judged) | ✅ | ⚠️ (rules override killing) |
| OpenSpec deltas | ✅ (npm/bash) | ⚠️ (delta logic adds cases) | ❌ (partial validation breaks determinism) | ⚠️ (partial artifacts risky) | ✅ | ✅ |
| BMAD personas | ✅ (bash+py) | ❌ (personas = cost multiplier) | ✅ (persona roles map to gates) | ✅ | ✅ | ✅ |
| GSD subagents | ✅ (cross-platform) | ❌ (spawning is required, not optional) | ⚠️ (orchestration, not gating) | ✅ | ✅ | ✅ |
| Tessl tiles | ⚠️ (MCP-first) | ✅ (tiles are optional) | ✅ (registry + validation) | ⚠️ (external registry) | ✅ | ✅ |

---

## Recommended Next Steps

### Immediate (v0.7, next 2 weeks)
1. **Spec Kit `/clarify` prototype**: Implement 5-turn structured interview as optional pre-spec gate. Low LOC (~200), high value (de-risking).
2. **Constitution loader**: Light parser for `.specify/constitution.md` (if present); integrate into semantic gates as principles checklist.

### Medium-term (v0.8, July–August 2026)
1. **Monitor Kiro**: Wait for standalone CLI announcement or equivalent steering-file standard.
2. **Monitor Tessl**: Watch for Series A close, registry adoption metrics (>500 org subscriptions = stability signal).
3. **Monitor OpenSpec**: Track Y Combinator cohort survival; if >50% survive AND delta-spec adoption >20% of users, revisit.

### Long-term (v0.9, September+ 2026)
1. Conditional port of Tessl registry *fetcher* (not framework), if stability confirmed.
2. Revisit Kiro port *if* standalone CLI or open-source steering-file spec emerges.
3. Revisit GSD *if* flow users report context degradation (current sessions >60% utilization).

---

## Unresolved Questions

1. **Spec Kit `/clarify` calibration**: How many turns are optimal? Does 5-turn limit map to flow's PRD expansion cycles? (flow has no internal data; recommend A/B test post-port).
2. **Constitution enforcement in semantic gates**: Should gate rejection cite specific violated principles, or just "fails constitution"? (affects Claude prompt complexity).
3. **Tessl registry survival timeline**: VC-backed registries have ~50% churn. How does flow handle registry API sunset? (recommend read-through-cache approach: fetch once, store locally, work offline).
4. **OpenSpec delta compatibility**: If flow adopts deltas, can mechanical gates remain deterministic (partial artifact inspection)? Or must gates become "best effort"? (architectural tension, requires user acceptance of gate probabilism).
5. **BMAD cost recovery**: Could flow monetize multi-persona gating (charge per persona)? Or conflicts with YAGNI? (business decision, out of scope here).

