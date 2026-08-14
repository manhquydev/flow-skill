---
title: "Attested execution"
description: "Fingerprint-bound receipts that stop an autonomous run from consuming a stale approval."
---

Once a run is autonomous, "this was reviewed" has to mean something a script can check. The
attested-execution control plane issues receipts — a `semantic_gate` receipt for a reviewed
stage or card, a `live_verify` receipt for a checked deployment — bound to fingerprints of
the thing they approved. While auto is active, `check`, the CLI-owned card flip, dependency
readiness, and removing a merged worktree all require current receipts, and `auto stop`
returns you to warning-only manual mode. Minting executes against committed blobs at a
specific revision rather than whatever is dirty in the working tree, and a live receipt
requires the exact HEAD tip plus recomputed fingerprints, so editing a file after approval
invalidates the approval instead of silently inheriting it.

The honest limit is stated in the design rather than implied: receipts detect **subject
staleness**. They do not authenticate actors and they do not resist a hostile host. They are a
guard against an autonomous loop consuming its own out-of-date approval, not a security
boundary against someone with control of the machine.

Receipt contract and command surface:
[`skills/flow/references/attestations.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/attestations.md)
