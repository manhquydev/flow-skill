# Flow × claudekit-engineer — Skill Orchestration Design

**Status:** ROUND-1 SHIPPED (v0.14.0, 2026-06-23) — design below; build outcome at bottom.
**Date:** 2026-06-23
**Round decision:** research + design only → operator greenlit Round-1 same session; team surveyed all mechanisms and recommended with evidence.

> **Round-1 build outcome (v0.14.0):** Shipped `references/claudekit-skills.md` (the whitelist
> + binding rules) + deep-wired ck-predict@ADR & ck-scenario@Contract into `gate-rules.md` +
> cross-ref from `agent-stage-mapping.md` + `tests/test_flow_claudekit_integration.sh` (27/27).
> Applied leans: NO `suggest` verb, opt-in-with-prompt, **ck-graphify** (gkg not wired), lazy
> logging off-by-default. Full suite green (all suites 0 failed), coherence PASS (0.14.0 ×3).
> Adversarial review: APPROVE_WITH_NITS (gate-parity preserved, scope clean, no runner change);
> the one terminology-drift NIT (review-pr label) was fixed.
>
> **Round-2 SHIPPED (v0.15.0, 2026-06-23, commit pending):** wired review-pr + ck-security into
> the Review gate (`adversarial-review.md`) and retro into `law/RETRO.md`, all opt-in-with-prompt
> / INFORM-only; ck-security never auto-passes the Tier-C HALT; retro keeps operator authorship.
> Decisions adopted — Q1 telemetry = ON-but-lazy (only at the 5 wired gates via existing
> `flow.sh harness intervention add`, no new runner verb), Q2 `suggest` verb = NO (guarded by a
> runner assertion), Q3 = ck-graphify, Q4 = opt-in-with-prompt. Test 27→42; full suite 24/24
> green; coherence PASS (0.15.0 ×3); review APPROVE_WITH_NITS (2 advisory NITs, one upgraded into
> a real Q2 runner guard). Still no runner change. CI verification pending GitHub billing fix.

---

## The problem (operator's words, characterized)

The claudekit-engineer kit (freshly pulled) has **~87 skills + 13 agents**. The operator
only uses `cook / plan / codereview / test / debug / fix` and feels the kit is "too many,
don't know what to use when." Goal: **flow becomes the conductor** that, at each gated
stage, knows which ck capability to reach for.

## The key finding

Flow **already** orchestrates claudekit — but only at the **agent layer**. `references/
agent-stage-mapping.md` + `agent-detection.md` map each stage → one of 13 ck: agents
(priority ck: → bmad → built-in, portable degrade), plus cross-vendor Codex/Antigravity
engines. Flow is **blind to the ~74 skills that aren't 1:1 with those 13 agents** — exactly
the "power tools" the operator never uses.

**So the task is not "integrate claudekit" — it's "extend flow's existing orchestration
seam from 13 agents to a curated skill whitelist, surfaced at the gates where each pays
off."** This mirrors precisely how Codex and Antigravity were added (reference file +
detection rule + high-value moments only). That pattern shipped twice without rotting —
that is the ROI evidence, not a trend.

---

## Recommended mechanism: A + selective-C (the `suggest` verb is CUT from round 1)

| Layer | What | Blast radius |
|---|---|---|
| **A. Reference catalog** | New `references/claudekit-skills.md` — the <15 whitelist as a stage→skill table, read lazily by Claude (never by `flow.sh`). One cross-ref line added to `agent-stage-mapping.md` so it's reachable from a file the skill already reads per-stage. Same shape as `codex-integration.md`. | Near-zero (markdown sibling) |
| **C. Selective deep gate-wiring** | Exactly 5 skills wired into the stages where a miss is most expensive, each adding a **distinct verb** no wired agent provides. | Targeted prose edits |
| ~~B. `flow.sh suggest` verb~~ | **CUT from round 1** — red-teamed as ceremony with no proven behavior change (operators already only use 5 verbs; a 6th static-list verb likely goes unread). Reconsider only if round-1 shows demand for a bash cheatsheet. | — |

