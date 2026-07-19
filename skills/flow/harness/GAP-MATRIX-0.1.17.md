# Gap matrix: flow durable layer vs repository-harness CLI 0.1.17

**Authority:** `repository-harness` (local `D:\project\flow\repository-harness`).  
**Pins:** protocol floor **`harness-cli-v0.1.14`** · trust/consumer CLI **`harness-cli-v0.1.17`** · **never** install/use **`0.1.16`** release assets (tag without published proof).  
**Scope:** inventory only — does **not** claim US-101 bit-identical or protocol-v1 parity for flow Python.

Supersedes: brainstorm 260703 Thread1 (“nothing to upgrade”).

## Schema

| Ver | Flow | Harness 0.1.17 | Notes |
|-----|------|----------------|-------|
| 001–004 | present (shared) | present | Hash-identical at last measure (2026-07-18) |
| 005 | present | present | File hash may differ on comments only — do not overclaim DDL fork |
| 006–008 | **absent** (reserved gap) | changesets / deps / hierarchy | Not adopted this plan |
| 009–012 | **usage/accessed** (flow-only) | improvement identity / links / closure | **Semantic collision** — same numbers, different DDL |
| 013 | absent | changeset content sha | Not adopted |

## Commands / invariants

| Surface | Flow status | Harness 0.1.17 | Trust note |
|---------|-------------|----------------|------------|
| `story update --status implemented` | rejected (trust-align) | rejected (US-101) | Use `story complete` |
| `story complete` | flow-native flags + honest `proof_source` | `story complete` + live verify | Flow may complete via `card_markdown_gate` **without** setting `last_verified_result=pass` |
| `story verify` | optional shell verify_command | required for shell-proven complete | shell=True = operator-authored only |
| `query sql` | **not exposed** | read-only connection | Do not add mutating SQL |
| Rust forward | refused on flow-lineage DB | n/a | `FLOW_HARNESS_BACKEND=rust` → exit 2 when usage mirror / schema≥9 |
| Changesets / work-graph | not ported | 006–013 | Out of scope (FOMO red line) |
| `query contract --json` | not on Python CLI | protocol v1 discovery | Optional external binary smoke only |

## Pins (consumer)

```
HARNESS_PROTOCOL_V1_TAG = harness-cli-v0.1.14   # floor
HARNESS_CLI_TRUST_TAG   = harness-cli-v0.1.17   # trust features + release proof
DO_NOT_USE              = harness-cli-v0.1.16   # no assets / failed promotion
```

## Rust refuse-forward

Any DB with `usage_event` or `MAX(schema_version) >= 9` is **flow-lineage**. Python entrypoint must refuse forwarding to external `harness-cli` (exit 2). Never unfreeze on `.flow/harness.db` without schema re-home ≥014 (separate epic).
