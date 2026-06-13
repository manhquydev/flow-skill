# Stage 02 — Scope (go/no-go)

Scope = features chosen by IMPACT × COST, inside your time budget.
KILL here is cheap and smart. Killing a weak idea at this gate is a SUCCESS outcome.

## Gate — check ALL before `/flow next`
- [x] Every feature below has an IMPACT (H/M/L with the business reason) AND a grade (A/B/C)
- [x] No L-impact feature above grade A survives in v1
- [x] The suggested-features section was actually considered (each suggestion has an in/out decision)
- [x] fit(grades, budget) holds — every C in scope is justified as path 1, 2, or 3 above (written next to the feature)
- [x] If the product IS a C feature: it is FIRST in build order, and its sibling C features are on the cut list
- [x] The cut list is written (what I am NOT building in v1)
- [x] GO / KILL decision is written below
- [x] No FILL placeholders remain in this file

## Time budget

One focused session (this dogfood). Additive only; must not break the 46 existing tests.

## Features in v1 (each with impact AND grade)

- **F1 — project-type setting + `flow.sh project-type [web|cli|library|skill]`** — impact H (core promise of this fix: lets /flow know what it's building) — grade A (a `PROJECT_TYPE` file + dispatch, mirrors the existing `MODE` mechanism). No C here.
- **F2 — per-type done-evidence definition (reference + gatekeeper guidance)** — impact H (fixes the actual pain: "done = live URL" is wrong for a CLI, where done = installs + runs + exit codes) — grade B (per-type evidence text the Claude layer enforces; not automated validators in v1).
- **F3 — per-type Contract-stage guidance (reference)** — impact H (web = endpoints; cli = subcommands + exit codes; library = public API; skill = install + a real /flow run) — grade A (a reference doc + a gatekeeper note; the existing 05 template stays, guidance adapts).
- **F4 — per-type standard-card-sequence guidance (reference)** — impact M (keeps builders on rails for non-web) — grade A (reference doc).
- **F5 — `flow.sh skip <stage> --reason` (advance a gate only if a matching open DEBT line exists, non-security-class)** — impact M (unblocks the legitimate gate-skip this dogfood itself hit) — grade A (small runner addition + planning_complete tolerates debt-skipped stages).

fit(grades, budget): all A/B, no C. Additive. Holds easily.

## Suggested features (impact-first — proposed, not decided)

Grounded in the dogfood findings (no public GTM; suggestions tie to observed friction):
- **S1 — auto-detect project type from repo signals (package.json `bin`, pyproject scripts, a SKILL.md)** — impact M (less setup) — grade B — **OUT** (explicit setting first; auto-detect is a v2 convenience, and a wrong guess is worse than asking).
- **S2 — per-type Research-gate variant (finding #1: complaints→first-party friction, channel→who-benefits)** — impact M — grade B — **OUT** (needs gate-template variants; bigger change; defer to keep v1 focused).
- **S3 — automated per-type evidence validators (e.g. `flow.sh verify-done` runs the type's check)** — impact M — grade B — **OUT** (v1 ships guidance the Claude layer enforces; automate later).

## Cut list (NOT in v1 — deferred, not deleted)

- Auto-detect project type (S1) — deferred; explicit `project-type` first.
- Per-type Research-gate template variants (S2) — deferred; tracked as backlog #1.
- Automated done-evidence validators (S3) — deferred.

## Decision

GO — H-impact, all grade A/B, purely additive, and it fixes a verified pain that this very dogfood exposed. F1 (the setting) goes FIRST; F2/F3 consume it; F5 is independent and unblocks legitimate skips.
