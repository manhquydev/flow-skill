# Dogfood: attested execution v0.28

Deterministic public-CLI evidence (no secrets / raw outputs):

| Step | Command surface | Result |
|---|---|---|
| Auto without Stage 05 receipt | `flow auto` | exit 1; no `.flow/auto-state` |
| Stage semantic mint + risk READY | `flow attest semantic --stage 05-contract …` then `flow auto` | ACTIVE |
| Active check without card semantic | `flow check C-001` | BLOCK |
| Semantic + live present | mint both then `check` | PASS |
| Stop | `flow auto stop` | state cleared; manual check usable |

Suite owners: `tests/test_flow_auto_attestation_enforcement.sh`, `tests/test_flow_attestations.sh` (path/live stale).
