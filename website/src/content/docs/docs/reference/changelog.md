---
title: "Changelog"
description: "Curated user-facing release notes for the flow skill, with a pointer to the full changelog."
---

Current pairing: skill product **v0.31.0**, npm installer **0.7.1-next.0** on `@next`
(`@latest` still ships 0.7.0 / skill 0.30.0 until promoted). The two numbers version
different things — `--help` prints both. See
[Two version numbers](/docs/how-to/troubleshoot-install/#two-version-numbers).
GitHub Release: [`v0.31.0`](https://github.com/manhquydev/flow-skill/releases/tag/v0.31.0).

These are the changes most likely to affect how you use `flow`. The complete, unabridged
history lives in the repository.

## 0.31.0 — eval hardening + host-agnostic parallel + value-first docs

- **Eval hardening.** Judge-input receipt, CI-only fixture-impossibility linter, `doctor` timeout line, cheaper isolated live-eval recipe.
- **Host-agnostic parallel law.** Flow stays the discipline layer; own-runtime parked behind a named tripwire (ADR-0001).
- **Value-first docs.** Landing + docs hub outcome-first, real heading anchors, i18n parity.
- **Cross-OS.** macOS BSD grep hotfix in the bash suite.

## 0.30.0 — discipline-layer identity + CI/eval hardening

- **Identity ADR.** Flow owns gates and receipts, never the runtime.
- **`/flow eval --record` / `--replay`.** Keyless artifact-eval replay. Not a fresh-judge; never counts toward the eval floor.
- **Named-artifact evidence.** Done-evidence items must name the artifact or command that produced them.
- **CI.** Manifest-driven suites, required `all-checks-passed` job, credentialless pack-rehearsal.

## 0.29.0 — spec-kit imports and converge

- **Open decisions.** Unresolved product decisions are `- [ ]` bullets under an
  `## Open decisions` heading on Scope, PRD, and Contract, counted by the existing gate
  scanner. `/flow clarify` prints them as an advisory, section-scoped list.
- **Card `## Independent test`.** Cards now name the user-visible slice proof, or `infra` /
  `none`. A leftover placeholder there fails `check`.
- **`/flow converge`.** Append-only remainder cards reconciling present code against the
  plan. Transactional, never edits an existing card, and writes nothing when there is no gap.

## 0.28.x — attested execution

- Fingerprint-bound `semantic_gate` and `live_verify` receipts, plus
  `/flow attest semantic|live-verify|status|recover` and `/flow auto stop`.
- Card risk fields, with an autonomous preflight that fails closed until every card has a
  classified risk.
- Receipts detect subject staleness; they do not authenticate actors or resist a hostile host.

## 0.27.0 — harness authority continuity

- The durable layer is flow-owned, with a live authority table in the harness README.
- Brownfield assessment gained evidence-ledger claim tags.

## 0.26.0 — hollow-done trust floor

- A mechanical floor on card evidence: process-only prose such as PR approvals, CI green, or
  release notes can no longer mark a card done.

## Full history

Every release, including internal and test-only changes:
[`CHANGELOG.md`](https://github.com/manhquydev/flow-skill/blob/master/CHANGELOG.md)

Release procedure:
[`docs/release-process.md`](https://github.com/manhquydev/flow-skill/blob/master/docs/release-process.md)
