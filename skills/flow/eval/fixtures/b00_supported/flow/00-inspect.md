# Brownfield assessment

## Gate
- [x] Existing behavior has been inspected with evidence.

## Evidence
Observed from `skills/flow/runner/flow.sh`:
- `cmd_next` calls `inspect_gate_clean` before the stage-index branch; a dirty
  assessment returns 1 before `cp` can unlock `00-idea.md`.
- `planning_complete` checks the same prerequisite before iterating planning stages.
- `inspect_gate_clean` accepts absent assessments (greenfield), clean assessments,
  or an explicit `00-inspect` skip recorded by the existing DEBT-guarded `cmd_skip`.

## Verdict
The inspected planning boundary fails closed for an existing dirty assessment,
including after planning begins. This static review supports proceeding only when
the assessment gate is clean or explicitly debt-skipped; it does not claim that
later planning documents prove assessment readiness.
