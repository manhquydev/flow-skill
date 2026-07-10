# Changelog

All notable changes to the flow skill. Versions follow the `version:` field in
`skills/flow/SKILL.md` (mirrored in `.claude-plugin/plugin.json` and `portable-manifest.json`;
`/flow coherence` enforces agreement). Earlier history lives in git and the README status line.

## 0.20.0 — 2026-07-10 — mission-control legibility (resume verb + status upgrade + per-card dwell)

Evidence-driven (1079-event dogfood telemetry): `status` is the most-called verb (287, 2.8x
`next`) yet had no next-action line or dwell; nothing gave a fresh agent session a resume brief
(industry's top unsolved "AI context amnesia" complaint); per-card dwell was blind in `usage
--global` because the compact log row omitted `card`/`args`. Composition of already-existing
data (per-project events log, `cards/.inflight`, gate state) — no new infrastructure.

- **New `flow.sh resume`** (read-only, no lock): last session (command names + exit + stage
  transitions, absolute timestamps — **never raw args**, since `_mask_secrets` is keyword-only
  and a quote-blind extractor would truncate escaped-quote values anyway), in-flight card(s) +
  dwell, current gate state, exactly one `NEXT ->` recommendation. Honest degradation: fresh
  project → "nothing to resume"; no telemetry → "no telemetry — showing gate state only" + gate
  state + NEXT. Torn-line defense (rejects a truncated OR mid-corrupted glued-together final
  log line). SKILL.md now instructs: run `/flow resume` first when entering a project mid-cycle.
- **`status` upgrade**: first content line after the header is `NEXT -> <action>` (shared
  `_next_action` helper with `resume` — the two verbs can never disagree); current-stage dwell
  anchored on a genuine entry transition (`exit_code=0`, not a failed-`next` retry — see fix
  below); card list compacts to `cards: N created (X done · Y in flight · Z todo)` past 10 cards
  (in-flight + todo cards always listed individually, only `done` cards summarized). Existing
  anchor strings (`gate: PASS`, `gate: BLOCKED`, `cards: N created`, `planning: at stage`) frozen
  byte-for-byte for the two known consumer suites; ≤10-card output is byte-identical beyond the
  two new lines.
- **`usage --global` dwell-blind fix**: the compact GLOBAL log row gains `card` + a
  charset-guarded, 32-char-bounded `args` field, populated ONLY when `command=card` (constant
  key shape otherwise) — reuses the existing pairing reader, no schema migration. `flow_harness.py`'s
  `cmd_rollup` (and `cmd_prune`, found missing by review) gain `errors="replace"` decode
  tolerance + a cursor-hold on a final unparseable line so one bad byte can no longer kill the
  whole rollup or permanently drop a torn-then-completed `card done` pairing.
- **Caught and fixed during the per-phase code-review pass** (independent `code-reviewer`
  subagent, one pass per phase):
  - **Critical — Windows/Git-Bash hang.** Piping `_gate_state_brief`'s nested `scan_gate`
    output into a `while read` consumer (a new Phase-3 construct) froze indefinitely whenever
    the current stage's gate was genuinely BLOCKED — a Git-Bash/MSYS early-pipe-reader-exit
    class issue. The review also found this was not new: the pre-existing Phase-2
    `_next_action` reason-lookup pipe (`scan_gate | grep -m1 | sed`) had the identical latent
    bug, previously confined to the rarely-called `resume`, now exposed on the highest-traffic
    verb by this release's own `NEXT ->` wiring. Fixed by eliminating both pipes:
    `_gate_state_brief` takes the dwell string as a plain arg and is called directly (no
    subshell); `_next_action` captures `scan_gate`'s output into a variable first, then
    greps/seds the already-drained string. A `timeout`-guarded regression test was added so CI
    can never wedge on this class again.
  - **Critical — wrong stage-dwell anchor.** A failed `/flow next` retry writes
    `stage_to=<same stage>` but never sets `stage_from` (stays at its script default `""`), so
    the original `stage_from != cur` filter did not actually exclude failed retries — dwell kept
    shrinking toward the latest failure, the exact bug the design was meant to prevent. Fixed by
    anchoring on `exit_code=0`, the field that actually discriminates a genuine entry from a
    failed retry.
  - **Medium** — the compact card-summary's displayed total could drift from the real
    done+in-flight+todo sum under sparse card numbering (`highest_card()` returns the max
    suffix, not a file count); now computed from the real per-file count.
  - **Low** — a redundant double file-loop in the compaction branch merged into one pass.
- **Tests**: new `test_flow_resume.sh` (29) and `test_flow_status_legibility.sh` (24, incl. a
  `timeout`-guarded BLOCKED-gate regression case) wired into `run_all.sh`. Full suite:
  **31 suites / 799 checks**, all green.

Also bundled (originally scoped as a separate 0.19.0, shipped together since both landed in the
same cycle):

- **New `flow.sh eval`**: behavioral proof for the semantic gate layer. Runs the real per-stage
  `gate-rules.md` challenge text against 6 curated sound/hollow fixture pairs (Stage 01
  fabricated-quote pattern, Stage 02 grade-laundering, card "merge≈shipped" evidence),
  majority-votes a nonce-protected verdict (N=3, injection-resistant), prints a per-stage
  scorecard. Opt-in and billable (clean zero-call skip if `claude` CLI absent); `--report`
  re-reads a prior batch offline for free. Proves a fresh-judge lower bound, not the work-mode
  self-challenge — see `references/gate-eval.md`. A Step-0 contract spike found `claude -p` runs
  a full agentic loop with live tool access by default; locked down with `--tools ""`. Code
  review caught and fixed a critical stdin-consumption batch-truncation bug, a shared-helper
  space-path bug, an unanchored verdict-parse regex, and a misleading drift comparison across
  differently-scoped batches.
- **Post-ship hardening (found only by the first real 3-OS CI run, invisible to local
  Windows/Linux testing):** macOS ships bash 3.2.57 as `/bin/bash` (bash < 4.4 treats a
  zero-element array as unset under `set -u`) — `_cleanup_tds()`'s unconditional
  `"${_CLEANUP_TDS[@]}"` threw "unbound variable" inside the EXIT trap on every single flow.sh
  invocation on macOS, silently breaking telemetry entirely; fixed by guarding with
  `${#arr[@]}` first. A new CI regression test called `timeout` directly, which macOS doesn't
  ship (BSD userland); fixed with a small portable wrapper. `_run_with_timeout`'s macOS fallback
  watchdog does not reliably bound a slow/stuck `claude` call on macOS specifically (confirmed
  across 3 targeted fix attempts against real CI, root cause still unconfirmed without live
  macOS access) — tracked as open debt (`DEBT.md`, opened 2026-07-10); scoped to the opt-in,
  billable, never-auto-invoked `eval` verb only. Ubuntu + Windows CI fully green including e2e.

## 0.17.0 — 2026-06-24 — repository-harness v0.1.10 deep integration (schema reconcile + kind-aware tool registry)

Reconciles flow's ported durable layer with freshly-pulled upstream `repository-harness`
(Rust `harness-cli` v0.1.10) and adopts its headline capability. Research was multi-agent +
verified-external (anti-FOMO): P1 confirmed aligned with 2025-26 tool-discovery practice
(Anthropic Tool Search); P2 (score-context) **deferred** with evidence (flow has no context-rules
surface to score against; a naive port would reward the context-bloat Chroma "Context Rot" measures).

- **P0 — schema-005 collision fixed (latent data-corruption).** flow once numbered its accessed-count
  migration `005`, colliding with upstream's `005-tool-extensions`. Adopted upstream's `005` verbatim
  and **re-homed flow's migrations to 009-012** (accessed-count + usage-log mirror), restoring 001-005
  as a faithful upstream port. The migration runner is now **column-idempotent** (skips an ADD COLUMN
  whose column exists, `CREATE … IF NOT EXISTS`, `INSERT OR IGNORE` schema_version) and a **legacy
  reconciliation** heals DBs built under the old numbering on the next `init` — no duplicate-column
  crash, no data loss (verified against a seeded legacy DB).
- **Rust seam frozen + guarded.** `_maybe_forward_to_rust` now **refuses** to forward a flow-lineage DB
  (usage mirror present, or `schema_version >= 9`) to an external `harness-cli` — exit 2 with a guiding
  message — since the lineages diverge past the shared 001-005 base. flow does not build/ship the binary.
- **P1 — kind-aware inbound tool registry** (ported from upstream, pure stdlib, 0 new deps). `tool`
  gains kind/capability/scan_target/status/checked_at; `tool register --kind cli|binary|mcp|skill|http
  [--capability] [--scan-target]`, `tool check`, `tool remove`; `query tools --capability --status`.
  Presence is probed mechanically (cli/binary on PATH incl. Windows PATHEXT, mcp/skill by path, http by
  2s TCP) so a step asks "what is equipped for purpose X" and clean-skips an absent tool. Registration
  always succeeds and records status (declared intent + last-scanned reality) — the old 4-arg
  `register` stays back-compatible (kind defaults to cli).
- **Tests:** new `test_flow_schema_migration.sh` (11: fresh + legacy-heal + crash-at-v3 heal + idempotency
  + guard) and `test_flow_tool_registry.sh` (19: 5 kinds + capability/status lookup + check + remove +
  back-compat + responsibility-reject + http-scheme), both wired into `run_all.sh`. `test_flow_usage_log.sh`
  updated for the re-homed version numbers. Full suite **27 suites / 633 checks**.
- **Release-close audit hardening** (4-agent adversarial pass, edge + happy, distrusting the first run):
  - BLOCKER fixed — `migrate()` now applies by **missing-version set** (not `version <= MAX`), so an init
    crash between migrations 003 and 004 (reconcile inserting 005) can no longer skip 004 / drop the
    `intervention` table. Regression test added.
  - http presence probe now **only probes http/https** schemes (matches upstream) — a foreign-scheme or
    bare-word `scan_target` no longer triggers a multi-second DNS/TCP stall.
  - `tool register` now **validates `--responsibility`** against the fixed 11-vocab (like `--kind`), so a
    typo can't silently break `query tools --responsibility` routing. The upsert is wrapped in an explicit
    transaction (atomic replace).
  - **Deferred / known low-probability edges** (revisit if observed): a `schema_version` row recorded while
    base tables are absent is now self-healed for the common case but not guaranteed for hand-corrupted DBs;
    `tool check` over many dead http rows scans them serially (2s each).

## 0.16.2 — 2026-06-23 — release-close polish (honesty + coverage punch-list)

A 3-agent release-readiness audit found v0.16.1 had zero code blockers but four small
honesty/coverage gaps worth closing before sealing the version. All fixed here:

- **CI-badge honesty (README EN+VN)** — the front-door claim "checks green on macOS·Ubuntu·Windows"
  implied a passing hosted CI, but GitHub Actions has been billing-blocked since v0.14.0 (every run
  fails to start). Reworded to "green **locally** … hosted CI parked on the Azure-Pipelines migration",
  so the README no longer contradicts the (red) badge. The CHANGELOG already disclosed this each release;
  now the README does too.
- **`command-dispatch.md` completed** — it billed itself the "exact mapping" but listed only 18 of the
  runner's commands. Added the 9 missing rows (consistency, constitution, project-type, usage, skip, debt,
  design, harness, doctor) so every runner verb has its documented duty.
- **Per-card dwell: failed-`done` exclusion now tested** — the "a reverted/failed `card done` never closes
  a dwell" guarantee was advertised but untested; added a negative end-to-end assertion (a gate-failed
  `card done` produces no `card_dwell` pair).
