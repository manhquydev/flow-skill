# /flow — quality metrics

Living record of the quality experiment: collect real numbers, improve, ensure quality.
Updated as the skill evolves. Current: **v0.22.0** (2026-07-16), **npm-wrapper v0.1.0-rc.2** LIVE on npm.

## npm-wrapper v0.1.0-rc.2 — cross-platform npm distribution (2026-07-17, LIVE)

Parallel distribution channel: `npx @manhquy/flow-skill@rc` — pure Node.js entry point, no shell/git dependency, for CI/CD and cross-platform environments.

| Metric | Value | Notes |
|---|---|---|
| **Version** | 0.1.0-rc.2 | LIVE on npm, both `latest` and `rc` dist-tags |
| **Tests** | 41/41 pass | 5 suites via `node:test` (installer.test, detect.test, cli.test, lock-atomicity.test, sync-manifest.test) |
| **CI matrix** | Ubuntu / macOS / Windows × Node 22/24 | All green on commit 19fff1f via publish-npm-wrapper.yml |
| **Code reviews** | 3 passes (code-reviewer) + 1 pass (red-team) | Post-audit hardening → post-publish verification; 16/18 red-team findings accepted, 2 rejected |
| **Runtime deps** | 1 (`@clack/prompts`) | 0 dev deps (uses `node:test` built-in) |
| **Tarball** | 76 files, 203 KB gzipped, 566 KB unpacked | No `.pyc`, no `node_modules`, no symlinks |
| **Anti-regression** | `git grep child_process` in src/ + bin/ is empty | Guard in `publish-npm-wrapper.yml` + CI check on every push (prevents shell spawning from Node) |

Real-world verification: cross-platform install tested on Windows (native Node, no WSL), detected Claude/Codex/Agy harnesses correctly, ran `flow.sh` end-to-end without shell dependency.

## v0.20.0 — mission-control legibility: resume verb + status upgrade + per-card dwell (2026-07-10)

