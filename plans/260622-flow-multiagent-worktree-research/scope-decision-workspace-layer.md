# Scope Decision — flow `workspace` multi-agent worktree layer (v0.13 candidate)

**Date:** 2026-06-22 · **Method:** ck-predict failure-debate + flow gate discipline, over 3 parallel designs (Minimal/YAGNI · Robust · Cross-vendor — the 3rd died on a socket error; judge ran on the 2 survivors, which was enough). · **Source:** workflow `flow-workspace-scope-decision` (run wf_d019fa7a-9a4).

## Chosen scope (one line)
A **mechanical `flow.sh workspace` command family + a 10-field JSONL side-file**, where **git stays the source of truth** (`git worktree list` is the live registry) and the side-file only carries the 4 things git can't know (vendor, task, card, port). **6 verbs, 10 fields, 4 cards, 1 new test suite.** No DB, no Docker, no GUI, no scheduler.

## Why this and not more (anti-FOMO)
- Base = **Minimal/YAGNI** design (won on Identity-Fidelity + matches operator "right scope, not biggest").
- Grafted only **3 things** from the Robust design, each cheap + justified: **G1** its crash/race + torn-line *tests* (memory F1 = concurrency lock was a must-fix → non-negotiable here); **G2** "git succeeded but registry append failed → exit 0 + WARNING, never roll back a real tree" (git-is-truth, costs one `printf`); **G3** lock-held port auto-derive (max active port +1) so serialized adds get distinct ports by construction, not after-the-fact.
- **Cut entirely:** SQLite/DB (research: *no tool uses a proprietary DB*), 4 extra registry fields (derivable/duplicated), a free-text `--owns` flag (it'd be a second, looser declaration surface vs the card's `## Allowed files` invariant), pnpm hint (JS-only; flow spans 4 project types), a dedicated migration-owner column (already covered by Tier-C HALT + allowed-files overlap), Docker/GUI/tmux/auto-merge, reimplementing git's branch lock, spawning/re-parenting the shell (POSIX sh can't, across 3 OS).

## The 6 verbs
| Verb | Does | Exit |
|---|---|---|
| `workspace add <branch> [--card C-NNN] [--vendor …] [--task "…"] [--copy-env]` | `git worktree add` (drops `-b` if branch exists), derive port under held lock, append 1 active JSONL record, optional `.env*` copy, print cd+env+port block | 0 = created (or tree-created + append-WARNING); 1 = git refusal relayed **verbatim** / bad args / no git |
| `workspace list` | join `git worktree list --porcelain` with latest-per-branch record → PATH BRANCH HEAD VENDOR CARD PORT TASK; orphans flagged | always 0 (read, not a gate) |
| `workspace enter <branch>` | re-print the cd+`CODEX_HOME`+`PORT` block (recover a crashed terminal's env without re-adding) | always 0 |
| `workspace remove <branch> [--force]` | `git worktree remove` (dirty refusal verbatim, **never auto-force**), tombstone, `git worktree prune` | 0 = removed; 1 = dirty-without-force |
| `workspace check <branch> [--card C-NNN]` | pre-flight: branch already claimed? + card `## Allowed files` overlap vs other active cards (sort\|comm, no `grep -oP`) + port-dup warn | 0 = parallel-safe; 1 = claimed/overlapping |
| `workspace doctor` | reconcile porcelain vs records: prunable/orphan-record/orphan-tree → exit 1; port-dup / >`FLOW_WORKSPACE_MAX`(4) → warn-only | 0 = no drift; 1 = drift (Claude decides what to clean) |

Registry: append-only `$ROOT/.flow/workspaces.jsonl` (gitignored), one `printf` per event, last-record-per-branch wins, torn lines skipped. 10 fields: `worktree_path, branch, vendor, agent_session_id, card_id, task_label, owned_files_glob, port_offset, created_at, status`.

## Build cards (strictly serial — all but C-004 touch `flow.sh`, so they overlap by the very invariant the feature enforces)
- **C-001** — `cmd_workspace` skeleton + `_ws_*` helpers (record append, latest-by-branch, max-active-port, git-absent degrade). No wiring. Done = helper unit tests green.
- **C-002** — `add` + `list` + `enter` + dispatch/usage wiring + lift the line-820 awk into shared `_card_allowed_files` (and make `cmd_ready` reuse it, byte-identical). Done = sandbox `git init` proves create/verbatim-refusal/distinct-ports/list-join.
- **C-003** — `remove` + `doctor` + `check` + crash/race/torn-line tests. Done = dirty-refusal, orphan detection both directions, overlap exit 1, 4-way concurrent add integrity.
- **C-004** — docs (SKILL.md table, command-dispatch, auto-run coexistence note) + telemetry verify. No `flow.sh` edits. Done = `run_all.sh` green **and `gh run` GREEN on ubuntu+macos+windows** (the v0.12.1 local≠CI lesson). Parallel-safe with C-003 but practically last.

Shipped via the **skill-dev/test/version-bump** path — never edited mid-project-run (flow LAW immutability).

## Honest risks carried
`grep -oP`/bashism slipping into overlap math → macOS CI red (mitigate: test asserts none); Windows path-join `C:\` vs `/c/` → `_norm_path` everywhere; collision with `/flow auto`'s internal `card/C-NNN` worktree (mitigate: identical naming → git's own refusal guards); side-file drift is **by design** (git is truth) so list shows `-` for hand/auto-created trees until `doctor` — document, not a bug.

## 4 real operator forks (the rest is decided)
1. **BASEPORT default?** `enter`/`add` emit a port hint — bake a `FLOW_WORKSPACE_BASEPORT` (default 3000) the operator overrides, or stay offset-only and let them supply BASEPORT? (How opinionated the port hint is.)
2. **Tombstone on failed remove?** Write the removal tombstone only on clean success (current), or also when `git worktree remove` fails dirty (fuller audit trail, but tombstones that don't match reality)?
3. **`add` past the 4-tree ceiling — warn or refuse?** Current = warn-only everywhere (respects "quality over speed, unlimited"). Some operators want the guardrail to bite (exit 1).
4. **A `workspace review <branch>` convenience verb?** Cross-vendor adversarial review stays in the semantic layer by default. Want a verb that just *prints* the cross-vendor invoke command, or keep it fully out?
