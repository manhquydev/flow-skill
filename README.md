# flow — gated build harness for coding agents

*Tiếng Việt: [README_VN.md](README_VN.md).*

[![npm](https://img.shields.io/npm/v/@manhquy/flow-skill?label=npm&color=cb3837)](https://www.npmjs.com/package/@manhquy/flow-skill)
[![tests](https://img.shields.io/badge/tests-manifest.txt-brightgreen)](tests/manifest.txt)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions%20%C2%B7%203%20OS-blue)](.github/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

`/flow` walks a product from **idea → real done-evidence** through honest gates (deployed URL,
install-and-run CLI, library API, or a real skill run). Chat is the default front door;
typed verbs (`/flow next`, `/flow card`, …) still work. **Standalone** — no AgentKit /
claudekit required. Optional multi-model review (Claude · Codex · Antigravity) when present.

| | |
|---|---|
| **Skill product** | **v0.29.0** |
| **npm installer** | [`@manhquy/flow-skill`](https://www.npmjs.com/package/@manhquy/flow-skill) **0.5.x** (ships the skill above) |
| **Tests / CI** | [`tests/manifest.txt`](tests/manifest.txt) · Ubuntu · macOS · Windows |
| **License** | MIT |

---

## Install (recommended)

**Requirement:** [Node.js](https://nodejs.org/) **≥ 22.14**.

### Standard command (copy this)

```bash
# Always use @latest so npx fetches the newest release (bare package name can hit a stale cache).
npx @manhquy/flow-skill@latest
```

What happens:

1. Downloads the **current GA** installer from npm (`latest` dist-tag).
2. Opens an **interactive** multi-select of agents detected on this machine.
3. Copies the skill tree into each selected home (e.g. `~/.claude/skills/flow`).

Then **restart / reload the agent** and invoke:

| Agent | After install |
|--------|----------------|
| Claude Code | type `/flow` |
| Codex CLI | restart once, type `$flow` |
| Cursor / Agents home | reload the tool, open the flow skill |
| Antigravity | restart IDE/`agy`, then `/flow` |

### Common variants

```bash
# Non-interactive: Claude + any agents already detected
npx @manhquy/flow-skill@latest --yes

# Explicit agents only
npx @manhquy/flow-skill@latest --yes --target claude
npx @manhquy/flow-skill@latest --yes -t claude -t codex

# All supported targets (claude, codex, agents, antigravity, cursor)
npx @manhquy/flow-skill@latest --yes --all

# Project-scoped Claude skill (commit under the repo)
npx @manhquy/flow-skill@latest --yes --project --dir .

# Preview without writing files (CI / dry-run)
npx @manhquy/flow-skill@latest --yes --all --dry-run --json

# Confirm what you will get (installer + bundled skill versions)
npx @manhquy/flow-skill@latest --help
# expect: flow-skill v0.6.x (ships skill v0.29.x)
```

### Verify install

```bash
# Version printed by the installer
npx @manhquy/flow-skill@latest --help

# Skill product version on disk (Claude global path example)
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
# expect: version: "0.29.0"  (or current skill product)

# Environment / runner
bash ~/.claude/skills/flow/runner/flow.sh doctor
# expect: READY
```

### Rules (read once)

| Do | Don’t |
|----|--------|
| Use **`@latest`** every time you want the newest skill | Bare `npx @manhquy/flow-skill` (npx cache may re-run an old copy) |
| **Run** the CLI so files land under agent homes | `npm i @manhquy/flow-skill` alone — that only adds the package; it does **not** install the skill |
| Pin installer as `@0.6.0` if you need a fixed release | Pin `@0.29.0` on npm — that is the **skill** version, not the npm package name |
| Use `@latest` / `@0.5.x` | Use `@rc` — retired / stale channel |

**Two version numbers (intentional):** npm package = installer CLI; skill product = `SKILL.md` `metadata.version`. `--help` prints both: `flow-skill v0.6.0 (ships skill v0.29.0)`.

Full flag reference: [npm-wrapper/README.md](./npm-wrapper/README.md).

---

## Quickstart

After install, open a **fresh** agent session in your project:

> "I want to build an inventory app for my shop."

The concierge reads `flow.sh status` (mechanical ground truth), asks one plain consent
question, and routes you to the next gate. Explicit `/flow …` verbs always win over chat
routing. Details: [`skills/flow/references/concierge.md`](skills/flow/references/concierge.md).

**Core ideas:** done = world-state proof (not “tests pass”); mechanical gate (`flow.sh`) +
semantic gate (skill) must both agree; kill at a gate is valid.

Release notes: [`CHANGELOG.md`](./CHANGELOG.md) · process: [`docs/release-process.md`](./docs/release-process.md).


## Where it installs

| Agent | Path | Invoke |
|-------|------|--------|
| Claude Code | `~/.claude/skills/flow` (or project `.claude/skills/flow`) | `/flow` |
| Codex CLI | `~/.codex/skills/flow` | `$flow` (restart Codex after install) |
| Agents home | `~/.agents/skills/flow` | host-specific |
| Antigravity | `~/.gemini/antigravity-cli/skills/flow` + `~/.gemini/config/skills/flow` | `/flow` after reload |
| Cursor | `~/.cursor/skills/flow` | agent skills panel after reload |

**Runtime deps for the skill (after install):** bash (Git Bash on Windows), python3 recommended for durable harness, git optional for worktrees/`auto`. Without python, gates still run; durable SQLite layer disables.

---

## Other install methods

Prefer **npm** above. Alternatives for contributors / air-gapped setups:

```bash
# From a git checkout — install script (syncs detected agent homes + doctor)
bash install.sh global                 # or: pwsh install.ps1 global  (Windows)
bash install.sh project [dir]          # project-local Claude skill

# Plugin / marketplace (Claude Code)
/plugin marketplace add <path-or-url-to-this-repo>
/plugin install flow@flow-marketplace

# Manual: copy skills/flow/ → ~/.claude/skills/flow/ and chmod +x runner/flow.sh
```

On Windows, prefer `pwsh install.ps1` or the npm path. In PowerShell, bare `bash` may be WSL
(wrong filesystem); use `runner/flow.cmd` when calling the runner outside Claude’s Git Bash.

**Dev only:** `git clone … && cd npm-wrapper && npm i && npm run sync && npm link`.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| No `/flow` after `npm i` | Run `npx @manhquy/flow-skill@latest` (must **execute** the CLI) |
| Old skill after “reinstall” | Always use `@latest`; avoid bare package name |
| Claude / Codex does not list skill | Fully restart the agent once after first install |
| `flow.sh: No such file` in PowerShell | Use `…/runner/flow.cmd` (not WSL `bash`) |
| `durable layer DISABLED` | Install python3, or ignore (mechanical gates still work) |
| CRLF / bad interpreter | Repo uses LF via `.gitattributes`; re-clone if needed |

---

## Everyday commands

```
/flow            status — where am I, what's blocking
/flow next       gate-check + unlock next stage
/flow assess     brownfield assessment
/flow card       create a build card
/flow check C-001  validate card (done = world-state proof)
/flow auto       autonomous build (halts on security-class)
/flow doctor     environment check
```

Codex uses `$flow` instead of `/flow`. Full list: [`skills/flow/SKILL.md`](skills/flow/SKILL.md).

## Command reference

All engine verbs (`bash …/runner/flow.sh <command>`):

| Command | What it does |
|---|---|
| `/flow resume` | **Read-only session-story brief for entering a project mid-cycle**: last session (command names only, never raw args), in-flight card + dwell, gate state, one `NEXT ->` line. Run this FIRST when picking up an existing project cold. |
| `/flow` *(status)* | Where am I? What's blocking? A `NEXT ->` line (same helper as `resume`), current-stage dwell, card list (compact summary past 10 cards) + a one-line memory summary |
| `/flow next` | Check the current gate; on pass, unlock the next stage (or start at 00) |
| `/flow assess` | Brownfield: scaffold + gate a current-state assessment (`flow/00-inspect.md`) before planning |
| `/flow card` | Create the next build card (after all planning gates pass) |
| `/flow card start\|done C-NNN` | Optional: mark a card "in flight" / CLI-owned flip to `done` (gated like `check`, reverts on fail). Coexists with hand-edit. |
| `/flow check C-NNN` | Validate a card (FILL/status/sections/done-evidence) |
| `/flow clarify` | List leftover `- [ ]` bullets under `## Open decisions` on Scope/PRD/Contract (advisory, not a `next` gate); write-back ritual in `references/clarify.md` |
| `/flow converge` | **Append-only** remainder cards reconciling present code vs plan: assess per `references/converge.md`, write a `flow-converge/v1` payload, then run (transactional; prints `CONVERGED` + writes nothing when there is no gap). Semantic proof: `flow.sh eval --stage converge` |
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
| `/flow eval [--stage 01\|02\|card] [--fixture <id>] [--n 3]` | **Behavioral proof for the semantic gate**: does the LLM actually flag a hollow-but-mechanically-clean fixture? Opt-in, **billable**, clean zero-call skip if `claude` CLI absent (live only). See `references/gate-eval.md` (fresh-judge lower bound, not the work-mode self-challenge). |
| `/flow eval --report` | Offline, zero calls: last complete batch's scorecard + drift vs the prior complete batch |
| `/flow eval --replay` | Keyless: replay recorded transcripts through parse/vote/scorecard. Not a fresh-judge; never counts toward the eval floor. |
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
> Windows/Git Bash; the dev suite is `bash tests/run_all.sh` (registry: `tests/manifest.txt`).

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
bash tests/run_all.sh    # suites from tests/manifest.txt; needs bash (+ python for harness/propose)
```
