# Changelog

All notable changes to the flow skill. Versions follow the `version:` field in
`skills/flow/SKILL.md` (mirrored in `.claude-plugin/plugin.json` and `portable-manifest.json`;
`/flow coherence` enforces agreement). Earlier history lives in git and the README status line.

## 0.11.0 — 2026-06-20 — usage-log telemetry correctness

Self-assessment of the shipped usage-log (driven by `/flow` on flow itself) audited real logs
from two external projects plus the 1739-line device-global log and found the telemetry was
empty or misleading on real, brownfield, agent-driven usage. v0.11.0 fixes the six defects so
the usage-log is a correct, honest, decision-grade signal. All changes are backward-compatible
(optional fields; the existing logs roll up without rewrite).

- **FR1 — `usage --global` works out of the box.** `cmd_usage` now forwards `--global` to the
  preliminary rollup, so the device-wide view returns analytics in one command instead of
  falsely reporting "no events". (runner)
- **FR2 — `cycle_id` at every entry point.** A new idempotent `_ensure_cycle` stamps the cycle id
  from `_log_event` (universal), `cmd_assess`, and the stage-00 unlock (now reuse-not-overwrite,
  so assess+plan is one cycle). Brownfield/pre-existing projects are no longer blind on cycle
  metrics. (runner)
- **FR3 — wall-clock per-stage dwell.** `usage` reconstructs real time-in-stage from `next`
  transitions (enter = `stage_to` epoch, exit = `stage_from` epoch) instead of reporting the
  runner's own ~1-2s exec time; both metrics are now labeled honestly. New json keys
  `stage_dwell` (wall-clock) + `stage_exec_time`. (harness)
- **FR4 — the concurrency lock can actually hard-block.** `session_id` auto-derives from a cascade
  (`FLOW_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → Codex/Antigravity vars → tty → ppid), so it is
  populated with no operator action; the lock gains same-host `kill -0` dead-process reclaim
  (no more waiting out the 900s TTL for a crashed session). (runner)
- **FR5 — test runs no longer pollute analytics.** Events carry an `ephemeral` flag (project under
  a temp dir or named `tmp.*`); `usage`/`rollup` default-exclude them (read-time `tmp.%` fallback
  covers the legacy log with no rewrite); `--include-ephemeral` opts back in. Schema migration
  `008-usage-ephemeral.sql`. (runner + harness)
- **FR6 — device-wide gate failures are explainable.** The compact device-global line now carries
  a bounded (`≤120` char) `gate_fail_reason`, so "why does stage X fail" is answerable across all
  projects, not just per-project. (runner)

Tests: 20 suites / 413 checks green (`tests/test_flow_usage_log.sh` §9–§14, plus updated
concurrency §L/§M and schema-version assertion). Built and gated through `/flow` itself.
A pre-tag adversarial review fixed two MED issues: cross-platform ephemeral-path
normalization (Windows `C:\` vs `/c/`, and macOS trailing-slash `$TMPDIR` — the latter
caught by CI on macOS, fixed in `_norm_path`) and `_json_str` now strips all control
characters. CI green on macOS · Ubuntu · Windows.
(plan in `flow-telemetry-v011/`, research in `plans/260620-flow-telemetry-assessment/`).
