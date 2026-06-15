# Stage 00 — Idea

## Gate — check ALL before `/flow next`
- [x] The pitch below is 3 sentences, no more
- [x] I can name at least ONE real person/group who has this pain (named below)
- [x] No FILL placeholders remain in this file

## Pitch (3 sentences: who, pain, what you'd build)

Teams running `/flow` orchestrate every stage and the adversarial Review gate on a single
vendor's model (Claude via ck:/bmad/built-in tiers), so a card's builder and its reviewer share
the same blind spots and correlated mistakes slip through green gates. When a ck: agent gets
stuck twice the only escalation is another same-model subagent or the operator — there is no
second-engine to break the deadlock with genuinely different reasoning. I'd add **Codex (OpenAI
GPT-5.x) as a first-class cross-vendor path** in `/flow`'s agent ladder: a rescue/escalation tier
for two-strikes deadlocks and a cross-model adversarial reviewer in the Review gate, detected and
used when present, degrading cleanly to today's behavior when absent.

## One real person/group with this pain

The flow-skill operator (this project's own dogfood, per `docs/quality-metrics.md` "Dogfood
findings"): review pass #4 caught a real security weakness only because a *different* review lens
was applied — the metrics already track "Reviews-to-clean" and same-model review correlation is
the next obvious quality ceiling. Also any Claude Code user who has the `openai-codex` plugin
installed (present in this host, v1.0.4) and wants their stuck builds handed to a second engine.
