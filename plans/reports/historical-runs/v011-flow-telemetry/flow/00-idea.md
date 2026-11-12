# Stage 00 — Idea

## Gate — check ALL before `/flow next`
- [x] The pitch below is 3 sentences, no more
- [x] I can name at least ONE real person/group who has this pain (named below)
- [x] No FILL placeholders remain in this file

## Pitch (3 sentences: who, pain, what you'd build)

Operators driving real builds with `/flow` (brownfield, agent-driven) get a usage-log that silently produces empty or misleading analytics — cycle metrics read 0, `usage --global` errors out, the device view is 83% test noise, and the concurrency lock never actually blocks. This makes the telemetry untrustworthy as a basis for improving the skill, which defeats the whole point of having shipped it. Build flow v0.11.0: fix the six telemetry defects (F1–F6) found by auditing real logs, so the usage-log becomes a correct, honest, and decision-grade signal.

## One real person/group with this pain

The flow skill operator (this device, manhquy) — confirmed empirically: across CMC, C2-App-001, and the 1739-line device-global log, every cycle metric on real projects reads 0, `flow usage --global` returns "no events", and `session_id` is empty in 92% of invocations. Report: `plans/260620-flow-telemetry-assessment/assessment-and-research-report.md`.
