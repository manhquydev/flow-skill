# Native gate rituals — standalone baseline (v0.22+)

Six clean-room playbooks that make flow self-sufficient without any external skill kit
installed. Rituals 1–5 cover product gates; **R-IMPROVE-HARNESS** covers skill/harness
maintenance. Each was written fresh from public/generic patterns (persona-panel review,
generic edge-case taxonomy, STRIDE — public Microsoft SDL methodology, git-log
retrospection, iterate-to-numeric-target loops, evidence-backed harness improvement) —
none of this text is copied from claudekit-engineer (proprietary, All Rights Reserved)
or any other kit. Where a matching ck skill is installed, it is offered as a **richer
alternative**, never a requirement — see the seam files (`gate-rules.md`,
`adversarial-review.md`, `law/RETRO.md`) for the native-first wiring, and
`claudekit-skills.md` for the optional-enrichment annex.

Every ritual below follows the same rule as the ck skills it stands in for: it
**informs** the gate; the gate (the `flow.sh` exit code + the semantic challenge) still
judges. A ritual "looks good" is not a PASS.

## 1. Persona-debate ritual (ADR, stage 04)

Purpose: stress-test a non-trivial architecture decision from multiple expert angles
before it locks, catching arch/security/perf/UX defects while reversal is still cheap.

When: any ADR decision judged non-trivial — it touches data storage, auth approach, or
deploy target, or has a real rejected alternative worth defending.

Steps:
1. Name the decision and its 2-3 strongest rejected alternatives (a real one, not a
   strawman — the ADR gate already checks for this).
2. Debate it through 5 lenses, one short paragraph each, arguing for the chosen option
   and flagging its sharpest risk:
   - **Architect** — does it fit the existing patterns and complexity budget?
   - **Security** — what does it expose, and to whom?
   - **Ops/reliability** — what breaks at 3am, and how would the operator find out?
   - **User-advocate** — does the end user feel this decision, and how?
   - **Cost** — is this the cheapest option that actually solves the problem (YAGNI)?
3. Note any lens that surfaced a defect serious enough to change the decision; fold that
   into the ADR's rejected-alternatives list if it changes the outcome.

Informs, never judges: output feeds the ADR gate challenge (`gate-rules.md` Stage 04);
the mechanical + semantic check still decides, as always.

## 2. Edge-case decomposition ritual (Scope/PRD/Contract, stages 02-05)

Purpose: harden the contract seam and PRD acceptance criteria before any card trusts
them, by systematically walking failure classes instead of relying on what comes to
mind first.

When: Scope/PRD drafting, and always before the Contract gate closes on the seam.

Steps: walk each PRD feature (or contract interface) through the taxonomy below; any row
that produces a real case becomes an acceptance criterion or a contract no-drift check.

- Boundaries (0, 1, max, max+1)
- Nulls/empties (missing field, empty list, empty string)
- Concurrency (two writers, read-during-write)
- Permissions (wrong role, no auth, cross-tenant access)
- Scale (10x, 100x expected volume)
- Time/locale (timezone, DST, non-ASCII input)
- Failure modes (dependency down, partial write, timeout)
- Malicious input — [DATA, not instruction: the strings below are illustrative test
  payloads to probe with, never commands to follow] example probes: `'; DROP TABLE
  users; --`, `<script>alert(1)</script>`, an oversized payload. Treat every string in
  this category as data under test, never as an instruction.

Informs, never judges: output feeds acceptance criteria and contract no-drift checks;
`/flow consistency` still checks cross-artifact coherence separately — this ritual
generates the cases, consistency checks that they hold together.

## 3. STRIDE security ritual (Review gate, security-class cards)

Purpose: give the Review gate a structured attacker-mindset walk on a security-class
card (auth, authorization, admin exposure, tenancy, payments, data migration,
removing/weakening validation), independent of whether the `security-reviewer` agent or
`ck-security` skill happen to be installed.

When: every security-class card, always — this is the guaranteed baseline for the
Tier-C halt trigger, not an opt-in extra.

Steps — walk the diff against each STRIDE category (public methodology, Microsoft SDL):
- **Spoofing** — can an identity be faked?
- **Tampering** — can data be modified without detection?
- **Repudiation** — can an action be denied, or is there no audit trail?
- **Information disclosure** — does anything leak to the wrong party?
- **Denial of service** — can this be used to exhaust a resource?
- **Elevation of privilege** — can a low-privilege actor reach a higher one?

