## Stage 02 — Scope (the decision stage)
Mechanical: every feature has Impact (H/M/L) + Grade (A/B/C), no L-above-A in v1, cut list,
GO/KILL, no FILL.
**Challenge — watch for GRADE LAUNDERING:**
- Compare to `gate-examples.md` §02 (PASS = C called C; FLAG = C-launder, realtime graded B).
- Shared OD/authority: `gate-shared.md`.
- Is any expensive feature quietly graded B when it's really C? (realtime, payments from
  scratch, custom auth, autonomous agentic pipeline, heavy concurrency = C). Call C a C.
- For every C in scope, is it justified as one of: (1) C IS the product -> it goes FIRST;
  (2) re-architected C->B (e.g. multi-step agent -> single structured call; auto-send ->
  human-approves-draft; custom -> managed service); (3) irreducible -> KILL/re-budget?
- Classic failure: v1 full of A-grade L-impact features (cheap to build, worthless to sell).
- If the product itself is a C, is it FIRST in build order with sibling Cs on the cut list?
- **Offer the forge-idea ritual (opt-in-with-prompt — `references/forge-idea.md`)** when a
  GO/KILL call is genuinely close. It informs the decision; it never decides it — the
  operator still calls GO or KILL.
