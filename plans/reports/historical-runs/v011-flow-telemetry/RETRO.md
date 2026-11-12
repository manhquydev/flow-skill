# Retro

After all cards are done, append ONE line per project run:
*Which gate did I skip or rush, and what did it cost?*

---

2026-06-20 (v0.11.0): I rushed the **Review gate** — went build→verify→ship and only ran the adversarial code-review *after* declaring all 6 cards done; it caught two real MED defects (Windows `$TEMP` ephemeral detection silently failing because `C:\` never matches POSIX `/c/`, and `_json_str` not stripping control chars), so a known-weak ephemeral path nearly got tagged. Cost: a near-miss release; lesson banked — run the Review gate *before* `status: done`, not after. (Stack lesson → `playbooks/`, flow friction → `FLOW-FEEDBACK.md`.)
