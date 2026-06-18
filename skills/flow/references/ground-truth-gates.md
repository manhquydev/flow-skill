# Ground-truth gates

At any decision point that advances, merges, or marks done, the gate condition MUST be a
mechanical signal — not the model's opinion that it's fine. LLM self-assessment is advisory
and used only to add color, never to pass a gate.

## The signal per gate

| Decision | Ground-truth signal | NOT acceptable as the gate |
|---|---|---|
| Stage 00-05 advance | `flow.sh next` exit 0 (no `[FILL]`, no unchecked box) | "the artifact looks complete" |
| Card valid | `flow.sh check C-NNN` exit 0 | "I filled the card" |
| Card behavior works | the card's `## Verify` steps RUN for real (curl/click/command + expected output) | "the code should work" / "tests would pass" |
| Story proof | `flow.sh harness story verify <id>` -> `verify_command` exit 0 | "I wrote tests" |
| Build merged-safe | review green (adversarial) + `flow.sh check` pass | "the diff is small" |
| Card DONE | deploy ran + **live URL verified as a user** (world-state evidence pasted) | "merged" / "deploy succeeded" / "tests pass" |
| Contract not drifted | contract-test card asserts every endpoint exists in live `/openapi.json` with matching shape | "backend and UI agree" (they don't, silently) |

## Rules
1. **The model never grades its own gate.** Use `flow.sh` exit codes and real command
   output. If a tool can produce a number/exit code, that is the gate.
2. **"Tests pass" is mid-pipeline, not done.** Done = a surface that changed in the world,
   verified live. (buildflow rule 3.)
3. **Self-assessment is color, not verdict.** An agent saying "looks correct" can accompany
   a green signal; it can never substitute for one.
4. **A red signal stops the run.** No "probably fine" override. Fix or open debt.
5. **Capture the proof.** Paste the real curl/URL/exit into the card `## Evidence` and the
   harness `trace` — so the next session sees ground truth, not a claim.

## Bug-fix cards: prove the test was tied to the bug
When a card's job is fixing a bug/regression (not new behavior), a passing test is not yet
ground truth — a test written after the fix can pass without ever having exercised the bug. The
ground-truth signal is the **red→green** pair: with the fix reverted the new test FAILS, with the
fix restored it PASSES. Paste both runs into `## Evidence`. The reverted-failure must fail **for the
bug's reason** — its message names the bugged behavior/output (a wrong value, a missing rejection, a
bad status), NOT an `ImportError`/compile/setup/typo error. A revert that errors before reaching the
asserted behavior proves nothing; if you see a collection/import/syntax error on revert, the test is
not yet tied to the bug — fix the harness and re-run. This is a *technique for this card class*, not a
project-wide test-first law — flow stays contract-/evidence-first. It is cleanest for
`cli`/`library`/`skill` cards where a fix reverts in isolation. For a `web` card whose fix genuinely
cannot revert cleanly (migration, stateful backend), the waiver is **not** agent-self-asserted: name
the **specific** blocking dependency in `## Evidence` (e.g. "irreversible migration `0042_*`",
"shared session store") and still paste a live `## Verify` reproduction that shows the **original
symptom before** the fix and its absence **after** — a bare post-fix green is not the signal.

## Why
LLM-as-judge is useful for triage and prioritization but unreliable at the exact moment a
mistake becomes expensive (a merge, a deploy, a "done"). The whole buildflow philosophy —
"done = proof in the world" — is ground-truth gating made into a method.