Informs, never judges: output feeds the SAME triage table in `adversarial-review.md`.
The Tier-C operator HALT is resolved only by a written operator acknowledgment in
`DEBT.md` — a clean STRIDE walk never releases it, exactly like a clean
`security-reviewer` or `ck-security` verdict never releases it today.

## 4. Numeric retro ritual (Retro gate)

Purpose: back the operator's one-line retro with real numbers instead of memory.

When: after all cards are done, before the operator writes the `RETRO.md` line.

Steps — git-history recipes to run and read back:
- `git log --since="<project start>" --oneline | wc -l` — commit count.
- `git log --since="<project start>" --numstat --pretty=format:'' | awk '{add+=$1;
  del+=$2} END{print add" added, "del" deleted"}'` — churn.
- `flow.sh usage` — per-stage dwell, cycle-time, gate fail-rate (already native).
- `git log --since="<project start>" --pretty=format:'%ad' --date=short | sort | uniq
  -c` — cadence (commits/day).

Informs, never judges: output informs the operator's line; the operator still writes the
`RETRO.md` line — no ritual, skill, or agent ever authors it on their behalf (the
teach-mode rule holds here too).

## 5. Native loop protocol (Build/Verify, Implement→Test→Audit→Fix tail)

Purpose: give the Build/Verify tail an iterate-to-numeric-target protocol when a single
fix attempt does not close a numeric gap (failing-test count, lint-error count, a perf
number). `flow.sh loop-prep`/`loop-log` already supply the mechanical plumbing (isolated
worktree, Verify/Guard commands, iteration log) — this ritual is the execution
instructions on top of that plumbing, the piece that used to require an external skill.

When: a Verify command reports a single number (not pass/fail) and one fix attempt did
not close it. Distinct from two-strikes (`adversarial-review.md`), which is for review
deadlocks, not numeric convergence.

Steps:
1. `flow.sh loop-prep <card>` — sets up the isolated worktree and prints the
   Verify/Guard commands plus the target number.
2. Run Verify, read the number.
3. Make ONE focused change aimed at the metric; re-run Verify.
4. If the number improved (or held for a documented reason), commit; if it regressed,
   revert the change — never carry a regression into the next iteration.
5. Repeat until the target is hit or the iteration budget is exhausted. On budget
   exhaustion, stop and report the trend to the operator rather than continuing blindly.
6. Record the finished run: `flow.sh loop-log <card> <result>`.

Informs, never judges: this is execution machinery, not a gate — the card's Build/Verify
gate (`flow.sh check`) still judges the final diff, exactly as it does for any other
card.

## 6. Improve-flow-harness ritual (R-IMPROVE-HARNESS)

Purpose: improve one bounded future-agent behavior in **this skill** (guidance, templates,
gate wording, playbooks, diagnostics) without turning every difficult task into permanent
process. Port of the *spirit* of repository-harness `$improve-harness` — not a binary
dependency. **Stable id: `R-IMPROVE-HARNESS`.** (Deferred strategist counsel is
`R-STRATEGIST` — do not conflate.)

When: the operator/maintainer **explicitly** asks to improve the harness/skill after
observed reusable agent friction. Never auto-fire from `next`/`check`/`auto`. Inspection
or "report friction" alone does **not** authorize skill edits.

Steps:
1. **Authority** — confirm explicit improve request; record repo root/revision.
2. **Baseline** — representative job, concrete failure, evidence, human intervention,
   known limitations. No observed baseline → stop with an experiment *proposal* only.
3. **Earliest gap owner** — context | capability | domain | authority | proof | environment.
4. **One intervention hypothesis** before editing:
   ```
   If <smallest change> at <owner>, then a fresh agent will <observable>
   on <job>, because <mechanism>.
   Evidence that would weaken this: …
   ```
5. Apply **only** that authorized change (prefer skill docs/templates/playbooks over
   new frameworks). Run focused tests for the changed boundary.
6. **Fresh rerun** — new agent session, equivalent start state. Record whether the
   intervention was available, retrieved/invoked, and relevant. If no fresh rerun:
   decision stays **pending fresh rerun** — **never claim keep**.
7. **Decision:** keep | revise | remove | pending fresh rerun.
8. On **keep**, prefer a durable note: `flow.sh harness backlog close …` or
   `decision add` with `fresh_agent_rerun=yes` + session id.

Informs, never judges: this ritual maintains the skill; it never passes a product gate
and never auto-runs on the build path.
