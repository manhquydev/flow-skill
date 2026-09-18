# Cook PIN printer — Phase 2

Date: 2026-09-18
Plan: `plans/260918-1052-constraint-pin`
Phase: 2 PIN printer

TDD first: PIN assertions added to `tests/test_flow_status_legibility.sh` (section M) while HEAD printer was absent. Then `_emit_pin` + `pin-v1.txt`. Did not edit SKILL.md, overlay refs, `_eval_engine_run`, `_run_with_timeout`, or the JSON key list.

## PIN v1 body (`skills/flow/references/pin-v1.txt`)

```
PIN v1
Never FLOW_FORCE a live session. Mechanical FAIL -> STOP.
Security-class skip/debt -> HALT until the operator accepts in DEBT.md.
Never mark a card done without pasted world-state evidence.
NEXT_VERB is advisory; never auto-exec next, card, card-start, check, fix-gate, auto, or skip.
```

No `STOP lock` / `without DEBT`. No substring `NEXT ->`.

## Wire

- `_emit_pin` reads `$SCRIPT_DIR/../references/pin-v1.txt`, `tr -d '\r'`, prints verbatim. Missing file: `FAIL: PIN file missing: …` on stderr, return 1.
- Called from `_emit_next` after `NEXT ->` and `NEXT_VERB=`.
- `cmd_resume` idx<0 (`flow.sh` ~1014) does not call `_emit_next`; calls `_emit_pin` after `NEXT_VERB=`.
- `_emit_context_json` unchanged; JSON path does not call `_emit_pin`.
- command-dispatch status/resume rows: PIN v1 after NEXT_VERB, display-only, do not exec. Compact recovery is prose status/resume, not `--json`.

## Commands

| Command | Exit | Result |
|---|---|---|
| `bash tests/test_flow_status_legibility.sh` (TDD, before printer) | 1 | 66 passed, 6 failed — all 6 fails in M (empty PIN vs pin-v1.txt; idx<0 missing `PIN v1`) |
| `bash tests/test_flow_status_legibility.sh` (after printer) | 0 | 72 passed, 0 failed |
| `git diff -U0 HEAD -- skills/flow/runner/flow.sh` | 0 | hunks only: `cmd_resume` +`_emit_pin`; `_emit_next` +`_emit_pin` + new `_emit_pin` fn. No `_eval_engine_run` / `_run_with_timeout` lines |

## Phase 2 checks

- status PIN == resume PIN == pin-v1.txt (`grep -F` per line).
- resume on empty project (idx<0) still prints PIN v1, bytes match pin-v1.txt.
- Test A: `NEXT ->` still first content line after header blank; exactly one `NEXT ->`.
- `status --json` / `resume --json`: no `PIN v1`; still 7 keys (`v,stage,gate,next_verb,card,dwell,load`).
- extras on status/resume still exit 2 (section K).
- Exclusive writes: `pin-v1.txt` (untracked CREATE), `flow.sh` (`_emit_pin` + wire), `test_flow_status_legibility.sh`, `command-dispatch.md` status/resume rows.
- Eval STOP: `_eval_engine_run` / `_run_with_timeout` bodies byte-identical vs HEAD.

Status: DONE
