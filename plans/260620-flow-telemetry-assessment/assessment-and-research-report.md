# flow skill — usage-log assessment + research-grounded upgrade basis

**Date:** 2026-06-20
**Scope:** flow v0.10.2. Self-assessment of the usage-log telemetry shipped recently, using real logs from
`D:\project\CMC` (54 events), `D:\project\AI20K\C2-App-001` (121 events), and the device-global log
`~/.claude/flow/usage.jsonl` (1739 events, spanning v0.8.0→v0.10.2).
**Method:** mechanical rollup (ground truth) → root-cause in `flow.sh`/`flow_harness.py` → 4 parallel research
tracks (web-sourced) → empirical portability verification on this machine. Findings separated from recommendations.

---

## Part 1 — Findings (facts from the logs + code)

| # | Finding | Evidence | Class | Severity |
|---|---------|----------|-------|----------|
| **F1** | `/flow usage --global` returns "no events" out-of-the-box | `cmd_usage` runs `rollup` **without** `--global` (`flow.sh:1391`), then queries the global src that was never ingested. Manual `rollup --global` → 1739 events appear | Bug | **High** (the exact device-wide view is broken) |
| **F2** | Cycle metrics blind on real builds | `cycle_id` empty in 100% of CMC+C2 events, 81% global. Stamped only at `next`-unlock-of-stage-00 (`flow.sh:426`); `assess`-first / pre-existing projects never get one → cycles-started, cycle-time, reached-cards, abandonment all read 0 | Data-quality | **High** |
| **F3** | "Per-stage dwell" measures the wrong duration | `duration_s` = the runner's own exec time (all avgs 1–2s), not wall-clock time-in-stage. Cannot answer "where do builds stall" | Metric validity | **Medium** |
| **F4** | Device-global log cannot explain failures | Compact global format (`flow.sh:1363`) drops `gate_fail_reason` + 6 fields. **Note:** the code comment claims this is for PIPE_BUF atomicity, but POSIX guarantees atomic append only for *pipes* ≤PIPE_BUF, **not regular files** — so the field-trimming buys de-facto safety, not a real guarantee | Telemetry gap | **Medium** |
| **F5** | Concurrency lock can't hard-block | `session_id` empty in 92% (1599/1739) — hard-block needs operator-exported `FLOW_SESSION_ID`, never done in practice → lock only warns. Confirms long-standing memory finding | Concurrency | **High** |
| **F6** | Global analytics are ~83% test noise | 1449/1739 global events come from throwaway `tmp.*` projects; no flag to exclude → "104 abandoned cycles" headline is mostly dogfood scaffolding | Telemetry hygiene | **Medium** |

**Not a defect (checked & cleared):** `gate_fail_reason` IS captured correctly in the per-project full log — it's
set only on real `next`/`check` failures (`flow.sh:439,584`), which are rare (C2 gate fail-rate 10%), so the field
is legitimately empty most of the time. The gap is purely that the *global* log omits it (F4).

### What the logs prove WORKS
- Mechanical capture is reliable: 1739 events, every command, masked args, exit codes, gate pass/fail — no gaps.
- Per-project rollup → SQLite analytics works (CMC 0% gate-fail, C2 10%, global 19%).
- Command-mix is legible and useful: globally `next` 301, `status` 160, `consistency` 158, `card` 155, `check` 131,
  `recall` 95, `skip` 90. (High `consistency`/`skip` usage are real behavioral signals worth a later look.)

---

## Part 2 — Research-grounded fix directions (validated, with sources)

Each direction was researched (web sources cited per track) and then **filtered against YAGNI/KISS + empirical
portability on this machine**. Where research over-engineered, the minimal sound fix is stated.

