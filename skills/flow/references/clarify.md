# Clarify ritual — resolve leftover open decisions (Scope / PRD / Contract)

Bounded, sequential write-back for open product decisions. Ported in *shape* from
Spec Kit's `/speckit.clarify` protocol; rewritten in Flow nouns. Open decisions
are unchecked `- [ ]` bullets under `## Open decisions` on `02-scope.md`,
`03-prd.md`, and `05-contract.md`. The existing line-anchored box scanner in
`scan_gate` already fails `next` / `gate` / `planning_complete` on those bullets.
This file is how you *clear* them.

**Not a planning stage. Not a `next` prerequisite command.** `flow.sh clarify`
only prints leftover bullets (section-scoped). The interview is this ritual.
Never auto-fired. Offer it (opt-in-with-prompt) when `scan_gate` lists unchecked
boxes under `## Open decisions`, the same way forge-idea is offered at Idea/Scope.

Does **not** replace:
- `forge-idea.md` — persona pressure-test of the *idea* (kill/harden), not write-back
- `mode-work.md` — one batch interview up front; leftover open decisions are the
  *only* reason to ask more after that batch
- `native-rituals.md` §2 — edge-case *generation* for the contract
- `gate-rules.md` material-authority stop — detect invented policy; this ritual
  *asks* then writes the answer

Informs, never judges: a finished clarify session does not pass the gate.
`flow.sh next` still has to see zero `[FILL]` / unchecked boxes, and you still
run the stage's semantic challenge.

## When

- Stage 02, 03, or 05 has one or more unchecked `- [ ]` bullets under
  `## Open decisions` (mechanical fail), **or**
- The operator asks to pin a Decision-required item before it gets invented into
  the artifact.
- Skip at 00 / 01 / 04 — those stages have forge-idea / research / ADR rituals.

Cap: **at most 5 questions asked** in one session (retries on the same question
do not count). There is no mechanical cap on how many open-decision bullets a
file may carry (every leftover `- [ ]` already fails the gate). If the section
is a pile, that is a **semantic** "too many — assume or cut" judgment (see
`gate-rules.md`), not a runner count.

## Token rules (authoring, before this ritual)

When drafting 02 / 03 / 05 (especially in `mode work`):

1. **Write it** if the operator said it or the previous stage locked it.
2. **Assume + record** if a reasonable industry default exists and the choice
   does not change scope, security/privacy, or UX. On 02/03 record it under
   `## Assumptions`. On **05 (contract) there is no `## Assumptions` section** —
   do not invent one (`gate-rules.md` forbids it); assume by writing the
   access/effects cell or shared shape, or cut.
   Reasonable defaults (do **not** open-decide these): data retention for the
   domain, ordinary error-message tone, session/OAuth2 for a standard web app
   unless tenancy/SSO is the product, REST vs GraphQL when the stack is already
   picked.
3. **Add a line like `- [ ] which tenant key?` under `## Open decisions`** only
   when: the choice changes scope, security/privacy, or UX; several
   interpretations have different implications; **and** no honest default exists.
   Priority: scope > security/privacy > UX > technical.
4. Never invent auth, tenancy, retention, billing, or enforcement-owner to clear
   `[FILL]`. That is the failure this section exists to stop.

## Taxonomy (coverage scan — internal)

Walk the current artifact. Mark each category Clear / Partial / Missing. Do not
print the raw map unless you will ask zero questions (then print a one-line
"all Clear" summary).

| Category | Look for |
|---|---|
| Functional scope | who it is for, v1 vs cut list, GO/KILL still standing |
| Domain & data | entities, identity/uniqueness, lifecycle |
| Interaction / UX | critical journey, empty/error/loading |
| Non-functional | latency, scale, availability — only if v1-load-bearing |
| Integration | external services, failure modes |
| Edge / failure | negative path, conflict, throttle |
| Constraints / tradeoffs | stack already locked in ADR? rejected alternatives |
| Terminology | one canonical noun (`ticket` vs `issue`) |
| Completion | numeric success metric; observable result per FRn |
| Placeholders | leftover open-decision bullets, vague adjectives ("robust", "secure") |

Skip a candidate question if answering it would not change implementation,
validation, or the cut list — or if it belongs in ADR (stage 04), not here.

Queue at most 5, ranked Impact × Uncertainty. Prefer one high-impact security
or tenancy question over two low-impact wording questions.

## Sequential loop

