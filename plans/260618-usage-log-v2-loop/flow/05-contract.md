# Stage 05 — Interface Contract (the seam)

The contract is whatever sits between your core and its consumer. For a web app that's
API endpoints (the table below). For a CLI it's commands + flags + output shapes; for a
plugin it's hooks + filters; for a pipeline it's input/output file schemas. Keep the
table's SPIRIT — every feature maps to an interface, every interface has its shapes
written before code — and adapt the columns to your project's shape.

Written BEFORE any code. Backend cards build TO this table; UI cards consume FROM it.
The #1 AI-build failure is producer/consumer drift — backend ships one shape, UI assumes
another, both look green. This file is the cheap fix.

## Gate — check ALL before `/flow next`
- [x] Every PRD feature maps to at least one INTERFACE below (web: endpoint · cli: command · library: public function · skill: command/file)
- [x] Every interface has its INPUT and OUTPUT shapes written (web: request+response · cli: flags+output/exit code · library: args+return)
- [x] Access/effects column filled for every interface (web: public/token/admin · non-web: writes/side-effects, or "none")
- [x] No FILL placeholders remain in this file

## Interfaces (cli/shell + harness CLI + schema)

| Interface | Name / invocation | Access/Effects | Input | Output |
|---|---|---|---|---|
| **I1 usage summary** (FR1) | `flow_harness.py usage --summary` | read-only (rolls up first) | usage_event (project) | compact block: `median cycle-time`, `top gate-fail stage(s)`, `cycles started/reached`; empty string if no rows |
| **I2 recall hook** (FR1) | `cmd_recall` appends I1 output (best-effort) | read-only; degrades silently if no python/data | none | recall output + a `USAGE (mechanical log):` block, or unchanged recall if I1 empty/unavailable |
| **I3 usage→propose** (FR2) | a branch in `_build_proposals`, surfaced by `flow_harness.py propose [--commit]` | read (usage_event) → proposes; `--commit` writes a backlog row | usage_event | a proposal `{title, component=stage, current_pain, suggested, confidence}` when `fail_rate ≥ THRESHOLD` over `≥ MIN_CYCLES`; nothing otherwise |
| **I4 prune** (FR3) | `flow_harness.py prune [--keep N] [--global]` AND `flow.sh usage --prune [--keep N] [--global]` | **writes** sink(s): atomic temp + `os.replace` | keep N (default 5000) | `{"sink":path,"kept":N,"dropped":M}` per sink; exit 0 |
| **I5 gate-fail reason** (FR4) | gate body sets `FLOW_LAST_GATE_FAIL`; `_log_event` writes field `gate_fail_reason`; migration **007** adds `usage_event.gate_fail_reason TEXT` | writes event/usage_event | failing `next`/`check` | event JSON gains `"gate_fail_reason":"fill:N,unchecked:M"` (empty/absent on pass); gate exit code UNCHANGED |

## Shared shapes

```
usage --summary (I1) text block (or "" when no data):
  USAGE (mechanical log): cycles=<S> reached-cards=<R> | cycle-time s min/med/max=<a>/<b>/<c>
    | gate fail-rate=<p>% | top-fail-stage=<stage>(<f>/<t>)

propose usage branch (I3) thresholds (honest heuristic, documented; operator commits):
  THRESHOLD = gate fail-rate >= 0.5 (per stage_to over next|check events)
  MIN_CYCLES = stage seen failing in >= 2 distinct cycle_id
  -> proposal: "stage <S> fails its gate often (<f>/<t> over <k> cycles) - tighten the artifact/template or split the stage"

FLOW_LAST_GATE_FAIL (I5): "fill:<N>,unchecked:<M>" set in the gate-fail path; "" otherwise.
gate_fail_reason column (migration 007): ALTER TABLE usage_event ADD COLUMN gate_fail_reason TEXT;
  + bump schema_version to 7. Rollup: add 'gate_fail_reason' to USAGE_COLS (back-compatible: .get -> None for old lines).

No-fail (all): I1/I2/I3/I5 best-effort; never alter recall/propose/next exit codes or output when usage data/python absent.
Prune crash-safety (I4): write keep-set to "<sink>.tmp" then os.replace onto sink (atomic on same fs); never truncate-in-place.
```

## Feature → interface map
- **FR1** (usage-aware recall) → I1 + I2.
- **FR2** (usage→propose) → I3.
- **FR3** (prune) → I4.
- **FR4** (gate-fail reason) → I5 (+ migration 007).

## OpenAPI / Swagger rule  (web only — N/A for cli/library/skill)

For non-web types there is no served spec; the equivalent "no producer/consumer drift" check
is the per-type done-evidence (the command runs / the API imports / the skill installs+runs).
For `web`:

This table is the PLANNING source of truth. If the framework serves a spec (FastAPI →
`/openapi.json` + `/docs`), the served spec is the RUNTIME artifact of this same contract:
- Path/method/shapes here and in the served spec must agree — the contract-test card
  asserts every endpoint in this table exists in the live `/openapi.json` with matching
  request/response shapes.
- Change flows ONE way: amend this file first, then the code, then the spec follows.
- **Docs land with the API, not after**: the served spec is live from the vertical-slice
  card onward, and every backend card's verify checks its endpoints appear in the live
  `/docs` with correct schemas. The contract-test card later asserts full agreement —
  but by then the docs have been growing card by card, never a catch-up task.
- Keep `/docs` enabled at least until v1 ships — it's the free human-readable contract.

(Interfaces, shared shapes, and the feature→interface map are defined above.)
