# /flow Research — Multi-agent parallel work without branch collisions

**Date:** 2026-06-22 · **Stage:** Research (gated) · **Target:** upgrade `flow` skill (v0.12.2 → v0.13 candidate)
**Operator problem (verbatim intent):** running many terminals, each with an agent (Claude Code / Codex / Antigravity), sometimes several of the same kind. When one terminal's agent creates/switches a branch, **every other terminal flips to that branch and its files change underneath the other agents.** Want: many agents at once, each knowing who is doing what on which branch, fully isolated, no "one switches → all switch."

> Findings (facts, cited) are separated from Recommendations (judgment). Numbers are dated snapshots, not vibes. FOMO rejected: qualitative signal only validates, never justifies adoption.

---

## 1. Root cause (diagnosed, git-internals level) — FINDING

Your collisions are **not** an AI-agent bug. They are the documented behaviour of a single git clone.

A normal clone has **exactly one** of each of these, shared by every terminal whose working dir is inside it:
- `.git/HEAD` — one file: `ref: refs/heads/<branch>`. This *is* "the branch you're on." It is **not** per-terminal.
- `.git/index` — one staging area.
- the working-tree files on disk — one set.

So when agent A runs `git checkout -b X` (or `git switch`), git does three things to that **shared** state: rewrites `.git/HEAD`, resets `.git/index`, and **overwrites the files on disk** to match X. Agent B ran nothing — but B's `git status` now says X (re-reads the same HEAD) and B's open files changed underneath it (step 3). That is your exact symptom.
Bonus failure you'll also hit: two agents committing at once race on `.git/index.lock` → `fatal: Unable to create '.git/index.lock': File exists`, which blocks all git ops until cleared.

**Source:** Pro Git 2e (Git Internals — References & Objects); `git-worktree(1)` man page, Git 2.54.0 (2026-04-20); Augment Code parallel-agents guide (upd. 2026-06-18).

## 2. The fix primitive: `git worktree` — FINDING

`git worktree add <path> <branch>` creates a **linked working tree**: its own directory, its own `HEAD`, its own `index`, its own files — but it **shares the same `.git` object store and refs**. Per the man page: "sharing everything except per-worktree files such as `HEAD`, `index`, etc."

| Resource | Shared across worktrees | Per-worktree |
|---|---|---|
| object DB (commits/blobs/packs), refs, `config`, hooks | ✅ | |
| `HEAD`, `index`, working files on disk | | ✅ |

Consequence: agent A switching branches rewrites only `…/worktrees/agentA/HEAD` + agentA's files. **B is untouched.** Commits A makes are still visible to B (shared object DB) without changing B's checkout. This is precisely the isolation you asked for.

