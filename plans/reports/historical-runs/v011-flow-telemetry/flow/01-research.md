# Stage 01 — Research (inspect first)

Rule: INSPECT what already exists. Evidence required — links, quotes, screenshots.
"I think there's nothing like this" without searching = gate fail.

> Project type: **skill** (internal tool). Items use the non-web framing: first-party friction,
> who-benefits. Full evidence: `plans/260620-flow-telemetry-assessment/assessment-and-research-report.md`
> (4 web-sourced research tracks + empirical verification on this machine).

## Gate — check ALL before `/flow next`
- [x] I actually OPENED 3 existing tools/competitors (links below, with one honest note each)
- [x] **(non-web/internal)** I named the concrete first-party friction / observed pain that justifies this
- [x] **(non-web)** what people spend AROUND this problem today (time, a worse tool, manual work)
- [x] **(non-web/internal)** who benefits and how they hear about it; "no market channel" is NOT a kill signal
- [x] I wrote why those users would pick this over the status quo (one honest paragraph)
- [x] I wrote what is technically free vs hard for this idea
- [x] No FILL placeholders remain in this file

## What exists already (3 — prior art for telemetry, opened during research)

1. **OpenTelemetry** (opentelemetry.io trace spec + `deployment.environment` semconv) — gold standard for trace/run id assigned at first invocation across all entry points, and `environment` attribute set at write-time. Falls short for us: full OTEL is a heavy dependency; we need the *pattern*, not the SDK.
2. **CI run-id model** (GitHub Actions `run_id`, Bazel invocation id) — a single durable id stamped at the start regardless of which command begins the run. Directly maps to our cycle_id gap (F2).
3. **GA4 internal-traffic filter / Sentry environments** — mark test/synthetic traffic with a tag and default-exclude it at read-time. Directly maps to our tmp.* noise gap (F6).
   Also inspected: git `index.lock`, apt/dpkg, cargo locks (precedent for PID-liveness stale-lock, F5); POSIX write()/pipe(7) atomicity (F4).

## First-party friction (the real, observed pain — with evidence)

1. > `flow usage --global` returns "no events yet" despite 1739 lines in the log — `cmd_usage` never forwards `--global` to the rollup step (flow.sh:1391). The device-wide view the feature promises is dead on arrival. (F1)
2. > `cycle_id` is empty in 100% of CMC + C2-App-001 events and 81% globally, because it is stamped only at `next`-unlock-of-stage-00 (flow.sh:426), never at `assess`. Every cycle metric (cycle-time, completion, abandonment) reads 0 on real brownfield builds. (F2)
3. > `session_id` is empty in 92% (1599/1739) of invocations; the concurrency lock can only hard-block with an operator-exported `FLOW_SESSION_ID` that is never set, so the lock that exists to prevent plan-corruption never actually blocks. (F5)

## GTM & business reality

### What people spend AROUND this problem today

- Status quo cost = **wasted effort + wrong decisions**: the operator (me) spent a full assessment session manually rolling up logs and grepping JSONL because the built-in `usage --global` is broken — exactly the toil the feature was meant to remove.
- Alternative = build improvement decisions on **vibes** instead of the telemetry that was already paid for (the feature shipped in v0.6–v0.10 but produces untrustworthy numbers).

### Who benefits & how they hear about it

The flow skill operator and any future flow user who runs `/flow usage`/`/flow recall`. They learn via the v0.11.0 release notes + CHANGELOG. No market channel — expected for a skill, not a kill signal.

### Why switch (vs the status quo)

The status quo is "telemetry exists but lies." After v0.11 the same commands return correct cycle metrics on brownfield builds, a working device-global view, honest dwell (wall-clock not script-time), explainable failures device-wide, a lock that actually blocks, and analytics free of test noise. The switch cost is near-zero (same commands, richer truth) and the alternative — distrust the data and ignore it — wastes the whole prior investment.

## Technically free vs hard

- **Free (already solved / present):** F1 is a 1-line flag forward. cycle_id mechanism (`CYCLE_FILE`) already exists — just stamp it at more entry points. dwell inputs (`stage_from/to`, `epoch_s`) already in the full log. Harness session id (`CLAUDE_CODE_SESSION_ID`) verified present in env. `kill -0` works for lock liveness.
- **Hard / real risk:** F4 device-global enrichment — POSIX gives NO atomic-append guarantee for regular files and **`flock` is absent in this Git Bash** (verified), so the safe path is per-shard logs + merge-at-rollup, which adds merge/cleanup code and a backward-compat migration for the existing 1739-line log. Schema changes to a shared log format risk breaking the existing rollup cursor if done carelessly.
