# Stage 00 — Idea

## Gate — check ALL before `/flow next`
- [x] The pitch below is 3 sentences, no more
- [x] I can name at least ONE real person/group who has this pain (named below)
- [x] No FILL placeholders remain in this file

## Pitch (3 sentences: who, pain, what you'd build)

The flow operator builds many projects on this device but `/flow` keeps only curated, agent-authored memory (intake/story/trace at gate moments) — so when the agent forgets to write a trace, or a run dies between gates, the actual usage history vanishes and there is no mechanical record of how builds really went. I would add an automatic, append-only **usage log**: `flow.sh` self-records every invocation (command, args, stage transition, gate result, exit code, duration, tier) as a JSONL event with zero reliance on the agent remembering, plus a `harness event` channel so Claude can append richer semantic events (gate verdict, kill, retro). Events land both per-project (`.flow/events.jsonl`) and device-global (`~/.claude/flow/usage.jsonl`), roll up into SQLite for a `flow usage` stats view, and feed `recall`/`propose` so the device learns how I actually build.

## One real person/group with this pain

Me — the flow-skill operator (this device, personal use). Direct evidence in this very project: the durable layer is **agent-authored at gate moments only** (`harness/README.md:58-66`), the `trace` tier check is **advisory and never hard-fails** (`harness/README.md:55`), so thin/absent traces are routine; and there is **no mechanical event log** in the runner today (grep of `runner/flow.sh` finds "logged" only inside DEBT messaging, no append-event writer). Across the many builds tracked in memory (SecuSense, CMC Odoo, flowstat, the flow-skill cycles themselves) there is no replayable record of cycle time, gate fail rates, or abandonment points.
