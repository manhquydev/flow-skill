# Eval replay fixtures (artifact modality)

Operator-recorded **stripped** transcripts for `flow.sh eval --replay`. Not skill
content — `sync.mjs` `shouldShip` excludes this directory from the npm tarball.

## Record (live, billable)

On a host with real `timeout`/`gtimeout` (or `FLOW_EVAL_UNBOUNDED=1` for that run only):

```
bash skills/flow/runner/flow.sh eval --record --n 3
```

Plan accounting is 11 fixtures × 3 + 1 probe = 33 + 1 billable calls (9 heading-mapped
fixtures bill 27 + probe today). Writes `meta` plus `<fixture>/<vote>.txt` (one
`GATE-EVAL-<nonce>: FLAG|PASS` line each). Never commit raw `claude --output-format json`
envelopes (`session_id` / `cwd` must stay out).

A `gate-rules.md` edit invalidates `gate_rules_sha` in `meta`. Refresh `--record` and the
rules edit must land in **one commit**. No recorded batch exists yet — CI `eval-replay`
skip-with-notice until the operator records. Do not invent transcripts.

**B1-S live measurement (operator checkpoint, billable):** `eval --n 3` on `fcdd`/`fcde`
(fresh-judge only; replay is not the measurement), then a full `--record` as above.
**B1 escalation:** recurring hollow-done decoys that name no artifact/command after this
addendum lands → escalate to full structured lineage evidence.

## Replay (keyless)

```
bash skills/flow/runner/flow.sh eval --replay --n 3
```

Feeds recorded text through the unchanged parse → vote → scorecard path. Hard-fails
if `gate_rules_sha` in `meta` does not match `_eval_gate_rules_sha` (staleness —
re-record live per the identity ADR). Replay is **not** a fresh-judge and never
counts toward the eval floor.

`--record|--replay` are artifact-only: not `--stage routing|converge`, not `--report`.
