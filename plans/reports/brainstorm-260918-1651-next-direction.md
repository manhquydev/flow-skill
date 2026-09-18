---
type: brainstorm
date: 2026-09-18
created: 2026-09-18T16:51
skill: v0.33.0
npm: 0.7.3
status: recommended
constitution: docs/adr/0001-discipline-layer-identity.md
overrules: plans/reports/brainstorm-260916-2028-discipline-max.md Wave-2-as-next
internet: true
---

# Brainstorm: next implementation direction (internet, not self-ranking)

## Summary

09-16 ranked Wave 2 (bug ritual) after JSON+f05. Internet 2026-06→09 says that ranking is the self-thinking trap: **compaction deletes governance rules**, not missing SDD stages. `flow.sh status` today prints `NEXT ->` / `NEXT_VERB` / optional JSON **state**. It does **not** reprint STOP / HALT / done=world-state. Those live in SKILL.md chat-context — the exact class ConstraintRot calls "soft organizational policy" (8.3× more decay than hard safety).

**Decision:** next cut = **Constraint Pin on the mechanical status path** (Approach A). Land the already-written AgentKit `ak:*` alias overlay in the same PR as hygiene, not as the product story. Park bug ritual and skills-ref CI.

## Brainstorm contract

### Outcome

Operator-visible: after host compact, a host that still runs `flow.sh status` (dispatch rule 2) sees a **verbatim, non-summarized** pin of the three laws + STOP/HALT — not a paraphrase, not JSON fields. Hollow-done and security-class skip stay refused even if SKILL.md body was evicted from the conversation. ADR-0001 holds: flow does not compact, hook, or own the loop.

### Constraints

- ADR-0001: invoked-by-host, terminates on return. No daemon, PreToolUse, compaction engine, MCP client, `flow-orch`.
- Eval STOP: no `_eval_engine_run` / `_run_with_timeout` body edits.
- bash 3.2; zero new skill runtime deps.
- `NEXT_VERB` stays advisory; hosts MUST NOT auto-exec.
- One home per fact. Do not grow SKILL.md (Anthropic Jul 2026: they cut 80% of Claude Code system prompt; overconstraint fights itself).
- 09-16 operator choice still binds for *state*: stdout-only, no `.flow/context.*` dual-write. Pin is a **second closed block on the same printer**, not a second source of truth.

### Non-goals

- Cloning OpenSpec / spec-kit / BMAD (commercetools 2026-09-07: framework does not make the model smarter).
- AgentKit overlay as the release headline (dialect hygiene; already drafted uncommitted).
- `/flow bug` spine this cut.
- `skills-ref` Node in the skill tree.
- Owning host compaction / Constraint Pinning *inside the summarizer*.
- Website. Live billable eval without operator checkpoint.

### Acceptance

1. This report names four contract fields, three identity-legal approaches with assumption + first-failure, and a recommendation that is **not** "ship the alias overlay" and **not** "clone SDD".
2. Recommended slice is mechanically testable: `status` / `resume` stdout contains a byte-stable pin whose text matches the STOP/HALT/done-evidence invariants (string match, no LLM).
3. Pin is verbatim (Compaction Cliff: constraints have zero distortion tolerance). JSON `flow_context/v1` stays the *state* record.
4. AgentKit alias overlay may merge in the same PR; it is not the definition of done.
5. Unresolved questions last. No implementation in this brainstorm.

## Evidence (internet, 2026-09-18)

Verified this session (primary URLs, not the 09-16 packet):

