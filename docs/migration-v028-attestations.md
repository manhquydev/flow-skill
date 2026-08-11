# Migration: v0.28 Attested Execution

## Summary

v0.28 adds card **risk** metadata, fingerprint-bound **attestation receipts**, and
an **auto-active** policy latch. Manual/teach/work paths stay usable; hard
enforcement applies only while `/flow auto` has written `.flow/auto-state`.

Fingerprints detect **staleness**. They do not authenticate actors.

## Legacy projects

| Existing state | Manual | Auto |
|---|---|---|
| Card lacks risk fields | Warn; check/done still work | Block as `unknown` until classified |
| Invalid/duplicate risk | Structural warning/failure where parsed | Block |
| No `.flow/auto-state` | Inactive | Run `flow auto` after risk + Stage 05 receipt |
| No receipts | Warning only | Required boundaries block |
| Old/unknown receipt schema | Invalid | Re-mint with current CLI |

## Operator steps for auto

1. Classify every card: `risk: standard|security-class` + non-placeholder reason.
2. For `security-class`, commit a DEBT open line from a **different** Git author and set `risk-ack: git:<full-oid>`.
3. Commit a Stage 05 semantic owner manifest; mint:
   `flow attest semantic --stage 05-contract --revision HEAD --owner <manifest>`.
4. `flow auto` — activates shared policy.
5. Per card: mint semantic (and live after deploy) before `check` / `card done`.
6. `flow auto stop` for deliberate manual continuation.

## Rollback

`flow auto stop`, then revert skill version. Receipt files under `.flow/` are
run-state; remove for audit loss only.

## See also

`skills/flow/references/attestations.md`