### The 5 deep-wired skills (and why these, not the other top-10)

| # | Skill | Stage / gate | Distinct verb / ROI |
|---|---|---|---|
| 1 | **ck-predict** | ADR (04) | 5-persona pre-decision debate; catches arch/security/perf/UX defects when reversal is cheapest. No agent twin. Highest single-gate leverage. |
| 2 | **ck-scenario** | Scope/PRD/**Contract** (02-05) | 12-dim edge-case decomposition → acceptance criteria + contract tests; hardens the Contract seam the whole build depends on. No twin. |
| 3 | **review-pr** | Review/Ship | PR-context review (AI-slop, CI-blockers, `--fix`) — distinct from the `code-reviewer` agent which reviews a diff, not a PR-in-context. |
| 4 | **ck-security** | Review (security-class cards only) | STRIDE+OWASP threat-model on the exact auth/authz/tenancy/payments/migration card class flow already flags as Tier-C. |
| 5 | **retro** | Retro | git-history numeric retrospective — real numbers, distinct from `journal-writer` narrative. |

> gkg/ck-graphify/repomix/scout are valuable but belong in the **reference catalog (A)**
> as Assess-stage enrichments, not deep gate-wiring (Assess is operator-reviewed, not a
> hard gate).

---

## The curated whitelist — the "what to use when" (the deliverable that answers the pain)

Each pinned to a stage + the distinct verb it adds beyond the already-wired agent. Pure
twins dropped.

| Skill | Stage | Distinct verb (why not a twin) |
|---|---|---|
| ck-predict | ADR | 5-persona pre-decision debate |
| ck-scenario | Scope/PRD/Contract | 12-dim edge-case → acceptance + contract tests |
| repomix | Assess | packed single-file repo snapshot for LLM context |
| gkg **or** ck-graphify | Assess/Build | semantic impact analysis (pick ONE — open Q3) |
| review-pr | Review/Ship | PR-context review + AI-slop + CI-blocker + `--fix` |
| ck-security | Review (security cards) | STRIDE+OWASP threat-model |
| security-scan | Review/Deploy | mechanical secrets/deps/OWASP scan (tip-level) |
| retro | Retro | git-history numeric retrospective |
| xia | Research/Build | port/adapt a feature from another repo |
| ghpm | Verify/Deploy | bind work to GitHub Issues/Projects/CI |
| deploy | Deploy | platform auto-detect publish |
| web-testing | Verify-live | Playwright/k6 e2e/load/a11y (distinct from `tester` unit verb) |
| docs-seeker | Research/Build | fetch current library docs (llms.txt/context7) |
| scout | Assess/any | fast parallel file discovery |

**Dropped as pure twins** (wired agent already covers): research/researcher,
ck-code-review/code-reviewer, ck-debug/debugger, test/tester, git/git-manager,
ck-plan/planner, docs/docs-manager, journal/journal-writer, ask, brainstorm.

---

## What we deliberately DON'T do (FOMO traps cut, one line each)

- **Competing orchestrators (cook, vibe, ship, bootstrap):** never invoked as whole
  pipelines inside a stage — they double-gate and fight flow's stage authority. Cherry-pick
  sub-verbs only.
- **Skill/agent twins (10):** wire the agent, never the duplicate skill — surfacing both
  doubles the "what to use" confusion we're fixing.
- **`worktree` skill:** flow already ships `flow.sh workspace` (v0.13.0). Pure dup.
- **`bmad-spec` as a gate:** overlaps flow's own `consistency` audit. Keep as optional
  Contract drafter only.
- **Hot-path injection (suggest on `cmd_next`/`cmd_check`):** token tax for marginal value
  — the constitution-command precedent already keeps advisory features OFF the hot path.
- **Bash availability detection:** `flow.sh` can't see Claude's skill registry and the 5
  install homes differ — any bash "is-skill-present" check would lie. Detection stays
  Claude-side, degrades silently (same as Codex/Antigravity INSTALLED≠USABLE).
- **The 12 marketing skills + 17 stack-adapters as a flat list:** ignore marketing;
  stack-adapters surface only via `playbooks/<stack>.md` by project-type.

---

## Hard constraints any wiring must honor (from flow's own laws)

- Never edit `runner/flow.sh` or `_templates/` **mid-run** (a pre-run reference file + prose
  edits are fine).
- **Portability:** a missing skill never lowers a gate — it only changes who drafts.
- **Mechanical-vs-semantic split:** script checks deterministic/cheatable things; Claude
  judges quality. A skill **INFORMS** a stage; the `flow.sh` + `gate-rules.md` gate
  **JUDGES**. Never let a skill's "looks good" become a gate PASS (cardinal sin = gate
  dilution).
- **Same gate regardless of path.**
- **Cost gate:** ck-predict/ck-security fire only at non-trivial decisions / the defined
  security-card class — never on every ADR/review by default (the Codex cost-gate pattern).

---

## Red-team — how this rots, and the mitigation

| Failure mode | Likelihood | Mitigation / kill-criterion |
|---|---|---|
| R1 Reference map no one reads | HIGH | Hook it into `agent-stage-mapping.md` (read per-stage). Kill-criterion: if round-1 usage-log shows no skill-uptick at the 5 wired gates → cut the map, keep only the 5 wirings. |
| R2 `suggest` verb ignored | HIGH | Already cut from round 1. Build only on demonstrated demand; delete if ~0 events in 2 weeks. |
| R3 Whitelist drifts as ck renames skills | MED | One source-of-truth file + a `tests/test_flow_claudekit_integration.sh` asserting each name still resolves. Drift = red test, not silent rot. |
| R4 Gate dilution (skill verdict leaks into PASS) | MED-HIGH | Verbatim "gate parity (absolute)" clause from Codex: skills feed triage, never auto-pass. |
| R5 ck-predict/ck-security become mandatory tax | MED | Opt-in-with-prompt at the gate; trivial cards skip. |
| R6 gkg AND ck-graphify both wired | LOW | Q3 forces one pick before wiring. |

**Skeptic's cut (kept honest):** the `suggest` verb is ceremony with no proven behavior
change → cut from round 1. Real measurable value = A (reachable catalog) + C (5 deep
wirings at expensive gates). Everything else is documentation.

---

## Phased rollout (measured via flow's existing usage-log — no new telemetry)

- **Round-1 (smallest real value):** `references/claudekit-skills.md` + cross-ref line;
  deep-wire **ck-predict @ ADR** and **ck-scenario @ Contract**; integration test
  (name-resolution + gate-parity). Signal: richer Contract artifacts + fewer downstream
  Review-stage red gates (`cmd_usage` top-fail-stage trend).
- **Round-2:** wire review-pr / ck-security / retro; decide on `suggest` verb only if demand
  shown.
- **Later:** Assess enrichments (repomix, gkg/ck-graphify) + usage-weighted suggestions
  (only if Q1 = capture skill-invocations in the usage-log).

---

## Open questions for the operator (genuine forks — need human decision before any wiring)

1. **Capture ck-skill invocations in the usage-log?** Enables usage-weighted suggestions
   later but adds a small `flow.sh harness` event after each wired skill use. *Team lean:
   YES, but lazily — only at the 5 wired gates.*
2. **Does the `suggest` verb exist at all, or is the reference map enough?** *Team lean: map
   is enough; don't build the verb in round 1.*
3. **gkg vs ck-graphify** — pick ONE graph tool. gkg = semantic navigation (go-to-def,
   find-usages, multi-language); ck-graphify = queryable graph from code+docs+images.
4. **ck-predict / ck-security: opt-in-with-prompt or auto at their gates?** *Team lean:
   opt-in-with-prompt (offer at the gate, operator confirms) to honor the anti-ceremony
   stance.*

---

## Provenance

Built by a 3-agent flow-skill dev team: (1) flow-internals/integration-surface,
(2) claudekit catalog triage, (3) design synthesizer + red-teamer. All read-only research;
findings cross-checked. No flow skill files modified.
