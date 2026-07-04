---
title: "flow xia-upgrade research — decision report (2026-06-15)"
status: superseded
priority: P3
created: 2026-06-15
---

> **Retired 2026-07-04**: the PORT-NOW recommendations from this research (`/flow constitution`,
> accessed_count recall signal, assess repo-map ranking) all shipped in v0.7.0 (see
> docs/journals + git history) — via direct implementation, not by checking off this plan's own
> phase-01/02/03 boxes. Superseded by that shipped work; retired so scans stop treating the
> unchecked boxes here as live/unstarted.

# flow xia-upgrade research — decision report (2026-06-15)

**Goal:** Research current (2025–26) trending tech/repos across 4 domains, score each as an
`xia`-port candidate for the `flow` skill on a philosophy-grounded rubric, and deliver a
**data-driven gain/loss decision** — explicitly separating real value from market FOMO.

**Scope this session:** research + decision report ONLY. No integration. (Per operator:
"nghiên cứu trước, tích hợp sau — cần đánh giá kỹ từ số liệu".)

**Anti-FOMO yardstick (flow's laws):** portability (pure bash + optional python, no heavy
deps, Windows Git Bash + macOS + Linux), graceful degradation, two-layer mechanical+semantic
gates, ground-truth (never trust agent self-assessment), capture→reuse, honest gates.

## Research phases (parallel) — DONE
- [x] R1 — Spec-driven dev tools (Spec Kit, Kiro, Tessl, OpenSpec)
- [x] R2 — Agent orchestration frameworks (LangGraph, OpenAI Agents SDK, Claude Agent SDK, CrewAI, MS Agent Framework)
- [x] R3 — Agent memory systems (Mem0, Letta/MemGPT, Zep/Graphiti, Cognee) — HIGH overlap risk
- [x] R4 — Coding-agent harnesses & eval (OpenHands, SWE-agent, Aider, DeepEval, promptfoo, LangSmith)

## Synthesis — DONE → `flow-xia-upgrade-decision-report.md`
- [x] Scored decision matrix (rubric below) across 18 candidates
- [x] Per-candidate gain/loss
- [x] Verdict buckets: PORT-NOW / PLAN / WATCH / SKIP(FOMO)
- [x] Top transferable ideas + biggest FOMO traps

## OUTCOME (no integration this session, per operator)
- **PORT-NOW (real, dep-free, not yet in flow):** (1) project `/constitution` gate, (2) gate self-eval harness, (3) usage-weighted memory consolidation.
- **PLAN:** auto crash-resume (modest gain), `/clarify` interview, Aider repo-map (already backlog), settings.json law hooks.
- **SKIP(FOMO):** all full memory systems (vector-DB/server), Temporal/CrewAI/MS infra, Kiro/Tessl/GSD/BMAD-personas/JWT-tokens, LLM-as-judge-over-mechanical.
- **Data caveat:** 2026 adoption numbers unverified; scored on mechanism+portability, not stars.

## Scoring rubric (0–5 each; weighted)
| Criterion | Weight | Why (flow philosophy) |
|---|---|---|
| Philosophy fit + portability | 0.30 | No heavy deps, graceful degrade, two-layer — core law |
| Measurable quality lift | 0.25 | Fewer escaped defects / hollow gates / drift |
| Overlap (inverse: novelty) | 0.20 | flow already absorbed ACE/Reflexion/AGENTS.md — penalize re-ports |
| Low maintenance & complexity | 0.15 | LOC, deps, schema, test surface added |
| Token / runtime efficiency | 0.10 | Favor deterministic mechanical checks over more LLM calls |

**Verdict thresholds:** ≥4.0 PORT-NOW · 3.0–3.9 PLAN · 2.0–2.9 WATCH · <2.0 SKIP(FOMO).
