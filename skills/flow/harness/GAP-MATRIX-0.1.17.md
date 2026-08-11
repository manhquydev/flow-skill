# SUPERSEDED (2026-08) — historical comparison only

> **Live policy:** durable layer is **flow-owned**. **No further schema sync** from
> repository-harness / `harness-cli`. Last published protocol-v1 archive:
> **`harness-cli-v0.1.22`** (EOL; no features). Do not treat 0.1.14/0.1.17 as live trust pins.
>
> **Live authority:** `flow_harness.py` + `flow.sh` + `gate-rules.md` (see `harness/README.md`).

---

# Gap matrix (archive): flow durable layer vs repository-harness CLI 0.1.17

**Historical authority note:** compared against `harness-cli-v0.1.17` during v0.24 trust-align.
Pins below are **archive labels**, not install targets.

| Archive label | Tag | Historical use |
|---------------|-----|----------------|
| Protocol floor (archive) | `harness-cli-v0.1.14` | protocol v1 discovery floor at trust-align time |
| Trust-align snapshot | `harness-cli-v0.1.17` | US-101 spirit inspiration |
| Do not use | `harness-cli-v0.1.16` | tag without published assets |
| Last published archive | `harness-cli-v0.1.22` | EOL max (repository-harness ADR 0027) |

Flow does not claim US-101 parity or an isomorphic control plane.

**Supersession:** upstream work-graph / protocol-v1 is not a sync target (recorded 2026-07-26 graph band + 2026-08 EOL).

## Schema

| Ver | Flow | Harness 0.1.17 (archive) | Notes |
|-----|------|--------------------------|-------|
| 001–004 | present (shared ancestry) | present | Frozen; no further sync |
| 005 | present | present | tool registry ancestry |
| 006–008 | **absent** (reserved gap) | changesets / deps / hierarchy | Not adopted |
| 009–012 | **usage/accessed** (flow-owned) | different upstream meaning | Semantic collision avoided |
| 013 | absent | changeset content sha | Reserved/absent |
| 014+ | **graph-executor** (flow-owned) | absent | Flow-owned since 2026-07-26 |

## Commands / invariants (still live in flow Python)

| Surface | Flow status | Trust note |
|---------|-------------|------------|
| `story update --status implemented` | rejected | Use `story complete` |
| `story complete` | flow-native `proof_source` | Never forge `last_verified_result=pass` from markdown alone |
| Rust forward | refused on flow-lineage DB | exit 2 when usage mirror / schema≥9 |
| Changesets 006–013 | not adopted | graph band 014+ is flow-owned |

## Historical pins (do not install as product dependency)

```
# archive labels only — not live authority
HARNESS_PROTOCOL_V1_TAG_ARCHIVE = harness-cli-v0.1.14
HARNESS_CLI_TRUST_ALIGN_SNAPSHOT = harness-cli-v0.1.17
HARNESS_CLI_LAST_PUBLISHED_ARCHIVE = harness-cli-v0.1.22
DO_NOT_USE = harness-cli-v0.1.16
```

## Rust refuse-forward

Any DB with `usage_event` or `MAX(schema_version) >= 9` is **flow-lineage**. Python entrypoint
must refuse forwarding to external `harness-cli` (exit 2). `graph` verbs are NEVER forwarded.
**Supersession:** upstream work-graph / protocol-v1 is not a sync target.
