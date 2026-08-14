# Eval replay fixtures (artifact modality)

Operator-recorded **stripped** transcripts for `flow.sh eval --replay`. Not skill
content — `sync.mjs` `shouldShip` excludes this directory from the npm tarball.

## Record (live, billable)

On a host with real `timeout`/`gtimeout` (or `FLOW_EVAL_UNBOUNDED=1` for that run only):

```
bash skills/flow/runner/flow.sh eval --record --n 3
```

That is 9 fixtures × 3 + 1 probe = 27 + 1 billable calls. Writes `meta` plus
`<fixture>/<vote>.txt` (one `GATE-EVAL-<nonce>: FLAG|PASS` line each). Never commit
raw `claude --output-format json` envelopes (`session_id` / `cwd` must stay out).

## Replay (keyless)

```
bash skills/flow/runner/flow.sh eval --replay --n 3
```

Feeds recorded text through the unchanged parse → vote → scorecard path. Hard-fails
if `gate_rules_sha` in `meta` does not match `_eval_gate_rules_sha` (staleness —
re-record live per the identity ADR). Replay is **not** a fresh-judge and never
counts toward the eval floor.

`--record|--replay` are artifact-only: not `--stage routing|converge`, not `--report`.
