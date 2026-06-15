# Retro

After all cards are done, append ONE line per project run:
*Which gate did I skip or rush, and what did it cost?*

---

- 2026-06-14 (Codex tier v0.4): I rushed the Contract/PRD semantic gates — they passed
  internally-inconsistent detection wording (installed-vs-usable) that only the live cross-model
  Codex review caught. Cost: a rework cycle late, but it *proved the feature* (same-model gate has
  the exact blind spot the second engine fixes). Lesson → wire the cross-model lens into the
  Contract gate, not just card review (DF-2).
- 2026-06-14 (v0.5 hardening): I again rushed the count-sync gate — updated quality-metrics to 249
  checks but left the README at 243, caught by code-review (a repeat of the v0.4 stale-count class).
  Cost: one extra fix pass. Lesson → counts should be regenerated from `run_all.sh`, not hand-edited
  (the standing DF that keeps recurring). The coherence fix (now reads skill version fields) is the
  same spirit applied to versions — extend it to test counts.
- 2026-06-15 (v0.6 consistency): I heeded the recurring count-sync lesson — regenerated every
  count from `run_all.sh` (and re-regenerated after the review added 5 tests: 18→23, 267→272). No
  stale-count miss this run. But I rushed the runner's own portability law: the first cut used `\b`
  in `grep -E`, a GNU-only construct the file header forbids — the adversarial review (F1) caught it
  before ship, on a declared target (macOS BSD grep). Cost: one fix pass. Lesson → run a portability
  scan (grep for `\b`, `-P`, GNU-only flags) on any new runner code BEFORE the review, not via it.
