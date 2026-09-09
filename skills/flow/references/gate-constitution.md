## Constitution challenge (operator invariants — run at scope/PRD/contract)

`flow.sh constitution` is the mechanical half: it proves the `flow/constitution.md` table is
well-formed (no placeholder, every invariant has an ID) and scans any declared grep-marker. It
**cannot** tell whether the artifact you just wrote actually *honors* the invariant — that is your
job. After the mechanical pass, for each invariant whose `applies-at` includes the current stage,
challenge the stage artifact against it:

- Read each invariant (e.g. "all PII access is facility-scoped", "no API surface ships without a
  `flow/05-contract.md` entry").
- Walk the current artifact (scope / PRD / contract) and ask: does anything here *violate* it, or
  quietly assume an exception? A contract endpoint exposing cross-tenant data violates a
  facility-scoped invariant even though the table is structurally clean.
- If you find a violation, report *"constitution passed mechanically, but `<artifact>` violates
  invariant `<ID>` (`<rule>`)"* and let the operator decide — same posture as every other gate.

This is **advisory and per-project**; it never auto-blocks `next`, and it does NOT replace the
security-class Tier-C halt (a constitution rule may *restate* a security concern, but the halt is
the enforcement). Low-noise by design: the mechanical layer is structural, the judgement is yours.
