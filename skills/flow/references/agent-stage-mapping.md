# Stage -> agent mapping

How each buildflow stage delegates to a specialist. Pick the path by `agent-detection.md`
priority (ck: first, bmad alternative, built-in fallback). The artifact + gate are
identical across paths; only the drafter changes.

**Codex (cross-vendor second engine) column.** When the codex tier is eligible
(`agent-detection.md` / `codex-integration.md`), each stage gains two extra options on top of the
ladder below: (1) **rescue** — if the chosen path is BLOCKED twice, hand the scoped brief to
`codex:codex-rescue` before escalating; (2) **opt-in primary** — the operator may select Codex as
the primary drafter for **research** and **build** stages (`codex:codex-rescue --write` /
`codex-companion.mjs task --write`). **Default stays ck:**; Codex-as-primary is operator-selected,
never automatic. The scope/PRD/ADR/Contract judgment stages stay Claude by default (Codex may
still rescue them). The stage gate is identical on the Codex path — Codex drafts, the gate judges. In `teach` mode you do NOT author — you
gatekeep; agents assist the operator. In `work`/`auto` mode you (or the agent) draft, then
the gate still judges.

Artifact language: **Vietnamese for user-facing copy** (per `law/DESIGN.md`: VN native,
`₫` prices, VietQR), **English for code identifiers/endpoints**.

## Brownfield pre-stage (existing codebase)

If the project ALREADY EXISTS, run `/flow assess` first → `flow/00-inspect.md` (current-state map:
stack, functionality/UI/UX vs product goals, risks, test baseline). Delegate to `ck:scout` +
`researcher` (or `bmad-document-project`); the gate is operator-reviewed. This seeds planning (and
the harness) with reality before stage 01. Greenfield projects skip it and start at `/flow next` (00).

## Planning stages (flow/)

| Stage | ck: (primary) | bmad (alt) | fallback | Durable hook |
|---|---|---|---|---|
| 01 Research | `researcher` | `bmad-market-research` / `bmad-technical-research` | `Explore` + WebSearch | `harness intake --type new_spec` |
| 02 Scope | `planner` | `bmad-prd` (scope) | inline | record scope decision |
| 03 PRD | `planner` | `bmad-prd` / `bmad-product-brief` | inline | — |
| 04 ADR | `architect` | `bmad-create-architecture` | inline | `harness decision add` per ADR |
| 05 Contract | `planner` | `bmad-spec` (5-field kernel) | inline | — |

