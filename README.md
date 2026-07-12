# flow — a gated build harness skill for Claude Code

*Read this in [Tiếng Việt](README_VN.md).*

**31 test suites, green on the 3-OS CI matrix (Ubuntu · macOS · Windows). Hosted CI runs on
Azure Pipelines (free-tier private) after v0.21.0; GitHub Actions has been retired due to
recurring billing/quota blocks on private repos. Last verified: v0.21.0 line, GitHub Actions
run `29141602431` = green 3/3 OS immediately before the switch to Azure.**

`/flow` takes a product from **idea to its real done-evidence** through honest gates — a
deployed URL for a web app, an install-and-run for a CLI, a public API + coverage for a
library, a real run for a Claude Code skill. It re-encodes the `buildflow` method and adds a
durable harness layer (intake/story/trace/decision/backlog), agent orchestration (ck: + bmad +
**Codex (GPT-5.x) second engine + Antigravity (Gemini-3) third engine** = a three-model adversarial
gate), and project-type awareness.

> Status: **v0.21.0** (2026-07-11) — **eval-trust hardening + roadmap-A (express-lane) KILLED
> by data.** Two-part release, both evidence-driven from the first REAL gate-eval baseline.
>
> **Phase 1 — eval robustness** (motivated by a 260710 17/18-INVALID transient storm the
> pre-v0.21 harness could not postmortem): raw stdout+stderr+rc capture for both attempts on
> a final-INVALID vote (envelope stripped — no cwd/session/plugin paths — git-ignored via
> `_ignore_run_state`); first-UNRELIABLE circuit breaker (`invalid_count*3 > n` — catches the
> exact 17/18 storm class, not just all-INVALID) with an `aborted` flag guarding the batch
> `done` trailer so a filtered aborted run cannot slip through `--report`/drift as complete;
> `--keep-going` overrides (worst case ≈ 37 calls documented next to the flag);
> `FLOW_EVAL_RETRY_BACKOFF` env (default 5s, tests 0) + retry skipped when rate-limit fired OR
> when the previous attempt was a timeout (`rc=124`); best-effort `rate_limited` field anchored
> to `rate_limit_info.status` (advisory — a healthy `allowed` event carries
> `overageStatus:rejected` as a separate field, so naive grep would false-positive);
> pre-batch raw-dir prune keyed off the epoch embedded in `run_id` with a `FLOW_LOCK_TTL`
> guard for concurrent/in-postmortem runs; `fid` sanitized before touching filesystem.
>
> **Phase 2 — fixture f01a repair**: complaint #3 rewritten (lines 38-41) as a coherent online
> quote with a synthetic thread-style link; no interview-paraphrase framing that the judge was
> flagging as "laundered interview data".
>
> **Phase 3 — canonical baseline + A-kill + docs**: canonical billable batch (run
> `…-1783743592-…`) = **6/6 MATCH, 0 unreliable, 0 invalid, 18/18 parsed**. Judge
> `claude-opus-4-7`, cli `2.1.201`, `gate_rules_sha 3672145322`. Elapsed ~14 min. This is the
> drift baseline `eval --report` reads. Roadmap A (express-lane) **KILLED with numbers**:
> cycles with ≥1 successful `next` reach Cards at 14/15 (93%); contract dwell median 40s
> (n=12; the "1.3h bottleneck" was a `usage --global` averaging artifact); "33% abandonment"
> = exploration pokes + brownfield card-mode. Re-trigger condition logged in
> `docs/quality-metrics.md`.
>
> **Red-team pre-ship** (3 hostile lenses via `code-reviewer` subagents, every finding
> `file:line`-backed): 26 raw → 14 accepted (2 Critical, 5 High, 7 Medium). Adjudication
> table in `plans/260710-2354-v021-eval-trust-hardening/plan.md > ## Red Team Review`. Catches
> include the original breaker missing its own motivating 17/18 incident (retrip on
> first-UNRELIABLE, not all-invalid) and the raw-capture spec being stdout-only when the storm
> signature was stderr — both would have shipped as latent bugs without the pass. **CI GREEN
> 3/3 OS** on run `29141602431` after 2 rounds of macOS-only fixes for the retry-on-timeout
> DEBT interaction and a bash-3.2 prune-loop portability issue. Post-ship independent
> `code-reviewer` audit found 0 runtime defects, 1 fixed docs drift.
>
> **v0.20.0** — **mission-control legibility: resume verb + status upgrade + per-card
> dwell in `--global`.** Evidence-driven (1079-event dogfood telemetry: `status` is the
> most-called verb, 287 calls, 2.8x `next`, yet had no next-action line or dwell; nothing gave a
> fresh agent session a resume brief — the industry's top unsolved "AI context amnesia"
> complaint; per-card dwell was blind in `usage --global` since the compact log row omitted
> `card`/`args`). Composition of already-existing data, no new infrastructure: (1) new read-only
> `flow.sh resume` — last session (command names only, never raw args), in-flight card + dwell,
> gate state, one `NEXT ->` line; honest degradation on a fresh project or missing telemetry;
> (2) `status` gains a `NEXT ->` header line (same shared `_next_action` helper as resume, so the
> two verbs can never disagree), current-stage dwell, and a compact done/in-flight/todo summary
> past 10 cards — anchor strings (`gate: PASS`, `cards: N created`, `planning: at stage`) frozen
> for existing consumers, ≤10-card output byte-identical; (3) the compact global log row gains
> `card`+`args` (bounded, charset-guarded) only for `command=card`, unblocking per-card dwell in
> `usage --global`. Built via `ck:cook` per phase + an independent `code-reviewer` pass per phase
> (the review cycle the operator asked for), which earned its keep: it caught a **critical
> Windows/Git-Bash hang** — piping `_gate_state_brief`'s nested `scan_gate` output into a
> `while read` consumer (and a pre-existing, now-higher-blast-radius `_next_action` reason-lookup
> pipe) froze indefinitely whenever the current stage's gate was genuinely BLOCKED, an
> early-pipe-reader-exit class issue under MSYS — fixed by eliminating both pipes in favor of
> direct calls / pre-drained command substitution, with a `timeout`-guarded regression test added
> so CI can never wedge on it again. It also caught a **critical dwell-anchor bug**: a failed
> `/flow next` retry writes `stage_to=<same stage>` with `stage_from=""` (never set on that path),
> so the original `stage_from != cur` filter didn't actually exclude failed retries — fixed by
> anchoring on `exit_code=0` instead, the field that actually discriminates a genuine stage entry
> from a failed retry. Plus a medium fix (compact-form N could drift from the real
> done+in-flight+todo sum under sparse card numbering — now computed from the real count, not
> `highest_card()`'s max-suffix value). 31 suites / 799 checks green (`run_all.sh`); `coherence`
> and `consistency` PASS; not yet pushed through CI or installed to homes.
>
> **v0.19.0** — **`flow.sh eval`: behavioral proof for the semantic gate layer.** Until
> now, `gate-rules.md`'s "flag a hollow-but-mechanically-clean artifact" promise had zero
> behavioral proof — a hollow artifact passes the mechanical gate by design, and nothing
> measured whether the LLM actually catches it. `eval` runs the real per-stage challenge text
> against 6 curated sound/hollow fixture pairs (Stage 01 fabricated-quote pattern, Stage 02
> grade-laundering, card "merge≈shipped" evidence), majority-votes a nonce-protected verdict (N=3,
> injection-resistant — a fixture body literally cannot predict this run's nonce), and prints a
> per-stage scorecard. Opt-in and billable (clean zero-call skip if `claude` CLI absent);
> `--report` re-reads a prior batch offline for free. Honest scope: this proves a **fresh-judge
> lower bound**, not the work-mode self-challenge (same model reviewing what it just authored) —
> see `references/gate-eval.md`. Built via a full spike→build→review→fix pass: the Step-0 contract
> spike found a **new** risk beyond the design's own red-team (`claude -p` runs a full agentic
> loop with live tool access by default; locked down with `--tools ""`), and code review across
> the 3 phases caught and fixed a **critical** silent-batch-truncation bug (a stdin-consumption
> gotcha inside the manifest read loop), a shared-helper space-path bug (`_CLEANUP_TDS` silently
> no-op'd on any space-containing TMPDIR — common on Windows), and a misleading-drift gap
> (comparing batches that evaluated different fixture sets). Real smoke-tested against the actual
> `claude` CLI on both a sound and a hollow fixture — correctly PASS and FLAG.
> **v0.18.0** — **`ck-loop` loop-engineering integration**: flow's own "Implement→Test→Audit→Fix"
> tail gained a mechanical verify→iterate→circuit-breaker primitive by wrapping the already-installed
> `ck-loop` ClaudeKit skill — flow supplies plumbing only (`flow.sh loop-prep`/`loop-log`: isolated
> worktree, a numeric Verify command, telemetry), ck-loop stays the untouched execution engine (git
> commit/revert per iteration, stuck-detection, verify-safety-screen). Deep-wired as the 6th
> claudekit-skills.md entry, with a loop-vs-two-strikes decision matrix so there's one clear "fix it"
> path. Built via a full red-team → review → test → audit → fix pass (two independent adversarial
> reviews beyond the standard code-review gate) that caught and fixed a **critical** design bug
> (`Scope` was hardcoded to test files, which would have pushed ck-loop toward gutting tests rather
> than fixing source), a **high**-severity missing timeout on the Verify dry-run (a hanging suite
> could block the runner indefinitely), and a secret-masking bypass on `loop-log`'s card-id argument.
> **v0.17.0** — **repository-harness v0.1.10 deep integration**: reconciled flow's ported durable
> layer with upstream and adopted its **kind-aware inbound tool registry** — register external tools by
> kind (`cli|binary|mcp|skill|http`) + capability, probe presence mechanically, and let a step ask
> `query tools --capability X --status present` and clean-skip an absent tool (stdlib-only, 0 new deps).
> Fixed a latent **schema-005 collision** (flow's accessed-count vs upstream's tool-extensions): adopted
> upstream's `005` verbatim, re-homed flow's migrations to `009-012`, made the runner column-idempotent,
> and auto-reconcile legacy DBs on `init` (no data loss). The `FLOW_HARNESS_BACKEND=rust` seam is **frozen
> + guarded** (refuses flow-lineage DBs). Scope was multi-agent + verified-external research; **score-context
> deferred** with evidence (no context-rules surface to score against; a naive port would reward context-bloat).
> **v0.14–0.15** add a **claudekit skill-layer** on top of the 13-agent orchestration: a curated per-stage
> whitelist (`references/claudekit-skills.md`) answering "the kit has ~87 skills — which do I use when?",
> with 5 high-ROI skills wired into their gate rituals (ck-predict@ADR · ck-scenario@Contract ·
> review-pr + ck-security@Review · retro@Retro) — all opt-in, INFORM-only (a skill never passes a gate),
> Claude-side-detected and silently degrading, so portability holds.
> **v0.13.1** — real-usage hardening found by auditing flow's own telemetry on two real builds:
> the durable **`harness` CLI** now accepts the natural flag variants agents actually type (`--actions_taken`,
> `--files_changed`, `--card`) so traces/decisions stop silently dropping to argparse exit-2, and any bad
> form prints a guiding hint instead of a silent drop; and running flow from a **monorepo subdir** now adopts
> the ancestor flow root instead of minting a fragmented second `.flow` root.
> **v0.13.0** adds **multi-agent worktree workspaces** (`/flow workspace add|list|enter|remove|check|doctor`):
> run several agents (Claude/Codex/Antigravity, many terminals) in parallel without the "one agent switches
> branch → every terminal flips" trap — one `git worktree` per agent, git as the live registry, a lean
> `.flow/workspaces.jsonl` side-file for vendor/card/port/task, per-worktree port-offsets, allowed-files
> overlap checks, and safe teardown. Built on the existing
> engine + a closed durable **knowledge loop** (recall · audit/propose ·
> cross-project KB) + gate-fired capture + a **mechanical usage log** wired into a closed feedback loop
> (every `flow.sh` invocation self-recorded to JSONL; `recall` surfaces a usage digest, `propose` flags
> chronically-failing stages, `/flow usage [--prune]` → cycle-time/gate fail-rate/dwell; local-only).
> **v0.11 makes that telemetry trustworthy** — working `usage --global`, brownfield `cycle_id` at every
> entry point, **wall-clock** per-stage dwell, auto-derived `session_id` + PID-liveness lock (hard-blocks
> for real now), ephemeral test-run exclusion, and device-wide gate-fail reasons.
> **v0.12 deepens orchestration** — `debugger` wired into the two-strikes repair ladder, `security-reviewer`
> layered into Review, atomic lock with TOCTOU-safe acquire + crash self-heal, honest `_python` exit code,
> per-stage dwell forwarded for global analytics, and honest read-only cycle accounting — plus
> drift checks (contract/tokens/coherence/**consistency**) + brownfield
> `assess` + a concurrency lock + agent integration + DESIGN law + project-type awareness +
> **portable install across Claude Code (`/flow`), Codex CLI (`$flow`), and Antigravity (`agy` CLI /
> IDE)** + a **Windows/Codex runner launcher** (`flow.cmd`, routes around WSL-bash path failures).
> **v0.12.1** closes the v0.12 polish round: telemetry-honesty labels (`~approx` dwell + `--builds-only`
> count), orchestration completeness (git-manager + docs-manager wired; tripwire derives from
> agent-detection.md; full-suite repair discipline), and engine hygiene (tempdir SIGINT/early-return guard).
> **v0.12.2** adds the language-specialist Review lens (typescript-reviewer/.ts·.js + python-reviewer/.py,
> layered with code-reviewer, composes with security lens, detect-first degrade, gate-parity preserved) and
> fixes a v0.12.1 latent portability defect (agent-wiring tripwire used GNU-only `grep -oP`; rewritten
> with POSIX `sed -E` so macOS BSD grep CI passes).
> **31 test suites green on the 3-OS CI matrix** (Ubuntu · macOS · Windows). Hosted CI moved to
> **Azure Pipelines** (free-tier private, 1 parallel job / 1,800 min/mo) after v0.21.0 —
> GitHub Actions retired because of recurring billing/quota blocks on private repos. The last
> GitHub Actions run was `29141602431` on the v0.21.0 line = green 3/3 OS immediately before
> the switch. MIT.

## What ships

```
flow-skill/
├── skills/flow/                 # the installable skill  (-> ~/.claude/skills/flow)
│   ├── SKILL.md                 # command dispatch + semantic gatekeeper + agent orchestration
│   ├── runner/flow.sh           # gate engine (exit 0/1): status/next/assess/card/check/mode/project-type/
│   │                            #   skip/ready/workspace/auto/recall/unlock/harness/debt/design/contract/
│   │                            #   tokens/coherence/consistency/constitution/promote/doctor/usage/retro/
│   │                            #   loop-prep/loop-log (ck-loop thin wrapper)
│   ├── _templates/              # 00-idea .. 05-contract + card (buildflow) + 00-inspect (brownfield)
│   ├── law/                     # CLAUDE.md (build-session law), DESIGN.md (UI law), RETRO.md
│   ├── references/              # 16 semantic playbooks (gates, agents, codex/antigravity, loop, design, project-types)
│   ├── harness/                 # durable layer: flow_harness.py + _db.py + _domain.py + schema
│   └── playbooks/               # paid-for stack knowledge (read before, harvest after)
├── .claude-plugin/              # plugin.json + marketplace.json (plugin/marketplace install)
├── install.sh / install.ps1     # one-command install (global or per-project)
├── tests/run_all.sh             # 31 suites / 799 checks (runner/harness/scenarios/locks/recall/capture/propose/contract/tokens/coherence/assess/usage-log/workspace/monorepo-root/harness-args/loop/eval/resume/status-legibility)
└── docs/                        # architecture + codebase summary
```

---

# Installation

`/flow` is a **portable skill** — a folder with a `SKILL.md` that the same format runs in
Claude Code **and** Codex CLI (and other SKILL.md-aware agents). Install it once and the
installer drops it into every harness you have:

| Harness | Install dir | Invoke |
|---|---|---|
| **Claude Code** | `~/.claude/skills/flow/` (or `<project>/.claude/skills/flow/`) | `/flow` |
| **Codex CLI** | `~/.codex/skills/flow/` | `$flow` |
| **Agents / claudekit** | `~/.agents/skills/flow/` | per host |
| **Antigravity** | `~/.gemini/antigravity-cli/skills/flow/` (CLI) · `~/.gemini/config/skills/flow/` (IDE) | auto-match (`agy inspect`) |

It works the same on **macOS, Linux (Ubuntu), and Windows**.

## Prerequisites

| Tool | Required? | Why | macOS | Ubuntu | Windows |
|---|---|---|---|---|---|
| **bash** | **Required** | the gate engine is a bash script | built-in (3.2) | built-in | Git Bash (Git for Windows) |
| **python3** | Recommended | the durable harness layer (sqlite3) | `brew install python` | `sudo apt install python3` | python.org / winget |
| **git** | Optional | worktree parallel builds + `/flow auto` | built-in / Xcode CLT | `sudo apt install git` | Git for Windows |
| **cargo** | Optional | Rust harness power-path only | — | — | — |

> Without python the **gate engine still works fully**; only the durable records layer is
> auto-disabled. `sqlite3` ships inside python's standard library on all three OSes — no
> separate install. macOS's built-in bash 3.2 is fine (`/flow` avoids bash-4 features); install
> bash 4+ via Homebrew only if you prefer.

## Per-platform setup

### macOS
```bash
# 1. python3 (not preinstalled on macOS 12.3+):
brew install python            # or: xcode-select --install
# 2. install /flow globally:
cd /path/to/flow-skill
bash install.sh global         # -> ~/.claude/skills/flow
# 3. verify:
bash ~/.claude/skills/flow/runner/flow.sh doctor
```
Note: macOS BSD `grep` has no `-P`, so the optional `flow design` emoji check degrades
gracefully (everything else works).

### Linux (Ubuntu / Debian)
```bash
sudo apt update && sudo apt install -y bash python3 git
cd /path/to/flow-skill
bash install.sh global         # -> ~/.claude/skills/flow
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

### Windows
Requires **Git for Windows** (provides Git Bash). Install python from python.org (tick "Add
to PATH") or `winget install Python.Python.3.12` — avoid the Microsoft Store stub.
```powershell
# PowerShell:
cd C:\path\to\flow-skill
pwsh .\install.ps1 global       # -> %USERPROFILE%\.claude\skills\flow  (PowerShell 7+)
```
```bash
# or from Git Bash:
cd /c/path/to/flow-skill
bash install.sh global
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

## Install methods

**A. npm — one command, cross-OS, provenance-signed** (RC channel; stable `0.1.0` pending):
```bash
npx @manhquy/flow-skill@rc                # pre-release channel (current)
# After stable ships: npx @manhquy/flow-skill@0.1.x
```
Interactive multi-select of the 4 target agents, or use `--yes --all` for non-interactive. Pure Node — no bash, no PowerShell, works identically on macOS/Linux/Windows. See [npm-wrapper/README.md](./npm-wrapper/README.md) for the full flag reference and the JSONL streaming contract for CI.

**B. Install script (upstream reference)** — installs into **every harness present** + runs a doctor check:
```bash
bash install.sh global            # ~/.claude/skills/flow (always) + ~/.codex/skills/flow
                                  #   + ~/.agents/skills/flow  (each added only if that harness exists)
bash install.sh global codex      # one harness: claude | codex | agents | antigravity
bash install.sh project [dir]     # <dir>/.claude/skills/flow (one project, commit-able)
# Windows PowerShell: pwsh install.ps1 global | pwsh install.ps1 global codex | pwsh install.ps1 project [dir]
```
The repo is the single source of truth — **re-run the installer after any update** to re-sync
every harness (no drift between your Claude Code and Codex copies).

> **Windows:** use **`pwsh install.ps1 global`**, not `bash install.sh` — in PowerShell a bare
> `bash` may be **WSL**, which installs into the WSL filesystem (`/home/...`) instead of your
> Windows home. Run `bash install.sh` only from **Git Bash**.

**C. Plugin / marketplace** (for sharing across machines or a team):
```
/plugin marketplace add <path-or-git-url-to-flow-skill>
/plugin install flow@flow-marketplace
```
The repo ships `.claude-plugin/plugin.json` + `marketplace.json`.

**D. Manual** — copy `skills/flow/` to `~/.claude/skills/flow/` (or `<project>/.claude/skills/flow/`)
and `chmod +x` the runner on macOS/Linux.

## Activate & verify
- **Claude Code:** a **new** skills directory needs Claude Code restarted once so it starts
  watching it; edits to an already-watched skill apply within the session. Type **`/flow`**.
- **Codex CLI:** Codex loads its skill catalog **at startup**, so **fully restart Codex** after
  installing, then type **`$flow`** (or `/skills` to confirm `flow` is listed). Codex invokes
  skills with a `$` prefix — `$flow`, `$flow next`, `$flow assess` — not `/flow`.
- Confirm the environment any time: `bash ~/.claude/skills/flow/runner/flow.sh doctor`.
- **Windows manual runner calls (PowerShell/cmd/Codex):** use the launcher, not bare `bash` —
  `~/.codex/skills/flow/runner/flow.cmd doctor`. In PowerShell a bare `bash` usually means WSL,
  which can't read `C:/` paths and fails with "No such file or directory"; `flow.cmd` finds Git
  Bash for you. (Inside Claude Code's own Bash tool, `bash …/flow.sh` is fine — that's Git Bash.)

## Troubleshooting
| Symptom | Cause | Fix |
|---|---|---|
| `\r: command not found` / `bad interpreter` | CRLF line endings (Windows clone) | the repo enforces LF via `.gitattributes`; re-clone, or `sed -i 's/\r$//' runner/flow.sh` |
| `/flow` not listed | new skills dir not watched yet | restart Claude Code once after first install |
| `$flow` not found in Codex | skill not in `~/.codex/skills` or Codex not restarted | `bash install.sh global` then fully restart Codex; `/skills` to confirm |
| runner: `flow.sh: No such file or directory` in PowerShell/Codex | bare `bash` = WSL, can't read `C:/` paths | call `…/runner/flow.cmd <command>` (finds Git Bash) instead of `bash …/flow.sh` |
| `durable layer DISABLED` in doctor | python not found | install python3 (see per-platform) or ignore — engine still works |
| `flow design` finds no emoji on macOS | BSD grep has no `-P` | expected; the rest of the design check still runs |
| PowerShell `??` parse error | PowerShell 5.1 | use `pwsh` (PowerShell 7+) or the Git Bash `install.sh` |

---

## Quick start (`/flow ...`  ·  Codex: `$flow ...`)
```
/flow                  where am I, what's blocking, memory summary
/flow assess           brownfield: scaffold + gate a current-state assessment of an existing repo
/flow project-type cli set what you're building (web|cli|library|skill) -> adapts done-evidence
/flow next             gate-check current stage, unlock the next (or list what's missing)
/flow recall           read back prior knowledge (debt/retro/previous-card/friction/playbooks) first
/flow card             create a build card (after all planning gates pass)
/flow check C-001      validate a card (done = real-world proof, not "tests pass")
/flow auto             autonomous build run (Tier-A auto-merge green, halt at security-class)
/flow loop-prep C-001  iterate-to-numeric-target: worktree + Verify/Guard for the ck-loop skill
/flow contract|tokens|coherence|consistency   drift/coverage checks (path-resolution · design tokens · version · cross-artifact FR mapping)
/flow doctor           environment check across macOS/Linux/Windows
```

## Commands

Quick start above is the common path; this is the full reference — all 28 commands the engine dispatches (`bash skills/flow/runner/flow.sh <command>`):

| Command | What it does |
|---|---|
| `/flow resume` | **Read-only session-story brief for entering a project mid-cycle**: last session (command names only, never raw args), in-flight card + dwell, gate state, one `NEXT ->` line. Run this FIRST when picking up an existing project cold. |
| `/flow` *(status)* | Where am I? What's blocking? A `NEXT ->` line (same helper as `resume`), current-stage dwell, card list (compact summary past 10 cards) + a one-line memory summary |
| `/flow next` | Check the current gate; on pass, unlock the next stage (or start at 00) |
| `/flow assess` | Brownfield: scaffold + gate a current-state assessment (`flow/00-inspect.md`) before planning |
| `/flow card` | Create the next build card (after all planning gates pass) |
| `/flow card start\|done C-NNN` | Optional: mark a card "in flight" / CLI-owned flip to `done` (gated like `check`, reverts on fail). Coexists with hand-edit. |
| `/flow check C-NNN` | Validate a card (FILL/status/sections/done-evidence) |
| `/flow mode [teach\|work]` | Show or set who writes the gate artifacts |
| `/flow project-type [t]` | Show or set project type (`web\|cli\|library\|skill`); adapts done-evidence |
| `/flow skip <stage> --reason` | Advance past a gate that has a matching open DEBT (non-security only) |
| `/flow ready` | List buildable todo cards + a parallel-safety hint |
| `/flow workspace add\|list\|enter\|remove\|check\|doctor` | **Multi-agent worktree isolation** — one `git worktree` per agent so several agents (Claude/Codex/Antigravity, many terminals) run in parallel without "one switches branch → all flip". `add` provisions a worktree + distinct port-offset + paste-ready cd/env block; `list` shows who's-where; `check` flags branch/allowed-files overlap before you launch; `remove`/`doctor` tear down + reconcile safely. git is the registry; a `.flow/workspaces.jsonl` side-file adds vendor/card/port/task |
| `/flow auto` | Preflight an autonomous run (orchestration lives in SKILL.md) |
| `/flow loop-prep <card> [--metric][--iterations][--guard]` | Plumbing for the `ck-loop` skill — isolated worktree + a numeric Verify command derived from the card's own Allowed files + Phase-0 precondition self-check. ck-loop stays the untouched iteration engine. |
| `/flow loop-log <card> --iterations N --start M --end K --outcome converged\|circuit-broke\|no-improve` | Record a finished ck-loop run into usage-log telemetry (0/1/2 exit codes) |
| `/flow recall` | Read back prior knowledge (debt/retro/prev-card/friction/playbooks) before working |
| `/flow unlock` | Clear this project's concurrency lock (after a crashed/abandoned session) |
| `/flow harness <args>` | Passthrough to the durable layer CLI (intake/story/trace/decision/backlog/query/audit/propose) |
| `/flow debt add\|list` | Record/list deliberate gate-skips in `DEBT.md` (security-class = operator-only) |
| `/flow design <file>` | Mechanical `DESIGN.md` check on a UI file (emoji/`{{}}`/engine-words/gradient) |
| `/flow contract` | Client base-URL vs served-path prefix drift (path-resolution; web) |
| `/flow tokens` | `DESIGN.md` declared tokens vs CSS usage (design-system drift) |
| `/flow coherence` | Version drift across declared version fields (doc-vs-code coherence) |
| `/flow consistency` | Cross-artifact coverage: every PRD `FRn` claimed by a card (`implements:`) + served by a contract interface; numeric metric; placeholder sweep (advisory) |
| `/flow constitution` | Check operator-authored per-project invariants in `flow/constitution.md` (structure + grep-markers; advisory, **not** a `next` gate) |
| `/flow eval [--stage 01\|02\|card] [--fixture <id>] [--n 3]` | **Behavioral proof for the semantic gate**: does the LLM actually flag a hollow-but-mechanically-clean fixture? Opt-in, **billable**, clean zero-call skip if `claude` CLI absent. See `references/gate-eval.md` (fresh-judge lower bound, not the work-mode self-challenge). |
| `/flow eval --report` | Offline, zero calls: last complete batch's scorecard + drift vs the prior complete batch |
| `/flow promote <file>` | Copy a playbook into the cross-project KB (`~/.claude/flow/playbooks`) |
| `/flow doctor` | Check the environment (bash/python/grep/git) across macOS/Linux/Windows |
| `/flow usage [--global\|--prune]` | Roll up the JSONL usage log into build analytics: cycle-time, gate fail-rate, per-stage + per-card dwell, command breakdown (local-only) |
| `/flow retro` | Print the 3 retro questions |

## Modes

`/flow` has **four independent mode axes** — set them per project and mix freely:

**1. Authoring mode** — *who writes the gate artifacts* (`MODE` file; default `teach`)
- `teach` — **you** write each artifact; the AI only gate-keeps (catches hollow/fabricated content).
- `work` — the AI interviews you once, drafts stages 00–05 itself, pauses only for the scope
  sign-off, then delivers the card set. Gates bind identically in both.
- set: `/flow mode teach|work`

**2. Project type** — *what "done" means* (`PROJECT_TYPE` file; default `web`)

| Type | done-evidence |
|---|---|
| `web` | a live deployed URL + real curl output |
| `cli` | installs + a real invocation returns the expected output + exit code |
| `library` | public API imports + a usage example runs + coverage threshold met |
| `skill` | installed into `~/.claude/skills` + a real run reaches its own done-definition |

- set: `/flow project-type web|cli|library|skill` — adapts the contract seam, card sequence, and done-rule.

**3. Run mode** — *how cards get built*
- **manual** (default) — you drive: `/flow card` → build → `/flow check`.
- **auto** — `/flow auto`: an autonomous run. **Tier-A** (green) auto-merges; **Tier-B** (fixable)
  gets one repair by a fresh subagent (two-strikes) — or, if the fix needs >1 experimental attempt
  against a single numeric target, `/flow loop-prep` + the `ck-loop` skill; **Tier-C security-class**
  (auth, tenancy, payments, data migration) **HALTS** for written risk acceptance in `DEBT.md`.

**4. Greenfield vs brownfield** — *new vs existing codebase*
- **greenfield** (default) — start at `/flow next` (stage 00-idea).
- **brownfield** — `/flow assess` first → a gated `flow/00-inspect.md` current-state map (stack,
  functionality / UI-UX vs product goals, risks, test baseline) before planning. Operator-reviewed.

> **Concurrency:** one session per project. A `flow/.lock` refuses a second concurrent session
> (export a stable `FLOW_SESSION_ID` for hard protection); `/flow unlock` clears a stale lock.
>
> **Monorepo root (v0.13.1):** running flow from a subdir (e.g. `frontend/`) that has no `flow/` of its
> own automatically adopts the nearest ancestor flow project (a one-line note prints to stderr) instead of
> minting a fragmented second `.flow` root. A subdir with its own `flow/`/`cards/` and an explicit
> `FLOW_PROJECT_ROOT` are always respected.

## Knowledge loop & drift checks

The durable harness (`.flow/harness.db` + `RETRO.md`/`DEBT.md`/`playbooks/`) is a **closed
capture → reuse → improve loop** — agents accumulate and reuse experience like a human team:

- **Capture (engine-fired):** `/flow next` past stage 01 seeds an `intake`; `/flow check` (done)
  records a tier-scored `trace`; `/flow debt` logs deliberate skips.
- **Reuse:** `/flow recall` reads it all back — open debt, recent retro, the previous card's scope,
  harness friction/backlog, audit health, and playbooks — so a stage/card starts with prior pain
  in view, not cold. `/flow status` shows a one-line memory summary.
- **Improve:** `/flow harness audit` scores entropy/drift; `/flow harness propose [--commit]`
  mines repeated friction/interventions into an improvement backlog (deterministic, fires at ≥2);
  `/flow harness decision outcome` closes the predicted-vs-actual loop; `/flow retro` surfaces proposals.
- **Cross-project:** `/flow promote <playbook.md>` copies a hard-won lesson into
  `~/.claude/flow/playbooks` so `recall` surfaces it in **every** project, not just this one.

**Drift checks (advisory — flag, never auto-fix):**
- `/flow contract` — client base-URL vs served-path **prefix** drift (the double-`/api`,
  mixed-prefix class that oasdiff/Pact/Spectral miss).
- `/flow tokens` — DESIGN.md declared tokens vs the CSS actually used (unused + **value mismatch** + orphan).
- `/flow coherence` — version drift across declared version fields (the cheap doc-vs-code slice).
- `/flow consistency` — cross-artifact coverage: every PRD `FRn` claimed by a card and served by a
  contract interface, numeric success metric, no leftover placeholders (the traceability spine,
  mechanized). The drift lattice's missing axis: coherence=versions, contract=URLs, tokens=design,
  consistency=do the artifacts trace to each other.

## Codex — cross-vendor second engine (v0.4+)

`/flow`'s agent ladder is **ck: agents → bmad-\* skills → built-in fallback**. v0.4 adds a 4th,
**cross-vendor** tier: OpenAI **Codex (GPT-5.x)** via the [`openai-codex`](https://github.com/) Claude
Code plugin. It is a *second engine* — a genuinely different model used at the few moments where
that beats another Claude pass — **never a replacement** and **never required**.

**Why a second vendor.** A single-vendor harness makes the builder and the reviewer share one
model, so correlated blind spots sail through green gates. A different engine is the cheapest way
to close that same-vendor gap without weakening any gate. In this project's own dogfood, a live
Codex cross-model review caught **2 real defects** (an installed-vs-usable detection hole + a rogue
cost-gate) that same-model passes had missed — see `docs/quality-metrics.md`.

**Detect-and-degrade (absence never breaks a run).** Two states:
- **INSTALLED** — `codex:codex-rescue` is in the agent registry *or* the plugin dir exists. Necessary, not sufficient.
- **USABLE** — INSTALLED **and** a cheap, non-billable probe passes: `codex-companion.mjs setup --json`
  reports `ready` + `auth.loggedIn`. (`setup --json`, **not** `status` — `status` carries no auth field.)

`/flow` only routes to Codex when **USABLE**; otherwise it silently-but-announced degrades to
`ck:→bmad→built-in` and records the reason. You never get a hard failure from Codex being absent.

**Cost gate — exactly 3 triggers** (Codex calls are billable GPT-5.x; default engine stays ck:):
1. a **two-strikes deadlock** — a same-model agent BLOCKED twice (Tier-B fresh-engine repair),
2. a **security-class card review** (auth / tenancy / payments / data-migration),
3. an **explicit operator opt-in** — e.g. *"draft this stage on Codex"*, or selecting it as a primary drafter.

**Gate parity is absolute.** Codex DRAFTS or CRITIQUES; the identical stage gate (`flow.sh` +
`gate-rules.md`) still judges. A cross-model review **informs triage — it never auto-passes or
auto-fails** a card.

**Trust boundary (read before enabling on sensitive code).**
- *Auth* is delegated entirely to the plugin (`codex login` / `OPENAI_API_KEY` / ChatGPT sub).
  `/flow` never reads, stores, or logs Codex credentials.
- *Data* — selecting Codex **sends** the ScopedBrief (the diff + contract/PRD/law excerpts) to
  OpenAI's API under your OpenAI plan's retention/training terms. Even with perfect secret handling,
  the *code and specs* leave the machine. For regulated / NDA'd codebases, opt in knowingly; the
  cost gate keeps the default exposure surface small.

**Try it.** With the `openai-codex` plugin installed + authenticated:
```
/flow project-type skill
/flow card                       # cut a card
# build it, then on a security-class card or a two-strikes deadlock /flow will
# offer the Codex tier automatically; or force it explicitly:
#   "review this card on Codex"  /  "draft stage 03 on Codex"
```
The engine that ran is always announced, e.g. `review via Codex cross-model lens (needs-attention, 2 findings)`.
Full seam spec: `skills/flow/references/codex-integration.md`.

## Antigravity — cross-vendor third engine (v0.8+)

v0.8 adds a **third** cross-vendor engine: Google **Antigravity (Gemini-3)** via the `agy` CLI or the
Antigravity IDE. Same role as Codex — a genuinely different vendor used at the same high-value moments,
giving a **three-model adversarial gate** (Claude × GPT-5.x × Gemini-3 rarely share a blind spot).
flow installs into Antigravity's skill homes (`~/.gemini/antigravity-cli/skills/flow` for the CLI,
`~/.gemini/config/skills/flow` for the IDE) — it's the **same `SKILL.md` bundle**, no restructuring;
run `agy inspect` to confirm it's discovered.

**Strictest usability check of any tier (measured, not assumed).** `agy -p` returns **exit code 0 with
empty stdout even when unauthenticated** (the error only lands in `--log-file`), and non-TTY stdout
capture is empty. So flow routes to Antigravity **only on non-empty expected output — never on the exit
code, which lies** — and because headless capture is unreliable, the **supported default is interactive**
(run the review in the IDE Agent Manager / a real `agy` terminal and paste the result back). An empty
Gemini result is **"review unavailable", never an approval**. Same detect-and-degrade, same billable +
data-leaves-the-machine cost gate (3 triggers), same absolute gate parity as Codex. Full seam spec:
`skills/flow/references/antigravity-integration.md`.

## Demos — real walkthroughs (captured from a live install)

These are real transcripts from driving the installed `/flow` (see `tests/`-style `e2e-drive.sh`).

### Demo 1 — build a web app (happy path: walk the gates → card → done)
```
$ /flow next                         # unlock stage 00 (idea); fill it, check its gate boxes
$ /flow next   (x6, filling each)    # Research → Scope → PRD → ADR → Contract
PASS: stage 05-contract gate clean. Planning is COMPLETE.
All planning stages passed (or were debt-skipped). Run '/flow card' to create build cards.
$ /flow card                         # -> cards/C-001.md
$ /flow check C-001                  # after building + pasting real evidence
PASS: C-001 is valid (status: done).
```

### Demo 2 — build a CLI / skill (done-evidence adapts, no URL needed)
```
$ /flow project-type cli
$ /flow project-type
project type: cli (default web)
  done-evidence for 'cli': the tool installs and a real invocation returns the expected output + exit code
```

### Demo 3 — a gate blocks you honestly (and KILL is a valid outcome)
```
$ /flow next                         # nothing filled in yet
FAIL: gate for stage 00-idea is not clean.
  [x] unchecked gate boxes:
      L4:- [ ] The pitch below is 3 sentences, no more
  [x] unfilled [FILL] placeholders:
      L10:[FILL: sentence 1 — who has the problem]
Fix the above, then run '/flow next' again. (Kill at a gate is also valid.)
```

### Demo 4 — "done" must be real-world proof, not "tests pass"
```
$ /flow check C-001                  # status: done, but Evidence still "(empty until done)"
  [x] status is 'done' but ## Evidence is empty (paste world-state proof: URL/curl/DB row)
FAIL: C-001 has gate violations (above).
```

### Demo 5 — legitimately skip a gate that doesn't fit (debt + skip)
```
$ /flow debt add "skip 01-research" "internal tool, no public market" "before public release"
$ /flow skip 01-research --reason "internal tool, no public market"
PASS: stage 01-research debt-skipped (logged) -> 02-scope available. planning_complete now tolerates it.
# (the contract stage 05 can NEVER be skipped; a security-class reason HALTS)
```

### Demo 6 — durable harness + design check
```
$ /flow harness intake --type change_request --summary "add login" --flags auth
PASS: intake #1 -> lane=high_risk          # auth is a hard gate -> auto-escalates
$ /flow design page.html                   # static UI check before a frontend card
  [x] emoji / smart arrows (DESIGN.md: never): L1:<h1>My Workshop 🎉</h1>
  [x] raw {{ }} template outside a power surface: L2:<p>Welcome {{ user.name }}</p>
```

> Verified: a full happy/edge e2e (22 checks) runs green against a fresh per-project install on
> Windows/Git Bash; the dev suite is 31 suites / 799 checks (`bash tests/run_all.sh`).

## Project types
`/flow project-type <web|cli|library|skill>` adapts the Contract seam, the card sequence, and
**what "done" means** per type (web: a live URL; cli: installs + runs + exit codes; library:
public API + coverage; skill: installed + a real run). See `skills/flow/references/project-types.md`.

## How it works (two layers)
- **`runner/flow.sh`** — deterministic gate engine: catches the cheatable things (unchecked
  boxes, `[FILL]`, empty evidence), exit 0/1.
- **`SKILL.md`** (Claude) — the semantic gatekeeper: catches what a script can't (fabricated
  research, grade-laundered scope, world-state evidence vs "tests pass").
A gate passes only when **both** agree. The `harness/` durable layer is the external memory
that survives sessions.

## Run the tests
```bash
bash tests/run_all.sh    # 31 suites / 799 checks; needs bash (+ python for the harness/propose suites)
```

## Provenance
Method: `ai20k-build-phase/buildflow` (Tony). Harness: `repository-harness`.
Agents/packaging: `claudekit-engineer`. Method/review: `BMAD-METHOD`.
Built (and improved, by dogfooding itself) with `/flow` — see `plans/reports/`.
