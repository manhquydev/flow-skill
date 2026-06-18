# Stage 00 — Idea

## Gate — check ALL before `/flow next`
- [x] The pitch below is 3 sentences, no more
- [x] I can name at least ONE real person/group who has this pain (named below)
- [x] No FILL placeholders remain in this file

## Pitch (3 sentences: who, pain, what you'd build)

v0.9.0 gave `/flow` a mechanical usage log that *records* every invocation, but nothing *consumes* it — `recall`/`propose` are blind to the data, so the device still does not "learn how I build" (the whole payoff), and the global log grows unbounded with no prune. I would close the capture→reuse loop: `flow.sh recall` surfaces a compact usage summary (cycle-time, top gate-fail stage) and `flow.sh propose` emits a backlog item when usage shows recurring gate friction, plus a `flow usage --prune` cap for the log and a captured "which gate check failed" reason on `next`. This finishes the deferred v1 follow-ups (S-a + rotation + R5) so the usage log becomes a working feedback loop, not a write-only sink.

## One real person/group with this pain

Me — the flow operator (this device). Direct evidence from THIS project: v0.9.0's own quality-metrics + plan explicitly deferred "wire usage stats into recall/propose (close capture→reuse loop, S-a)", "global-log rotation", and "capture which-gate-check-failed reason (R5)" as open follow-ups; and `/flow recall` today returns "no project-specific history yet" even though events.jsonl exists — proving the recorded data is not yet read back.
