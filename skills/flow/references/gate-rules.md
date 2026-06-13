# Gate rules — the semantic layer

The runner (`flow.sh`) checks the mechanical gate: no `[FILL]`, no unchecked `- [ ]`, valid
card status, non-empty evidence. **This file is what YOU check after the script passes.**
The script cannot judge truth or quality; you can. For each stage, after a mechanical PASS,
run the challenge below. If it fails, tell the operator: *"mechanically passed, but
qualitatively weak: <reason>"* and let them decide — never silently advance a hollow
artifact, never silently block a sound one.

> Rule of behavior: in `teach` mode you do NOT edit the artifact or tick boxes. You report.
> In `work` mode you authored it, so you self-challenge before presenting.

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

## Debt (deliberate skips)
If the operator deliberately skips/reorders a gate, ensure a line opens in `DEBT.md` naming
the skip, the concrete exposure, and the close condition. **Security-class skips** (auth,
admin exposure, tenancy, payments) are never silent and never your decision — the operator
accepts the exposure in writing. In `/flow auto`, that is a Tier-C halt.