- **`--global` per-card-dwell empty-state message fixed** — it told users to "mark cards" even though the
  metric is project-local by design (the compact global log omits card ids); now says so plainly under
  `--global`.

No behavior change beyond the dwell empty-state copy. Full suite green; coherence PASS. **This seals the
v0.16 line.** Still parked (disclosed, not blocking the close): Azure CI org-setup + free grant; Phase-2
`card archive`; `docs/` refresh (CHANGELOG remains the source of truth).

## 0.16.1 — 2026-06-23 — per-card dwell metric + README sync (completes v0.16.0)

Closes the loop on v0.16.0: the `card start` stamp is now turned into a real analytics number, and
the user-facing docs are brought current (they had lagged at v0.13.1, three releases behind).

- **Per-card dwell in `/flow usage`** — pairs each operator-marked `card start` with its successful
  `card done` (both `command='card'`, the verb in `args`) per (project, cycle, card) and reports the
  start→done wall-clock. Earliest start × latest *successful* done; a failed/reverted `done`
  (exit_code≠0) never closes a dwell; cards finished by hand-edit + `check` (no `card done` event)
  simply have no pair. Surfaced in both the human view and `--json` (`card_dwell`). Rollup-only —
  the FR2 logging is unchanged; no new event type, no hot-path cost.
