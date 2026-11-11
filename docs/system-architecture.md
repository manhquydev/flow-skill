# /flow — system architecture

`/flow` is a gated build harness: idea -> deployed URL through honest gates. It is built as
three cooperating layers plus on-disk artifacts, so a fast deterministic engine handles the
cheatable mechanics while the model handles judgment, and durable records survive sessions.

Identity (gates and receipts, never the runtime): [`adr/0001-discipline-layer-identity.md`](adr/0001-discipline-layer-identity.md).
Harness qualification SOP ("Support Thật" mandate): [`harness-qualification-process.md`](harness-qualification-process.md).

## Layers

```
+---------------------------------------------------------------+
|  Semantic layer  -  SKILL.md + references/  (Claude)          |
|  judgment: hollow content, grade-laundering, adversarial      |
|  review, agent orchestration, mode work, /flow auto tiers     |
+---------------------------------------------------------------+
              | calls (exit code = ground truth)
              v
+---------------------------------------------------------------+
|  Mechanical layer  -  runner/flow.sh  (bash, exit 0/1)        |
|  stage/card lifecycle, gate checks ([FILL]/box/evidence),     |
|  debt ledger, design check, harness passthrough               |
+---------------------------------------------------------------+
              | durable reads/writes and graph ordering (required for v1 product progression)
              v
+---------------------------------------------------------------+
|  Durable layer  -  harness/flow_harness.py  (Python+sqlite3, flow-owned) |
|  intake/risk-lane, story+proof, trace+tier, decision, backlog       |
|  (Rust forward frozen: refuse on flow-lineage DBs; not a live pin)  |
+---------------------------------------------------------------+

On-disk artifacts (in the project being built):
  flow/00-idea.md .. 05-contract.md   planning, gated
  cards/C-NNN.md                      shipping units
  MODE, RETRO.md, DEBT.md, AUTO-LOG.md, DESIGN.md
  .flow/harness.db                    durable records
```

## Distribution architecture (skill vs npm)

```
  monorepo skills/flow/  ──npm run sync──►  npm-wrapper/skills/flow  ──npm pack──► registry
         │                                         │
         │ install.sh / agent skill homes          │ npx @manhquy/flow-skill@latest
         v                                         v
  ~/.claude/skills/flow                     same tree via installer CLI
```

- **Skill product version** (SKILL.md / plugin.json / portable-manifest) drives coherence and
  harness `flow_version` telemetry.
- **npm package version** versions the installer CLI only. Canonical `scripts/release.sh` dispatches the publisher via `workflow_dispatch`; no tag-push trigger exists. Tags are verified output, created only after registry/provenance/install verification.
- Full procedure: [`docs/release-process.md`](release-process.md).

## Why this shape
- **Two-layer gate (mechanical + semantic).** A script can't tell a real competitor quote
  from a fabricated one, but it can catch an unchecked box or empty evidence deterministically.
  Splitting them means the cheatable part is ground-truth-enforced and the judgment part is
  the model's, and a gate passes only when both agree. (This is the original buildflow design.)
- **Durable layer as external memory.** Story/trace/decision/backlog persist in SQLite so
  progress and friction survive across sessions and context windows — the antidote to context rot.
- **Agents are pluggable, gates are fixed.** Stages delegate to ck:/bmad agents when present,
  fall back to built-in; the gate is identical on every path, so a missing agent never lowers
  a gate.

## Control flow (a build)
0. Entering a project mid-cycle with no prior context this session? `/flow resume` first —
   read-only session-story brief (last session, in-flight + dwell, gate state, one `NEXT ->`
   line) composed entirely from existing state (events log, `.inflight` registry, gate scan).
1. `/flow next` checks the current gate and asks the graph executor for the next topology
   node under the v1 contract; `flow.sh` remains the gate-verdict authority and refuses to
   advance when graph state is unavailable, paused, inconsistent, or untrusted. The
   current skip rules and 05-contract refusal remain unchanged.
   Unresolved product decisions live as `- [ ]` bullets under `## Open decisions` (Scope/PRD/
   Contract) — the same box scanner blocks `next`; `/flow clarify` lists them and
   `references/clarify.md` is the bounded write-back ritual (advisory, never a `next` gate).
