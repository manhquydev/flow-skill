# Cook test — Phase 1 overlay + Phase 2 PIN printer

Date: 2026-09-18
Plan: `plans/260918-1052-constraint-pin`
Role: tester

Did not edit product code. Did not commit.

## Commands

| Command | Exit | Result |
|---|---|---|
| `bash tests/test_flow_status_legibility.sh` | 0 | 72 passed, 0 failed (incl. section M PIN arms) |
| `bash tests/test_flow_claudekit_integration.sh` | 0 | 54 passed, 0 failed |
| `bash tests/test_flow_native_rituals.sh` | 0 | 26 passed, 0 failed |
| `bash tests/test_flow_concierge.sh` | 0 | 31 passed, 0 failed |
| `bash tests/test_doc_budgets.sh` | 0 | 8 passed, 0 failed |

## Eval STOP

`git diff HEAD -- skills/flow/runner/flow.sh | grep -E '_eval_engine_run|_run_with_timeout'` → 0 matching lines.

Hunks only:

- `@@ -1011,6 +1011,7 @@ cmd_resume()` — `+_emit_pin`
- `@@ -1353,6 +1354,18 @@ _emit_next()` — `+_emit_pin` + new `_emit_pin` fn

`_run_with_timeout` @ 3179, `_eval_engine_run` @ 3450: no hunks on those bodies.

## Smokes

| Command | Exit | Result |
|---|---|---|
| empty `FLOW_PROJECT_ROOT` sandbox: `bash skills/flow/runner/flow.sh resume` then `grep -F 'PIN v1'` | resume 0; grep 0 | PIN v1 present after `NEXT_VERB=next` (idx<0 path) |
| `bash skills/flow/runner/flow.sh status --json \| grep -F 'PIN v1'` | status 0; grep 1 (no match) | empty — JSON is 7 keys, no PIN text |

Resume sandbox stdout (PIN block):

```
PIN v1
Never FLOW_FORCE a live session. Mechanical FAIL -> STOP.
Security-class skip/debt -> HALT until the operator accepts in DEBT.md.
Never mark a card done without pasted world-state evidence.
NEXT_VERB is advisory; never auto-exec next, card, card-start, check, fix-gate, auto, or skip.
```

`status --json`:

```
{"v":"flow_context/v1","stage":"05-contract","gate":"PASS","next_verb":"check","card":"","dwell":"","load":"law/CLAUDE.md"}
```

## Checks vs plan success criteria

- Overlay 54/54 green.
- PIN printer suite 72/72 including status==resume==pin-v1.txt, idx<0 PIN, JSON no PIN / 7 keys.
- `NEXT ->` still first content line after header (section A).
- Eval STOP bodies unchanged vs HEAD.

Status: DONE
