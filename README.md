# flow — a gated build harness skill for Claude Code

*Read this in [Tiếng Việt](README_VN.md).*

[![CI](https://github.com/manhquydev/mq_flow/actions/workflows/ci.yml/badge.svg)](https://github.com/manhquydev/mq_flow/actions/workflows/ci.yml) — 20 test suites / 479 checks on macOS · Ubuntu · Windows

`/flow` takes a product from **idea to its real done-evidence** through honest gates — a
deployed URL for a web app, an install-and-run for a CLI, a public API + coverage for a
library, a real run for a Claude Code skill. It re-encodes the `buildflow` method and adds a
durable harness layer (intake/story/trace/decision/backlog), agent orchestration (ck: + bmad +
**Codex (GPT-5.x) second engine + Antigravity (Gemini-3) third engine** = a three-model adversarial
gate), and project-type awareness.

> Status: **v0.13.0** — adds **multi-agent worktree workspaces** (`/flow workspace add|list|enter|remove|check|doctor`):
> run several agents (Claude/Codex/Antigravity, many terminals) in parallel without the "one agent switches
> branch → every terminal flips" trap — one `git worktree` per agent, git as the live registry, a lean
> `.flow/workspaces.jsonl` side-file for vendor/card/port/task, per-worktree port-offsets, allowed-files
> overlap checks, and safe teardown. Built on the existing —
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
> **20 test suites / 479 checks green.** MIT.

## What ships

```
flow-skill/
├── skills/flow/                 # the installable skill  (-> ~/.claude/skills/flow)
│   ├── SKILL.md                 # command dispatch + semantic gatekeeper + agent orchestration
│   ├── runner/flow.sh           # gate engine (exit 0/1): status/next/assess/card/check/mode/project-type/
│   │                            #   skip/ready/auto/recall/unlock/harness/debt/design/contract/tokens/
│   │                            #   coherence/promote/doctor/retro
│   ├── _templates/              # 00-idea .. 05-contract + card (buildflow) + 00-inspect (brownfield)
│   ├── law/                     # CLAUDE.md (build-session law), DESIGN.md (UI law), RETRO.md
│   ├── references/              # 16 semantic playbooks (gates, agents, codex/antigravity, loop, design, project-types)
│   ├── harness/                 # durable layer: flow_harness.py + _db.py + _domain.py + schema
│   └── playbooks/               # paid-for stack knowledge (read before, harvest after)
├── .claude-plugin/              # plugin.json + marketplace.json (plugin/marketplace install)
├── install.sh / install.ps1     # one-command install (global or per-project)
├── tests/run_all.sh             # 20 suites / 479 checks (runner/harness/scenarios/locks/recall/capture/propose/contract/tokens/coherence/assess/usage-log)
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

**A. Install script (recommended)** — installs into **every harness present** + runs a doctor check:
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

**B. Plugin / marketplace** (for sharing across machines or a team):
```
/plugin marketplace add <path-or-git-url-to-flow-skill>
/plugin install flow@flow-marketplace
```
The repo ships `.claude-plugin/plugin.json` + `marketplace.json`.

**C. Manual** — copy `skills/flow/` to `~/.claude/skills/flow/` (or `<project>/.claude/skills/flow/`)
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
/flow contract|tokens|coherence|consistency   drift/coverage checks (path-resolution · design tokens · version · cross-artifact FR mapping)
/flow doctor           environment check across macOS/Linux/Windows
```

## Commands

Quick start above is the common path; this is the full reference — all 22 commands the engine dispatches (`bash skills/flow/runner/flow.sh <command>`):

| Command | What it does |
|---|---|
| `/flow` *(status)* | Where am I? What's blocking? + a one-line memory summary |
| `/flow next` | Check the current gate; on pass, unlock the next stage (or start at 00) |
| `/flow assess` | Brownfield: scaffold + gate a current-state assessment (`flow/00-inspect.md`) before planning |
| `/flow card` | Create the next build card (after all planning gates pass) |
| `/flow check C-NNN` | Validate a card (FILL/status/sections/done-evidence) |
| `/flow mode [teach\|work]` | Show or set who writes the gate artifacts |
| `/flow project-type [t]` | Show or set project type (`web\|cli\|library\|skill`); adapts done-evidence |
| `/flow skip <stage> --reason` | Advance past a gate that has a matching open DEBT (non-security only) |
| `/flow ready` | List buildable todo cards + a parallel-safety hint |
| `/flow auto` | Preflight an autonomous run (orchestration lives in SKILL.md) |
| `/flow recall` | Read back prior knowledge (debt/retro/prev-card/friction/playbooks) before working |
| `/flow unlock` | Clear this project's concurrency lock (after a crashed/abandoned session) |
| `/flow harness <args>` | Passthrough to the durable layer CLI (intake/story/trace/decision/backlog/query/audit/propose) |
| `/flow debt add\|list` | Record/list deliberate gate-skips in `DEBT.md` (security-class = operator-only) |
| `/flow design <file>` | Mechanical `DESIGN.md` check on a UI file (emoji/`{{}}`/engine-words/gradient) |
| `/flow contract` | Client base-URL vs served-path prefix drift (path-resolution; web) |
| `/flow tokens` | `DESIGN.md` declared tokens vs CSS usage (design-system drift) |
| `/flow coherence` | Version drift across declared version fields (doc-vs-code coherence) |
| `/flow consistency` | Cross-artifact coverage: every PRD `FRn` claimed by a card (`implements:`) + served by a contract interface; numeric metric; placeholder sweep (advisory) |
| `/flow promote <file>` | Copy a playbook into the cross-project KB (`~/.claude/flow/playbooks`) |
| `/flow doctor` | Check the environment (bash/python/grep/git) across macOS/Linux/Windows |
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
  gets one repair by a fresh subagent (two-strikes); **Tier-C security-class** (auth, tenancy,
  payments, data migration) **HALTS** for written risk acceptance in `DEBT.md`.

**4. Greenfield vs brownfield** — *new vs existing codebase*
- **greenfield** (default) — start at `/flow next` (stage 00-idea).
- **brownfield** — `/flow assess` first → a gated `flow/00-inspect.md` current-state map (stack,
  functionality / UI-UX vs product goals, risks, test baseline) before planning. Operator-reviewed.

> **Concurrency:** one session per project. A `flow/.lock` refuses a second concurrent session
> (export a stable `FLOW_SESSION_ID` for hard protection); `/flow unlock` clears a stale lock.

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
> Windows/Git Bash; the dev suite is 20 suites / 413 checks (`bash tests/run_all.sh`).

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
bash tests/run_all.sh    # 20 suites / 413 checks; needs bash (+ python for the harness/propose suites)
```

## Provenance
Method: `ai20k-build-phase/buildflow` (Tony). Harness: `repository-harness`.
Agents/packaging: `claudekit-engineer`. Method/review: `BMAD-METHOD`.
Built (and improved, by dogfooding itself) with `/flow` — see `plans/reports/`.