**Optional ck-skill enrichments per stage** (the skill layer on top of the agents above; the
agent drafts, a skill adds a distinct verb): the curated whitelist + the rules (skill INFORMS,
gate JUDGES; Claude-side detection; opt-in-with-prompt) live in **`references/claudekit-skills.md`**.
Deep-wired into the gate ritual (all opt-in-with-prompt, degrade silently, never auto-pass a
gate): **`ck-predict` at ADR** (5-persona pre-decision debate) and **`ck-scenario` at Contract**
(12-dim edge-case → acceptance + contract tests) — both in `gate-rules.md`; **`review-pr` +
`ck-security` at the Review gate** (PR-context lens / STRIDE+OWASP on security-class cards) — in
`adversarial-review.md`; **`retro` at Retro** (git-history numbers for the operator's line) — in
`law/RETRO.md`. After any of these runs at its gate, record the lazy durable metric
(`flow.sh harness intervention add`). Full whitelist + rules: `references/claudekit-skills.md`.

## Shipping (inside cards/)

| Step | ck: (primary) | bmad (alt) | fallback | Durable hook |
|---|---|---|---|---|
| Build card | `fullstack-developer` | `bmad-dev-story` / `bmad-quick-dev` | inline | `harness story update --status in_progress` |
| UI card | `ui-ux-designer` | — | inline + `law/DESIGN.md` | review vs DESIGN.md |
| Repair / diagnostic | `debugger` | — | inline root-cause + fresh same-ladder subagent | `harness intervention add` |
| Review | `code-reviewer` (+ `typescript-reviewer` or `python-reviewer` layered — see language-specialist lens) | `bmad-code-review` (3-layer adversarial) | inline | `harness intervention add` on red |
| Deploy / git ship | `git-manager` | — | inline commit + PR guide | `harness story update --status implemented` |
| Docs sync | `docs-manager` | — | inline doc update | — |
| Verify-live | `tester` / `web-testing` | `bmad-qa-generate-e2e-tests` | curl/Playwright | `harness story update --e2e 1` + `trace` |

**Portability degrade rungs for git-manager and docs-manager:**
- `git-manager` absent → inline: operator runs `git commit` + `git push` + opens PR manually following the durable-hook pattern. Gate (PR merged, SHA logged in `AUTO-LOG.md`) is identical.
- `docs-manager` absent → inline: Claude updates docs directly after card implementation; gate (impacted docs under `docs/` match the code change) is identical.

**Portability degrade rungs for the language-specialist Review lens** (`adversarial-review.md` §Language-specialist lens selection):
- `typescript-reviewer` or `python-reviewer` AGENT present → run it layered with `code-reviewer` for `.ts/.tsx/.js/.jsx` or `.py` cards respectively. Gate (triage table, adversarial verdict) is identical.
- Specialist absent → `code-reviewer` runs an explicit language-targeted checklist (TypeScript: `any` escapes, unhandled promises, strict mode; Python: bare `except`, missing type hints, mutable defaults). Gate is identical.
- No dominant language → `code-reviewer` only; no specialist layer. Gate is identical.

## Scoped prompt template (use for EVERY delegation)

Keep it small. No session history. Fill every slot from the live artifacts.

```
Task: <one stage/card goal>
Read for context: flow/05-contract.md (shapes), law/DESIGN.md (UI only),
  flow/03-prd.md (features), the card file <path>, playbooks/<stack>.md if the stack matches
Files to modify: <card ## Allowed files ONLY>
Acceptance criteria: <the stage gate from gate-rules.md, or the card ## Verify steps>
Constraints: contract is the seam (never improvise a shape); done = world-state evidence;
  Vietnamese user-facing copy; touch only allowed files
Return: the drafted artifact + status (DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT)
```

## Stage notes

- **05 Contract via bmad-spec:** the 5-field spec kernel (Why, Capabilities, Constraints,
  Non-goals, Success signal) maps onto the contract — Capabilities -> endpoints, Constraints
  -> auth/shape rules. Use it to harden the seam against producer/consumer drift. The
  endpoint table in `flow/05-contract.md` remains the runtime-checkable source of truth.
- **Review via bmad-code-review (3-layer):** when present, prefer it for card review — Blind
  Hunter (diff only), Edge Case Hunter (diff + repo), Acceptance Auditor (diff + contract +
  PRD). "Must find issues; zero findings -> re-analyze." This is the adversarial gate
  detailed in `adversarial-review.md` (Phase 4).
- **Build via fullstack-developer:** one card = one scoped session. Pass the card's Scope +
  Allowed files + the contract shapes it consumes. It must honor shapes exactly.
- **Repair / diagnostic via debugger:** detect-first ladder entry — NOT a hard dependency.
  Dispatch `Task(subagent_type="debugger")` with a scoped brief: task description, the failing
  card file, test output, and `## Verify` acceptance criteria. NO session history (context
  isolation per orchestration-protocol). If `debugger` is ABSENT in the host, degrade to inline
  root-cause analysis + a fresh same-ladder (Claude) subagent for the redraw. A missing agent
  changes WHO diagnoses, never whether `## Verify` + `flow.sh check` must pass for real.
  Escalation order: debugger (Claude diagnostic) -> Codex (if USABLE) -> Antigravity (if USABLE)
  -> operator.
- **Verify-live:** the proof is the LIVE surface (deployed URL, real curl), not "tests pass".
  Record `story update --e2e 1` + a `trace` only after the live check.

## After any delegation
1. Run the gate (`flow.sh next` for stages, `flow.sh check C-NNN` for cards).
2. Apply the semantic challenge from `gate-rules.md`.
3. Write the durable hook above. NOTE: the engine now AUTO-fires some — `flow next` past 01 seeds
   `intake`, past 04 reminds `decision add`; `flow check` (done) records the `trace` and shows its
   tier. You still author the content the engine can't (decision rationale, interventions, rich traces).
4. Announce which path ran + the gate verdict to the operator.
