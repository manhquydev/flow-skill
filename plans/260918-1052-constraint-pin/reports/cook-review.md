# Cook review — constraint pin + overlay

Date: 2026-09-18
Plan: `plans/260918-1052-constraint-pin`
Scope: Phase 1 overlay WT + Phase 2 PIN printer vs plan.md / phase-02-pin-printer.md / cook-pinimpl.md
Fixes: none (no Critical)

## Verdict

**APPROVE**

No Accept findings. One Nit. Contract checks all PASS.

## Checks

| Check | Result | Evidence |
|---|---|---|
| PIN is exact STOP excerpts, not slogans `STOP lock` / `without DEBT` | PASS | `pin-v1.txt` bytes match the closed Phase 2 body. `grep -E 'STOP lock\|STOP hollow-done\|without DEBT'` empty. Line 3 is `HALT until the operator accepts in DEBT.md`, not a bypass slogan. |
| JSON 7 keys, no PIN on `--json` | PASS | `_emit_context_json` not in the `flow.sh` diff. Smoke: `{"v","stage","gate","next_verb","card","dwell","load"}` n=7; `grep -F 'PIN v1'` empty. Suite M: 7 keys, no `PIN v1` on status/resume `--json`. |
| resume idx<0 emits PIN without `_emit_next` | PASS | `cmd_resume` `idx -lt 0` (`flow.sh:1010-1015`): `NEXT_VERB=` then `_emit_pin`; no `_emit_next`. Smoke: PIN bytes match `pin-v1.txt`; no `NEXT ->`. |
| missing pin file fail-loud | PASS | `_emit_pin` (`flow.sh:1364-1366`): stderr `FAIL: PIN file missing: …`, `return 1`. Smoke with file moved: stderr FAIL, stdout has no `PIN v1`. |
| `NEXT ->` still first content after header | PASS | `_emit_pin` is after the two `_emit_next` echos. Suite A: first content after header blank is `NEXT ->`, exactly one. Smoke: `NEXT -> run '/flow next'…`. PIN has no substring `NEXT ->`. |
| eval engine bodies untouched | PASS | `git diff HEAD -- skills/flow/runner/flow.sh` hunks only: `cmd_resume` +`_emit_pin`; `_emit_next` +`_emit_pin` + new `_emit_pin`. `grep -E '_eval_engine_run\|_run_with_timeout'` empty. |
| overlay does not lower gates | PASS | INFORMS / gate JUDGES, "missing skill never lowers a gate", native-first catalog notes, Don't-surface `ak:agentkit` mid-gate, Tier-C HALT never auto-passed. `test_flow_claudekit_integration.sh` 54/54. Catalog still 6 columns. |
| no FLOW_FORCE live-session bypass in PIN | PASS | PIN line 2: `Never FLOW_FORCE a live session.` Prohibition, not an exception. |

## Findings

### N1 — missing pin file still exits 0

Disposition: **Nit**

`_emit_pin` returns 1, but `flow.sh` is `set -u` only. Callers do not check the status; idx<0 then `return 0`. Smoke: process exit 0 with FAIL on stderr.

Phase 2 step 3 allows "nonzero **or** stderr". Stderr meets it. No suite arm for the missing-file path.

Not a gate-lower. Install ships `pin-v1.txt`; this is a broken-tree signal, not compaction recovery.

## Pin body (closed; matches plan)

```
PIN v1
Never FLOW_FORCE a live session. Mechanical FAIL -> STOP.
Security-class skip/debt -> HALT until the operator accepts in DEBT.md.
Never mark a card done without pasted world-state evidence.
NEXT_VERB is advisory; never auto-exec next, card, card-start, check, fix-gate, auto, or skip.
```

Wire: `_emit_next` → `_emit_pin` after `NEXT ->` / `NEXT_VERB=` (status 906, empty-events resume 1032, full resume 1124). JSON early-returns to `_emit_context_json` only. command-dispatch status/resume rows: PIN after NEXT_VERB, display-only, do not exec; compact recovery is prose, not `--json`.

## Verification run this review

| Command | Exit | Result |
|---|---|---|
| `bash tests/test_flow_status_legibility.sh` | 0 | 72 passed, 0 failed (A + M) |
| `bash tests/test_flow_claudekit_integration.sh` | 0 | 54 passed, 0 failed |
| `bash tests/test_doc_budgets.sh` | 0 | 8 passed, 0 failed |
| status PIN `cmp` vs `pin-v1.txt` | 0 | identical |
| `status --json` keys | 0 | 7; no `PIN v1` |
| resume empty `FLOW_PROJECT_ROOT` | 0 | PIN present; no `NEXT ->` |
| pin file moved; `status` | 0 | stderr FAIL; no PIN on stdout; file restored |

Status: APPROVE
