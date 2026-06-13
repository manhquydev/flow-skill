# Project rules — buildflow project

This repo is a project run with the **buildflow** method. Planning artifacts live in
`flow/`, build cards in `cards/`. The method: every stage/card has a GATE; no gate pass,
no advance. Read `README.md` once for the method; THESE rules govern every session here.

## /flow commands

`/flow` (status) · `/flow next` (gate-check + unlock stage) · `/flow card` (new card) ·
`/flow check C-NNN` (validate card) · `/flow mode teach|work` (who writes the plan) ·
`/flow retro` (3 questions → RETRO.md / playbooks/ / FLOW-FEEDBACK.md) ·
`/flow ready` (what's buildable now, parallel-safe groups) · `/flow auto` (autonomous
build run — preflight via runner, then drive per SKILL.md AUTO PRINCIPLES: subagent per
card, planner reviews + verifies, worktree isolation for parallel groups, operator-gated
cards halt by design, state in card files + AUTO-LOG.md).
Runner: `bash .claude/skills/flow/runner/flow.sh <cmd>`.

Modes (`MODE` file at root; default `teach`): **teach** — the user writes every artifact,
the AI only gatekeeps. **work** — the AI interviews the operator once, drafts stages 00-05
itself, pauses only for scope sign-off, delivers the card set as one summary. Gates and
done-rules are identical in both modes.

## Build-session discipline (when implementing a card)

1. ONE card per session. The card IS the session brief: build exactly its `## Scope`,
   touch ONLY its `## Allowed files`. Need another file? Stop — amend the card first.
   Default is serial, in card order. Parallel is allowed ONLY per the worktree protocol below.
2. Two law files: the contract (`flow/05-contract.md`) for shapes, `DESIGN.md` for pixels.
   Every UI card (mock + frontend) is built AND reviewed against DESIGN.md — tokens,
   affordance ladder, object-first pattern, never-do list. Read it before any UI work.
   The contract: never improvise a request/response shape.
   If the contract is wrong, amend `flow/05-contract.md` FIRST, then code to it.
   When the contract requires a field whose FEATURE belongs to a later card: honor the
   SHAPE now (null/stub value, commented as such), deliver the VALUE in that feature's
   card. Never omit the field — the UI card will consume the shape you ship.
3. Run every `## Verify` step for real before claiming done. Paste actual output/URLs
   into `## Evidence`. Only then set `status: done`, then run `/flow check C-NNN`.
4. Done-evidence = world-state (deployed URL, curl output, DB row). "Tests pass" /
   "code merged" are mid-pipeline, never done.
5. Never check a gate box or write a planning artifact on the user's behalf.
   Never set a card `done` without pasted evidence.
6. Read any file flow.sh just created before first editing it.
7. **Playbooks** (`playbooks/`): paid-for stack knowledge. Before building a card that
   touches a stack with a playbook (check `playbooks/README.md` index), READ it and run
   its smoke tests before committing to a design on that stack. After a card pays for a
   non-obvious lesson, HARVEST it back into a playbook — the card review isn't done
   until the lesson is filed. More stacks → more playbooks.

## Standard card sequence

1. **Scaffold + CI/CD** — repo, deploy pipeline, `/healthz` on a public URL. The scaffold
   picks the spec-serving mechanism (FastAPI: free at `/docs` + `/openapi.json`; other
   stacks: choose the generator in the ADR) — API docs are plumbing, not a later feature.
2. **Vertical slice** — one contract endpoint + one ugly page calling it, deployed.
   From this card on, `/docs` is LIVE on the deployed URL and shows the endpoint.
3. **Backend cards** — one endpoint-group per card, built TO the contract.
   **Swagger lands WITH the API**: every backend card's verify includes "the card's
   endpoints appear in the live `/docs` with correct request/response schemas" — its
   done-evidence includes the docs URL. Docs are never a catch-up card.
4. **Contract-test card** — automated suite hitting EVERY contract endpoint with edge +
   failure cases against the deployed API. The objective "feel safe" gate before UI.
   If the framework serves OpenAPI (FastAPI: `/openapi.json`), the suite ALSO asserts
   every `flow/05-contract.md` endpoint exists in the live spec with matching shapes —
   planning contract and runtime swagger must never drift.
