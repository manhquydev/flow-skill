# claudekit skills — the per-stage capability map (the seam)

`/flow` already orchestrates claudekit at the **agent layer** (`agent-detection.md` +
`agent-stage-mapping.md`: 13 ck: agents, ck:→bmad→built-in degrade). This file extends that
same seam to the **skill layer** — the curated set of ck *skills* worth reaching for at each
stage, beyond the wired agents. It is a **whitelist, not a dump**: the kit has ~87 skills and
~60% are marketing/content noise for a build harness. Only the skills below ever get surfaced.

This is the single source of truth for the skill map; `agent-stage-mapping.md` points here.

## Standalone note (v0.22)

Five of the six deep-wired skills below now have a **native flow ritual** as the
guaranteed baseline — see `references/native-rituals.md`. Installing flow alone already
gets you all five (persona-debate @ ADR, edge-case decomposition @ Contract, STRIDE
security @ Review, numeric retro @ Retro, native loop protocol @ Build/Verify); the ck
skills in this file are optional **enrichment** when already installed, never a
requirement. `review-pr` has no native equivalent (it is PR-context-specific,
GitHub-only) — flow's own 3-layer `adversarial-review.md` already covers diff-level
review natively.

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
| **ck-loop** | Build/Verify (Implement→Test→Audit→Fix) | mechanical iterate-to-numeric-target with per-iteration git commit/revert — the loop-engineering primitive flow lacked natively |

> Graph tool: **ck-graphify** is the chosen impact-analysis tool (operator decision, 2026-06-23
> — polyglot/doc-heavy brownfield fit, e.g. CMC Odoo). `gkg` is NOT wired; do not surface both.

## The 6 deep-wired skills (offered inside the gate ritual)

These are wired into the per-stage prose because each sits at a gate where a miss is most
expensive and adds a verb no wired agent provides. **Wired ≠ required**: each is offered
(opt-in-with-prompt), degrades silently, and only informs the gate. Wiring locations:
ck-predict/ck-scenario → `gate-rules.md` (stages 04/05); review-pr + ck-security →
`adversarial-review.md` (the Review gate); retro → `law/RETRO.md`; ck-loop → the Build/Verify
tail, plumbing via `flow.sh loop-prep`/`loop-log` (this file).

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
6. **ck-loop @ Build/Verify (Implement→Test→Audit→Fix tail)** — when a fix needs more than one
   experimental attempt against a single numeric target (failing-test count, lint errors, etc.),
   offer `flow.sh loop-prep <card>` to set up an isolated worktree + Verify/Guard commands, then
   invoke the `ck-loop` skill with the printed block (ck-loop stays the untouched execution
   engine — flow supplies plumbing only). See "Loop vs two-strikes" below for when to reach for
   this instead of the default repair path. The finished run is recorded via `flow.sh loop-log`
   (NOT the `intervention` channel below — recording it twice would double-count the same event).

## Loop vs two-strikes — the one "fix it" decision tree

flow already has a bounded repair mechanism (two-strikes: one fresh-subagent repair attempt on a
review deadlock, then escalate to a cross-model lens — `adversarial-review.md`). `ck-loop` is a
different tool for a different situation; do not let operators reach for the wrong one:

| Situation | Use | Why |
|---|---|---|
| Review BLOCKED twice, same model, no metric | two-strikes → cross-model lens | bounded disagreement, not a number |
| One numeric verify command, needs >1 experimental attempt | `flow.sh loop-prep` + ck-loop | open iterate-to-target, git-tracked/revertable |
| Drive failing-tests / lint / perf count to a threshold | ck-loop | Verify is a single number; Direction lower |
| Single obvious fix, one retry | default auto repair | cheaper than spinning up a worktree+loop |

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

## Lazy capture (ON — only at the 5 wired gates)

Skill-invocation telemetry is **enabled, lazily**: after a deep-wired skill runs at its gate,
record the use via the existing `flow.sh harness intervention add` (the same durable-metric
channel the Codex/Antigravity lenses use — `adversarial-review.md` §S2). **Only at the 5 wired
gates** — never on every skill, never on the `cmd_next`/`cmd_check` hot path, no new runner verb.
Note whether the skill caught a class the wired agent missed; that signal lets a later phase rank
the whitelist by what this operator actually reaches for (the `accessed_count` signal flow already
uses). The whitelist stays hand-curated until then.
