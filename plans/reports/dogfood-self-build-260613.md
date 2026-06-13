# Dogfood report — /flow building /flow (2026-06-13)

We ran the just-built `/flow` skill (the global install, as the stable driver) to plan and
build an improvement to `/flow` itself, in an isolated git worktree on branch
`dogfood/self-build`. Target idea: **project-type awareness** (web | cli | library | skill).
Mode: `work` (AI drafts, operator signs off scope). This is the live test of whether `/flow`
is good enough to develop itself — and the evidence if it is not.

## Verdict

**Success — the machinery is sound; the methodology needed project-type adaptivity (now fixed).**
- `/flow`'s engine, gate-honesty, growth-rule, debt ledger, and agent integration all worked
  correctly on a real task.
- It honestly surfaced that the buildflow *content* assumes a web app. We fixed the core of
  that, validated by the dogfood's own success metric.

## What worked (the harness held)
- **Gate-honesty:** the Research gate refused to let us fake market research — we could not
  find 3 real online complaints or a GTM channel for an internal tool, so per /flow's own
  anti-fabrication rule those boxes stayed unchecked and the gate blocked. Correct.
- **Agent integration:** Research delegated to a `researcher` agent (as the stage->agent map
  prescribes); it did real research (Spec Kit ~90k*, BMAD ~46.7k*, Tessl, Kiro $20-200/mo).
- **Growth-rule + debt:** all 5 frictions were recorded as durable backlog items; #2 and #5
  were later closed with actual outcomes (predicted -> shipped). Debt skips were logged.
- **Stages that fit cleanly:** Scope (impact x grade), PRD (numeric metric + pain->feature),
  ADR (with honest N/A-adaptation for auth/deploy). Contract's PREAMBLE already adapts to
  CLI/plugin/pipeline — better than predicted.

## The 5 findings (evidence)
1. **Research gate assumes a market-facing product** — items "3 online complaints" + "first-10-users channel" cannot be honestly satisfied for an internal/non-web build. (backlog #1, deferred — needs gate-template variants.)
2. **No mechanical skip-with-debt path** — an operator-accepted gate skip still hard-blocked `next`. **FIXED:** `flow.sh skip <stage> --reason` (stage-matched DEBT, non-security). (backlog #2, closed.)
3. **"Forbidden: edit flow.sh during a run" is ambiguous when the product IS a build tool** — resolved in practice by worktree isolation (global driver vs worktree product); the rule text should clarify. (backlog #3, documented.)
4. **Contract gate wording + OpenAPI section are web-only** despite the adaptive preamble (says "every endpoint", "auth: public/token/admin"). **PARTIALLY FIXED:** `references/project-types.md` + per-type guidance; the template wording itself is tracked. (backlog #4.)
5. **`next` and `card` disagreed on "planning complete"** for a debt-skipped stage. **FIXED:** `cmd_next` uses `planning_complete`, which now tolerates debt-skips. (backlog #5, closed.)

## What we shipped (merged to master, live install updated)
- `flow.sh project-type [web|cli|library|skill]` + per-type **done-evidence** (CLI: installs+invoke+exit code; library: API+coverage; skill: install + a real /flow run).
- `flow.sh skip <stage> --reason` — hardened after review: the contract (05) is **never** skippable (it is adapted, not skipped); the DEBT must **name the stage**; a security-class reason HALTS.
- `planning_complete` tolerates debt-skipped stages; `next`/`card` agree.
- `references/project-types.md`; **+20 tests (66 total; 46 pre-existing stayed green).**

## Reviews
2 code-review passes on the v2 code. The second found 2 HIGH security issues in the first
cut of `skip` (any-DEBT bypass + paraphrasable keyword guard could skip the contract/auth
seam). Both fixed with stage-identity guards + stage-matched DEBT, then re-tested.

## Honest remaining gaps (tracked, not hidden)
- Research-gate variant for internal/non-web (backlog #1) — deferred.
- Contract template *wording* still says "endpoint/auth" (backlog #4) — guidance added, template unchanged (editing templates mid-run is forbidden; do it as its own change).
- The dogfood's full planning artifacts + history live on branch `dogfood/self-build`.

## Bottom line
You were right: it was valuable either way. `/flow` built a real, reviewed, tested
improvement to itself and is now better at building non-web projects than it was this morning.
