# Cost receipts — model and spend evidence (`flow-cost/v1`)

Per-stage accounting evidence for a FlowSkill run: which model ran the
stage, how many tokens it billed, and what it cost. A cost receipt never
gates anything and never changes any attestation verdict.

Cost receipts are warn-only accounting evidence: a missing, stale, or
unparseable cost receipt warns on stderr and never changes any attestation
verdict.

## Schema (`flow-cost/v1`)

Path layout under the main state root:

```text
<main-state-root>/.flow/attestations/
  cost/stage-05-contract.receipt
```

One file per stage; the newest run overwrites atomically (temp in the
destination dir → `chmod 600` → rename). `cost/` is a sibling of
`semantic_gate/` and `live_verify/`; the attestation parser never scans it,
and the receipt chain never covers it — `flow attest verify-chain` skips
`cost/` (chain entries are attestation receipts only).

Required keys, **canonical order**, single-line `key: value`:

| # | Key | Type |
|---|-----|------|
| 1 | `schema` | literal `flow-cost/v1` |
| 2 | `run_id` | `[A-Za-z0-9._-]{1,64}`, minted `run-YYYYMMDD-HHMMSS-<6 lowercase hex>` |
| 3 | `stage` | one of `00-idea`, `00-inspect`, `01-research`, `02-scope`, `03-prd`, `04-adr`, `05-contract` |
| 4 | `subject_fingerprint` | `git-sha1:<40 hex>` or `git-sha256:<64 hex>`, copied from the stage attestation receipt when one exists, else the stage blob at HEAD |
| 5 | `attestation_ref` | `none` or a relative path, e.g. `.flow/attestations/semantic_gate/stage-05-contract.receipt` |
| 6 | `model_id` | single token, no spaces, ≤128 bytes — the model as billed |
| 7 | `input_tokens` | non-negative integer, ≤12 digits |
| 8 | `output_tokens` | non-negative integer, ≤12 digits; 0 is legal |
| 9 | `token_count_source` | `reported` (provider usage) or `estimated` (counted locally) |
| 10 | `price_table_version` | `[A-Za-z0-9._-]{1,64}`, e.g. `widelai-2026-11-12` |
| 11 | `input_price_mcr_per_1k` | integer or `unknown` |
| 12 | `output_price_mcr_per_1k` | integer or `unknown` |
| 13 | `cost_mcredits` | integer or `unknown`; `ceil((in*in_price + out*out_price) / 1000)` |
| 14 | `budget_cap_mcredits` | integer or `none` |
| 15 | `budget_status` | `none` \| `within` \| `exceeded` \| `unpriced` |
| 16 | `timestamp` | UTC `YYYY-MM-DDTHH:MM:SSZ` |

All money is integer **millicredits** (1 credit = 1000 mcr, 1 credit =
$0.005). Bash 3.2 has no floats, so costs are always rounded **up** — a
receipt never understates spend.

## Price table and model routing

The price table is the routing table: `model_id` selects the price, and the
recorded `model_id` is the per-stage routing record. No gate enforces model
choice; routing is recorded, not policed.

| `model_id` | input mcr/1K | output mcr/1K |
|---|---|---|
| `claude-sonnet-5.5` | 400 | 2000 |
| `claude-opus-5.5` | 800 | 4000 |
| `claude-fable-5.1` | 2000 | 10000 |

`price_table_version` is date-based (`widelai-YYYY-MM-DD`); a new table
gets a new version label, never a silent edit. A model with no table entry
is recorded with both prices `unknown`, `cost_mcredits: unknown`, and
`budget_status: unpriced` — never a fallback price, never 0.

## Parser rules

Mirror the attestation parser (`references/attestations.md`): reject blank
lines, unknown keys, duplicate keys, missing keys, out-of-order keys,
multiline values, tabs in values, and oversized values; never source/eval
receipt content; CRLF normalized on read. Additionally the parser
recomputes the arithmetic and checks status consistency:

- Prices known ⇒ `cost_mcredits` must equal the recomputed ceil value.
- `cost_mcredits: unknown` ⇔ `budget_status: unpriced`.
- Cap `none` ⇔ status `none`; cost ≤ cap ⇔ `within`; cost > cap ⇔
  `exceeded`.

A rejected receipt counts as missing, with the parse reason in the warning.

## Status and warnings

`flow attest cost status [--stage <stage>]` reports
`missing` | `invalid` | `stale` | `current` per stage. Stale means the
`subject_fingerprint` no longer matches the stage attestation receipt (or
the stage blob at HEAD when there is no attestation), or the
`attestation_ref` target no longer exists. `flow next` and `flow attest
status <stage>` warn on stderr the same way, every time — never silently
skipped, never blocking.

- Missing: no file for the stage. No usage numbers ⇒ write **no** receipt;
  missing is warn-only.
- Invalid: parse failure (see above); treated as missing.
- Both token counts 0 on a completed stage ⇒ warn `no usage recorded`
  (suspect, not free).
- Over cap ⇒ record the real totals, status `exceeded`, warn with the
  overage. Never truncate or clamp to the cap.
- Unpriced with a cap set ⇒ warn `cap unverifiable`.

## Worked example

Sonnet 5.5, 12,000 input + 3,000 output tokens, cap 50,000 mcr:

- Input: 12 × 400 = 4,800 mcr; output: 3 × 2,000 = 6,000 mcr; total
  10,800 mcr = 10.80 credits = $0.054; status `within`.

```text
schema: flow-cost/v1
run_id: run-20261112-000001
stage: 05-contract
subject_fingerprint: git-sha1:<object-id of the subject>
attestation_ref: .flow/attestations/semantic_gate/stage-05-contract.receipt
model_id: claude-sonnet-5.5
input_tokens: 12000
output_tokens: 3000
token_count_source: reported
price_table_version: widelai-2026-11-12
input_price_mcr_per_1k: 400
output_price_mcr_per_1k: 2000
cost_mcredits: 10800
budget_cap_mcredits: 50000
budget_status: within
timestamp: 2026-11-12T00:00:00Z
```

## CLI surface

```text
flow attest cost record --stage <stage> --model-id <id> --input-tokens <n> --output-tokens <n>
  [--token-count-source reported|estimated] [--budget-cap-mcredits <n>|none]
  [--price-table-version <v>] [--run-id <id>] [--subject-fingerprint <fp>]
  [--attestation-ref <path>|none]
flow attest cost status [--stage <stage>]
```

`record` defaults: `run_id` minted, `token_count_source: reported`,
`budget_cap_mcredits: none`, `price_table_version:
widelai-2026-11-12`; `subject_fingerprint` copied from the stage
attestation receipt (else the stage blob at HEAD); `attestation_ref` points
at the stage attestation receipt when one exists, else `none`. Usage
numbers come from the caller — for provider runs, the provider-reported
usage; `estimated` means the caller counted locally, by a method the
caller defines (no local counting standard exists yet). Exit codes: `0`
recorded/current, `1` write failure, `2` invalid usage.

## Deferred

- A standard local token-counting method for `token_count_source:
  estimated` (currently caller-defined; an estimate must never be
  presented as provider-reported).
- Eval hooks: cost accuracy (T04b) and budget (T07) checks consume these
  receipts once the eval set defines them.
