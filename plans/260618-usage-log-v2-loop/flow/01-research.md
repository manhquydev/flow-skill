# Stage 01 — Research (inspect first)

Rule: INSPECT what already exists. Evidence required — links, quotes, screenshots.

> Internal **skill** tool — non-web framing: first-party friction, who-benefits.

## Gate — check ALL before `/flow next`
- [x] I actually OPENED 3 existing tools/competitors (links below, with one honest note each)
- [x] (non-web/internal) I named the concrete first-party friction / observed pain that justifies this
- [x] (non-web) what people spend AROUND this problem today (time, a worse tool, manual work)
- [x] (non-web/internal) who benefits and how they hear about it; "no market channel" is NOT a kill signal here
- [x] I wrote why those users would pick this over the status quo (one honest paragraph)
- [x] I wrote what is technically free vs hard for this idea
- [x] No FILL placeholders remain in this file

## What exists already (3 — opened them, not guessed)

1. **`flow.sh recall` / `cmd_recall`** — reads back debt, retro, previous-card, harness friction/backlog, playbooks. Does well: assembles prior pain at stage/card start. Falls short: it reads the curated harness tables only; it does NOT touch the new `usage_event`/JSONL — so cycle-time, gate fail-rate, and per-stage dwell (now recorded) never reach the operator's working context. (`runner/flow.sh` cmd_recall; `harness/README.md` recall list)
2. **`flow_harness.py propose` / `_build_proposals`** — deterministic backlog proposals from repeated friction + interventions + audit drift (≥2 to fire). Does well: turns recurring curated-signal into a committable backlog row. Falls short: its inputs are friction/intervention/audit only — a stage that *mechanically* fails its gate over and over (now visible in `usage_event.gate_pass`) produces NO proposal. The richest new signal is unused.
3. **`flow usage` (v0.9.0, just shipped)** — prints cycle-time / gate fail-rate / dwell on demand. Does well: the read surface exists. Falls short: it is pull-only (operator must remember to run it), has no prune (global log grows unbounded), and the per-event `gate_pass` is a bare bool — it does not say WHICH gate check failed (FILL count / unchecked boxes), so "stage X fails a lot" can't be diagnosed from the log alone.

## First-party friction (the observed pain that justifies this)

1. > `/flow recall` on this v2 project printed "no project-specific history yet" while `events.jsonl` already had rows — proving recorded usage data is not read back into context (write-only sink).
2. > v0.9.0's own `docs/quality-metrics.md` lists, verbatim, the deferred follow-ups: "wire usage stats into recall/propose (close the capture→reuse loop — S-a)", "global-log rotation/retention (unbounded today)", "capture which-gate-check-failed reason (R5)".
3. > `propose` can only learn from friction the agent remembered to log; the mechanical gate-fail history (the most objective signal of where builds hurt) is invisible to it.

## GTM & business reality

### What people spend AROUND this problem today
- **Manual `flow usage` + eyeballing** → operator time, and only if they remember to look.
- **Re-discovering the same gate friction each project** → repeated cost the capture→reuse loop is meant to kill.
- **Unbounded JSONL** → eventual disk/parse cost (low now, grows silently).

### Who-benefits (non-web/internal)
The flow operator (me). Surfaced automatically via `/flow recall` at every stage/card start, and via `propose` at retro. No market channel — expected.

### Why switch (vs the status quo)
Status quo = the data exists but is inert: the operator must manually run `flow usage` and mentally connect "stage X keeps failing" to an action. Wiring usage into the EXISTING recall/propose surfaces means the device's most objective build-history signal shows up where decisions are already made (start-of-stage recall, retro propose) with zero extra ritual — turning a write-only log into the closed feedback loop that was the feature's stated payoff.

## Technically free vs hard

- **Free (stdlib/existing):** querying `usage_event` (rollup already exists); appending a summary block to `cmd_recall`'s output; adding a usage-derived proposal branch to `_build_proposals`; a line-cap prune in Python; `_log_event` already knows the gate context.
- **Hard (real risk):** (a) **no-fail still load-bearing** — recall/propose must degrade silently if usage data/python is absent (don't break recall); (b) **capturing the gate-fail reason** needs the gate body to export a global the EXIT trap reads, without altering control flow/exit codes (the R5 reason it was deferred); (c) **prune must be crash-safe** (atomic rewrite, never lose the live tail); (d) **propose threshold must be an honest heuristic** surfaced for the human, not an invented magic number (anti-FOMO).
