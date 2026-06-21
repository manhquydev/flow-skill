# Changelog

All notable changes to the flow skill. Versions follow the `version:` field in
`skills/flow/SKILL.md` (mirrored in `.claude-plugin/plugin.json` and `portable-manifest.json`;
`/flow coherence` enforces agreement). Earlier history lives in git and the README status line.

## 0.12.2 — 2026-06-21 — language-aware review

Two improvements closing the last v0.12 backlog item. All backward-compatible.

**language-specialist Review lens [C-021]**

- **`typescript-reviewer` dispatched for `.ts`/`.js` files.** When the file set under review
  contains TypeScript or JavaScript source, the Review seam now routes to `typescript-reviewer`
  as a specialist pass layered on top of the standard `code-reviewer`. The specialist findings
  INFORM triage; they never auto-pass or auto-fail the gate (gate-parity preserved).
- **`python-reviewer` dispatched for `.py` files.** Same pattern: `python-reviewer` runs as an
  advisory specialist alongside `code-reviewer` when `.py` files are in scope.
- **Composes with the security lens.** The language-specialist pass stacks with the existing
  `security-reviewer` lens (C-014) — both can fire in the same Review invocation; neither
  blocks the other.
- **Detect-first degrade.** When the specialist agent is absent or returns empty output, the
  review falls back to `code-reviewer`-only; a missing specialist is never treated as an
  approval. Documented as a "Specialist absent" degrade rung in `adversarial-review.md`.
- **Both agents wired** in `agent-stage-mapping.md` (Review seam) and listed in
  `agent-detection.md` (ck: priority list), so the existing agent-wiring tripwire
  (`test_flow_coverage_gaps.sh`) guards them automatically. +12 checks.

**Portability fix: POSIX `sed -E` replaces GNU-only `grep -oP` in the agent-wiring tripwire [C-018 latent defect]**

- **Root cause.** The C-018 tripwire (`test_flow_coverage_gaps.sh`) used `grep -oP` with a
  Perl-compatible regex to parse the derived agent set from `agent-detection.md`. GNU `grep -P`
  is not available on macOS BSD grep — a CI target. This was a latent portability defect
  introduced in v0.12.1: the tripwire passed on Linux/Windows (GNU grep) but would have failed
  on macOS CI with `grep: invalid option -- P`.
- **Fix.** The parse was rewritten using POSIX `sed -E`, which is supported on both BSD (macOS)
  and GNU (Linux/Windows) grep environments. No change to what the tripwire asserts — only the
  tool used to extract the agent list changed.

## 0.12.1 — 2026-06-21 — v0.12 polish round

Three polish items closing the v0.12 backlog. All backward-compatible.

**telemetry-honesty [C-017]**

- **Legacy-dwell `~approx` label.** `flow usage` now marks dwell figures inferred from legacy
  rows (rows that pre-date the compact global-sink `stage_from` field) with a `~approx` suffix
  so the operator can distinguish reliable wall-clock data from estimated dwell.
- **`--builds-only` build-cycle count.** `flow usage --builds-only` now filters the cycle-time
  line to show only build-intent cycles (excludes diagnostic-only sessions), labeled
  `[N build cycles]` for clarity.
- **Dead variable removed.** `display_count` was assigned but never consumed; the assignment is
  removed so the variable is not a latent confusion risk for future readers.

**orchestration completeness [C-018]**

- **`git-manager` + `docs-manager` seam rows wired.** Both agents now appear as explicit entries
  in `agent-stage-mapping.md` (previously listed in `agent-detection.md` but absent from the
  mapping — a declared-but-unwired gap of the same class as the C-013 `debugger` defect).
- **Agent-wiring tripwire DERIVES its set from `agent-detection.md`.** The `test_flow_coverage_gaps.sh`
  tripwire no longer hard-codes the agent list; it reads the priority list from `agent-detection.md`
  at test time, so a newly added agent that is not wired into `agent-stage-mapping.md` will
  automatically turn the assertion red — no manual maintenance of the test's expected set.
- **Repair-discipline rule.** A new law entry states: when a control-flow or runner repair is
  applied, the FULL test suite must be re-run before advancing the gate (partial re-runs are
  insufficient for changes that touch shared runner paths).

**engine hygiene [C-019]**

- **Advisory-probe tempdir cleaned on SIGINT and early-return.** The tempdir created during
  an advisory probe is now removed via a dual `RETURN`+`EXIT` guard, so a SIGINT mid-probe or
  an early function return leaves no leftover temp directories under `$TMPDIR`.

## 0.12.0 — 2026-06-20 — telemetry truth + orchestration depth

Six improvements across three themes, plus a new CI tripwire that catches "declared but unwired"
agent gaps before they ship. All changes are backward-compatible (optional fields, additive seams,
no gate-contract change).

**telemetry-truth**

- **`usage --global` per-stage dwell now works.** The compact global-sink line carries `stage_from`
  for new rows; for legacy rows the harness infers dwell by partitioning `next`-transition pairs on
  `(project, cycle_id)`. The device-wide dwell view now reflects real stage time instead of
  always zero. [C-011]
- **Honest cycle accounting.** `flow usage` now breaks cycles into build-intent vs diagnostic-only
  using the existing `read_only` field: a session that only ran `status`/`recall`/`usage` is counted
  separately from one that advanced a gate or touched a card. The FR2 logging path is unchanged;
  reclassification happens at read-time and is retroactively correct across the existing log. [C-012]

**orchestration-depth**

- **`debugger` wired into the two-strikes repair ladder.** When a same-ladder agent returns BLOCKED
  a second time, the repair order is now: `debugger` (Claude diagnostic, scoped brief) → Codex
  (if USABLE) → Antigravity (if USABLE) → operator. Previously the `debugger` agent was listed in
  `agent-detection.md` but absent from `agent-stage-mapping.md`'s Repair row — a declared-but-unwired
  gap. The degrade rung ("if `debugger` absent → inline root-cause + fresh same-ladder subagent")
  is explicit and tested. [C-013]
- **Security-class Review lens.** `security-reviewer` is layered into the Review seam alongside
  `code-reviewer` — it runs as an advisory pass (informing triage, flagging OWASP/secrets/injection
  patterns) but never releases a Tier-C operator HALT on its own: the gate still judges. The lens
  is absent-safe (degrade to `code-reviewer` only when `security-reviewer` is not in the host
  registry). [C-014]

**engine-hardening**

- **Atomic `mkdir`-guard concurrency lock, TOCTOU-safe.** The lock acquire now uses a single
  `mkdir` (atomic on POSIX + NTFS) instead of a test-then-create sequence, closing the acquire
  race. FR4 metadata (session_id, PID, timestamp) is written inside the directory after acquire,
  and a crash-recovery self-heal (`kill -0` dead-PID reclaim) runs before each acquire attempt.
  The existing lock TTL and unlock command are unchanged. [C-015 W5]
- **Honest `_python` exit code.** The `_python` dispatcher now propagates the Python subprocess
  exit code to the caller instead of always returning 0; callers that relied on the swallowed exit
  code degrade gracefully (the harness is optional). [C-015 W6]

**agent-wiring tripwire (this card)**

- New test block in `tests/test_flow_coverage_gaps.sh` asserts that every ck: agent named in
  `references/agent-detection.md`'s priority list appears in `agent-stage-mapping.md` as either a
  stage row entry OR an explicitly-labelled repair/diagnostic/review seam. The test is backed by a
  negative-control proof: the assertion turns red if any agent is removed from the wiring. The exact
  `debugger`-unwired defect fixed in C-013 would have been caught by this tripwire at CI time.

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
