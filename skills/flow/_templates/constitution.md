# Project Constitution — operator-authored invariants

Non-negotiable rules for THIS project, enforced as a **two-layer advisory gate**:
- **mechanical** — `flow.sh constitution` checks structure (no leftover placeholder, every
  invariant has a stable ID) and advisory-scans any declared grep-marker under `src/`.
- **semantic** — at the scope / PRD / contract gates, Claude challenges each artifact against
  these invariants (see `references/gate-rules.md` → "Constitution challenge").

This is **advisory and per-project**. It does NOT replace the security-class Tier-C halt. It is
intentionally **NOT wired into `/flow next`** — run it yourself at the scope/PRD/contract seam.

## Invariants

Each row: a stable **ID**, the **rule**, the **stages** it applies at, an OPTIONAL **grep-marker**
(a regex that should appear in code when the invariant holds — put `-` for semantic-only rules; if
the regex needs a literal `|` alternation, escape it as `\|` so it survives the table cell),
and the **rationale**.

| ID | Invariant | Applies-at | grep-marker (optional) | Rationale |
|----|-----------|-----------|------------------------|-----------|
| INV-1 | [FILL: e.g. all PII access is facility-scoped] | scope,prd,contract | [FILL: e.g. facility_id  — or  -] | [FILL: why this must always hold] |
| INV-2 | [FILL: e.g. no API surface ships without an entry in flow/05-contract.md] | contract,cards | - | [FILL] |