2. After stage 05 passes, `/flow card` creates cards; each card names an `## Independent test`
   (user-visible slice proof) and is one scoped build session.
3. Cards build to the contract (the seam), are reviewed adversarially, verified on the LIVE
   URL (done = world-state, not "tests pass"), then marked done. `/flow auto` runs this loop
   autonomously with Tier-A/B/C and hard stops. `/flow status` (called far more than any other
   verb in practice) surfaces the same `NEXT ->` decision ladder as `resume` at any point.
4. **Flow-back reconciliation:** `/flow converge` (v0.29) assesses present code vs the plan and
   **appends** remainder cards transactionally (never edits an existing card) for any declared
   `FRn`/interface/MUST the tree still owes — the "hollow-complete" gap per-card gates miss.
5. Every transition writes durable records; deliberate skips open a `DEBT.md` line.

## Components
| Path | Responsibility |
|---|---|
| `skills/flow/SKILL.md` | semantic-layer entry: dispatch + gatekeeper + orchestration |
| `skills/flow/runner/flow.sh` | mechanical engine: lifecycle, gates, debt, design, harness passthrough, loop-engineering, doctor registry + bundled tree integrity |
| `skills/flow/harness/` | durable layer (Python CLI + sqlite + Rust toggle) |
| `skills/flow/_templates/` | the 7 gated artifacts (verbatim buildflow) |
| `skills/flow/law/` | CLAUDE.md (build-session law), DESIGN.md (UI law), RETRO.md |
| `skills/flow/references/` | semantic playbooks (gates, agents, loop, design, auto, v0.22 concierge/native-rituals/forge-idea, v0.29 clarify/converge/artifact-lifecycle) — count is owned by [`docs/codebase-summary.md`](codebase-summary.md), which mirrors the `references/` tree |
| `skills/flow/eval/` | behavioral-eval fixtures: artifact-vs-gate + v0.22 routing judge (`fixtures/routing/`) + v0.29 converge repo-state gap judge (`fixtures/converge/`) |
| `skills/flow/playbooks/` | paid-for stack knowledge (read before, harvest after) |
| `tests/` | Suites listed in `tests/manifest.txt` (runner / harness / scenarios / loop / eval / resume / status-legibility / concierge / native-rituals / forge-idea / harness trust-align / graph executor / doc budgets). GitHub Actions `bash-suite` job (ubuntu+macos+windows) is the source of truth. |
| `install.sh` / `install.ps1` | install to ~/.claude or a project |
| `docs/harness-qualification-process.md` | standard operating procedure for market harness intake, live 4-point verification, anti-illusion catalog, and disclosure categorization |

## Distribution channels

Two parallel installation paths, both syncing the same canonical `skills/flow/` tree:

| Channel | Entry point | Transport | Platform | Use case |
|---|---|---|---|---|
| **npm** (primary) | `npx @manhquy/flow-skill@latest` | Node.js package, 76 files 566 KB unpacked | Cross-OS (no shell dependency) | CI/CD, any environment with Node 22+ |
| **install.sh** (reference) | `bash install.sh global` + doctor step | Direct from repo via Git | UNIX shell (Bash 3.2+) | Dev machines, local skill setup, preserves diagnostic doctor |

The npm channel is the **canonical distribution** for cross-platform adoption (pure Node.js, no `bash`/`git` requirement, fast tarball extraction). The `install.sh` channel is the **reference implementation** used in development and CI matrix testing; it includes the `doctor` diagnostic step to verify the local environment. Both write to the same skill home (`~/.claude/skills/flow`, `~/.codex/skills/flow`, etc.), so a project can switch channels without re-issuing any gates or cards.

### Bundled Tree Receipt Integrity
The npm installer co-ships `skills/flow/manifest-hashes.json` generated during `sync.mjs`. `flow doctor` validates every bundled file against this receipt (detecting missing files, post-install drift, symlink substitutions, or unsafe path traversals with loud FAIL, while skipping with an advisory message on un-receipted local dev checkouts).