Evidence-driven (1079-event dogfood telemetry): `status` is the most-called verb (287 calls,
2.8x `next`) yet had no next-action line or dwell; nothing gave a fresh agent session a resume
brief (industry's top unsolved "AI context amnesia" complaint); per-card dwell was blind in
`usage --global` since the compact log row omitted `card`/`args`. Pure composition of
already-existing data (per-project events log, `cards/.inflight`, gate state) — no new
infrastructure, no schema migration.

Built in 3 phases, each via `ck:cook` → independent `code-reviewer` subagent pass → fix → re-test
(the review cycle earned its keep every phase):

- **Phase 1 (telemetry):** compact GLOBAL log row gains `card`+bounded `args` only for
  `command=card`; `flow_harness.py`'s `cmd_rollup`/`cmd_prune` gain `errors="replace"` decode
  tolerance + a cursor-hold on a final unparseable line. Review found two test-coverage
  overclaims (fixtures that didn't actually exercise their claimed branch) and a `cmd_prune`
  decode-crash bug missed by the original `cmd_rollup` fix — all fixed.
- **Phase 2 (resume verb):** new read-only `flow.sh resume`. Review caught (1) the ppid-reuse
  time-gap fallback was dead on its own primary trigger (fresh session, no own-row yet) — fixed
  with a wall-clock anchor, verified live with spoofed `FLOW_SESSION_ID` values; (2) the
  torn-line defense didn't catch two JSON objects glued together on one line (only the
  no-trailing-newline case) — fixed to reject any line with >1 `{"ts":` occurrence.
- **Phase 3 (status upgrade):** `NEXT ->` line (shared `_next_action` helper with `resume`),
  stage dwell, >10-card compaction. Review caught two **CRITICAL** issues before ship:
  1. A genuine Windows/Git-Bash **hang** — piping `_gate_state_brief`'s nested `scan_gate`
     output into a `while read` consumer froze indefinitely whenever the current stage's gate
     was BLOCKED (an early-pipe-reader-exit class MSYS issue). The review also traced this to a
     **pre-existing, previously-undetected** Phase-2 bug in `_next_action`'s own
     `scan_gate | grep -m1 | sed` reason-lookup, silently present since Phase 2 but confined to
     the rarely-called `resume` — now exposed on the highest-traffic verb by this phase's own
     wiring. Fixed by eliminating both pipes (direct call with the value passed as an arg;
     pre-drained command substitution instead of a live pipe). Reproduced directly: hung
     reliably on a fresh sandbox before the fix, fast + correct after — plus a
     `timeout`-guarded regression test so CI can never wedge on this class again even if it
     resurfaces on a different pipe shape.
  2. A wrong **dwell anchor** — `_stage_dwell`'s filter (`stage_from != cur`) does not actually
     exclude a failed `/flow next` retry, because that path never sets `stage_from` (stays at
     its script default `""`, and `"" != cur` is always true). Dwell would have shrunk toward
     the latest failed attempt on every hard stage — exactly the bug the design was meant to
     prevent. Fixed by anchoring on `exit_code=0` instead, the field that actually discriminates
     a genuine entry from a failed retry; the test fixture was rewritten to log a real entry via
     an actual `/flow next` invocation rather than a hand-fabricated event shape.
  3. Medium: the compact form's displayed card total could drift from the real
     done+in-flight+todo sum under sparse card numbering; fixed to compute the displayed total
     from the real per-file count instead of `highest_card()`'s max-suffix value.

**Test metrics:** new suites `test_flow_resume.sh` (29 assertions) and
`test_flow_status_legibility.sh` (24 assertions, incl. a `timeout`-guarded BLOCKED-gate
regression case). **31 suites / 799 checks, 0 failures.**

| Component | Before | After | Notes |
|---|---|---|---|
| Test suite | 29 suites / 729 checks | 31 suites / 799 checks | +2 suites (resume, status-legibility), +70 checks |
| Commands | 29 verbs | 30 verbs | +`resume` |
| Real bugs caught by review (not by my own testing) | — | 2 critical (hang + wrong dwell anchor), 1 medium, 1 low | both critical bugs were in code that had already passed its own author-written test suite |

## v0.19.0 — `flow.sh eval`: behavioral proof for the semantic gate (2026-07-10)

New capability: `flow.sh eval` runs the real per-stage `gate-rules.md` challenge text against
6 curated sound/hollow fixture pairs (Stage 01 fabricated-quote pattern, Stage 02
grade-laundering, card "merge≈shipped" evidence), majority-votes a nonce-protected verdict
(N=3), and prints a per-stage scorecard. `--report` re-reads a prior batch offline (zero calls).

**Step-0 contract spike found a risk beyond the design's own red-team**: `claude -p` runs a
full agentic loop with live Bash/PowerShell/Edit tool access by default (verified: an
unrestricted probe call executed a real shell command via a tool). Neither `--allowedTools ""`
nor `--disallowedTools <list>` reliably disabled this on the measured CLI version (2.1.201) —
only `--tools ""` (disable the entire built-in tool set) did, confirmed via zero `tool_use`
events and zero filesystem side effects. Now mandatory on every judge invocation.

**Post-implementation code review (2 passes, one per phase pair) found and fixed:**
- **CRITICAL:** a stdin-consumption gotcha silently truncated a live batch to 1 of 6 fixtures —
  `_eval_cli_version`'s `claude --version` call had no explicit stdin source, and since it ran
  inside the manifest `while read ... done < manifest.tsv` loop's body, it inherited and drained
  the loop's own file descriptor. **Fix:** `< /dev/null` + hoisted the call to run once per batch
  (not once per fixture row) instead of inside the loop.
- **HIGH:** interrupt cleanup didn't survive a signal mid-run; the shared `_register_td`/
  `_cleanup_tds` helper (used by 8 call sites across the file) silently no-op'd on any
  space-containing path (routine on Windows) because it stored paths as a space-joined string
  iterated unquoted. **Fix:** converted to a bash array; added a scoped `INT`/`TERM` trap in
  `cmd_eval`. Honest residual: mid-in-flight-call preemption is best-effort on this platform,
  documented rather than oversold.
- **MEDIUM:** an unanchored substring match in `_eval_parse_verdict` would let a marker buried
  mid-prose parse as a valid verdict (not the documented whole-line match). **Fix:** line-start
  anchor after unescaping the JSON response's literal `\n`.
- **MEDIUM:** drift comparison silently produced a misleading delta when the two compared
  batches evaluated different fixture sets for a stage (e.g. a `--fixture`-filtered smoke check
  against an earlier full baseline) — a shrinking/growing denominator read as "the judge got
  worse." **Fix:** `_eval_flag_rates` now tracks the fixture-id set per stage; a mismatch is
  flagged in the drift output instead of silently presented as a clean number.
- Also fixed: an off-by-one in run_id string extraction (stray leading quote corrupted every
  `--report`/drift comparison), an awk empty-vs-zero display bug, and two independent
  header-skip implementations (position-based vs value-based) that only agreed by coincidence.

**Real (non-mocked) verification:** two live `claude -p` smoke-test calls — the sound card
fixture (`fcda`) correctly returned `PASS`; the hollow card fixture (`fcdb`, reworded during
Phase 1 review away from `gate-rules.md`'s own banned "tests pass"/"deployed successfully"
phrases) correctly returned `FLAG` — a genuine semantic catch, not a keyword match. **A full
6-fixture × N=3 baseline batch (18 calls + 1 probe, ~$6–7 at this machine's measured per-call
cost) was NOT run in this session** — real money, deliberately left as an explicit operator
decision rather than spent silently; `flow.sh eval` is ready to run it on request.

**Cost finding (undocumented in the original plan):** this repo's large global `CLAUDE.md` +
skill/agent/MCP declarations load as system-prompt context on every call regardless of prompt
size (~50–60K cache-creation tokens) — measured ~$0.30–0.37/call with the default model under
an OAuth/subscription session (`--bare`, the natural cost-cutter, requires an API key and isn't
available here). Disclosed in `references/gate-eval.md` rather than assumed cheap.

**Test metrics:** new suite `test_flow_eval.sh`, 49 assertions, mocked engine only (never calls
a live LLM) — probe skip/fail paths, nonce nonce-injection resistance, majority-vote math,
UNRELIABLE floor, the `_run_with_timeout` fallback regression, CRLF manifest, space-containing
TMPDIR, no-ritual-copy guard, and the Phase 1 anti-leak guard. **29 suites / 729 checks, 0
failures.**

| Component | Before | After | Notes |
|---|---|---|---|
| Test suite | 0 (`eval` verb didn't exist) | 49 assertions (`test_flow_eval.sh`) | new suite covering mocked-engine plumbing, injection resistance, robustness cases |
| Commands | 28 verbs | 29 verbs | +`eval` (`--stage`/`--fixture`/`--n`/`--timeout`/`--report`) |
| Overall | 28 suites / 680 checks | 29 suites / 729 checks | +1 suite, +49 checks |

## v0.18.0 — loop-engineering: ck-loop integration + red-team proof (2026-07-04)

New capability: thin wrappers (`cmd_loop_prep`, `cmd_loop_log`) around the installed `ck-loop`
ClaudeKit skill, giving flow's Implement→Test→Audit→Fix tail a mechanical verify→iterate→
circuit-breaker engine. flow supplies plumbing only (worktree reuse, Verify metric derived from
card's Allowed files, telemetry); ck-loop stays untouched. 6th deep-wired skill entry in
`claudekit-skills.md` with a loop-vs-two-strikes decision matrix.

**Red-team + CI pipeline** (2 independent adversarial reviewers + cross-OS CI) found and fixed:
- **CRITICAL:** `Scope` hardcoded to `tests/test_*.sh` instead of deriving from card's
  `## Allowed files`. Would have let ck-loop "improve" a metric by weakening tests instead of
  fixing source. **Fix:** derive Scope via `_card_allowed_files()` + abort if glob matches zero files.
- **HIGH:** no timeout on `cmd_loop_prep`'s dry-run Verify — a hanging suite could block indefinitely.
  **Fix:** portable `_run_with_timeout()` helper (GNU timeout/gtimeout when present, background+watchdog
  fallback otherwise).
- **MEDIUM (security):** `loop-log` card-id argument bypassed secret-masking check. **Fix:** validate
  via `resolve_card_file()` before logging.
- **MEDIUM:** `loop-prep --iterations` unvalidated (inconsistent with loop-log). **Fix:** added same
  numeric validation guard.
- **CI-caught macOS bug:** timeout fallback returned raw SIGTERM 143 instead of GNU-compatible 124,
  because the fallback code path was never executed locally (Windows Git Bash has real GNU timeout).
  **Fix:** track watchdog kill via temp flag file, force 124 only if watchdog fired.

**Test metrics:** assertions expanded 27 → 43 (6 new groups I–N covering each fix);
**28 suites / 680 checks, 0 failures**; `flow coherence` PASS; CI green on Ubuntu/macOS/Windows.
Commits: `e7fb7b1` (all fixes) + `65e29ce` (macOS portability fix), both pushed and CI-verified.

**Lesson:** red-team pass on a single dev machine missed a platform-specific degradation path that
only executed where the "faithful fallback" was genuinely exercised — cross-OS CI remains load-bearing.

| Component | Before | After | Notes |
|---|---|---|---|
| Test suite | 27 test_flow_loop.sh assertions | 43 assertions | 6 new groups: Scope derivation, --iterations validation, Verify timeout, branch-reuse warning, loop-log card validation, real-Allowed-files fallback |
| Commands | 25 verbs | 27 verbs | +loop-prep, +loop-log |
| Overall | 20 suites / 467 checks | 28 suites / 680 checks | +8 test suites (incl. loop integration), +213 checks |

## v0.12.2 — language-aware review (2026-06-21)

Two improvements closing the last v0.12 backlog item (C-021) plus a v0.12.1 latent portability
fix. All backward-compatible. Docs/manifest/test-count only — no engine logic changes.

- **language-specialist Review lens (C-021):** `typescript-reviewer` dispatched for `.ts`/`.js`
  files; `python-reviewer` dispatched for `.py` files — each layered on top of `code-reviewer`
  as an advisory specialist pass. Composes with the existing `security-reviewer` lens (C-014).
  Findings INFORMS triage; never auto-pass or auto-fail (gate-parity preserved). Detect-first
  degrade: absent specialist falls back to `code-reviewer`-only, never treated as approval. Both
  agents wired in `agent-stage-mapping.md` (Review seam) and `agent-detection.md` (ck: list).
- **Portability fix — POSIX `sed -E` replaces GNU-only `grep -oP` (C-018 latent defect):**
  The v0.12.1 agent-wiring tripwire used `grep -oP` (Perl-compatible regex) to parse the derived
  agent set from `agent-detection.md`. GNU `grep -P` is unsupported on macOS BSD grep (a CI
  target). This was a latent defect: the tripwire passed on Linux/Windows (GNU grep) but would
  have failed on macOS CI. Rewritten with POSIX `sed -E` — no change to assertions, only to the
  extraction tool.

Suite **20 suites / 479 checks** green (suite count unchanged; 467→479 checks; run on 2026-06-21).
Coherence clean (0.12.1 → 0.12.2).

| Changed check count | Suite | What changed |
|---|---|---|
| 42 (was 30) | `test_flow_coverage_gaps.sh` | +12 checks: C-021 language-specialist lens routing (adversarial-review.md + agent-stage-mapping.md + agent-detection.md assertions for typescript-reviewer and python-reviewer) |

## v0.12.1 — v0.12 polish round (2026-06-21)

Three polish items closing the v0.12 backlog (C-017 / C-018 / C-019). All backward-compatible.
Docs/manifest/test-count only — no engine logic changes.

- **telemetry-honesty (C-017):** `~approx` suffix on dwell header when figures are legacy-inferred
  (no `stage_from`); `--builds-only` now shows `[N build cycles]` on the cycle-time line; dead
  variable `display_count` removed from the print path.
- **orchestration completeness (C-018):** `git-manager` and `docs-manager` seam rows wired in
  `agent-stage-mapping.md` (previously listed in `agent-detection.md` but absent from the mapping);
  agent-wiring tripwire now DERIVES its expected set by reading `agent-detection.md` at test time
  (no more hard-coded list); repair-discipline rule added: control-flow / runner repairs re-run the
  FULL suite before advancing.
- **engine hygiene (C-019):** advisory-probe tempdir cleaned on SIGINT and early-return via a
  dual `RETURN`+`EXIT` guard (no leftover temps).

Suite **20 suites / 467 checks** green at time of release (suite count unchanged; 458→467 checks; run on 2026-06-21).
Coherence clean (0.12.0 → 0.12.1).

| Changed check count | Suite | What changed |
|---|---|---|
| 30 (was 27) | `test_flow_coverage_gaps.sh` | +3 checks: derived-agent-set assertion + C-018 seam-row checks for docs-manager and git-manager |
| 59 (was 54) | `test_flow_usage_log.sh` | +5 checks: 20a/20b `~approx` marker, 21a/21b `--builds-only` count label, 21c `display_count` wired proof |

## v0.12.0 — telemetry truth + orchestration depth (2026-06-20)

Six improvements across three themes (C-011 to C-015) plus a CI tripwire for agent-wiring gaps (C-016).
All backward-compatible. Built through `/flow`'s own card-based process.

- **telemetry-truth (C-011):** `usage --global` per-stage dwell now works end-to-end — compact global
  line carries `stage_from`; harness infers dwell for legacy rows by partitioning on `(project,cycle_id)`.
- **telemetry-truth (C-012):** read-time build-intent vs diagnostic-only cycle breakdown using the
  existing `read_only` field — retroactively correct across existing logs, no schema change.
- **orchestration-depth (C-013):** `debugger` agent wired into the two-strikes repair ladder
  (detection.md listed it, stage-mapping.md's Repair row did not — closed). Explicit degrade rung.
- **orchestration-depth (C-014):** `security-reviewer` layered into the Review seam as an advisory
  pass (informs triage; never auto-releases a Tier-C HALT; absent-safe).
- **engine-hardening (C-015 W5):** atomic `mkdir`-guard lock acquire (TOCTOU-safe); crash-recovery
  self-heal (`kill -0` dead-PID reclaim before each acquire). FR4 metadata preserved.
- **engine-hardening (C-015 W6):** `_python` exit code propagated to callers (was always 0).
- **agent-wiring tripwire (C-016):** new test block in `test_flow_coverage_gaps.sh` — asserts all
  wired ck: agents appear in `agent-stage-mapping.md`; negative control proves it goes red when an
  agent is unwired (the exact C-013 defect would have been caught at CI time).

Suite **21 suites / 458 checks** green (20→21 suites; 413→458 checks; run on 2026-06-20).
Coherence clean (0.11.0 → 0.12.0). Tripwire negative-control verified: `debugger` removed from a
temp copy of the mapping → assertion fails for `debugger` specifically.

| New / updated test | Suite | What changed |
|---|---|---|
| §F `_python` exit code | `test_flow_runner.sh` | +4 checks (honest non-zero on no interpreter, path on present) |
| Round 7 repair-ladder order | `test_flow_scenarios.sh` | +1 check (debugger before codex in auto-run.md) |
| Agent-wiring tripwire + negative-control | `test_flow_coverage_gaps.sh` | +13 checks (was 14 → 27) |
| §N atomic race + §O crash-recovery | `test_flow_concurrency_lock.sh` | +10 checks (was 26 → 36) |
| §15-§19 global dwell + C-012 classification | `test_flow_usage_log.sh` | +27 checks (was 27 → 54) |

## v0.11.0 — usage-log telemetry correctness (2026-06-20)

v0.6–v0.10 *built* the usage-log; a self-assessment (driven by `/flow` on flow itself, auditing two
external projects' logs + the 1739-line device-global log) proved it produced **empty or misleading
analytics on real, brownfield, agent-driven usage**. v0.11.0 fixes the six defects so the telemetry is
a correct, honest, decision-grade signal. All changes are backward-compatible (optional fields; the
existing logs roll up with no rewrite).

- **FR1** `usage --global` forwards `--global` to the rollup → device-wide view works in one command
  (was always "no events").
- **FR2** idempotent `_ensure_cycle` stamps `cycle_id` at assess + lazily everywhere → brownfield builds
  are no longer blind on cycle metrics (was 0% cycle_id on real projects).
- **FR3** per-stage dwell reconstructed as **wall-clock** time-in-stage from `next` transitions (was the
  runner's own ~1-2s exec time); both metrics now labeled honestly.
- **FR4** `session_id` auto-derives from a cascade (FLOW_SESSION_ID → CLAUDE_CODE_SESSION_ID →
  Codex/AGY → tty → ppid) + same-host `kill -0` dead-PID lock reclaim → the concurrency lock can
  hard-block for real (was 92% empty session_id, warn-only).
- **FR5** `ephemeral` flag (temp-dir or `tmp.*`) + default-exclude in analytics (migration 008; read-time
  `tmp.%` fallback for the legacy log) → device view stopped being 83% test noise. `--include-ephemeral` opts in.
- **FR6** bounded `gate_fail_reason` added to the compact device-global line → gate failures explainable device-wide.

Built through `/flow`'s own gates (idea→contract PASS, consistency PASS, 6 cards). Adversarial code
review before tag verdict **SAFE TO TAG** (0 critical/high; 2 MEDIUM fixed pre-tag: Windows `$TEMP`
ephemeral path normalization `C:\`↔`/c/`, and `_json_str` now strips all control chars). Live dogfood on
the installed runner: `usage --global` **1739 → 334** events (85% tmp noise excluded), gate-fail-rate
19% → 6%, per-project wall-clock dwell showing real stage times. Suite **20 suites / 413 checks** green;
coherence clean (0.10.2 → 0.11.0). Shipped to all skill homes via `install.sh global`.

## v0.10.0 — closed the usage-log feedback loop (2026-06-18)

v0.9.0 *recorded* every invocation but nothing consumed it. v0.10.0 wires the recorded data into the
surfaces where the operator already acts, finishing the deferred v1 follow-ups (S-a + rotation + R5):
- **`recall` surfaces a usage digest** (`flow_harness.py usage --summary`): cycles, cycle-time, gate
  fail-rate, top gate-fail stage — at every stage/card start; silent when there is no data/python.
- **`propose` flags chronically-failing stages** (`_build_proposals` branch): a stage with gate
  fail-rate ≥ 50% over ≥ 2 cycles emits a committable backlog proposal (honest heuristic; operator commits).
- **`flow usage --prune [--keep N]`** caps each sink crash-safe (temp + `os.replace`; resets that
  sink's mirror+cursor so the next rollup rebuilds cleanly).
- **gate-fail reason** (migration 007 `gate_fail_reason` + failing `next`/`check` now attribute the
  stage): "stage X fails often" is diagnosable, not a bare bool.

**Closed by decision (not silently dropped):** sub-second/ms duration → WONTFIX (seconds is the
portability-correct ruling; `%N` is GNU-only); trace-tier auto-population (DF-4) → out of scope (a
separate harness-DX increment). Anti-FOMO held: the propose threshold is a surfaced heuristic for the
operator, never an auto-change; no invented magic numbers.

Built through `/flow`'s own gates (idea→contract PASS, consistency PASS, 3 cards). Live verification
caught a real fix (the gate-fail path now sets `FLOW_LOG_STAGE_TO` so failing events attribute their
stage — without it `top-fail-stage`/propose got no data). Independent code review verdict **SHIP**
(0 critical/high; 1 MEDIUM `prune --global` cross-project cursor staleness → documented + a stderr
warning at the point of use). Suite **20 suites / 394 checks** green; coherence clean (0.9.0 → 0.10.0).
Shipped to all 5 skill homes and verified by a live installed-runner `recall` showing the usage digest.

## v0.21.0 — eval-trust hardening + roadmap-A killed by data (2026-07-11)

### Roadmap A (express-lane / adaptive-ceremony) — KILLED WITH NUMBERS

The v0.19+v0.20 roadmap was `B (gate-eval) → C (mission-control legibility) → A (express-lane)`,
with A conditionally opened by "loosen the gate only with a gauge showing it's safe" (B). Both B
and C shipped 260710. The instant B produced its first REAL data, A's premise dissolved.

**Original justification for A** (roadmap brainstorm, 260710-0238):

- "33% build-intent cycles abandoned before Cards" (7/21).
- "Contract-stage dwell avg 1.3h" — cited as a possible bottleneck.

**Same-day per-cycle telemetry mining** (`~/.claude/flow/usage.jsonl`, real projects only,
tmp/ephemeral excluded):

- Cycles with **≥1 successful `next`**: **14/15 reach Cards (93%)** — the pipeline, once
  entered, essentially always completes.
- 8 zero-next cycles: 1 = CMC brownfield working directly in card mode by design (83 events,
  cards created); 7 = **exploration pokes** (only `status`/`assess`/`debt`, 1–9 events; never
  intended to build). Real mid-pipeline abandonment = **1/15 (~7%)**.
- **Contract dwell median 40s** (range 25–113s, n=12); the "1.3h avg" in `usage --global` was
  a measurement artifact of a different pairing rule. Full pipeline 00→05 wall-clock ≈ **5 min**.

**Verdict.** The signal express-lane was designed to relieve isn't a signal — it's exploration
pokes + one brownfield card-mode workflow + a measurement artifact. Loosening ceremony now would
lower quality without saving any time worth measuring.

**Re-trigger condition** (logged so future FOMO can be answered from data, not vibes): revisit
entry-activation only if, after ~15–20 new real cycles on v0.20's `resume`/`NEXT ->` legibility,
zero-`next` poke cycles still dominate AND entry conversion (poke → `next`) hasn't moved. Until
then, A stays killed.

### Eval-trust hardening (built + measured this release)

- First REAL gate-eval baseline (260710, run `…-1783701885-…`): **hollow-flag-rate 3/3 stages
  100%**, 0 INVALID/18, all fixtures unanimous — semantic layer proven enforceable by a fresh
  judge. Only mismatch = f01a "sound" fixture FLAGged 5/5 with defensible reasoning (dirty
  fixture, gate right — one laundered `paraphrased-with-permission … subreddit-homepage-link`
  complaint) → fixture repaired in Phase 2.
- **Canonical v0.21.0 baseline** (260711, run `…-1783743592-…` on the hardened harness + repaired
  f01a): **6/6 MATCH, 0 unreliable, 0 invalid**. Per-stage: `01-research hollow-flag-rate=1/1
  sound-pass-rate=1/1`, `02-scope 1/1 1/1`, `card 1/1 1/1`. Judge = `claude-opus-4-7`, CLI
  `2.1.201`, gate_rules_sha `3672145322`. Future drift vs this baseline surfaces as a delta on
  `eval --report`. Storm mechanism did not recur; the raw-capture path is armed for the next one.
- Preceding batch (`…-1783695631-…`) failed **17/18 INVALID** transiently — the whole reason
  Phase 1 exists. Diagnostic signal was on stderr, discarded by the pre-v0.21 seam. See
  `CHANGELOG.md 0.21.0` and `references/gate-eval.md → Failure modes and postmortem` for the
  playbook. Next storm is postmortemable + cost-capped by design.
- Red-team pass: 3 hostile lenses × `code-reviewer` subagents, all findings `file:line`-backed
  (evidence filter enforced), 26 raw → **14 accepted after dedup** (2 Critical, 5 High, 7
  Medium). No finding overturned the express-lane KILL — all were implementation-hardening.
  The Criticals (breaker-misses-its-own-motivating-incident, stderr-blind raw capture) shipped
  ONLY because they were caught at plan time, not build time.

Anti-FOMO discipline held: no vector-DB memory, no standalone TUI dashboard, no `flow-as-MCP`,
no model-specific routing. `rate_limited` field shipped as best-effort/advisory — an unverified
throttled shape does not get promoted to authoritative drift signal.

## v0.9.0 — mechanical usage log + `flow usage` analytics (2026-06-18)

flow gains a **mechanical usage log**: `flow.sh` self-records **every invocation** to append-only
JSONL — the deterministic mechanical layer (not the agent) is now the flight-recorder, closing the
gap where the agent-authored durable layer had silent holes (no record unless a trace was written).

- **Capture (`flow.sh`):** `_log_event` + a single `EXIT` trap writes per-run `{ts, epoch_s, session,
  cycle_id (stamped at stage-00 unlock), command, masked args, exit_code, gate_pass, duration_s,
  stage_from→to, card, project_type, mode, flow_version, tier, host, read_only}`. Dual sink: per-project
  `.flow/events.jsonl` (full) + device-global `~/.claude/flow/usage.jsonl` (compact, <PIPE_BUF →
  race-safe append). **No-fail / exit-code preserving** (trap captures `$?` first, re-exits unchanged;
  best-effort writes). Local-only; disable with `FLOW_LOG_DISABLE=1` / `DO_NOT_TRACK=1`. Conservative
  secret-arg redaction before disk.
- **`/flow usage`:** idempotent rollup (schema 006 `usage_event` + `rollup_cursor`, `UNIQUE(src,line_no)`)
  then analytics — cycle-time, gate fail-rate, per-stage dwell, cycle completion, command breakdown.
- **DRY:** semantic events keep reusing `trace`/`intervention`/`decision`; the usage log does not
  duplicate them (a generic `event` table was rejected at review).

**Built through `/flow`'s own gates** (isolated root, idea→contract all PASS, consistency PASS, 3 cards)
and **red-team-verified before build** (R1–R9: seconds-not-ms for portability, no-fail NFR, dropped the
overlapping table, compact global sink, `cycle_id`, redaction de-rated). Anti-FOMO discipline applied:
post-research "OTel-friendly naming" was rejected (no credible numbers, LLM-call-shaped not
harness-shaped); "kill rate" was **not fabricated** — replaced with a real cycle-completion proxy.
Independent code review verdict **SHIP** (0 critical/high; 1 MEDIUM cursor-reset fixed → monotonic
cursor; 1 LOW token-prefix mask gap accepted as documented residual). Suite: **20 suites / 386 checks**
green; version coherence clean (0.8.0 → 0.9.0). Shipped to all 5 skill homes on-device and verified by a
real installed-runner run (`flow_version=0.9.0` event + live `flow usage`).

Open follow-ups (next increment): wire usage stats into `recall`/`propose` (close the capture→reuse
loop — the feature's ultimate payoff, deferred as v2 S-a); global-log rotation/retention (unbounded
today, fine at personal volume); capture "which gate check failed" reason (deferred R5).

## v0.8.0 — Antigravity (Gemini-3) cross-vendor third engine (2026-06-16)

flow gains a **third** cross-vendor engine alongside Codex: Google **Antigravity (Gemini-3)** via the
`agy` CLI / IDE — a three-model adversarial gate (Claude × GPT-5.x × Gemini-3). Install scripts now
target Antigravity's skill homes (`~/.gemini/antigravity-cli/skills/flow` CLI + `~/.gemini/config/skills/flow`
IDE) — the same `SKILL.md` bundle, no restructuring. Seam doc `references/antigravity-integration.md`
+ detection mirrored in `agent-detection.md` + SKILL.md invocation note; doc-contract suite
`test_flow_antigravity_integration.sh` (29).

**Headline (the live-verify that shaped the design):** probing `agy` on this machine proved
`agy -p` returns **exit 0 with empty stdout even when unauthenticated** (error only in `--log-file`;
non-TTY capture empty via raw pipe and winpty alike). So the tier routes **only on non-empty expected
output, never on exit code** (which lies), the **interactive** path is the supported default, and an
empty Gemini result is **"review unavailable", never an approval** — a silent false-PASS gate avoided
by measurement, not assumption. Suite: **19 suites / 367 checks** green; coherence clean.

## v0.7.0 — usage signal + constitution + assess repo-map (2026-06-16)

Three ported-and-adapted upgrades (anti-FOMO research → red-team-verified plan → dogfooded build):
- **`accessed_count` usage signal** (schema 005): `recall`/`query` now order durable rows
  security-first, then by reuse count — a read-only signal that never deletes or reorders away
  real rows. (`flow_harness.py`)
- **`/flow constitution`** — advisory checker of operator-authored per-project invariants in
  `flow/constitution.md` (structure + optional `\|`-safe grep-markers). Deliberately NOT wired into
  `cmd_next` (no hot-path coupling); run it at the scope/PRD/contract seam. (`flow.sh`, template,
  gate-rules)
- **assess repo-map** — `flow.sh assess` now seeds a stdlib reference-count ranking of the
  existing codebase (no tree-sitter; 512 KB cap; TS typed-arrow aware). (`repo_map.py`)

Cross-model Codex red-team on the assembled release found 2 majors (repo_map TS typed-arrow blind
spot; constitution `|`-split corrupting alternation markers) + 2 doc/manifest drifts — all fixed
and regression-locked before ship. Suite: **18 suites / 338 checks** green; version coherence clean.

## v0.6.3 — Windows/Codex runner launcher (2026-06-15)

Found by dogfooding `$flow` inside Codex on Windows: the agent followed SKILL.md and ran
`bash <skill-dir>/runner/flow.sh status`, but in Codex/PowerShell a bare `bash` resolves to
**WSL** (`C:\WINDOWS\system32\bash.exe`), which can't read `C:/...` or `/c/...` paths — the
mechanical layer failed with `No such file or directory` before any gate ran (the skill looked
broken when it wasn't). Fix: added `runner/flow.cmd`, a Windows launcher that locates Git Bash
(skipping WSL) and runs the engine with a forward-slash path Git Bash accepts; SKILL.md's
"Running the mechanical layer" now tells the agent to use `flow.cmd` on Windows/Codex and warns
about the WSL trap. Verified: `flow.cmd doctor`/`coherence` run clean from PowerShell. No engine
or gate change; suite still **291** green.

## v0.6.2 — portable multi-harness install (2026-06-15)

`flow` is a portable skill (same `SKILL.md` format on Claude Code, Codex CLI, and other
SKILL.md-aware agents). `install.sh`/`install.ps1` `global` now install into **every harness
present** — `~/.claude/skills/flow` (always) + `~/.codex/skills/flow` + `~/.agents/skills/flow`
(each only if that harness exists) — plus targeted `global claude|codex|agents`. The repo is the
single source of truth: re-run `install.sh global` to re-sync all harnesses (no drift). Codex
invokes it as **`$flow`** (skill, `$`-prefix), not `/flow` or `/prompts:flow`. `install.ps1`
hardened here: prefers Git Bash over WSL's `System32\bash.exe` (WSL can't see `C:/` paths),
forward-slashes the runner path, dotfile-parity copy, non-fatal doctor. Suite still **291 dev**,
all green; no engine change.

## v0.6 — cross-artifact consistency audit (2026-06-15)

New advisory `flow.sh consistency`: the **mechanical** complement to the traceability spine
that gate-rules.md (§03/§05) demanded but only a human checked. It closes the missing axis of
the drift lattice — `coherence`=versions, `contract`=URL prefixes, `tokens`=design tokens, and
now `consistency`=do the planning artifacts + cards trace to each other. Grounded in 2026
research (GitHub Spec Kit's `/analyze` made spec-driven gating mainstream; harness > model is now
empirically established). Precise, ID-based only (no fuzzy matching, per the no-vibes rule):
every PRD `FRn` must be claimed by a card (`implements:`) and served by a contract interface; the
success metric must carry a number; placeholder sweep across 00–05. CRITICAL/HIGH → FLAGGED
(exit 1); MEDIUM/LOW → notes (exit 0). Three template anchors added (PRD `FRn:`, card
`implements:`, contract `FRn →`). Semantic passes the runner can't judge (hollow coverage,
conflicting requirements, cut-list contradiction, terminology drift) live in gate-rules.md.
39 consistency tests at v0.6 (happy + edge: boundary, CRLF, infra, missing dirs; now 42 with the
v0.6.1 nudge); full suite **291 dev / 313 grand**, all green.

### v0.6 dogfood run (2026-06-15) — `/flow` end-to-end on a real project (`flowstat`)

Built a real CLI (`flowstat`, a read-only consolidated `/flow` dashboard, D:\project\flow\flowstat)
through the FULL gate gauntlet (00-idea→05-contract→C-001..C-003→review→retro) in `work` mode, to
exercise the v0.6 `consistency` feature + FR anchors on REAL artifacts. Headline numbers:

- **`consistency` tracked the real build state exactly:** at the Cards boundary with the PRD's
  FR1/FR2/FR3 declared + contract-mapped but no cards yet → **3 CRITICAL (uncovered), exit 1**; after
  authoring the 3 cards with `implements:` → **PASS, exit 0**. **0 false positives, 0 false negatives**
  across the run. This is the first positive-path data point for the feature on real (non-synthetic) artifacts.
- **v0.6 template anchors scaffolded correctly** into a fresh project: the PRD `FRn:` guidance, card
  `implements:` field, and contract `FRn →` map all appeared from the global install — and were
  authorable in `work` mode with no friction.
- **The built tool cross-validates the feature:** `flowstat`'s own FR-coverage section agrees with
  `flow.sh consistency`'s verdict on the same project (manual paired capture; both CLEAN). 32 tests green.

Dogfood findings (friction → next upgrade):
| # | Finding | Severity | Status |
|---|---|---|---|
| DF6-1 | The live `consistency` cross-check from a Windows-python `subprocess` → Git-Bash loses drive mounts (rc 127); the script path can't be launched. Not a `/flow` bug, but any test that shells the runner from Windows-python must hand `/c/`-form paths or skip. | LOW (test-env) | flowstat test O skips honestly; asserts on Linux/macOS CI |
| DF6-2 | Trace tier stayed 1/3 (lane `normal` wants 2) on every `check` — the standing DF-4 reappears: card→trace fields aren't auto-populated. | LOW | tracked (DF-4 dup) |
| DF6-3 | `consistency` is advisory-only; nothing in the runner *prompts* the operator to run it at the Cards boundary (I ran it by discipline). A one-line nudge in `cmd_card`/`cmd_status` when FRs exist + a card lands could close the loop. | LOW (DX) | **FIXED v0.6.1** — `cmd_next` (planning-complete) + `cmd_status` now nudge `/flow consistency` when the PRD declares `FRn` (gated by `prd_declares_fr`); +3 tests |

Net: v0.6 `consistency` performed correctly on real artifacts (3→0 with zero error); the only friction
is DX (a nudge) + a test-harness portability note — no correctness defect in the feature.

## Codex-integration dogfood run (2026-06-14) — the headline result

Used `/flow` (released global runner) to build its OWN v0.4 Codex cross-vendor tier — full
gauntlet (assess→00..05→C-001..C-005→live verify). The point was to MEASURE the skill, and the
single most important number came from the new feature verifying itself:

**Live cross-model catch: a real GPT-5.x `codex adversarial-review` (job `review-mqdz64jr-bp75qu`)
found 2 genuine defects that the same-model author AND the same-model semantic gate both passed.**
- HIGH (conf 0.88): detection routed on "installed" not "usable" → installed-but-unauthenticated
  hosts would route into Codex then fail (broke the detect-and-degrade promise). Fixed (INSTALLED
  vs USABLE + liveness probe).
- MED (conf 0.93): the review-lens cost gate added a rogue zero-findings auto-trigger contradicting
  the 3-trigger cost gate. Fixed (opt-in only).
Both re-verified RESOLVED by a live rescue-path call (`codex:codex-rescue`). Recorded as
`harness intervention #1 (correction by reviewer)`. **This is the cross-model-catch metric going
from a cited claim (43→91% merge-ready) to a first-party data point: 2/2 real defects caught that
single-vendor review missed.**

### Dogfood findings (this run) — friction to feed the next upgrade
| # | Finding | Severity | Status |
|---|---|---|---|
| DF-1 | `flow coherence` reported "no declared version fields found — skipped" while a REAL drift existed (SKILL.md 0.2.0 vs manifest 0.3.0 vs docs v0.2). The skill's own anti-drift tool missed its own drift — its version-field detector doesn't read SKILL.md frontmatter `version:` or manifest `"version"`. | HIGH (tool blind spot) | open — runner fix next release (forbidden to edit runner mid-run) |
| DF-2 | Same-model semantic gate passed the contract/PRD stages on internally-inconsistent docs; only the cross-model engine caught it. Confirms the exact blind spot this feature targets — and argues the cross-model lens should be standard on the Contract gate, not just card review. | MED | tracked → consider widening lens to Contract gate in v0.5 |
| DF-3 | Harness CLI verb inconsistency: `decision add --id`, but `intervention` takes NO `add` subverb and `--description` (not `--note`); `intake` differs again. 3 usage errors hit this session. | MED (DX friction) | open — normalize harness CLI verbs |
| DF-4 | Auto-trace stayed tier 1/3 on every card (lane 'normal' wants 2); cards passed but the harness nags each `check`. The richer trace fields aren't auto-populated from a card. | LOW | tracked |
| DF-5 | Card allowed-files containment conflicts with cross-cutting fixes: the live HIGH finding spanned 3 docs but C-003 owned 1 → had to document honest drift. The "one card = its allowed files" law needs an escape hatch for review-driven cross-doc repairs. | LOW (process) | documented in C-003 |

Close rate this run: 2/5 fixed-and-shipped in-session (the 2 review findings); 3 tracked for the
runner-edit follow-up (can't touch the runner mid-run).

## v0.5 quality-hardening run (2026-06-14) — adversarial review → fix

A 32-agent adversarial workflow (5 static dimensions + a live cross-vendor Codex pass, every
finding adversarially verified) scored the v0.4 Codex tier and the `/flow` run that built it, then
the confirmed P0–P3 findings were fixed under `/flow` (cards C-006..C-009) + an out-of-band engine
maintenance step (the runner edits `/flow` forbids mid-run).

**Scorecard (v0.4 as-shipped):** safety 86 · consistency 78 · process 78 · portability 68 ·
**test-guard 38 (weakest)** · live Codex `needs-attention`. Composite ≈70 — "ships, safe, fixable debt."

**The live cross-vendor Codex pass caught a 2nd real defect on the shipped commit** (auto-run routed
a *first*-red Tier-B repair to billable Codex without the two-strikes condition; the test had 0
assertions against auto-run.md) — the feature's value-prop, proven a second time.

**Fixed (confirmed-real, adversarially verified):**
- **P2-1 (portability):** the USABLE liveness probe used `codex-companion status`, which returns
  **no auth field** (verified) → non-load-bearing. Switched to `setup --json` (`ready`+`auth.loggedIn`).
- **Auto-run cost-gate:** first-red Tier-B now stays same-ladder; Codex only at the true 2nd strike / security / opt-in.
- **Contract I1 drift:** `flow/05-contract.md` now carries the USABLE two-state (was INSTALLED-only).
- **Test guard (38→ robust):** rewritten clause-bound + anti-pattern `lacks` + auto-run/probe/durable-hook coverage (19→25 checks).
- **D3-F1:** data-boundary note (ScopedBrief → OpenAI) added beside the auth clause.
- **P3 / DF-2:** a self-consistency (+ opt-in cross-model) challenge wired into the **Contract gate** — closes the gate false-pass at its source.

**Engine maintenance (out-of-band, not a card — `/flow` forbids runner edits mid-run):**
- **DF-1 (now FIXED):** `flow coherence` now reads SKILL.md frontmatter `version:`, `*-manifest.json`,
  and `.claude-plugin/plugin.json` — for project-type=skill it had ZERO version source. The fix
  immediately caught a real drift (plugin.json stuck at 0.3.0). All now 0.5.0 → coherence PASSES.
- **DF-6 (now FIXED):** the runner idempotently adds run-state (`MODE`, `PROJECT_TYPE`, `.flow/`)
  to `.gitignore` (only in a git repo) — no more host-repo pollution.
- **DF-3 (partial):** `intervention --note` added as an additive alias for `--description`; full
  verb-grammar normalization remains a deliberate test-first follow-up (not a hasty rename).

DF status now: DF-1 ✅ · DF-2 ✅ (Contract-gate lens) · DF-3 ◑ (alias; grammar pending) · DF-6 ✅ ·
DF-4 (trace-tier nag) + DF-5 (allowed-files containment) tracked.

## Size & surface
| Metric | Value |
|---|---|
| Gate engine (`runner/flow.sh`) | 1430 LOC |
| Durable layer (python) | 1044 LOC (flow_harness + _db + _domain) |
| Commands | 23 (incl. drift/coverage probes `contract/tokens/coherence/consistency` + `usage [--prune]`) |
| Semantic references | 15 markdown playbooks |
| Stack playbooks | 4 |
| Schema migrations | 7 SQL (001–007; 006 = usage_event mirror, 007 = gate_fail_reason) |

## Test coverage
| Suite | Checks | Covers |
|---|---|---|
| `test_flow_runner.sh` | 18 | gate lifecycle, FILL/checkbox/evidence, gap-bypass, card validation, _python exit-code, tempdir-leak guard |
| `test_flow_harness.sh` | 19 | intake/risk-lane, trace tiers, story verify, decision, backlog, query |
| `test_flow_scenarios.sh` | 15 | the 6 buildflow validation rounds (mechanical) + repair-ladder order (debugger before codex) |
| `test_flow_project_types.sh` | 20 | project-type get/set, per-type done-evidence, skip hardening |
| `test_flow_gate_wording.sh` | 13 | Research/Contract gates project-type aware, web path preserved |
| `test_flow_coverage_gaps.sh` | 42 | retro, ready (deps), auto preflight, harness decision/tool/intervention, agent-wiring tripwire (derived set), C-021 language-specialist lens routing |
| `test_flow_concurrency_lock.sh` | 36 | session lock, TTL reclaim, foreign-lock refusal, force/unlock, atomic mkdir race, crash-recovery self-heal |
| `test_flow_recall.sh` | 22 | recall reads debt/retro/prev-card/friction/backlog/playbooks |
| `test_flow_gate_capture.sh` | 13 | gate-fired durable capture (intake/decision reminders) |
| `test_flow_propose_audit.sh` | 25 | audit health/entropy, propose suggestions, security-class review lens dispatch |
| `test_flow_contract.sh` | 14 | contract base-URL vs served-path drift (web) |
| `test_flow_tokens.sh` | 15 | DESIGN.md vs CSS token drift (unused/mismatch/orphan) |
| `test_flow_coherence_kb.sh` | 14 | version-drift coherence + cross-project KB |
| `test_flow_assess.sh` | 21 | brownfield assess scaffold + gate + status surfacing + repo-map ranking (incl. TS typed-arrow) |
| `test_flow_codex_integration.sh` | 25 | Codex doc-contract: installed≠usable, cost gate, gate parity, opt-in, auto-run, anti-pattern guard |
| `test_flow_consistency.sh` | 42 | cross-artifact coverage audit: FR→card→contract mapping, numeric metric, placeholder sweep, severity/exit |
| `test_flow_accessed_count.sh` | 12 | usage-signal ordering (security-first, reuse count), read-only, no row loss |
| `test_flow_constitution.sh` | 25 | per-project invariants: structure, `\|`-safe markers (loud sentinel-collision guard), NOT in cmd_next, recall surfacing |
| `test_flow_antigravity_integration.sh` | 29 | Antigravity third-engine doc-contract + install wiring: exit-code-lies → route on non-empty output, interactive default, data/cost gate, gate parity, liveness-probe shape, ~/.gemini install homes |
| `test_flow_usage_log.sh` | 59 | mechanical usage log + closed loop: full+compact event, mask, no-fail, disable envs, cycle_id+stage carry, idempotent rollup, `flow usage`; v2: migration 007, `usage --summary`, recall digest (+disabled), gate_fail_reason, `--prune`, usage→propose; C-017: `~approx` dwell label + `--builds-only` count + dead-var proof |
| **Total (dev)** | **479** | all green (`bash tests/run_all.sh`), 20 suites |

**Command coverage:** ~100% of runner commands now have a dedicated assertion (was 14/15;
`retro`/`ready`/`auto` + harness `decision`/`tool`/`intervention` gaps closed 2026-06-13).

## Review history (evidence-based, not self-assessed)
| Pass | Scope | Findings | Resolution |
|---|---|---|---|
| 1 | Phase 1 engine (flow.sh) | 1 HIGH + 4 MEDIUM | all fixed (gap-bypass, evidence SIGPIPE, section anchoring, …) |
| 2 | Phase 2 durable layer (python) | 3 HIGH | all fixed (migration atomicity, init crash, tool guard, Windows path) |
| 3 | Phase 4-6 shell (debt/design/install) | 0 HIGH, 1 MED + 1 LOW | both applied (PS 5.1 fallback, debt newline strip) |
| 4 | v2 skip-with-debt (dogfood) | **2 HIGH** | both fixed (stage-matched DEBT, contract never skippable, broadened guard) |
| 5 | project-type-aware gates (dogfood #1/#4) | 0 HIGH, 1 LOW | applied (stale column label); confirmed no web-gate regression |

The pattern that matters: review pass #4 caught a real security weakness (the contract/auth
seam could be skipped) before it shipped; pass #5 confirmed the gate-wording change did NOT
weaken the web/market path. The process works.

## Cross-platform support (macOS / Linux Ubuntu / Windows)
Portability self-audit of `runner/flow.sh` (re-run any time):
- ❌ none of: `mapfile`/`readarray`, `declare -A`, `${var^^}`/`${var,,}`, `[[ ]]` → **bash 3.2 safe** (macOS default shell).
- `grep -P` (emoji in `flow design`) is **probe-guarded** → degrades gracefully on macOS BSD grep.
- **no `sed -i`** in the shipped runner → no BSD/GNU `-i` divergence.
- python uses stdlib only (`sqlite3` present on all three OSes); `_python()` tries `python` then `python3`.
- `flow.sh doctor` reports the live environment on any platform.

Verified directly on Windows (Git Bash, bash 5.2). macOS/Linux: scripts written to POSIX +
bash-3.2 constraints from researched BSD/GNU differences (not yet run on real mac/linux —
the doctor command + the audit are the safety net; a real-machine run is the open item).

## Dogfood findings (using /flow to build /flow)
5 findings; 2 fixed + shipped, 3 tracked. See `plans/reports/dogfood-self-build-260613.md`.
This file's #1 and #4 are the next target (research/contract gate web-flavoring).

## Metrics to collect over time (to drive improvement)
The aim: make quality measurable so we know if `/flow` is getting better. Most of these are
recorded **for free** by `/flow`'s own durable layer (`harness/` tables) — wire the events,
read the trend.

| Metric | Definition | How to measure (durable layer) | Baseline | Target |
|---|---|---|---|---|
| **Gate false-pass** | gate passes but artifact is hollow/incomplete | `intervention --type correction --source reviewer`; count vs stages | 0 in tests | <1% |
| **Gate false-block** | gate blocks legitimate work | `backlog add --pain "gate blocked valid stage"` then close | 1 (dogfood v1, fixed) | <2% |
| **Card first-pass rate** | cards passing `check` first try | `story` rows: `last_verified_result='pass'`/total | ~70% (dogfood) | ≥85% |
| **Command coverage** | commands with a test | suite audit | ~100% | 100% |
| **Cross-platform pass** | suite green per OS | GitHub Actions matrix CI (`.github/workflows/ci.yml`) | **3/3 OS ✓** (CI green: ubuntu 11s, macOS bash-3.2 14s, windows 49s) | 3/3 OS |
| **Dogfood close rate** | self-found issues fixed | `backlog WHERE discovered_while~'dogfood'`, closed/total | 4/5 (80%) | ≥80% |
| **Reviews-to-clean** | review passes until 0 HIGH | `decision`/`intake` per review cycle | ~1-2 per change | ≤2 |
| **Doctor pass rate** | fresh envs returning READY | `flow doctor` exit + `trace --outcome` | Windows READY | ≥90% |

Durable-layer wiring (already present): card→`story add`, check-done→`story update`+`trace`;
to collect the rest, log review findings as `intake`, friction as `backlog`, overrides as
`intervention`. No new schema needed — see the coverage analysis (subagent report, 2026-06-13).

### Top-5 next (from the coverage analysis)
1. Run the 93-test suite on a **real macOS + Ubuntu** machine (currently static-audited).
2. `ready` **parallel-safety** test: assert no allowed-files overlap in the BUILDABLE set.
3. `trace` **tier-3 boundary** unit tests (9/10/11-char summaries, CRLF input).
4. Wire SKILL.md to auto-log high-risk gate decisions as `harness decision add` (metrics-as-byproduct).
5. `retro validate` gate (RETRO.md has ≥3 real lines) before a release.

## Open quality items
- ~~Run the suite on a real macOS + Ubuntu machine~~ — **DONE**: GitHub Actions matrix
  (`.github/workflows/ci.yml`) runs all 115 checks (93 dev + 22 e2e on a real install) on
  ubuntu/macOS/windows; green on all three (macOS verified on real bash 3.2.57 arm64).
- ~~Findings #1 + #4~~ — **DONE** (branch `fix/non-web-gates`, merged; reviewed 0 HIGH; +13 tests).
- Automated per-type done-evidence validators (currently guidance enforced by the Claude layer).
- Finding #3 (the "forbidden: edit flow.sh during a run" rule wording) — clarify in CLAUDE.md.
