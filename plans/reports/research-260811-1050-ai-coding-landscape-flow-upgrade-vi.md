# Research Report: AI Coding Landscape 2026 → hướng nâng cấp flow-skill

**Date:** 2026-08-11  
**Scope:** Tình hình công nghệ AI (đặc biệt coding agents, harness, SDD, eval) và mapping vào product flow-skill v0.25.0  
**Method:** Parallel web research + scout codebase/prior decision reports  
**Caveat:** Numbers (stars, bench scores) from secondary sources — treat as directional, not audited.

---

## Executive Summary

1. **2026 consensus: Agent = Model + Harness.** Cùng một model, đổi harness có thể lệch ~40 điểm trên GAIA. flow-skill **đang ở đúng category thắng** (gated build harness), không phải "thêm một coding agent".
2. **SDD (Spec-Driven Development) đã mainstream** (GitHub Spec Kit, Kiro, OpenSpec, constitution-first). flow đã có Idea→Contract + `constitution` + two-layer gate — **parity mạnh**, nhưng interoperability / discoverability còn yếu so với Spec Kit.
3. **Thị trường agent phân mảnh theo philosophy:** Cursor (IDE flow), Claude Code (terminal depth + programmable harness), Codex (agent-native long runs), Copilot (enterprise default), OpenCode/Cline (BYOK/open). flow's multi-home install + cross-vendor adversarial **fit multi-agent world**, nhưng cost observability & "default path simplicity" là áp lực mới.
4. **Kỹ thuật hot không phải "thêm model":** context engineering / compaction, skills+hooks+MCP at graduated cost, verification-as-signal, multi-agent review loops, harness self-evolution (AHE), token economics.
5. **Upgrade win for flow:** deepen **harness quality signals** (eval, cost, crash-resume graph dogfood), not re-port vector memory / CrewAI / full SDD clones (already rejected June 2026 decision matrix).

---

## 1. Market: coding agents mid-2026

| Tier | Tools | Philosophy |
|------|--------|------------|
| Front-runners | Cursor, Claude Code, Codex, GitHub Copilot, Cline | IDE speed · terminal brain · agent platform · enterprise default · VS Code control |
| Runner-ups | RooCode, Windsurf/Devin Desktop, Aider, Gemini CLI, JetBrains Junie | reliability / polish / git-native / free-frontier |
| Emerging | AWS Kiro, Kilo Code, Zencoder, OpenCode (OSS mindshare) | SDD automation, context control, provider-agnostic |

**Implication for flow:** Operators increasingly run **2–3 agents side-by-side**. Product that **coordinates gates across agents** + keeps proof durable is more valuable than becoming "the 4th agent".

Sources: Faros AI agents 2026; Artificial Analysis coding agents; Firecrawl harness comparison.

---

## 2. Technical themes that matter for flow

### 2.1 Harness engineering (primary)

- Harness = control plane: what model sees, can do, how verified, memory, cost, risk.
- Research 2026: **Agentic Harness Engineering (AHE)** — closed loop of component / experience / decision observability; tool+middleware+memory edits beat prompt-only tweaks; transfer across model families.
- arXiv "executable, verifiable, stateful agent systems": verification tools (tests, types, static analysis) as **primary loop signal**; parse/summarize traces, keep full fidelity offline.

**flow today:** mechanical `flow.sh` + semantic `gate-rules.md` + SQLite durable + opt-in graph executor (v0.25). Aligns strongly.

**Gaps vs state of art:**
- Limited **decision observability** (prediction → later outcome) for gate changes.
- Eval exists for hollow-gate catch; not yet full **harness A/B** or cross-model transfer eval.
- Graph executor **default-off**; dogfood→default path incomplete.

### 2.2 Spec-driven development (SDD)

- Spec Kit workflow: Constitution → Specify → Plan → Tasks → Implement; 28 agent platforms.
- Martin Fowler note: constitution = immutable principles; phase boundary human review.
- OpenSpec / Superpowers: delta-specs, task tracking; community: SDD for alignment, Plan Mode for speed.

**flow today:** 6 planning stages + cards + constitution + consistency/coherence/contract checks.

**Gaps:**
- No first-class **interop** with Spec Kit / OpenSpec artifact layouts (import/export or "assess foreign SDD tree").
- Spec Kit wins **distribution mindshare** among teams new to gated AI builds; flow wins **honest kill + two-layer + world-state done**.

### 2.3 Agent loop & tools

- Winning pattern remains simple: gather → act → verify; SWE-bench agents with **few tools** (bash + edit) still top-tier when harness is right.
- Ralph-style loops: forever iterate toward spec until done or budget — cousin of `/flow auto` + loop-prep.
- Extensibility stack (Claude Code analysis): MCP · plugins · skills · hooks at **different context costs**.

**flow today:** skill-as-extension; pluggable agents; native rituals; hooks PLAN'd earlier, not fully ported.

### 2.4 Multi-agent & review

- Common 2026 pattern: model A implements, model B reviews (Claude↔Codex).
- flow already: Claude + Codex + Antigravity three-model adversarial at gated moments.

**Gap:** cost/latency of multi-model path; operator needs **when-to-spend** policy surface (Tier A/B/C exists for auto-merge; less explicit for review spend).