| Source | Date | Finding that changes ranking |
|---|---|---|
| [Governance Decay / ConstraintRot](https://arxiv.org/html/2606.22528v2) | 2026-06 | Compaction raises tool-call violation 0%→30% (DeepSeek/Kimi 59%). Soft org policies decay 8.3× more than hard safety. Constraint Pinning ~47 tokens restores 0%. Compaction-Eviction Attack exists. |
| [Compaction Cliff](https://arxiv.org/html/2608.22752v1) | 2026-08 | Claude Code `/compact` keeps 53% of safety rules after 1 round, **10% after 5**. Type C (constraint) needs exact wording; episodic logs may drop. Type-blind summarization is production. |
| [Anthropic: Claude 5 context rules](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models) | 2026-07-24 | Removed **80%** of Claude Code system prompt. Then: rules/examples/upfront dump. Now: judgement, interface design, progressive disclosure, thin CLAUDE.md. Fat skill files are the anti-pattern. |
| [Agent Skills spec](https://agentskills.io/specification) | live | `name` lowercase+hyphens; SKILL.md <500 lines / <5k tokens; `skills-ref validate`. Flow `name: flow` already valid; body already under budget. |
| [commercetools SDD](https://commercetools.com/blog/spec-driven-development-what-we-learned-at-commercetools) | 2026-09-07 | Spec Kit / OpenSpec / BMAD produce **comparable code**. Difference = whether domain knowledge is *guaranteed to arrive*. OpenSpec loads on demand and cannot skip; Spec Kit only *asks*. BMAD onboarding disaster. |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | live, ~69k★ | Brownfield-first, living specs, 30+ hosts. Competitor on *ceremony adoption*, not on mechanical gates. |

Repo fact (this session, `flow.sh`): `_next_action` prints `NEXT ->` and `NEXT_VERB=`. No STOP/HALT/done-evidence reprint. Uncommitted AgentKit alias overlay is docs-only (11 files). Skill v0.33.0 already shipped JSON *state*.

**Killed assumption:** "highest-leverage remaining item is more SDD (bug ritual) or more kit dialect (ak:*)." That was intra-repo ranking. Papers measure a different failure: **the gate text evaporates while the task continues**.

## Approaches

### A — Constraint Pin on `status`/`resume` (recommended)

**Thesis:** treat STOP/HALT/three-laws as Compaction Cliff type-C. Re-inject **verbatim** on the mechanical path the skill already mandates (`Always call flow.sh first`). State stays `flow_context/v1`. Rules get a closed pin block (~the ConstraintRot 47-token class, not a second essay).

**In:** one printer function composing existing SKILL.md STOP lines (or a single sourced snippet, one home); `status`/`resume` prose + `--json` unchanged schema except maybe `pin=present`; tests: pin bytes stable, pin absent from JSON fields (no dual meaning); AgentKit overlay may ride along.

**Out:** bug verb, skills-ref, installer TARGETS, SKILL.md growth, `.flow/CONSTRAINTS.md` tracked file (AGENTS.md tax; Anthropic says thin).

**Assumption it depends on most:** after compact, the host still invokes `flow.sh status` (skill metadata / dispatch rule survive even if body was summarized).

**First failure:** host never calls status again and continues from the summary — pin unread. Same cheap-abandon as JSON: delete the pin block; prose NEXT remains.

**Worst case vs B/C:** unused stdout. Cost = a few echo lines + tests. Identity risk: none if it is display-only and not auto-exec.

### B — Brownfield bug ritual (09-16 Wave 2)

**Thesis:** most 2026 users do not start at Idea. OpenSpec markets brownfield; spec-kit has assess→fix→test. Mine as a **card ritual**, not a second spine.

**Assumption:** operators will enter a typed bug path instead of pasting a stack trace.

**First failure:** ritual grows its own lifecycle; identity dilution.

**Worst case given internet:** you onboard more sessions into a process whose **constraints still decay**. Adoption without pinning is filling a leaky bucket. commercetools: onboarding speed is real, but they still needed *guaranteed arrival* of domain rules.

### C — Unhobble + skills-spec (Anthropic / agentskills.io)

**Thesis:** SKILL.md already 1181w/1600. Spec-validate frontmatter; pushier description; do not add gates.

**Assumption:** trigger quality / spec compliance is the adoption bottleneck.

**First failure:** already under 500-line spec; validation is hygiene theater. Does not reprint STOP after compact.

**Worst case:** Anthropic's lesson is *delete* constraints that fight judgement. A spec-compliance wave looks busy and ships no pin.

## Comparison (worst plausible case)

| | A Pin | B Bug ritual | C Spec hygiene |
|---|---|---|---|
| Internet problem it answers | Governance Decay / Compaction Cliff | OpenSpec brownfield adoption | Agent Skills / Anthropic unhobbling |
| Worst case | Unused stdout | Second spine + still-leaking gates | Theater |
| Identity risk | Low | Medium (verb-fork) | Low |
| Cheapest to abandon | Delete pin block | Delete verb + catalog row | Delete CI check |
| Makes 0.33 JSON sufficient? | No — JSON is state, pin is rules | No | No |

## Recommendation

**Approach A.** Not B as next (09-16 Wave 2 is still valid *later*, after the leak is pinned). Not C as the cut (already in budget; do not grow SKILL.md).

Ship-with, not story: uncommitted `ak:*` Name resolution overlay (this session). It closes a dialect miss; it does not survive compact.

KISS: one sourced pin string, printed by the existing status/resume printer, tested with `grep -F`. No new verb. No file. No eval-engine edit.

### Vertical slice

```
$ bash runner/flow.sh status
...
NEXT -> fill current gate
NEXT_VERB=fix-gate
PIN v1
STOP lock. STOP hollow-done. STOP security-skip without DEBT.
Done = world-state evidence. NEXT_VERB advisory — do not auto-exec.
```

Bytes identical on `resume`. JSON object does **not** duplicate PIN (state ≠ rules). Tests fail if PIN paraphrases.

## Risks

| Risk | Mitigation |
|---|---|
| Pin bloated into a second SKILL.md | Hard cap ~47–80 tokens; source one home; budget test |
| Hosts treat PIN as auto-exec | Same scream as NEXT_VERB; tests forbid `auto` in PIN |
| Mid-tier never runs status | Overlay does not fix that; mid-tier wave2 disclosure still parked |
| False "we solved compaction" | Disclose: pin works only if status is invoked. Flow does not hook compact |

## Handoff

Four fields + Approach A → `/ak:plan` then `/ak:cook`. Do not implement from this report.

## Unresolved

1. Exact pin source: SKILL.md STOP section vs a 8-line `references/pin.txt` (one home — prefer SKILL.md excerpt mechanically extracted, or a dedicated file if extract is fragile).
2. Does `resume --json` grow a `pin_sha` field? Leans no (09-16: JSON is state). Optional later.
3. Compaction-survival *eval* fixture class: replay-only, never floor, still needs operator checkpoint for live.
4. Wave 2 bug ritual timing: after A is green, not in the same PR.
5. Whether any host actually re-activates the skill after compact (unknown; A is the probe, same as JSON).
