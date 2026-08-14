---
title: "Done means world-state evidence"
description: "Why flow refuses to accept green tests, an approved PR, or a merged branch as done, and what counts instead."
---

Every card names its done-evidence up front, and the gate demands that evidence pasted in
before the card can be marked done. "Tests pass" and "code merged" are mid-pipeline states.
They are never done.

## The failure this prevents

The most common way an agent-assisted build goes wrong is not a bug. It is a status. A card
is reported complete because the tests are green, the review is approved, and the branch
merged. Every one of those statements is true. Nobody has loaded the page.

Each of those signals measures a **proxy** for the thing you care about. Tests measure your
model of the system against itself. A merge measures agreement about a diff. Neither touches
the actual running world. Proxies drift from reality quietly, and the drift is invisible
exactly when it matters most, because all the dashboards are green.

The fix is not more proxies. It is to require one observation of the real thing.

## What counts, per project type

The project type decides the shape of the proof, and the spirit is identical in every case:
somebody interacted with the deployed reality and pasted what came back.

| Project type | Done-evidence |
|---|---|
| `web` | The live deployed URL plus real `curl` output |
| `cli` | The tool installs, and a real invocation returns the expected output and exit code |
| `library` | The public API imports, a usage example runs, coverage threshold met |
| `skill` | Installed into the skill home, and a real run reaches its own done-definition |

Set the type with `/flow project-type <type>`; the default is `web`.

## What does not count

Process artefacts, however impressive:

- an approved pull request
- a green CI badge or workflow run
- release notes describing what shipped
- a code review that found nothing
- an agent's own summary saying the work is complete

The mechanical layer enforces a floor here: a card whose evidence section contains only
process prose is rejected, so the discipline cannot be argued away in the moment. Beyond that
floor, the semantic gate asks the harder question — is this evidence the *world*, or a
description of the world?

An agent's self-assessment is specifically excluded. The ground-truth signal for every gate
is something the agent did not generate: a script's exit code, a real verify command's
output, a live check.

## Why the gate refuses an empty evidence section so aggressively

```
  [x] status is 'done' but ## Evidence is empty (paste world-state proof: URL/curl/DB row)
FAIL: C-001 has gate violations (above).
```

This fires even when the code is finished and correct. The reason is that the cheapest moment
to capture evidence is the moment you were looking at the running thing anyway. If it is
deferred, it is reconstructed later from memory, and reconstructed evidence is indistinguishable
from invented evidence.

The same reasoning drives the CLI-owned flip, `/flow card done C-NNN`: it applies the same
rules as `check` and reverts if the gate fails, so there is no code path that produces a
hollow done.

## The honest way out

If a card genuinely cannot be proven right now — the deploy target does not exist yet, the
external service is unavailable — the answer is not to weaken the evidence. It is to record
the exposure as debt, in writing, with a condition for closing it. Debt is visible and
surfaces in `recall`; a hollow done is invisible and surfaces in production.

## See also

- [Create and check cards](/docs/how-to/create-and-check-cards)
- [Project types](/docs/explanation/project-types)
- [Skip a gate with debt](/docs/how-to/skip-gate-with-debt)