5. **UI mock card** — static HTML, real copy, no logic/framework, rendered per `DESIGN.md`
   (its tokens + patterns; the mock IS the design review). Done-evidence = the operator
   viewed it in a browser and approved. Iterate here: mock retries cost seconds,
   framework retries cost deploys.
6. **Frontend cards** — implement the approved mock, consuming the contract, reviewed
   against `DESIGN.md`.
7. **E2E card** — automated browser test over the DEPLOYED app covering the PRD's user
   actions; its run doubles as verify-live.

## PR & merge protocol

Once the scaffold card lands, **main = deployable** (auto-deploy watches it). From then on:

1. **Branch per card**: `card/C-NNN`, serial or parallel alike. No direct commits to main.
2. **Commits**: plain ASCII messages (smart quotes / arrows can break CI+deploy hooks),
   prefixed with the card id (`C-003: resident reply endpoint`), one logical change each.
3. **PR per card** when the repo has a remote: title = the card's title; body = the card's
   scope + the verify outputs (paste real runs). The card review — diff vs scope, vs
   allowed-files, vs contract shapes, vs DESIGN.md for UI — happens ON the PR diff,
   BEFORE merge. A card with failing verify steps does not get a PR.
4. **Merge rules**:
   - Merge in card-number order (deps guarantee order makes sense).
   - After `gh pr create`, pushing more commits is a trap on squash-merge — trailing
     commits can silently drop. If you must push post-create, re-check the PR's commit
     list before merging, and verify the merged SHA on main contains every change.
   - Delete the branch (and worktree) after merge — never with unmerged work.
5. **Merge ≠ shipped.** After merge: deploy runs → verify the change on the LIVE URL
   (deploy-success is not proof the surface changed). Only then does the card's
   `## Evidence` get its world-state proof and `status: done`.
6. **Auto runs**: the planner opens the PR, reviews the diff, merges green cards without
   asking (Tier-A), and logs PR URL + merged SHA per card in AUTO-LOG.md. A red review
   goes back to a fresh subagent (two-strikes rule applies).
7. **No remote?** Local-only projects keep the same shape minus the PR: branch per card,
   review the diff before merging to main, same live-verify rule.

## Debt (deliberate gate-skips)

Reordering past the standard sequence or skipping a gate is a legitimate OPERATOR call
(demo-first, riskiest-first). But a skipped gate is a loan, and loans get written down:

1. Every deliberate skip opens a line in `DEBT.md` (create it on first use):
   `- [ ] DEBT: <what was skipped> — <the exposure, concretely> — close before: <named
   condition, e.g. "any real user touches this"> — opened <date> (cards: C-NNN…)`
2. **Security-class skips** (auth, public exposure of admin surfaces, tenancy, payments)
   are NEVER silent and never planner-decided: the operator explicitly accepts the
   exposure, in writing, in the DEBT line. In auto runs this is a Tier-C halt.
3. A debt's close condition is checked at every retro and before anything is given to a
   real user. Closing a project run with open security debt requires an explicit
   operator acknowledgment — "temporary" is one forgotten step from production.
4. Cards blocked by a debt (built but can't honestly reach done-evidence) stay
   `todo` with PARTIAL evidence naming the debt — never half-done, never rounded up.

## Parallel builds (worktree protocol)

Cards declare `deps:` (card ids, or "none"). `bash .claude/skills/flow/runner/flow.sh ready`
computes which todo cards have deps met AND no allowed-files overlap — only those may run
in parallel. The runner advises; the OPERATOR dispatches. Rules:

1. One card = one worktree = one session:
   `git worktree add ../<project>-C-NNN -b card/C-NNN`
2. A session in a worktree obeys its card's allowed-files exactly (overlap was checked
   against the card text — drifting outside it breaks the parallel-safety guarantee).
3. Merge back in card-number order, one at a time: `/flow check C-NNN` passes →
   merge to main → run the merged app once (deps-done means INTERFACE done, not proven
   integration) → only then merge the next. Conflicts on merge = the overlap check was
   gamed; stop and re-plan.
4. Remove the worktree after merge: `git worktree remove ../<project>-C-NNN`.
5. Cards whose verify needs the deployed app (contract-tests, e2e) are SERIAL by nature —
   don't parallelize them.

## Forbidden

- Building two cards in the SAME worktree/session, or in parallel without `flow.sh ready`
  marking them safe (planning all cards up front is fine).
- Editing `_templates/` or `flow.sh` during a project run.
- Frontend code before the UI mock card is approved.
