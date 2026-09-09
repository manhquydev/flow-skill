## Stage 04 — ADR
Mechanical: each decision has why + rejected, NOT-doing list, covers storage/auth/deploy.
**Challenge:** Does each decision name a *real* rejected alternative (not a strawman)? Are
data storage, auth approach, and deploy target all actually decided (not "TBD")? Is the
NOT-doing list honest about what's deferred?
- **Offer the native persona-debate ritual** (`native-rituals.md` §1 — the guaranteed
  baseline, no external skill required) before locking a non-trivial decision: a 5-lens
  debate (architect/security/ops/user-advocate/cost) that surfaces defects while reversal
  is still cheap. Output INFORMS this challenge; it never passes the gate. Skip on a
  trivial ADR.
- **If `ck-predict` is installed**, it is a richer alternative to the native ritual (same
  INFORMS-only rule, opt-in-with-prompt — see `claudekit-skills.md`).
