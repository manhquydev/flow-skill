# Gate rules — the semantic layer

The runner (`flow.sh`) checks the mechanical gate: no `[FILL]`, no unchecked `- [ ]`, valid
card status, non-empty evidence. **This file is what YOU check after the script passes.**
The script cannot judge truth or quality; you can. For each stage, after a mechanical PASS,
run the challenge below. If it fails, tell the operator: *"mechanically passed, but
qualitatively weak: <reason>"* and let them decide — never silently advance a hollow
artifact, never silently block a sound one.

> Rule of behavior: in `teach` mode you do NOT edit the artifact or tick boxes. You report.
> In `work` mode you authored it, so you self-challenge before presenting.

> Authoring note (when editing these challenges): **match the form to the failure.** A challenge
> that fights a *discipline drift* — the agent rationalizing a hollow artifact through (grade
> laundering, fabricated quotes, "merge ≈ shipped") — is rightly a prohibition + the specific
> rationalization it counters. A challenge that fixes a *wrong-shaped artifact* (a missing field, a
> drifted name) is better written as a positive recipe — "every interface has both shapes, names
> that won't drift" — than as a ban; a bare prohibition on a shaping problem can produce *more* of
> the bad shape, not less, and a hedging "unless it matters" clause turns a crisp recipe noisy. Pick
> the form deliberately; don't reflexively reach for another "do NOT".

## Stage 00 — Idea
Mechanical: pitch present, one real person named, no FILL.
**Challenge:** Is the pitch really 3 sentences (who / pain / what)? Is the named person a
*real, specific* person or group ("my uncle's 20-unit building"), not "people who..." or
"users"? Is the pain concrete, not a category?

## Stage 01 — Research
Mechanical: 7 boxes checked, no FILL.
**Apply the lens by project type (`/flow project-type`, default web):**
- **web / market product** → the strict version below. Reject the soft "non-web" framing for a
  product that has a real market: a real product DOES have online complaints + a GTM channel,
  and dodging them is the failure this gate exists to catch.
- **cli / library / skill / internal tool** → items 2+4 use first-party friction + who-benefits.
  Demand it be *concrete and real* (a named observed pain, named beneficiaries) — not vague.
  "No market channel" is expected here and is NOT a kill signal.
**Challenge (highest fabrication risk):**
- Were 3 competitors *actually opened*? Each note should read like someone used the tool. (all types)
- web: are the 3 complaints *real quotes with working source links*? · non-web: is the
  first-party friction *concrete and observed* (who hit it, when), not a guess?
- Are competitor/status-quo costs *real* (web: prices+who-pays · non-web: time/manual-work spent today)?
- web: is the first-10-users channel a *specific place* (reject "social media"/"online") ·
  non-web: are the *named beneficiaries* + how-they-learn real?
- Does the switch reason name what makes the *named* users move off today's workaround?

## Stage 02 — Scope (the decision stage)
Mechanical: every feature has Impact (H/M/L) + Grade (A/B/C), no L-above-A in v1, cut list,
GO/KILL, no FILL.
**Challenge — watch for GRADE LAUNDERING:**
- Is any expensive feature quietly graded B when it's really C? (realtime, payments from
  scratch, custom auth, autonomous agentic pipeline, heavy concurrency = C). Call C a C.
- For every C in scope, is it justified as one of: (1) C IS the product -> it goes FIRST;
  (2) re-architected C->B (e.g. multi-step agent -> single structured call; auto-send ->
  human-approves-draft; custom -> managed service); (3) irreducible -> KILL/re-budget?
- Classic failure: v1 full of A-grade L-impact features (cheap to build, worthless to sell).
- If the product itself is a C, is it FIRST in build order with sibling Cs on the cut list?

## Stage 03 — PRD
Mechanical: filled from stage 02, numeric success metric, pain&gain table, no FILL.
**Challenge:**
- Is the success metric a real NUMBER ("first response < 2h"), not "save time" / "better UX"?
- The pain&gain table is the spine: does *every pain* cite evidence (a stage-01 quote or
  named observation) AND name the v1 feature that kills it? Does *every v1 feature* kill at
  least one pain? Orphans on either side = scope drift.
- Could a stranger build v1 from this without asking the operator anything?

## Stage 04 — ADR
Mechanical: each decision has why + rejected, NOT-doing list, covers storage/auth/deploy.
**Challenge:** Does each decision name a *real* rejected alternative (not a strawman)? Are
data storage, auth approach, and deploy target all actually decided (not "TBD")? Is the
NOT-doing list honest about what's deferred?
- **Optional `ck-predict` (when present, non-trivial decision).** Before locking a risky
  decision, offer a 5-persona debate (`ck-predict`) — it surfaces arch/security/perf/UX defects
  when reversal is cheapest. Output INFORMS this challenge; it never passes the gate. Skip on a
  trivial ADR (opt-in-with-prompt — see `claudekit-skills.md`).

## Stage 05 — Contract (the seam)
Mechanical: every PRD feature -> >=1 interface, every interface has input+output shapes,
access/effects column filled, no FILL.
**The "interface" is the project type's seam** (`/flow project-type`): web=endpoint,
cli=command+flags+output/exit, library=public function+args+return, skill=command/file.
**Challenge — this is where producer/consumer drift is born (every type):**
- Does every PRD feature map to at least one interface, and vice versa?
- Does every interface have BOTH input and output shapes, with field/flag names that will not
  drift (the #1 AI-build failure: backend ships `player_email`, UI assumed `email`, both green;
  the cli equivalent: `--out` vs `--output`)?
- Is the access/effects column real for every interface (web: public/token/admin · non-web:
  writes/side-effects or "none")? Do NOT let a web product blank the access column.