- **README + README_VN synced v0.13.1 → v0.16.1** — status banner now covers the v0.14–0.15
  claudekit skill-layer and the v0.16 card lifecycle; command tables document `card start|done` and
  the per-card dwell line.

New assertions in `test_flow_usage_log.sh` (end-to-end: real `card start`→`card done`→`usage`).
Full suite green; coherence PASS. CI remains parked on the Azure-Pipelines migration (GitHub billing
block) — tracked, not forgotten.

## 0.16.0 — 2026-06-23 — legible card lifecycle (operator-marked start + CLI-owned done)

Closes the one real gap a 3-agent analysis found when the operator asked whether flow underuses
ck:plan: flow already has a richer lifecycle than ck:plan (a 5-state harness story + world-state
done-gates) but only ever SHOWED the operator a 2-state card (`todo|done`) — the "what am I
mid-flight on" state was invisible, buried in the harness. ck:plan's value was never its drafter
(a real twin of flow's planner — correctly stays dropped) but its *legible* status model. This
borrows that legibility natively, portably, with zero `ck`-CLI / server dependency.

**Two new verbs (both opt-in; they COEXIST with hand-editing `status:` + `/flow check`):**
- `flow.sh card start C-NNN` — marks a card **in flight**. Tracked in a portable side registry
  (`cards/.inflight`: `<id> <epoch>`) that never touches the gate-validated `status:` frontmatter,
  so it shows even when python/harness is absent; best-effort mirrors to the harness story as
  `in_progress`. The start stamp is the foundation for a future per-card dwell metric.
- `flow.sh card done C-NNN` — a **CLI-owned** flip to `done` that removes the markdown-hand-edit
  drift risk. It is gated by the SAME done-rules as `check` (real `## Evidence` + checked Verify)
  and **reverts** to the prior status if the gate fails — never leaves a hollow `done`.

`flow.sh status` now prints an "in flight" section listing started-but-not-done cards with elapsed
time (GNU/BSD-portable integer math, no `date -d/-r`). Bare `/flow card` still creates as before
(dispatch only intercepts `start`/`done`). New suite `test_flow_card_lifecycle.sh` (16 assertions);
full suite green. **Deliberately NOT built** (adjudicated FOMO for flow's CLI-first single-cycle
use): a visual kanban board, cross-plan/cross-cycle dependency graph, the `ck config ui` server,
and `--html`/`--wiki` plan export. Analysis: `plans/260623-flow-ckplan-lifecycle-analysis/`.

## 0.15.0 — 2026-06-23 — claudekit skill-layer orchestration (Round-2: complete the wirings)

Completes the skill layer started in 0.14.0 by wiring the remaining 3 high-ROI skills into
their gate rituals and turning on lazy skill-telemetry. Docs+wiring only — still **no runner
change**. Operator decisions adopted: Q1 telemetry = yes/lazy, Q2 `suggest` verb = no, Q3 graph
tool = ck-graphify, Q4 = opt-in-with-prompt.

**3 skills wired into their gate rituals** (all opt-in-with-prompt, INFORM-only, degrade silently):
- `review-pr` @ Review — a new PR-context lens in `adversarial-review.md` (duplicate-work,
  AI-slop, breaking-change, CI-blocker, `--fix`), distinct from the wired `code-reviewer` diff
  lens (not a twin); offered only when the card ships as a GitHub PR, never on local-only builds.
- `ck-security` @ security-class cards — an explicit opt-in offer in `adversarial-review.md`
  (STRIDE+OWASP attacker personas); it **never auto-passes the Tier-C operator HALT** (the HALT
  stays classification-triggered, operator-released in `DEBT.md`).
- `retro` @ Retro — offered in `law/RETRO.md` for git-history numbers; the **operator still
  writes the retro line** (teach-mode rule holds); distinct from the `journal-writer` narrative.

**Lazy skill-telemetry ON (Q1).** After a deep-wired skill runs at its gate, its use is recorded
via the **existing** `flow.sh harness intervention add` (the same durable-metric channel the
Codex/Antigravity lenses use) — **only at the 5 wired gates**, never on every skill, never on the
`cmd_next`/`cmd_check` hot path, no new runner verb. Feeds a future usage-weighted whitelist.

Test suite `test_flow_claudekit_integration.sh` grows 27 → 42 clause-bound assertions (Round-2
adds the 3 wirings + telemetry + no-new-verb guard). Full suite green; coherence PASS (0.15.0 ×3).
Note: GitHub Actions CI is currently blocked by an account billing issue (jobs refuse to start) —
local suite is the available ground truth until billing is restored.

## 0.14.0 — 2026-06-23 — claudekit skill-layer orchestration (Round-1)

Flow already orchestrated claudekit at the **agent layer** (13 ck: agents, ck:→bmad→built-in
degrade). This release extends the same seam to the **skill layer** — a curated per-stage
whitelist answering "the kit has ~87 skills, which do I use when?". Built engine-design-first
via a 3-agent flow-skill dev team (flow-internals + catalog-triage + synthesis/red-team); the
red-teamer cut its own teammate's proposed `flow.sh suggest` verb as unproven ceremony, so
Round-1 ships docs + wiring only, no runner change.

**New `references/claudekit-skills.md`** — the single source of truth for the skill map: a
<15-skill build whitelist (the ~60% marketing catalog curated out), each pinned to its stage and
the **distinct verb** it adds beyond the wired agent (pure skill/agent twins deliberately
dropped). Carries the binding rules, identical to the Codex/Antigravity seam: a skill **INFORMS**
a stage and the gate **JUDGES** (never auto-pass/auto-fail); detection is **Claude-side** and
degrades silently (the runner can't see the skill registry and the 5 install homes differ, so
skill detection is never put in `flow.sh`); enrichments are **opt-in-with-prompt, off the hot
path** (the constitution/Codex cost-gate discipline).

**5 deep-wired high-ROI skills** at the gates where a miss is most expensive: `ck-predict` @ ADR
(5-persona pre-decision debate), `ck-scenario` @ Contract (12-dim edge-case → acceptance +
contract tests), `review-pr` @ Review/Ship, `ck-security` @ security-class cards (never
auto-passes the Tier-C operator HALT), `retro` @ Retro. ck-predict@ADR and ck-scenario@Contract
are wired into the gate ritual itself (`gate-rules.md`) this round; the rest are catalogued.

**Cuts (FOMO, not ROI):** competing orchestrators (cook/vibe/ship/bootstrap run inside a stage),
skill/agent twins, the `worktree` skill (dup of `flow.sh workspace`), `bmad-spec` as a gate (dup
of `/flow consistency`), all marketing skills. Graph tool resolved to a single pick: **ck-graphify**
(gkg not wired). New regression suite `tests/test_flow_claudekit_integration.sh` (27 clause-bound
doc-contract assertions). Operator decisions deferred to Round-2: skill-invocation telemetry
(lazy, off by default), the `suggest` verb (cut unless demand shown). Backward-compatible;
additive only.

## 0.13.1 — 2026-06-23 — real-usage fixes (harness CLI forgiveness + monorepo root guard)

Two defects found by auditing flow's OWN telemetry from two real builds it drove
(`D:\project\CMC`, 118 invocations; `D:\project\AI20K\C2-App-001`, 214 — its heaviest
real project). Both caused silent loss/fragmentation of durable data. Backward-compatible.

**Harness CLI forgiveness + non-silent errors** — in both projects, `flow harness
trace/decision/intake` calls were silently dropped to argparse **exit-2** (the durable
record never reached `harness.db`) because agents typed natural variants the parser
rejected. Now `trace` accepts the underscore variants (`--actions_taken`, `--files_changed`,
`--files_read`) and `--card` as an alias of `--story`; and **any** parse failure prints a
guiding "common forms" hint to stderr instead of a bare usage line, so a bad call is
actionable rather than a silent data loss. Canonical hyphen flags are unchanged.

**Monorepo dual-root guard** — running flow from a monorepo subdir (e.g. `frontend/`)
silently minted a **second** `.flow` root with its own `cycle_id` and `project` label,
fragmenting telemetry and double-counting cards (the real C2-App-001 failure mode). The
runner now resolves the root by adopting the nearest **ancestor** flow project (one that
has `flow/` or `cards/`) when the CWD has none of its own — printing a one-line note to
stderr. A subdir with its own `flow/`/`cards/` (a deliberate sub-project) and an explicit
`FLOW_PROJECT_ROOT` are both respected unchanged.

New suites `tests/test_flow_harness_args.sh` (6) + `tests/test_flow_monorepo_root.sh` (9).
Capability-erosion audit across v0.3→v0.13 (separate pass): **no erosion** — every past
command/gate/telemetry-field/agent-tier/test suite is still present and unweakened.

## 0.13.0 — 2026-06-22 — multi-agent worktree workspaces

A new `flow.sh workspace` command family that lets one operator run several agents
(Claude Code / Codex / Antigravity, many terminals) in **parallel without the
"one agent switches branch → every terminal flips" trap**. Each agent gets its own
`git worktree` (own HEAD/index/files, shared object store); git stays the source of
truth (`git worktree list`) and a lean append-only JSONL side-file
(`.flow/workspaces.jsonl`, 10 fields) adds the four things git can't know:
vendor, card, port-offset, task. Backward-compatible; advisory (not a `next` gate).

**`workspace add|list|enter|remove|check|doctor`**
- `add <branch> [--card C-NNN] [--vendor claude|codex|antigravity] [--task "…"] [--copy-env]` —
  provisions a worktree (reuses an existing branch or `-b` a new one), derives a
  **distinct per-worktree port-offset** under the held lock, appends one active record,
  and prints a paste-ready `cd` + `PORT`/`CODEX_HOME` block. git's refusal to check out
  one branch in two worktrees is relayed **verbatim** — that refusal is the real collision lock.
- `list` — joins `git worktree list` with the registry: BRANCH/VENDOR/CARD/HEAD/PORT/TASK,
  plus orphan-record callouts. `enter <branch>` re-prints a crashed terminal's env block.
- `check <branch> [--card C-NNN]` — pre-flight: branch already claimed? + **allowed-files
  overlap** vs other active cards (computed from the card's `## Allowed files`, the same
  invariant `/flow ready` uses — no second declaration surface).
- `remove <branch> [--force]` — safe teardown: relays git's dirty refusal verbatim,
  **never auto-forces**, tombstones only on clean success, then prunes.
- `doctor` — reconciles orphan trees / orphan records / prunable trees (exit 1 on drift);
  duplicate-port and `>FLOW_WORKSPACE_MAX` (default 4) are advisory warnings, never blocking.

New env: `FLOW_WORKSPACE_BASEPORT` (default 3000), `FLOW_WORKSPACE_MAX` (default 4).
Internals reuse the existing atomic-mkdir lock + `_json_str`/`_now`/`_norm_path`; the
line-820 `## Allowed files` extractor was lifted into a shared `_card_allowed_files`
(cmd_ready unchanged). New suite `tests/test_flow_workspace.sh` (43 assertions incl.
torn-line skip + concurrent-add registry integrity). Coexists with `/flow auto`'s internal
`card/C-NNN` worktrees via identical branch naming.

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
