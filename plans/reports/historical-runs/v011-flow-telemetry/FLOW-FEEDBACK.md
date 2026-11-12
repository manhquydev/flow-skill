# FLOW-FEEDBACK — friction in the flow itself (v0.11.0 run, 2026-06-20)

What slowed THIS build down, as actionable backlog for the flow tool (not the product):

1. **`flow.sh check` validates card STRUCTURE, not behavioral coverage.** It checks no `[FILL]`,
   valid status, sections present, evidence non-empty — but it cannot tell that a metric is
   *hollow on one code path*. The wall-clock dwell (C-006) passes every gate yet silently does
   nothing on the `--global` view (the compact device-log omits `stage_from`). Only manual
   dogfood caught it. → A card could declare which code paths/inputs its done-evidence covers,
   and `check` could nudge when a claimed capability has an unexercised path. (idea, not a must)

2. **No Review gate is enforced between Build and Verify.** The stage list has Review, but the
   card lifecycle (`card`→`check`) lets you go build→done without an adversarial pass. I only ran
   code-review *after* marking all cards done; it found 2 real MED defects. → Consider a per-card
   or pre-tag "review ran" checkbox in the card gate, or a `flow review` command that records a
   review trace the way `check` records a story trace.

3. **Windows background-shell output capture is unreliable.** Running `tests/run_all.sh` in the
   harness kept auto-backgrounding and several runs produced empty output files, so I re-ran the
   full suite 3× to get a trustworthy tally. This is a harness/runner ergonomics issue, not a
   flow-logic one, but it cost real wall-clock. → A `flow test` wrapper that writes a parseable
   summary file (suite, passed, failed) would make CI/agent consumption deterministic.

These are observations for a future flow version, not blockers for v0.11.0.
