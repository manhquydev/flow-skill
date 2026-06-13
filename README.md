# flow — a gated build harness skill for Claude Code

`/flow` takes a product from **idea to its real done-evidence** through honest gates — a
deployed URL for a web app, an install-and-run for a CLI, a public API + coverage for a
library, a real run for a Claude Code skill. It re-encodes the `buildflow` method and adds a
durable harness layer (intake/story/trace/decision/backlog), agent orchestration (ck: + bmad),
and project-type awareness.

> Status: **v0.2** — engine + durable layer + agent integration + loop/harness principles +
> DESIGN law + packaging + project-type awareness. **66 tests green.** MIT.

## What ships

```
flow-skill/
├── skills/flow/                 # the installable skill  (-> ~/.claude/skills/flow)
│   ├── SKILL.md                 # command dispatch + semantic gatekeeper + agent orchestration
│   ├── runner/flow.sh           # gate engine (exit 0/1): next/card/check/status/mode/
│   │                            #   project-type/skip/ready/auto/harness/debt/design/doctor/retro
│   ├── _templates/              # 00-idea .. 05-contract + card (verbatim buildflow)
│   ├── law/                     # CLAUDE.md (build-session law), DESIGN.md (UI law), RETRO.md
│   ├── references/              # 14 semantic playbooks (gates, agents, loop, design, project-types)
│   ├── harness/                 # durable layer: flow_harness.py + _db.py + _domain.py + schema
│   └── playbooks/               # paid-for stack knowledge (read before, harvest after)
├── .claude-plugin/              # plugin.json + marketplace.json (plugin/marketplace install)
├── install.sh / install.ps1     # one-command install (global or per-project)
├── tests/run_all.sh             # 66 checks across runner / harness / scenarios / project-types
└── docs/                        # architecture + codebase summary
```

---

# Installation

`/flow` is a Claude Code **skill**: a folder at `~/.claude/skills/flow/` (personal, all
projects) or `<project>/.claude/skills/flow/` (one project). It works the same on **macOS,
Linux (Ubuntu), and Windows**.

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

**A. Install script (recommended)** — copies the skill + runs a doctor check:
```bash
bash install.sh global            # ~/.claude/skills/flow (every project)
bash install.sh project [dir]     # <dir>/.claude/skills/flow (one project, commit-able)
# Windows PowerShell: pwsh install.ps1 global | pwsh install.ps1 project [dir]
```

**B. Plugin / marketplace** (for sharing across machines or a team):
```
/plugin marketplace add <path-or-git-url-to-flow-skill>
/plugin install flow@flow-marketplace
```
The repo ships `.claude-plugin/plugin.json` + `marketplace.json`.

**C. Manual** — copy `skills/flow/` to `~/.claude/skills/flow/` (or `<project>/.claude/skills/flow/`)
and `chmod +x` the runner on macOS/Linux.

## Activate & verify
- A **new** skills directory needs Claude Code to be restarted once so it starts watching it;
  edits to an already-watched skill apply within the session.
- Confirm the environment any time: `bash ~/.claude/skills/flow/runner/flow.sh doctor`
- In a project, type **`/flow`** (or `/flow next` to start a build).

## Troubleshooting
| Symptom | Cause | Fix |
|---|---|---|
| `\r: command not found` / `bad interpreter` | CRLF line endings (Windows clone) | the repo enforces LF via `.gitattributes`; re-clone, or `sed -i 's/\r$//' runner/flow.sh` |
| `/flow` not listed | new skills dir not watched yet | restart Claude Code once after first install |
| `durable layer DISABLED` in doctor | python not found | install python3 (see per-platform) or ignore — engine still works |
| `flow design` finds no emoji on macOS | BSD grep has no `-P` | expected; the rest of the design check still runs |
| PowerShell `??` parse error | PowerShell 5.1 | use `pwsh` (PowerShell 7+) or the Git Bash `install.sh` |

---

## Quick start (`/flow ...`)
```
/flow                 where am I, what's blocking
/flow project-type cli  set what you're building (web|cli|library|skill) -> adapts done-evidence
/flow next            gate-check current stage, unlock the next (or list what's missing)
/flow card            create a build card (after all planning gates pass)
/flow check C-001     validate a card (done = real-world proof, not "tests pass")
/flow auto            autonomous build run (Tier-A auto-merge green, halt at security-class)
/flow doctor          environment check across macOS/Linux/Windows
```

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
bash tests/run_all.sh    # 66 checks; needs bash (+ python for the harness suite)
```

## Provenance
Method: `ai20k-build-phase/buildflow` (Tony). Harness: `repository-harness`.
Agents/packaging: `claudekit-engineer`. Method/review: `BMAD-METHOD`.
Built (and improved, by dogfooding itself) with `/flow` — see `plans/reports/`.