### Transactional Ownership Upgrades (npm channel)
The installer's receipt is also the upgrade ownership ledger: each install/update validates inputs strictly (disjoint trees, no source/dest/ancestor symlinks, no special files), surveys the destination read-only against the previous receipt (user-modified owned files, receipt/root mismatches, and legacy differing-byte collisions refuse before any mutation), stages a candidate that preserves all user-created files and prunes only unmodified retired files, then swaps via rename-only backup → promote → promoted-tree verification against the staged expectation, removing the backup only after verification. Failures restore the original; a failed restore keeps the backup and reports `recoveryPath` in the `install:done` JSONL event. The installed receipt is regenerated from the staged bytes and owns only new source files.

### Host Lifecycle Context Adapters (ADR-0001 Addendum)
Flow provides opt-in, operator-installed lifecycle context adapters (`skills/flow/adapter-hooks/`) invoked by hosting agents (e.g. SessionStart, PreCompact). Handlers execute with zero tool interposition, zero residency/daemons, and fail-open. The sole permitted write is an advisory private snapshot under `<project>/.flow/context-handoff/snapshot.json` (mode 0600 in a 0700 dir, symlink-rejected, size-bounded), enabling post-compaction status continuity without gate mutation.

### Harness Research & Qualification Process (Anti-Illusion Architecture)
Flow documents an evidence-first qualification standard for candidate coding-agent harnesses (e.g. Claude Code, Codex, Cursor, Windsurf, Roo Code, Cline, Zed, Aider). To prevent hollow compatibility claims ("quảng cáo ảo") and latent runtime bugs (container isolation failures, Windows WSL path traps, context truncation, phantom pass hallucinations), all integrations must satisfy the 6-phase intake procedure and the Four-Point Live Verification Protocol detailed in [`harness-qualification-process.md`](harness-qualification-process.md). Candidate targets are strictly partitioned into Category A (Native Skills), Category B (Workspace Rule Scaffolding), Category C (Automated Test Gates), and Category D (Incompatible/Deferred).

## Deep-wired skills (pluggable agents + decision matrix)

`/flow` ships 6 deep-wired skills (opt-in, never in `cmd_next`/`cmd_check`):
`ck-predict` (ADR), `ck-scenario` (Contract), `review-pr` (Review/Ship), `ck-security`
(security-cards), `retro`, `ck-loop` (loop-engineering). AgentKit `ak:*` names are the
same rows (`references/claudekit-skills.md` Name resolution). **v0.22 standalone**: 5 of these 6
now have a **native ritual** as the guaranteed baseline (`references/native-rituals.md`) —
persona-debate@ADR, edge-case@Contract, STRIDE@Review, numeric-retro@Retro, native loop
protocol@Build/Verify. The ck/ak skills above are offered as richer alternatives *when installed*,
never a requirement; only `review-pr` has no native equivalent (PR-context-specific).
**Loop vs two-strikes:** operators choose based on repair scope — `ck-loop`/`ak:loop`/the native loop
protocol iterates toward a numeric metric (Implement→Test→Audit→Fix tail, worktree-isolated,
5-iteration stuck-break); two-strikes gates handle deadlock in review (bounded 2-pass
escalation). Decision matrix in `references/claudekit-skills.md`.

## Concierge front-door (v0.22)

Chat is the default entry: `references/concierge.md` routes any natural-language ask through
`flow.sh status` (mechanical ground truth) → `references/flow-catalog.tsv` (intent-class ×
state → action, TSV) → one proposed action, per a default-deny May-run/Must-ask
classification covering all 29 dispatcher verbs (v0.29 added `clarify` → May-run, `converge` →
Must-ask). Typed verbs bypass the concierge entirely.
A sixth ritual, `references/forge-idea.md` (adapted from BMAD-METHOD's `bmad-forge-idea`,
MIT), offers persona-driven idea pressure-testing at Idea/Scope, opt-in, never a gate
condition. The routing judge (`flow.sh eval --stage routing`) is a separate eval modality
from the artifact-vs-gate-rules judge — own manifest, prompt, verdict vocabulary
(MATCH/MISS/INVALID), results stream, and 90-call/batch cost ceiling. **v0.29 adds a THIRD
modality**, the converge judge (`flow.sh eval --stage converge`): it feeds a whole repo-state
(flow docs + card claims + allow-listed source) and asks `GAP|CONVERGED` — does the present
code still owe a declared promise? Same self-contained shape (own manifest/results/cost cap),
its own verdict vocabulary (GAP/CONVERGED/INVALID), proving the `/flow converge` gap-detection.
