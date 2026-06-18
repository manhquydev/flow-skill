# Stage 01 — Research (inspect first)

Rule: INSPECT what already exists. Evidence required — links, quotes, screenshots.
"I think there's nothing like this" without searching = gate fail.

> Internal **skill** tool — non-web framing used below: first-party friction, who-benefits.

## Gate — check ALL before `/flow next`
- [x] I actually OPENED 3 existing tools/competitors (links below, with one honest note each)
- [x] (non-web/internal) I named the concrete first-party friction / observed pain that justifies this
- [x] (non-web) what people spend AROUND this problem today (time, a worse tool, manual work)
- [x] (non-web/internal) who benefits and how they hear about it; "no market channel" is NOT a kill signal here
- [x] I wrote why those users would pick this over the status quo (one honest paragraph)
- [x] I wrote what is technically free vs hard for this idea
- [x] No FILL placeholders remain in this file

## What exists already (3 — opened them, not guessed)

1. **flow's own durable harness** (`skills/flow/harness/`, SQLite at `.flow/harness.db`). Does well: high-signal curated memory (intake/story/trace/decision/backlog/intervention), accessed_count reuse signal, audit/propose loop. Falls short for usage logging: it is **agent-authored at gate moments only** (`harness/README.md:58-66`) and the trace-tier check is **advisory, never hard-fails** (`harness/README.md:55`) — so when the agent skips a trace or a run dies between gates, nothing is recorded. It captures *decisions*, not *what mechanically happened on every invocation*.
2. **flow's `AUTO-LOG.md` convention** (`runner/flow.sh:715`, `references/auto-run.md`). Does well: a per-card narrative trail during `/flow auto`. Falls short: only exists for autonomous runs, is human-prose markdown (not structured/queryable), and covers nothing about normal interactive `next/card/check` usage, gate fails, kills, or timing.
3. **Claude Code session transcripts / SessionStart summaries** (`~/.claude/projects/.../memory/`, the compaction summary injected this session). Does well: prose recap of a session. Falls short: Claude-side and lossy (frozen at compaction, "STALE-BY-DEFAULT"); knows nothing about flow stage mechanics, exit codes, or per-command duration. Status-quo fallback = re-deriving history from `git log` + memory files by hand.

## First-party friction (the observed pain that justifies this)

1. > Trace tier is advisory and never hard-fails (`harness/README.md:55`) → thin or absent traces are routine; there is no guarantee any record exists for a given run.
2. > No mechanical event log in the runner today: grep of `runner/flow.sh` for `log|event|append` finds the word "logged" only inside DEBT messaging — there is no append-event writer anywhere (1316-line runner).
3. > Cross-cycle `flow/` reuse loses history — observed THIS session: `flow/03-prd.md` describes the Codex tier while `cards/C-010` is the v0.5 release, i.e. the dir was overwritten between cycles. Cycle time, gate fail-rate, and abandonment points across SecuSense / CMC Odoo / flowstat / the flow-skill cycles are unrecoverable.

## GTM & business reality

### What people spend AROUND this problem today
- **Manual reconstruction** → operator time: piecing a run's history from `git log` + memory `.md` files after the fact. No price, but lossy and only post-hoc.
- **AUTO-LOG.md** → free, but covers only `/flow auto`; interactive runs (the majority) get nothing.
- **Curated harness** → free, but write-cost falls on the agent remembering; gaps are silent.

### Who-benefits (non-web/internal)
The flow operator (me, this device, personal use). Learns about it via the skill's own `/flow recall` + `propose` surfacing the new signals, plus README/SKILL.md notes. No market channel — expected for an internal skill increment, not a kill signal.

### Why switch (vs the status quo)
Nothing in the status quo survives a dead run or is queryable: `git log` records commits, not gate fails / kills / stage dwell-time; memory summaries are frozen lossy prose; the harness depends on the agent remembering. A mechanical, append-only JSONL log written by the one component that runs on *every* invocation (`flow.sh`) is the only record that is both complete and replayable — and it feeds the existing recall/propose loop instead of adding a separate tool to check.

## Technically free vs hard

- **Free (solved by stdlib/platform):** append-only JSONL writing; small (<PIPE_BUF) line appends are atomic on POSIX; SQLite rollup via Python stdlib `sqlite3` (already a dependency); `date`/epoch + `trap EXIT` for duration; reading/querying via the existing harness Python.
- **Hard (custom work, real risk):** (a) **secret redaction** of command args before they hit disk (global rule: never log secrets); (b) **atomic dual-write** to per-project + global logs without a race or partial line on Git Bash/Windows; (c) **duration + exit-code capture across shells** via a single EXIT trap without corrupting existing exit codes; (d) **EXIT-trap tempdir cleanup** (open backlog #1 — a signal-kill mid-run currently leaks a tempdir; new file code must not repeat this); (e) **portability** — no GNU-only grep/flags in new runner code (retro lesson: `\b` in `grep -E` was a BSD-incompatible miss caught only at review).
