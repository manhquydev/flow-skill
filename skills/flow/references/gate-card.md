## Card gate (`/flow check C-NNN`)
Mechanical: no FILL, valid status, required sections, if done -> verify boxes checked +
evidence non-empty.
**Challenge:**
- Compare to `gate-examples.md` §Card (PASS names URL/curl/path; FLAG = process-only / artifact-less).
- Is the scope ONE thing? If it's two, split the card.
- **Independent test:** if the field is empty, missing on a value card, or is
  "unit tests pass" / "code merged", split or rewrite. A value card names a
  user-visible proof ("resident files a ticket at /new and sees it on /tickets").
  Scaffold/CI/contract-test/e2e may say `infra` or `none`. Mechanical leftover
  `[FILL]` fails `check` only while the heading remains (the heading is not a
  required `cmd_check` section — §1.6 is cut).
- Does the diff touch only `## Allowed files`? Drift outside = stop, amend the card first.
- Do request/response shapes match `flow/05-contract.md` exactly? No improvised shapes.
- For UI cards: reviewed against `law/DESIGN.md` (tokens, affordance ladder, object-first,
  no engine words, no emoji, no gradient on inputs/tables)?
- **Is `## Evidence` real world-state** — a clickable URL, real curl output, a DB row — and
  NOT "tests pass" / "code merged" / "deployed successfully"? Merge != shipped: the proof is
  the live surface changing, verified as a user.
- **Does every `## Evidence` item name its artifact (path/URL) or the command that produced
  it?** Plausible prose that names neither is still hollow even when the mechanical floor
  passes (`ground-truth-gates.md` rule 8).
- **If this card fixes a bug/regression**, the evidence includes the red→green proof that the
  new test was actually tied to the bug (`ground-truth-gates.md` → "Bug-fix cards"), not just a
  green run.