- One-way rule: this file is planning source of truth. For web the served spec
  (`/openapi.json`) is the runtime artifact of the SAME contract (amend file -> code -> spec).
  For non-web there is no served spec — the no-drift check is the per-type done-evidence.
- **Self-consistency pass (the contract is ground truth every downstream card trusts).** Before
  passing this gate, read the contract AGAINST any doc it names as its own source of truth and
  re-state each shared rule in your own words — a contradiction here ships as "passed" and every
  card inherits it. (This gate once passed an internally-inconsistent seam that only a later
  cross-model review caught — catch that class HERE, at its source, where it is cheapest.) When the
  **codex tier is USABLE**, an OPTIONAL opt-in **cross-model** check of the contract is the
  highest-value single Codex call in a run — a different engine breaks the same-model blind spot at
  the one artifact whose drift is most expensive downstream.
- **Optional `ck-scenario` (when present).** Offer 12-dimension edge-case decomposition to
  harden the seam: each case becomes an acceptance criterion + a per-type no-drift check, so the
  contract is exhaustive before any card trusts it. Complements `/flow consistency` (it
  *generates* cases; consistency checks *coherence*). INFORMS the gate; never auto-passes it.
  Opt-in-with-prompt — see `claudekit-skills.md`.

## Card gate (`/flow check C-NNN`)
Mechanical: no FILL, valid status, required sections, if done -> verify boxes checked +
evidence non-empty.
**Challenge:**
- Is the scope ONE thing? If it's two, split the card.
- Does the diff touch only `## Allowed files`? Drift outside = stop, amend the card first.
- Do request/response shapes match `flow/05-contract.md` exactly? No improvised shapes.
- For UI cards: reviewed against `law/DESIGN.md` (tokens, affordance ladder, object-first,
  no engine words, no emoji, no gradient on inputs/tables)?
- **Is `## Evidence` real world-state** — a clickable URL, real curl output, a DB row — and
  NOT "tests pass" / "code merged" / "deployed successfully"? Merge != shipped: the proof is
  the live surface changing, verified as a user.
- **If this card fixes a bug/regression**, the evidence includes the red→green proof that the
  new test was actually tied to the bug (`ground-truth-gates.md` → "Bug-fix cards"), not just a
  green run.

## Cross-artifact consistency (`/flow consistency`)
Run after the Contract gate and before building cards (advisory; never blocks the build path).
The runner does the **precise, ID-based** passes mechanically: every PRD `FRn` is claimed by a
card (`implements:`) and served by an interface, the success metric carries a number, no leftover
placeholders. **You do the passes that need judgment, not string-matching:**
- **Hollow coverage:** an `FRn` is "covered" by a card whose scope does not actually deliver it
  (the id is referenced but the work isn't there). Mechanical coverage can be gamed by pasting an
  id; read the card scope against the feature.
- **Conflicting requirements:** two artifacts state incompatible things (PRD says no-login, ADR
  decides OAuth; scope cut a feature the PRD still lists). The runner won't catch a contradiction
  expressed in different words — you must.
- **Cut-list contradiction:** a feature on the stage-02 cut list reappears (by name, not id) as a
  v1 PRD feature or a card. Scope drift in disguise.
- **Terminology drift:** the same entity named differently across artifacts (`ticket`/`issue`/
  `request`) — the seed of producer/consumer drift the contract gate guards against.
If you find any, report *"`consistency` passed mechanically, but <artifact> contradicts <artifact>
on <thing>"* and let the operator decide — same posture as every other gate.

**Canonical form the mechanical pass expects** (deviate and coverage silently can't map — the runner
then prints "no FR ids found" rather than a false pass, but be aware): FR ids are **uppercase `FRn`**,
declared in the PRD's **`## Features`** section (ids in prose or the pain table are intentionally
ignored so a legacy mention can't inflate the set). A blank success-metric body is the gate's job, not
this probe's (it only checks "if a metric exists, it carries a number"). When `consistency` reports
"no FR ids found", treat it as *coverage-unverified*, not *coverage-clean*.

## Constitution challenge (operator invariants — run at scope/PRD/contract)

`flow.sh constitution` is the mechanical half: it proves the `flow/constitution.md` table is
well-formed (no placeholder, every invariant has an ID) and scans any declared grep-marker. It
**cannot** tell whether the artifact you just wrote actually *honors* the invariant — that is your
job. After the mechanical pass, for each invariant whose `applies-at` includes the current stage,
challenge the stage artifact against it:

- Read each invariant (e.g. "all PII access is facility-scoped", "no API surface ships without a
  `flow/05-contract.md` entry").
- Walk the current artifact (scope / PRD / contract) and ask: does anything here *violate* it, or
  quietly assume an exception? A contract endpoint exposing cross-tenant data violates a
  facility-scoped invariant even though the table is structurally clean.
- If you find a violation, report *"constitution passed mechanically, but `<artifact>` violates
  invariant `<ID>` (`<rule>`)"* and let the operator decide — same posture as every other gate.

This is **advisory and per-project**; it never auto-blocks `next`, and it does NOT replace the
security-class Tier-C halt (a constitution rule may *restate* a security concern, but the halt is
the enforcement). Low-noise by design: the mechanical layer is structural, the judgement is yours.

## Debt (deliberate skips)
If the operator deliberately skips/reorders a gate, ensure a line opens in `DEBT.md` naming
the skip, the concrete exposure, and the close condition. **Security-class skips** (auth,
admin exposure, tenancy, payments) are never silent and never your decision — the operator
accepts the exposure in writing. In `/flow auto`, that is a Tier-C halt.