### D1 — Fix `usage --global` (F1) · effort: trivial
**Root cause:** `cmd_usage` (`flow.sh:1391`) calls `rollup` but doesn't forward `--global`, so the global JSONL is
never ingested before `usage --global` queries it.
**Fix:** forward the flag — when args contain `--global`, run `rollup --global` (and/or have the python `usage --global`
auto-ingest its own src). One-line change. Add a regression test under the runner's test suite.
**Confidence:** 100% — reproduced both failing and passing paths.

### D2 — Make `cycle_id` cover all entry points (F2) · effort: low
**Research (Track A):** standard practice = a durable run/trace id assigned at the *first* invocation regardless of
entry point (OpenTelemetry trace id; GitHub Actions `run_id`; Bazel invocation id). Sources: opentelemetry.io trace
spec, W3C Trace Context, Bazel invocation-id docs.
**Filtered recommendation (KISS):** flow already has the `CYCLE_FILE` mechanism (`$LOG_DIR/cycle_id`, format
`epoch-host`). Do **not** add a new uuid dependency or a JSON state machine (researcher over-built this). Instead:
1. Stamp `CYCLE_FILE` in `cmd_assess` (brownfield entry), not only `cmd_next` stage-00.
2. Lazily stamp it on any mutating command if absent (covers pre-existing projects) — `cyc="$(cat CYCLE_FILE || stamp)"`.
3. Defer "when does a new cycle start" policy (YAGNI) — one cycle per project dir until an explicit `retro`/reset says otherwise.
**Confidence:** 95%. Edge case to decide: should a finished build start a fresh cycle on next `assess`? (open question Q1).

### D3 — Real per-stage dwell (F3) · effort: low, **depends on D2**
**Research (Track A):** time-in-stage = delta between consecutive stage-transition timestamps (Kanban "time in column",
DORA lead-time, process-mining dwell). Sources: DORA lead-time, Kanban cycle/lead-time refs.
**Filtered recommendation:** the full per-project log **already** records `stage_from`, `stage_to`, and `epoch_s` on
every `next`. No new table needed (researcher proposed one — YAGNI). Change the analytics only: in `cmd_usage`, compute
dwell as `epoch_s(next transition) − epoch_s(this transition)` per `cycle_id`. Use existing `epoch_s` (ms not needed for
day-scale gaps). Label the current metric honestly ("command exec time") and add the new "stage dwell (wall-clock)".
**Confidence:** 90%. Requires D2 (needs `cycle_id` to group transitions). Handle abandoned final stage = no successor.

### D4 — Zero-config session id + hard-blocking lock (F5) · effort: low–medium
**Research (Track C):** cascade harness-injected env → TTY → PPID+host; upgrade stale detection from TTL-only to
`kill -0` PID-liveness + TTL. Sources: git `index.lock`, apt/dpkg lock, cargo cache lock precedents.
**Empirically verified on this machine (corrections to the research):**
- ✅ `CLAUDE_CODE_SESSION_ID` is present (NOT `CLAUDE_SESSION_ID` as guessed); also `CLAUDECODE`, `AI_AGENT`.
- ⚠️ `tty` = "not a tty" under the agent harness → **TTY fallback is useless** for real AI-driven usage; the env-var
  cascade is the only viable primary, PPID+host the last resort.
