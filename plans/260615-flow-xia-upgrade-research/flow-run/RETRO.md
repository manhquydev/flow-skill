# Retro

After all cards are done, append ONE line per project run:
*Which gate did I skip or rush, and what did it cost?*

---

flow-self-upgrade run: built C-001/C-002/C-003 (accessed_count read-only signal, /flow constitution advisory gate, assess stdlib repo-map), shipped 0.7.0 installed + verified live. No planning gate skipped; only cost was DF3 (the `[FILL]` check false-positived on a legit token mention in the PRD → one re-edit). Biggest lesson: Codex cross-model review caught **10 real bugs the 18-suite green pass missed** (narrow security regex, read-only-DB write, code-fence/malformed-row parsing, O(n²) ranking, generic + non-unique symbol noise, py2 interpreter pick) — ground-truth tests and a different *model* are complementary, not redundant. flow's own friction logged for a follow-up fix: DF1 no second-cycle/epic concept, DF2 false-PASS on a missing project root, DF4 `harness decision add` hint says `--summary` but the CLI needs `--title`.
