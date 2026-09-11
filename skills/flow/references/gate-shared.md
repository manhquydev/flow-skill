# Shared gate rules — open decisions and material authority

Unique home for OD / material-authority. Stages 02 / 03 / 05 point here; do not copy.

## Material authority

If materially different externally observable product choices remain open (quota,
identity key, tenancy model, response contract, enforcement owner, …), **stop** —
list the choice and consequences. Configurable defaults are not authority.

If the artifact invents policy (who can access what, retention, billing rules) with
no prior operator/ADR authority, stop and list Decision-required items.

Access/effects (public/token/admin, writes) that encode product policy without
operator authority → stop; do not invent tenancy/auth from convenience.

## Assumption vs open decision

Read `## Assumptions`. A bullet that encodes product law (who can access what,
tenancy, retention, billing, enforcement owner) with no operator/ADR authority is
an **open decision or a stop**, not a silent default — move it under
`## Open decisions` (a line like `- [ ] which tenant key?`) or halt. Do not invent
auth/tenancy/retention/billing to clear `[FILL]`.

Contract has no `## Assumptions` section; do not invent one. Access/effects or
shared shapes that encode product law (tenancy, auth, retention, billing) with no
operator/ADR authority are an **open decision or a stop** — add a
`## Open decisions` bullet or halt.

## Open decisions — mechanical

**More than 5 markdown bullets under `## Open decisions` fails `scan_gate`.**
Leftover `- [ ]` still fails boxes. Clarify (`references/clarify.md`) is opt-in,
never a `next` prereq.

If the section is a pile after that floor, assume or cut rather than interview
everything. Offer clarify when any open decision remains.
