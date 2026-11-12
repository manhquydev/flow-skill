# Plan: Closed Machine JSON Report for Gate Scan (`flow gate [--card C-NNN|<stage>] --json`)

## 1. Consumer & Observable Baseline
Host agents and orchestrators need a closed, machine-readable gate report to inspect gate readiness without fragile terminal prose parsing.

**Current baseline (`flow gate`):**
- `flow gate <stage>` prints `GATE stage <stage>:\n  clean` (exit 0) or scan findings (exit 1).
- `flow gate --card C-NNN` prints `GATE card C-NNN:\n  clean` (exit 0) or scan findings (exit 1), or exits 2 if the card is missing or invalid.
- Passing `--json` is rejected as an invalid stage name with exit 2 (`usage: /flow gate <stage: ...> | /flow gate --card C-NNN`), or ignored if placed after `--card C-NNN`.
- `scan_gate` in `skills/flow/runner/flow.sh` is the single source of truth for gate checks, encompassing unchecked checkbox detection (`- [ ]`), unfilled placeholders (`[FILL]`), and mid-tier smell checks (`_scan_midtier`).

## 2. Roadmap Context & Parked Scope
- This work fulfills the `gate` verb slice of **Wave 5 Item 1 (G4 remainder)** from `plans/research/agentkit-flow-upgrade/wave5-plan.md`.
- **Parked scope:** The `debt list --json` and `usage --json` envelopes from Wave 5 Item 1 are explicitly parked for separate, subsequent slices. This implementation focuses strictly on `flow gate <stage> --json` and `flow gate --card C-NNN --json`.

## 3. Envelope Specification & Target Conventions
The JSON report emits a single closed JSON object on stdout:

```json
{
  "schema_version": 1,
  "kind": "gate.report",
  "target": "<target>",
  "clean": true,
  "findings": []
}
```

Or with findings:

```json
{
  "schema_version": 1,
  "kind": "gate.report",
  "target": "<target>",
  "clean": false,
  "findings": [
    "[x] unchecked gate boxes:",
    "L4:- [ ] The pitch below is 3 sentences, no more",
    "[x] unfilled [FILL] placeholders:",
    "L10:[FILL: sentence 1 — who has the problem]"
  ]
}
```

### Target Convention
- **Stage scan (`flow gate <stage> --json`):** `target` is the stage name without `.md` extension, e.g. `"00-idea"`, `"01-research"`, `"02-scope"`, `"03-prd"`, `"04-adr"`, `"05-contract"`.
- **Card scan (`flow gate --card C-NNN --json`):** `target` is the normalized card identifier, e.g. `"C-001"`.

### Closed Display-Only Rule
- No progression fields or actions (`next_verb`) are included in `gate.report`. Gates are read-only verifiers; progression remains strictly owned by `flow next` and `flow check`.

## 4. Acceptance Criteria
1. `flow gate <stage> --json`:
   - Valid stage + clean gate: stdout emits JSON with `"clean": true, "findings": []`, exit code 0.
   - Valid stage + gate violations: stdout emits JSON with `"clean": false` and non-empty `"findings"` array, exit code 1.
   - Valid stage + missing stage file: `scan_gate` detects missing file; emits JSON with `"clean": false`, `"findings": ["missing file: ..."]`, exit code 1.
2. `flow gate --card C-NNN --json`:
   - Existing card + clean: stdout emits JSON with `"target": "C-NNN", "clean": true, "findings": []`, exit code 0.
   - Existing card + violations: stdout emits JSON with `"target": "C-NNN", "clean": false, "findings": [...]`, exit code 1.
   - Nonexistent card or invalid card syntax: fails loudly with exit code 2 and usage/error string (no JSON output emitted).
3. Error handling:
   - Unknown stage name: fails loudly with usage message and exit code 2.
   - Unknown extra arguments (e.g. `flow gate 00-idea --json extra`): fails loudly with exit code 2.
   - Missing arguments (`flow gate` with no args, `flow gate --card` with no card): fails loudly with exit code 2.
4. Formatting & JSON safety:
   - Output string escaping utilizes `_json_str` from `flow.sh` for quotes (`"`), backslashes (`\`), and control characters.
   - Multi-line `scan_gate` output is preserved as discrete lines in the `findings` array without breaking JSON validity or line numbers.
   - `scan_gate` is invoked exactly once (captured into variable; no double-scanning).
5. Prose non-regression:
   - Invocations without `--json` produce byte-identical prose and identical exit codes (0 clean, 1 findings, 2 errors).

## 5. Non-Goals & Boundaries
- No changes to `scan_gate` verification rules, mid-tier checks, or gate templates.
- No changes to `skills/flow/runner/flow.sh` STOP zones (`_eval_engine_run`, `_run_with_timeout`).
- No changes to `website/`.
- No new runtime dependencies; Bash 3.2 compatibility strictly preserved.
- No semver version bumps.

## 6. Scope of Changes
- `skills/flow/runner/flow.sh`: Update `cmd_gate` to accept `--json` and emit the `gate.report` envelope.
- `skills/flow/references/command-dispatch.md`: Update `/flow gate` documentation row with `--json` option and schema summary.
- `tests/test_flow_runner.sh`: Add regression tests covering clean, violations, missing stage file, nonexistent card, unknown args, and JSON parsing.
- `CHANGELOG.md`: Record `--json` envelope addition under `[Unreleased]`.

## 7. Risk & Rollback
- Risk: Low. Changes are restricted to CLI parsing and output formatting in `cmd_gate`.
- Rollback: Revert the feature commit on branch `feat/gate-json-report`.
