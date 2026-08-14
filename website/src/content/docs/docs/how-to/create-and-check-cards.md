---
title: "Create and check cards"
description: "Cut a build card, build only what it allows, and pass the check gate with real world-state evidence."
---

A card is one scoped build session. This is the loop you will spend most of your time in
once planning is complete.

## Prerequisite

`/flow card` refuses until all six planning gates have passed or carry a matching open debt
line. If it refuses, run `/flow` and fix the stage it names.

## Cut the card

```
/flow card
```

This creates the next `cards/C-NNN.md`. Before you write a line of code, read it and fill
in what the template asks for:

| Section | What it is for |
|---|---|
| `## Allowed files` | The only paths this session may touch. This is the blast radius. |
| `implements:` | The PRD requirement ids (`FRn`) this card claims. |
| `## Verify` | Commands you will actually run, not aspirations. |
| `## Independent test` | The user-visible slice proof — or `infra` / `none` if genuinely neither. |
| `## Evidence` | Left empty until done. Real world-state proof goes here. |
| `risk` / `risk-reason` | The risk class, needed before any autonomous run. |

A leftover `[FILL]` in `## Independent test` fails `check`, so do not skip it.

## Load prior knowledge first

```
/flow recall
```

Open debt, the last retro, the previous card's scope, harness friction, and promoted
playbooks. Treat the output as context to apply, not noise.

## Optionally mark it in flight

```
/flow card start C-001
```

This records the card as in-progress in a portable `cards/.inflight` registry so it shows up
in `/flow status`. It never touches the gated `status:` field, and it is entirely optional —
hand-editing still works.

## Build inside the lines

Three rules bind every build session:

1. **One card per session.** Not two, and not two in parallel until `/flow ready` says they
   are safe.
2. **Touch only `## Allowed files`.** Drift outside that list is exactly what the reviewer
   looks for.
3. **The contract is the seam.** Build to the shapes stage 05 declared. If a shape is wrong,
   amend the contract first, then the code.

For a UI card, the mock card must be approved before any frontend code, and `/flow design
<file>` runs the mechanical `DESIGN.md` check on it.

## Check which cards are safe to run in parallel

```
/flow ready
```

Lists buildable todo cards with a parallel-safety hint based on overlapping allowed files.

## Check the card

```
/flow check C-001
```

The mechanical layer validates the card first: status validity, remaining `[FILL]`
placeholders, required sections, and whether `## Evidence` is actually populated. Only after
it passes does the semantic review start — diff versus scope, allowed-files drift, contract
shape conformance, `DESIGN.md` for UI, and whether the evidence is genuinely world-state.

The failure you will meet most often:

```
  [x] status is 'done' but ## Evidence is empty (paste world-state proof: URL/curl/DB row)
FAIL: C-001 has gate violations (above).
```

This fires even when the build is finished and every test is green. "Tests pass" and "merged"
are mid-pipeline states.

## Paste evidence that counts

What counts depends on the project type:

| Project type | Evidence that passes |
|---|---|
| `web` | The live deployed URL plus real `curl` output |
| `cli` | A real invocation with its actual output and exit code |
| `library` | The public API imported, a usage example that runs, coverage threshold met |
| `skill` | Installed into the skill home, plus a real run reaching its done-definition |

Process artefacts — an approved PR, a green CI badge, release notes — are not evidence. The
mechanical floor rejects process-only prose, so a card cannot be marked done on paperwork.

## Flip it to done

```
/flow check C-001
PASS: C-001 is valid (status: done).
```

Or let the CLI own the flip:

```
/flow card done C-001
```

`card done` applies the same done-rules as `check` and **reverts** the flip if the gate
fails, so it can never produce a hollow done. Hand-editing `status: done` and running
`check` remains equally valid.

## See also

- [Done means world-state evidence](/docs/explanation/done-evidence)
- [Skip a gate with debt](/docs/how-to/skip-gate-with-debt)
- [Run an auto build](/docs/how-to/run-auto-build)
