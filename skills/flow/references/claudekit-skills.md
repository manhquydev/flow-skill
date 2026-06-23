# claudekit skills — the per-stage capability map (the seam)

`/flow` already orchestrates claudekit at the **agent layer** (`agent-detection.md` +
`agent-stage-mapping.md`: 13 ck: agents, ck:→bmad→built-in degrade). This file extends that
same seam to the **skill layer** — the curated set of ck *skills* worth reaching for at each
stage, beyond the wired agents. It is a **whitelist, not a dump**: the kit has ~87 skills and
~60% are marketing/content noise for a build harness. Only the skills below ever get surfaced.

This is the single source of truth for the skill map; `agent-stage-mapping.md` points here.

## The two rules that bind every skill suggestion

1. **A skill INFORMS a stage; the gate JUDGES it.** Same as the Codex/Antigravity rule
   (`agent-detection.md`, `codex-integration.md`): a skill's output feeds your triage — it
   **never auto-passes and never auto-fails** a gate. The `flow.sh` exit code + the
   `gate-rules.md` challenge remain the only deciders. A skill that "looks good" is not a PASS.
2. **Detection is Claude-side, and degrades silently.** You already know the host Skills list
   (the available-skills registry) — check it; do not assume. `flow.sh` **cannot** see which
   skills are loaded (bash has no view of the registry, and the 5 install homes — Claude,
   Codex, Antigravity ×2, project — differ), so skill detection is never put in the runner. A
   missing skill **never lowers a gate** — it only changes whether the enrichment is offered.
   Rich where the skill exists, unbroken where it doesn't.

## Cost gate — offer, don't impose

The high-value skills below are **opt-in-with-prompt**: at the matching gate you *offer* the
skill and the operator confirms — you do not auto-fire it on every stage (the constitution /
Codex cost-gate discipline: advisory, off the hot path, no token-tax on trivial work). Skip the
offer on a trivial decision/card. Never wire a skill into `cmd_next`/`cmd_check`.

## The whitelist — what to use when

Each skill is pinned to the stage where it pays off and the **distinct verb** it adds beyond the
already-wired agent. Pure skill/agent twins are deliberately absent (see "Don't surface").

| Skill | Stage | Distinct verb it adds (why it's not a twin) |
|---|---|---|
| **ck-predict** | ADR (04) | 5-persona pre-decision debate — no agent equivalent |
| **ck-scenario** | Scope/PRD/**Contract** (02–05) | 12-dimension edge-case → acceptance criteria + contract tests |
| **repomix** | Assess | packed single-file repo snapshot for LLM context |
| **ck-graphify** | Assess/Build | queryable knowledge graph (code+docs) for impact analysis |
| **review-pr** | Review/Ship | PR-context review: AI-slop, CI-blocker, breaking-change, `--fix` |
| **ck-security** | Review (security-class cards) | STRIDE+OWASP threat-model with attacker personas |
| **security-scan** | Review/Deploy | mechanical secrets/deps/OWASP scan (tip-level, cheap) |
| **retro** | Retro | git-history numeric retrospective (vs narrative journal) |
| **xia** | Research/Build | port/compare/adapt a feature from another repo |
| **ghpm** | Verify/Deploy | bind work to GitHub Issues/Projects/CI status |
| **deploy** | Deploy | platform auto-detect publish |
| **web-testing** | Verify-live | Playwright/k6 e2e/load/a11y (distinct from `tester` unit verb) |
| **docs-seeker** | Research/Build | fetch current library docs (llms.txt/context7) — version-drift guard |
| **scout** | Assess/any | fast parallel file discovery (distinct from inline read) |

> Graph tool: **ck-graphify** is the chosen impact-analysis tool (operator decision, 2026-06-23
> — polyglot/doc-heavy brownfield fit, e.g. CMC Odoo). `gkg` is NOT wired; do not surface both.

## The 5 deep-wired skills (offered inside the gate ritual)

These are wired into the per-stage prose (`gate-rules.md` / `agent-stage-mapping.md`) because
each sits at a gate where a miss is most expensive and adds a verb no wired agent provides.
**Wired ≠ required**: each is offered, degrades silently, and only informs the gate.

1. **ck-predict @ ADR** — before locking a non-trivial architecture decision, offer a 5-persona
   debate. Catches arch/security/perf/UX defects when reversal is cheapest. Output informs the
   ADR challenge; it does not pass it.
2. **ck-scenario @ Contract** (and Scope/PRD) — offer 12-dimension edge-case decomposition to
   harden the seam (`flow/05-contract.md`): the cases become acceptance criteria + the per-type
   no-drift checks. Complements `/flow consistency` (it *generates* cases; consistency checks
   *coherence*).
3. **review-pr @ Review/Ship** — when the change lives as a GitHub PR, offer PR-context review
   (AI-slop, CI-blocker, breaking-change) on top of the wired `code-reviewer` diff review.
4. **ck-security @ security-class cards** — on the exact card class flow already halts at
   (auth, authz, tenancy, payments, data migration, removing validation), offer a STRIDE+OWASP
   threat-model. It informs; the **Tier-C operator HALT is never auto-passed** by a clean scan.
5. **retro @ Retro** — offer a git-history numeric retrospective so the Retro line is backed by
   real commit/velocity numbers, not prose.

## Don't surface (cut on purpose — these add noise, not signal)

- **Skill/agent twins** — the wired agent already covers these; surfacing the duplicate skill
  doubles the "what do I use" confusion: research/researcher, ck-code-review/code-reviewer,
  ck-debug/debugger, test/tester, git/git-manager, ck-plan/planner, docs/docs-manager,
  journal/journal-writer, ask, brainstorm. Prefer the **agent** for in-stage execution; reach
  for the skill only for a distinct verb the agent lacks (already captured above).
- **Competing orchestrators (cook, vibe, ship, bootstrap)** — each is its own end-to-end
  pipeline with its own gates; invoking one inside a flow stage double-gates and fights flow's
  stage authority. Cherry-pick a sub-step (e.g. ship's merge/PR) at the matching stage only.
- **`worktree` skill** — flow already ships `flow.sh workspace` (git-worktree-per-agent). Pure
  duplicate; never wire it.
- **`bmad-spec` as a gate** — overlaps flow's own `/flow consistency` cross-artifact audit.
  Keep it only as the optional Contract drafter already named in `agent-stage-mapping.md`.
- **Marketing/content/media skills** (ads, seo, social, email, video, branding, copywriting,
  the `ckm:*`/`bmad-*` marketing families, cti-expert) — never relevant to a build gate.
- **Stack adapters** (backend/frontend/db/auth/payment/mobile/ui-* …) — surface only via
  `playbooks/<stack>.md` by project-type, never as a flat global menu.

## Lazy capture (optional, off by default)

If skill-invocation telemetry is enabled, record a skill use only at the 5 wired gates via
`flow.sh harness …` (not on every skill, not on the hot path) so a later phase can rank the
whitelist by what this operator actually reaches for (the `accessed_count` signal flow already
uses). Until then the whitelist is static and curated by hand.
