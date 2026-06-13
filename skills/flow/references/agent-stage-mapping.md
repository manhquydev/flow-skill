# Stage -> agent mapping

How each buildflow stage delegates to a specialist. Pick the path by `agent-detection.md`
priority (ck: first, bmad alternative, built-in fallback). The artifact + gate are
identical across paths; only the drafter changes. In `teach` mode you do NOT author — you
gatekeep; agents assist the operator. In `work`/`auto` mode you (or the agent) draft, then
the gate still judges.

Artifact language: **Vietnamese for user-facing copy** (per `law/DESIGN.md`: VN native,
`₫` prices, VietQR), **English for code identifiers/endpoints**.

## Planning stages (flow/)

| Stage | ck: (primary) | bmad (alt) | fallback | Durable hook |
|---|---|---|---|---|
| 01 Research | `researcher` | `bmad-market-research` / `bmad-technical-research` | `Explore` + WebSearch | `harness intake --type new_spec` |
| 02 Scope | `planner` | `bmad-prd` (scope) | inline | record scope decision |
| 03 PRD | `planner` | `bmad-prd` / `bmad-product-brief` | inline | — |
| 04 ADR | `architect` | `bmad-create-architecture` | inline | `harness decision add` per ADR |
| 05 Contract | `planner` | `bmad-spec` (5-field kernel) | inline | — |

## Shipping (inside cards/)

| Step | ck: (primary) | bmad (alt) | fallback | Durable hook |
|---|---|---|---|---|
| Build card | `fullstack-developer` | `bmad-dev-story` / `bmad-quick-dev` | inline | `harness story update --status in_progress` |
| UI card | `ui-ux-designer` | — | inline + `law/DESIGN.md` | review vs DESIGN.md |
| Review | `code-reviewer` | `bmad-code-review` (3-layer adversarial) | inline | `harness intervention add` on red |
| Deploy | `deploy` skill | — | manual guide | — |
| Verify-live | `tester` / `web-testing` | `bmad-qa-generate-e2e-tests` | curl/Playwright | `harness story update --e2e 1` + `trace` |

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
- **Verify-live:** the proof is the LIVE surface (deployed URL, real curl), not "tests pass".
  Record `story update --e2e 1` + a `trace` only after the live check.

## After any delegation
1. Run the gate (`flow.sh next` for stages, `flow.sh check C-NNN` for cards).
2. Apply the semantic challenge from `gate-rules.md`.
3. Write the durable hook above.
4. Announce which path ran + the gate verdict to the operator.