- ✅ `kill -0` works → PID-liveness reclaim is viable.
**Recommendation:** auto-derive `session_id` in `flow.sh` from the first present of
`FLOW_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → `CODEX_*`/`AGY_*` session vars → `ppid:$PPID:$(uname -n)`. This both
populates telemetry (fixes the 92%-empty field) AND lets the lock actually hard-block. Add `kill -0` liveness so a
crashed session's lock is reclaimed immediately instead of waiting 900s.
**Confidence:** 90%. Open: confirm Codex/Antigravity session-var names (Q2).

### D5 — Enrich the device-global log so failures are explainable (F4) · effort: medium
**Research (Track B):** POSIX does **not** guarantee atomic append to regular files (only pipes ≤PIPE_BUF) — so the
current "keep it small" rationale is not the guarantee the comment claims. Portable options without new deps: (a) status
quo, (b) per-process/per-day shard files merged at rollup, (c) `flock`, (d) SQLite WAL. Sources: opengroup write()
spec, man7 pipe(7), SQLite WAL docs.
**Empirically verified:** ❌ `flock` is **absent** in this Git Bash → option (c) is not portable here.
**Recommendation:** the robust, dependency-free, Windows-safe path is **(b) sharded global logs**
(`~/.claude/flow/usage-YYYYMMDD-<sid>.jsonl`), merged at rollup — no lock needed — carrying the FULL schema incl.
`gate_fail_reason`. Low-effort interim (given F5 shows real concurrency is ~1 session): just **enrich the single global
line** with `gate_fail_reason` + key fields and accept the de-facto atomicity that already exists. Truncate reason to a
bounded string. Avoid `flock` (not present) and SQLite-as-sink (bigger migration; revisit at "v1.0").
**Confidence:** 85%. Shards add merge/cleanup code; quantify expected concurrency before choosing interim vs shard (Q3).

### D6 — Tag & default-exclude ephemeral/test runs (F6) · effort: low
**Research (Track D):** canonical move = an `environment`/`deployment.environment` attribute set at write-time, filtered
at read-time (OpenTelemetry `deployment.environment`, Sentry environments, GA4 internal-traffic filter). Sources:
opentelemetry semconv, Sentry docs, GA4 filter docs.
**Recommendation:** add an `ephemeral` (or `environment`) field at write-time — detected via project root under
`$TMPDIR`/`tempfile.gettempdir()` (resolve symlinks: macOS `/tmp`→`/private/tmp`) **plus** `tmp.*` name heuristic.
Default-exclude at rollup; add `--include-ephemeral`. **Backward-compat (no migration):** the existing 1739 lines can be
filtered retroactively by the `project` name pattern `tmp.*` at read-time — works today, zero rewrite.
**Confidence:** 90%.

---

## Part 3 — Suggested sequencing (not yet a build plan)

1. **D1** (one-liner bug) + **D6 read-time filter** — instant, makes `usage --global` both work AND be honest.
2. **D2** (cycle_id at all entry points) — unlocks D3.
3. **D3** (real dwell from existing events) + **D4** (session id + liveness lock).
4. **D5** (global enrichment) — decide interim-enrich vs shards after measuring concurrency.

Each is independently shippable behind flow's own gates. Recommend dogfooding via `/flow` on a throwaway root so the
fixes are themselves gate-checked. **No code has been changed yet — this is the research/assessment basis only.**

---

## Open questions (need operator decision)
- **Q1 (D2):** Does a finished build start a fresh `cycle_id` on the next `assess`, or stay one-cycle-per-project until explicit reset?
- **Q2 (D4):** Confirm the exact Codex / Antigravity session-id env-var names (Claude's is `CLAUDE_CODE_SESSION_ID`, verified).
- **Q3 (D5):** Expected real concurrency? If ~1 session (as F5 implies), interim single-line enrichment may be enough; shards only if multi-session becomes common.
- **Q4:** Behavioral signals worth a separate study — global `skip`=90 (frequent gate-skips) and `consistency`=158 (very high advisory use). Investigate or leave?

## Sources (by track)
- **A (run-id/dwell):** OpenTelemetry trace spec; W3C Trace Context; Bazel invocation-id; DORA & Kanban lead/cycle-time; process-mining dwell.
- **B (atomic logging):** opengroup write() spec; man7 pipe(7); SQLite WAL concurrency; advisory-lock POSIX-vs-BSD notes.
- **C (session id/lock):** Claude Code session-state writeups; git index.lock; apt/dpkg & cargo lock mechanisms; PPID-reuse caveats.
- **D (test traffic):** OpenTelemetry `deployment.environment` semconv; Sentry environments; GA4 internal-traffic filters; cross-platform `tempfile` behavior.
