---
phase: 2
title: "PIN printer"
status: pending
priority: P1
effort: "3h"
dependencies: [1]
---

# Phase 2: PIN printer

## Overview

Print a verbatim `PIN v1` block on prose `status` and `resume` after `NEXT_VERB=`. JSON unchanged. Pin bytes live in `references/pin-v1.txt` (one home).

## Context Links

- `_emit_next` `skills/flow/runner/flow.sh:1351`
- `_emit_context_json` `flow.sh:1370` (7 keys: v,stage,gate,next_verb,card,dwell,load)
- `cmd_status` `flow.sh:888` calls `_emit_next` then gate brief
- Test A: `tests/test_flow_status_legibility.sh:41` — `NEXT ->` first content line after header blank
- SKILL.md STOP `skills/flow/SKILL.md:45` (essay; do not dump)

## Requirements

- Functional: after `_emit_next`, print pin-v1.txt verbatim (no paraphrase).
- Functional: `status` PIN bytes == `resume` PIN bytes == `pin-v1.txt`.
- Functional: `status --json` / `resume --json` schema unchanged; stdout JSON line contains none of `PIN v1`.
- Non-functional: PIN ≤80 tokens. Must not include substring `NEXT ->`. Must not instruct hosts to exec verbs.
- Non-functional: bash 3.2; no new deps. Eval engine bodies byte-identical.

## Architecture

```
cmd_status / cmd_resume
  header...
  blank
  _emit_next          → NEXT -> … \n NEXT_VERB=…
  _emit_pin           → cat pin-v1.txt (skill-dir relative)
  blank
  rest of status/resume
```

`_emit_pin` reads `$SCRIPT_DIR/../references/pin-v1.txt` (same skill-dir pattern as other refs). Missing file: print nothing + no crash (degrade); test on this repo requires the file present.

JSON path does **not** call `_emit_pin`.

## Related Code Files

- Create: `skills/flow/references/pin-v1.txt`
- Modify: `skills/flow/runner/flow.sh` (`_emit_pin` + one call after `_emit_next` so both status and resume inherit)
- Modify: `tests/test_flow_status_legibility.sh` (PIN arms)
- Modify: `skills/flow/references/command-dispatch.md` (status/resume rows: mention PIN v1 display-only)
- Do **not** modify SKILL.md, overlay files, `_eval_engine_run`, `_run_with_timeout`, `_emit_context_json` key list

## PIN v1 body (closed; copy into pin-v1.txt)

Exact STOP excerpts (RtSecurity F2/F3). Not slogans.

```
PIN v1
Never FLOW_FORCE a live session. Mechanical FAIL -> STOP.
Security-class skip/debt -> HALT until the operator accepts in DEBT.md.
Never mark a card done without pasted world-state evidence.
NEXT_VERB is advisory; never auto-exec next, card, card-start, check, fix-gate, auto, or skip.
```

Do not write `STOP lock` / `STOP hollow-done` / `without DEBT`. `--json` stays 7 keys; compact recovery is **prose** `status`/`resume`, not `--json` (disclose in command-dispatch).

## Implementation Steps

1. Write `pin-v1.txt` with the closed body above.
2. Add `_emit_pin` next to `_emit_next` (`flow.sh` ~1351). Call it from `_emit_next` **after** the two echo lines. Do not print PIN on JSON.
3. `_emit_next` callers: `cmd_status` (`flow.sh:906`) and `cmd_resume` (`flow.sh:1031` empty-events, `flow.sh:1123` full). **Also** `cmd_resume` idx<0 (`flow.sh:1010-1014`) prints `NEXT_VERB=` **without** `_emit_next` — must call `_emit_pin` there (or route that branch through `_emit_next`). Missing `pin-v1.txt` is fail-loud (nonzero or stderr), not silent empty. JSON uses `_emit_context_json` only.
4. Tests in `test_flow_status_legibility.sh`:
   - status and resume PIN blocks identical on a staged project
   - `resume` on idx<0 (empty FLOW_PROJECT_ROOT) still prints PIN v1
   - `grep -F` pin-v1.txt against status/resume PIN
   - `NEXT ->` still first content after header (existing A)
   - JSON line has no `PIN v1` and still parses 7 keys
   - extras on status still exit 2
5. command-dispatch status/resume cells: one sentence "PIN v1 after NEXT_VERB, display-only, do not exec."
6. Diff `_eval_engine_run` and `_run_with_timeout` against HEAD — empty.

## Tests Before (TDD)

Add failing PIN assertions to `test_flow_status_legibility.sh` first; they fail on HEAD; then printer.

## Todo

- [ ] Resume idx<0 (`flow.sh:1010`) prints PIN (not only `_emit_next` callers)
- [ ] pin-v1.txt
- [ ] `_emit_pin` + wire
- [ ] tests green
- [ ] command-dispatch pointer
- [ ] eval-engine bodies unchanged

## Success Criteria

- [ ] `bash tests/test_flow_status_legibility.sh` exit 0 including new PIN arms
- [ ] `status --json` keys exactly `v,stage,gate,next_verb,card,dwell,load`
- [ ] `git diff` on `_eval_engine_run` / `_run_with_timeout` empty

## Risk Assessment

- Folding PIN into `_emit_next` if a third caller exists. Signal: grep shows extra caller. Response: explicit calls from status/resume only.
- Test A "first content line" if PIN is printed *before* NEXT. Signal: test A fail. Response: PIN after NEXT_VERB, never before.
- Hosts treat PIN as commands. Signal: pin contains exec verbs as imperatives. Response: wording "Do not exec it."
- `cat` of pin file on Windows CRLF. Signal: PIN mismatch. Response: strip CR like other flow readers (`tr -d '\r'`).

## Security Considerations

- Stdout pin is display-only; not a capability token (same as NEXT_VERB).
- Do not put secrets in pin-v1.txt.
- Compaction-Eviction: pin is re-injected only if status is invoked. Disclose in command-dispatch; flow does not hook compact.