**Guardrails (documented):**
- Git **refuses** to check out the *same branch* in two worktrees: `fatal: '<branch>' is already used by worktree at '<path>'` (Git 2.43+). This is itself the strongest possible lock against two agents on one branch — you physically cannot.
- Lifecycle: `git worktree list [--porcelain]` (live registry of path+branch+HEAD), `git worktree remove <path>` (clean trees only; `--force` otherwise), `git worktree prune` (repair stale metadata after a manual `rm -rf`), `--lock` (stop auto-prune reaping a long-running agent's tree).
- Cost: shares history (the bulk of a mature `.git`), so it's **seconds to create vs minutes to re-clone**; only the working files + index duplicate. The duplication that hurts is **not git's** — it's `node_modules`/build output (mitigations in §5).

**Honest gap:** no rigorous third-party timed benchmark (specified hardware/repo) was found; the "seconds vs minutes" and disk figures are vendor/community worked examples — order-of-magnitude, not measured.

## 3. Your three vendors already support this natively — FINDING (this changes the recommendation)

| Vendor | Native worktree support | How |
|---|---|---|
| **Claude Code** | ✅ first-class | `claude --worktree <name>` (alias `claude -w`). Official docs section "Run parallel sessions with worktrees." Auto-removes a worktree+branch if the session made no changes. `.worktreeinclude` copies gitignored files (e.g. `.env`) into the managed tree. `agent-view`/background agents to watch many sessions on one screen. |
| **Codex** | ✅ app; manual in CLI | Codex **app** has a Worktrees feature (composer "Worktree", `$CODEX_HOME/worktrees`, keeps 15 most recent, detached-HEAD default, `AGENTS.override.md` auto-copied). Codex **CLI** has **no `--worktree` flag yet** (issues #13120/#12862) → use plain `git worktree add`; set `CODEX_HOME` per worktree for isolated history. |
| **Antigravity** | ✅ auto (2.0) | "Manager surface" spawns/observes multiple agents across **workspaces**; a "Project" = a folder set = the agent's scope. v2.0 **auto-provisions a worktree per subagent** and auto-cleans on finish ("child agents literally cannot stomp on each other's files"). |

**Cross-vendor takeaway:** all three converge on the **same** primitive — *one git worktree (own branch, own dir, shared `.git`) per agent.* So the professional answer is not "adopt a framework"; it's "use the worktree primitive consistently, and have a registry so you know who's where."

**Source:** code.claude.com/docs Common workflows; developers.openai.com/codex/app/worktrees + /subagents; developers.googleblog Antigravity launch + antigravitylab.net worktree isolation writeup. Flagged UNVERIFIED: "worktrees = Anthropic's #1 internal tip" (community framing); exact Antigravity 2.0 auto-provision wording (reported behaviour, not a Google-doc quote).

## 4. Tool landscape — what pros built (numbers, dated 2026-06-22) — FINDING

Two patterns dominate; a third is for untrusted scale.

**Pattern A — git worktree per agent** (the de-facto default; ~10 of the tools below): filesystem isolation only, lowest setup, fastest, trivial merge-back (it's just a local branch). Does NOT stop semantic merge conflicts or shared-port/DB collisions.
**Pattern B — Docker container per agent** (container-use, Sketch, Sculptor-marketing): strong isolation (agent can trash its sandbox, not your box), but image build + daemon + disk cost, clunkier merge-back. On Windows = Docker Desktop/WSL2 overhead.
**Pattern C — cloud sandbox per agent:** strongest + unlimited parallelism, but not your box, latency/cost. Worst fit for a lightweight local harness.

| Tool | Isolation | Stars (2026-06-22) | Maturity | Tracks who's-where via |
|---|---|---|---|---|
| Vibe Kanban (BloopAI) | worktree | **27.1k** | **sunsetting** → community | kanban board (card=branch+terminal+devserver) |
| Claude Squad (smtg-ai) | worktree + tmux | ~7.9k | active | TUI over tmux (1 session/agent) |
| Worktrunk (max-sixty) | worktree | 5.5k | active (new) | minimal; launches `wt switch -x claude` |
| container-use (Dagger) | container + branch | 3.9k | experimental | git branch; runs as MCP server |
| Crystal (stravu) | worktree | ~3.1k | **deprecated** → Nimbalyst | desktop GUI |
| Conductor (Melty Labs) | worktree | n/a (closed) | polished, **macOS-only** | GUI tiles |
| workmux (raine) | worktree + tmux | 1.6k | active | **tmux window status icons** 🤖/💬/✅ + TUI |
| uzi (devflowinc) | worktree + tmux | 579 | early | `uzi ls` table (agent/model/status/diff/**auto-port**) |
| lazyworktree (chmouel) | worktree TUI | 255 | active | "agent sessions pane" per worktree |
| gwq (d-kuro) | worktree | 434 | early | `gwq status --watch` |

**Coordination reality:** there is **no proprietary DB** in this space — every tool uses **git branches as the source of truth** for "what each agent produced," and differs only in the *visibility layer* (tmux session list → status TUI → GUI/kanban). `git worktree list` is the always-accurate live registry; task/agent/status needs a small side file. The realistic ceiling everyone converges on is **3–4 parallel agents per person** before review overhead + rate limits dominate.

**Honest maturity flag:** the *highest-starred* tools are dying (Vibe Kanban sunsetting, Crystal deprecated, Sketch discontinued). The durable survivors are Claude Squad, container-use, the worktree-manager TUIs — and **the vendors' own native worktree features** (§3), which outrank all of them for your stack.

## 5. Pitfalls that worktrees do NOT solve (and the fixes) — FINDING

| Pitfall | Why | Fix |
|---|---|---|
| dev-server **port collisions** | every worktree's server defaults to :3000/:5432 | per-worktree port offset in its `.env`: `PORT = BASE + index*10` |
| **node_modules** duplication / disk blowup | each worktree has its own working dir | pnpm `enableGlobalVirtualStore: true` → symlink-only into one content store (near-instant installs); or npm workspaces |
| **`.env` missing** in new worktree | it's gitignored → doesn't travel | **copy** it in (`.worktreeinclude`), don't symlink (so one agent's edit doesn't leak) |
| shared **dev DB / migrations** | worktrees share the local DB daemon | per-worktree SQLite or name-prefixed test DBs; one **migration owner** agent |
| **semantic merge conflicts** | surface at merge time, not real time | scope each agent to **disjoint files/modules**; merge schema/migration branch first, rebase others |
| submodules | git's multi-checkout submodule support is "incomplete" | avoid worktrees on submodule-heavy superprojects |

## 6. RECOMMENDATION (judgment)

**Operationally, today:** one worktree per agent, named per agent, registry side-file, per-vendor launch (Claude `-w`; Codex CLI manual `git worktree add`; Antigravity = open the worktree dir as its own workspace). Cap at 3–4. Do **not** adopt containers (wrong cost/benefit for a trusted solo-dev stack on Windows) and do **not** adopt a GUI app (Conductor macOS-only; Crystal/Vibe Kanban EOL).

**For the `flow` skill:** flow already uses worktrees *internally* for `/flow auto` (one card → one worktree, serial) and has a single coarse `flow/.lock` for "one session per project." It does **not** yet help the operator orchestrate *human-driven, multi-terminal, cross-vendor* parallel agents — which is the actual pain. The upgrade is a **multi-agent workspace layer**: a `flow.sh workspace` command family + a `flow/workspaces.json` registry that (a) provisions a per-agent worktree+branch, (b) records agent→worktree→branch→task→status→port, (c) detects collisions (same branch is already git-blocked; add overlapping-allowed-files + port-clash checks), (d) lists live state by merging `git worktree list` with the registry, (e) tears down safely (clean + merged gate). This fits flow's two-layer model (mechanical runner + semantic gate) and its existing durable-record habit (harness/, telemetry JSONL, lock).

**Phasing (recommended): ship the playbook now, build the mechanical layer through flow's own gates.**
- **Now (no code):** add `references/parallel-agents-worktree.md` (this report's §1–§5 distilled to an operating procedure) so the operator is unblocked today.
- **v0.13 (gated build):** the `flow.sh workspace` registry layer, dogfooded + adversarially reviewed like every prior flow release.

---

## Sources (consolidated)
- git-scm.com/docs/git-worktree (Git 2.54.0, 2026-04-20); Pro Git 2e Git-Internals (References, Objects)
- code.claude.com/docs/en/common-workflows (Claude Code worktrees) ; developers.openai.com/codex/app/worktrees + /subagents ; developers.googleblog.com Antigravity launch ; antigravity.google/docs (Projects, Agent Manager — JS-rendered, corroborated via index)
- pnpm.io/git-worktrees (enableGlobalVirtualStore)
- augmentcode.com/guides/git-worktrees-parallel-ai-agent-execution (2026-06-18) ; antigravitylab.net worktree isolation ; upsun.com/devcenter git-worktrees parallel agents ; codex.danielvaughan.com (2026-03-26)
- GitHub repos (stars dated 2026-06-22): smtg-ai/claude-squad, dagger/container-use, BloopAI/vibe-kanban, max-sixty/worktrunk, stravu/crystal, raine/workmux, devflowinc/uzi, chmouel/lazyworktree, d-kuro/gwq ; conductor.build (closed, macOS-only)

## Honest gaps / flagged
- No measured benchmark for worktree-create vs clone (vendor worked-examples only).
- Antigravity 2.0 auto-worktree details = reported behaviour, not a verbatim Google doc.
- parruda/swarm star count unverified (page 404 on fetch).
- "Anthropic's #1 internal tip" = community framing, not a primary source.
