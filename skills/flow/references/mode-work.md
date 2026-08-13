# Mode: work (AI drafts, gates still bind)

`MODE` file at project root (default `teach`). Set with `/flow mode work`.

- **teach** — the operator writes every artifact; you only gatekeep. Default.
- **work** — you interview the operator ONCE, draft stages 00-05 yourself, pause only for
  scope sign-off, deliver the card set as one summary. **Gates and done-rules are identical
  to teach** — you still pass every gate, you just also author.

## The work-mode shape (interview once -> draft -> one pause -> summary)

1. **Interview once.** Ask a single tight batch (use `AskUserQuestion`): the idea in one
   line, who has the pain (a real named person/group), the rough budget/time, the stack if
   they have a preference, and the one channel for the first users. Don't drip questions
   across stages.
2. **Draft 00 -> 01 -> 02.** Fill idea, do real research (delegate to `researcher` per
   `agent-stage-mapping.md` — actually open competitors, quote real complaints with links),
   and produce the scope table with honest Impact + Grade. Run each gate with `flow.sh next`.
3. **ONE scope pause.** Stop at the Scope gate (stage 02). Present the GO/KILL + cut list +
   any C-feature path decisions and get explicit sign-off. This is the only mandatory pause
   in work mode — scope is the operator's call, and killing here is cheap.
4. **Draft 03 -> 05.** PRD (numeric metric, pain->feature mapping), ADR (delegate to
   `architect`/`bmad-create-architecture`), Contract (the seam; consider `bmad-spec` kernel).
   Run each gate. After drafting 02 / 03 / 05, leftover bullets under `## Open decisions`
   are the **only *scheduled*** reason to ask more (via `/flow clarify` + `references/clarify.md`);
   the assumption challenge after a mechanical PASS can still halt (see Rules below).
   Never invent auth, tenancy, retention, or billing to clear `[FILL]`.
5. **Deliver the card set as one summary.** After stage 05 passes, run `/flow card` to
   create the cards, fill their scopes, and present the whole set + build order + which are
   parallel-safe (`/flow ready`) in a single summary for the operator to review.
   Group cards under PRD `FRn` (the user-visible story), not under layer (all models, then
   all services). Every value card fills `## Independent test`.

## Rules that still hold in work mode
- Every gate must pass mechanically (`flow.sh`) AND semantically (`gate-rules.md`). Drafting
  does not lower the bar — self-challenge before presenting (you are now the author AND under
  review, so apply the adversarial lens to your own draft).
- Research must be real (opened competitors, quoted complaints with links) — no fabrication.
  This is the highest-risk stage for an AI author; verify every quote has a source.
- Scope honesty: do not grade-launder your own C features to B. Call C a C, justify the path.
- After 02 / 03 / 05, leftover open decisions are the only *scheduled* reason to ask more (via
  clarify). Even with none, the assumption-vs-open-decision challenge after a mechanical PASS
  can still halt or add a bullet (a policy-encoding `## Assumptions` line with no operator/ADR
  authority is an open decision, not a silent default). Never invent auth / tenancy / retention
  / billing to clear FILL.
- Done is still world-state evidence; you cannot mark a card done without real proof.
- Write durable records (intake/decision/story) as you go, same as teach mode.