Present **exactly one** question at a time. Never reveal the rest of the queue.

**Question writing:**
- Lead with `**Question:**` and a full interrogative that ends in `?`.
- Optional suffix after the `?`: `(FR3)` or `(scope)`. Never use a label as the
  question (`Acceptance device matrix` is invalid).
- Next line: one plain "Why it matters" sentence (the stake for shipping).
- Everyday wording. A reader who does not know Flow must be able to answer
  from the Question line alone.

**Multiple choice (preferred):**
- Pick a **Recommended** option first (best default given project type, risk
  reduction, anything already locked in scope/ADR). One or two sentences why.
- Then a table:

  | Option | Description |
  |--------|-------------|
  | A | … |
  | B | … |
  | C | … (D/E if needed, max 5) |
  | Short | different answer, ≤5 words |

- After the table: `Reply with the letter, "yes"/"recommended" to accept, or a short answer.`

**Short answer (no honest discrete options):**
- `**Suggested:** <≤5 words> — <one-line why>`
- `Format: ≤5 words. Reply "yes"/"suggested" to accept, or your own answer.`

After the operator answers:
- "yes" / "recommended" / "suggested" → use your stated recommendation.
- Otherwise map to one option or accept a ≤5-word phrase.
- Ambiguous → re-ask (does not consume a new slot).
- Then write back (next section) **before** asking the next question.

**Stop when:**
- remaining queued items are no longer necessary, or
- the operator says done / good / no more / stop / proceed, or
- you have asked 5 questions, or
- no valid question existed at the start.

If the quota is hit with high-impact leftovers, list them under **Deferred**
with a one-line rationale (better as an Assumption, a cut-list item, or a later
ADR). Do not leave them as unchecked open-decision bullets if you can honestly
assume or cut.

## Write-back (after EACH accepted answer)

Target file = the stage you are clarifying (`flow/02-scope.md` / `03-prd.md` /
`05-contract.md`). Teach mode: the operator writes; you propose the exact
patch. Work mode: you write, then self-challenge.

1. Ensure a `## Clarifications` section exists. Create it **just above**
   `## Assumptions` (or at the end if Assumptions is missing). Under it, a
   `### Session YYYY-MM-DD` subheading for today.
2. Append `- Q: <question> → A: <final answer>`.
3. Patch the *real* section — do not leave the answer only in the log:
   - scope / cut / GO-KILL → Features in v1, Cut list, or Decision
   - actor / journey → Target users or Features (`FRn:`)
   - data / entity → Shared shapes (contract) or Features
   - NFR / metric → Success metric or Non-functional requirements (must stay
     numeric / observable)
   - edge / failure → a named bullet, or a contract failure shape
   - term → one canonical noun everywhere you just touched
4. **Remove the `- [ ]` bullet** this answer resolved (or tick it only if you
   keep a resolved record in-place — prefer delete so the section stays empty
   when work is done). Leave no contradictory earlier sentence.
5. Save after each answer (overwrite the file). Do not reorder unrelated
   headings. Keep each insertion short and testable.

Allowed new headings: `## Clarifications`, `### Session YYYY-MM-DD` only.

## Assumptions challenge (after the loop, and after a mechanical PASS)

Read `## Assumptions` on the artifact you just touched. For each bullet:

- Is this a real default (industry-standard, or already locked by the operator
  / ADR), or is it **product law** (who can access what, tenancy, retention,
  billing, enforcement owner) wearing an assumption hat?
- If it is product law with no operator/ADR authority → treat it as
  Decision-required: either add an open-decision bullet (and ask it) or
  **stop** and list it the same way `gate-rules.md` material-authority stop
  does. Do not silently keep it.

A clean mechanical gate with a sneaky assumption is the exact hollow-pass this
ritual exists to catch.

## Completion report (to the operator)

- Questions asked & answered (count).
- File(s) patched.
- Sections touched.
- Open-decision bullets remaining (should be zero on the file you cleared;
  say so if not).
- Coverage one-liner per taxonomy row: Resolved / Deferred / Clear / Outstanding.
- Suggested next: `/flow next` if open decisions are gone; otherwise another
  clarify pass or an honest cut/assume.

## Done when

Every accepted answer is in `## Clarifications` *and* in the real section.
Resolved open-decision bullets are gone from the file. Assumptions were
challenged for silent policy invention. No `cmd_next` / `cmd_clarify` coupling
was implied — the operator (or you, after they agree) runs `next` themselves.