### 2.5 Cost & economics

- AI coding = fastest-growing bill line; multi-agent teams struggle to attribute spend.
- Cursor/Windsurf lock agent traffic; CLI agents (Claude Code base URL) more proxyable.

**flow today:** usage log + `/flow usage` analytics (cycle time, gate fail-rate).  
**Gap:** **token/cost** per stage/card (not just command counts); budget hard-stops beyond iteration caps.

### 2.6 Memory

- Industry still experiments graph+vector (Mem0-style).  
- flow's prior decision (2026-06-15): **SKIP full vector memory systems**; keep SQLite + ACE + usage-weighted recall. Still correct under portability law.

---

## 3. flow-skill current position (scout)

| Strength | Evidence |
|----------|----------|
| Correct category (gated harness, not chatbot) | Architecture: mechanical + semantic + durable |
| Philosophy durable under FOMO | xia-upgrade matrix SKIPPED Mem0/CrewAI/Temporal SaaS |
| Shipped advanced seams | constitution, eval, concierge, cross-agent install, graph executor, harness trust 0.1.17 |
| Portable distribution | npm + multi-home (Claude/Codex/agents/Antigravity) |
| Measurable discipline | 46 test suites, behavioral eval fixtures |

| Risk / debt | Evidence |
|-------------|----------|
| Complexity surface | SKILL.md + 21 references + harness + graph — onboarding cognitive load |
| Graph executor opt-in maturity | v0.25 default off |
| Market narrative lag | Spec Kit / "agentic engineering" occupy vocabulary; flow less known |
| Cost layer thin vs 2026 pain | usage is command-centric |
| Prior PLAN backlog still open | hooks law-enforcement, /clarify, aider-style repo-map, durable auto crash-resume concepts |

---

## 4. Candidate upgrade directions (pre-advise, not committed)

Ranked by **philosophy fit × market leverage × YAGNI** (subject to advise interview):

| # | Direction | Why now | Risk |
|---|-----------|---------|------|
| A | **Harness observability v2** — decision predictions, gate change → catch-rate delta, AHE-style experience distill into playbooks | Industry says harness is the moat; flow is harness | Scope creep into research platform |
| B | **Token/cost budget surface** — per-stage estimate, hard stop, usage digest with cost hooks | #1 enterprise pain 2026 | Model pricing APIs unstable |
| C | **SDD interop (not clone)** — import Spec Kit tree / export flow stages; one-pager "flow vs Spec Kit" | Mindshare + brownfield assess | Dual maintenance of two schemas |
| D | **Hooks + permission law** — host-native hooks where available; degrade elsewhere | Planned Jun; reduces mid-run law breaks | Host-specific; portability uneven |
| E | **Graph executor dogfood → recommend path** | Crash-resume + parallel cards already built | Premature default-on if flaky |
| F | **OpenCode / Grok Build / Cursor skill homes polish** | Multi-agent world expands | Thin installs without depth tests |
| G | **Eval expansion** — card done-evidence quality, auto-run safety fixtures | Trust product | Billable eval cost |
| H | **Repo-map assess (Aider-class ranking)** | Brownfield quality | Optional dep / graceful degrade complexity |

**Still SKIP (reaffirm):** full Mem0/Zep, CrewAI-style persona fan-out, managed Temporal SaaS, Tessl registry lock-in.

---

## 5. Techniques glossary (for product language)

| Term | One-liner | flow analog |
|------|-----------|-------------|
| Agentic loop | context → action → verify | stage/card + gate + live verify |
| Ground-truth gate | decide on world signal not self-praise | `flow.sh` exit + live URL |
| Context engineering | assemble/compact what model sees | recall, scoped subagent prompts, law excerpts |
| Skill | domain instruction pack | flow itself + playbooks |
| Hook | intercept tool lifecycle | planned settings hooks |
| MCP | external tools | optional; not core |
| SDD / constitution | immutable principles + phase specs | `flow/constitution.md` + stages |
| Multi-agent review | second model finds issues | Codex/Antigravity adversarial |
| AHE | evolve harness from trajectory evidence | eval + retro + playbook harvest |

---

## 6. Resources (entry points)

- Faros: Best AI Coding Agents 2026 — Agent = Model + Harness
- GitHub Spec Kit / GitHub Blog SDD
- Martin Fowler: Exploring SDD (Spec-kit, Kiro, …)
- arXiv: Toward Executable, Verifiable, Stateful Agent Systems (2026)
- Medium/Masood: Agentic Harness Engineering OS
- Anthropic: Building Effective Agents (loop + tool design)
- Prior in-repo: `plans/260615-flow-xia-upgrade-research/flow-xia-upgrade-decision-report.md`

---

## 7. Unresolved (for advise interview)

1. Primary outcome of next upgrade: **trust/quality**, **adoption/distribution**, **autonomy/speed**, or **cost control**?
2. Target operator: solo power-user, team lead, or product-builder non-expert?
3. Willing to break "pure bash + optional python" for optional higher tiers?
4. Compete with Spec Kit narrative or stay "honest gates for shippers" niche?

---

## Next step

Feed into `ak:advise` interview → confirmed requirements → ordered work checklist for `ak:plan`.
