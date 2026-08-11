---
phase: 2
title: "Attestation execution authority and redaction"
status: completed
priority: P1
effort: "1.5-2d"
dependencies: [1]
---

# Phase 2: Attestation execution authority and redaction

## Context links

- [Plan overview](./plan.md)
- [Phase 1 contract](./phase-01-contract-freeze.md)
- `skills/flow/runner/flow.sh:251-255,2576-2605,3915-4012`
- `DEBT.md:3`
- `tests/test_flow_eval.sh:126-131`
- `tests/test_flow_usage_log.sh:21-41,628-637`

## Overview

Build only the bounded execution/redaction primitive required by attestation.
The optional Python/SQLite harness remains advisory and unchanged in v0.28.
Global harness command migration, graph-wide durable sanitization, and DB
permission cleanup move to a later independent maintenance plan.

## Requirements

### Functional

- One argv-safe supervisor runs committed attestation owner/oracle executables.
- Every run is pinned to the logical checkout root, owns a process group,
  streams stdout/stderr through independent and combined byte caps, and
  terminates the whole group on timeout/cap/signal.
- TERM is followed by bounded grace, KILL, and a confirmed wait before terminal
  receipt publication.
- Stock-platform capability is probed. If a reliable process-group supervisor
  is unavailable, live verification and auto activation fail closed with an
  actionable unsupported result; they never run unbounded.
- Diagnostics are redacted and bounded before terminal/event output; no raw
  command output or argv after `--` is persisted.
- The existing usage logger records only attestation subcommand, subject ID,
  result class, and duration bucket.

### Non-functional

- Bash + Git remain the enforcement floor; no Python/SQLite requirement.
- Bash 3.2 and Git Bash compatible parsing.
- No raw command output, inherited environment, credential, target URL, or
  full argv is persisted.
- Existing harness behavior and `FLOW_HARNESS_STRICT` semantics stay unchanged.

## Architecture

### Attestation process supervisor

```text
committed owner/oracle executable
   -> validate tracked object/mode + exact argv
   -> create process group/session or refuse unsupported
   -> cwd=<current logical checkout root>
   -> stream stdout/stderr with bounded counters
   -> timeout/cap: TERM group -> grace -> KILL group -> wait
   -> parse only the closed producer/oracle result
   -> redact bounded terminal diagnostic
   -> return closed result code
```

The exact supervisor mechanism is a Phase 2 deliverable, not an assumption.
Linux CI must prove the runnable implementation; macOS and Git Bash CI must
either prove equivalent process-tree cleanup or prove deterministic
fail-closed capability refusal. The known macOS timeout DEBT must be closed
with native evidence before claiming live auto support there.

### Redaction/logging boundary

The attestation runner owns a small scalar sanitizer for receipt fields and
terminal summaries. The general usage logger receives a pre-redacted event
shape and never sees owner argv, oracle output, credentials, or environment.
Project and global event sinks are both in the privacy corpus.

## File inventory

| Action | File | Intended change | Rough size | Test impact |
|---|---|---|---:|---|
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/runner/flow.sh` | Capability probe, bounded process-group supervisor, redacted logging | 100-170 LOC | Runner + eval timeout regressions |
| Create | `/home/manhquy/Downloads/flow-skill/tests/test_flow_attestation_supervisor.sh` | Timeout, descendants, streaming cap, signal, logging privacy, unsupported-platform refusal | 220-320 LOC | Register in run_all |
| Modify | `/home/manhquy/Downloads/flow-skill/DEBT.md` | Close macOS timeout debt only with native evidence; otherwise document unsupported live-auto capability | <20 LOC | Contract |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/run_all.sh` | Register new suite atomically | <5 LOC | Full |

## Interface checklist

- [ ] One helper owns attestation owner/oracle execution.
- [ ] No owner command string reaches `eval`, `sh -c`, or shell re-parsing.
- [ ] Verification cwd is the current logical checkout root.
- [ ] Timeout and output limits validate positive bounded integers.
- [ ] Timeout, signal, cap breach, spawn failure, and non-zero are distinguishable.
- [ ] Process descendants are gone before terminal receipt publication.
- [ ] Output caps are enforced while streaming, before memory/disk exhaustion.
- [ ] Project/global usage logs contain no argv after `--`.
- [ ] Existing `FLOW_HARNESS_STRICT` caller behavior is unchanged.
- [ ] Python-absent engine path is unchanged.

## Dependency map

```text
phase 1 producer contract
          |
          v
attestation supervisor ----> receipt live-run semantics (phase 4)
          |
          +----> bounded diagnostics + redacted usage events
```

## Test scenario matrix

| Priority | Scenario | Expected |
|---|---|---|
| Critical | Owner manifest attempts shell metacharacters/string command | Refuse; command not executed |
| Critical | Verify sleeps beyond timeout | Whole process group terminated; no pass result |
| Critical | Command emits endless output | Streaming cap terminates group before unbounded capture |
| Critical | Runner is SIGKILLed after spawn | Attempt marker remains; old pass cannot be consumed |
| High | Command assumes attacker-controlled cwd | Runs from project root only |
| High | Probe spawns background child | Child is gone before result publication |
| High | Live argv contains opaque credential/private URL | Neither project nor global event log contains it |
| High | Reliable supervisor unavailable | Auto/live refuses; manual remains usable |
| Medium | Python absent | Core `flow.sh` still gates/scaffolds |

## Implementation steps

1. Add failing tests for process-group timeout, descendant cleanup, streaming
   output cap, signal handling, unsupported capability, cwd, and both event sinks.
2. Implement a capability probe and one argv-safe supervisor in `flow.sh`.
3. Pin cwd to the logical checkout and strip inherited Git redirection variables.
4. Implement bounded scalar/diagnostic sanitization and structured logging that
   excludes owner argv/oracle output.
5. Close the macOS DEBT only when native cleanup evidence exists; otherwise
   retain the debt and make live-auto refusal explicit.
6. Run the focused supervisor/runner/eval timeout suites and full `run_all.sh`.

## Todo

- [ ] Supervisor tests written first
- [ ] Process group + streaming cap implemented
- [ ] Attempt/logging privacy boundary proven
- [ ] Unsupported platform refusal proven
- [ ] Full suite green

## Success criteria

- [ ] No attestation command string reaches a shell interpreter.
- [ ] Verification cannot hang or leave descendants on supported capability.
- [ ] Unsupported capability is fail-closed, never an unbounded fallback.
- [ ] No attestation secret/argv/output persists in receipt or event sinks.
- [ ] Core runner remains functional with Python absent.

## Risk assessment

| Risk | Mitigation |
|---|---|
| Portable process-group support differs | Capability probe; support or explicit fail-closed refusal |
| Output cap races producer | Streaming byte counters terminate the group at threshold |
| Logging leaks argv | Structured event shape never receives argv/output |

## Security considerations

- Diagnostics never echo the full owner command, output, or environment.
- Target-defining environment is forbidden; credential environment is inherited
  only as documented and never persisted.

## Rollback

Revert supervisor/logging changes. Existing optional harness rows and schemas
remain intact because v0.28 does not migrate them.

## Next steps

Phase 4 may use the hardened timeout/redaction contract after this phase is
green. Phase 3 can proceed independently after Phase 1.
