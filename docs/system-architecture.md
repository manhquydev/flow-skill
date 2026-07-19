# /flow — system architecture

`/flow` is a gated build harness: idea -> deployed URL through honest gates. It is built as
three cooperating layers plus on-disk artifacts, so a fast deterministic engine handles the
cheatable mechanics while the model handles judgment, and durable records survive sessions.

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
              | reads/writes (best-effort, graceful degrade)
              v
+---------------------------------------------------------------+
|  Durable layer  -  harness/flow_harness.py  (Python+sqlite3)  |
|  intake/risk-lane, story+proof, trace+tier, decision, backlog |
|  (Rust harness-cli power-path via FLOW_HARNESS_BACKEND=rust)  |
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
         │ install.sh / agent skill homes          │ npx @manhquy/flow-skill@rc
         v                                         v
  ~/.claude/skills/flow                     same tree via installer CLI
```

- **Skill product version** (SKILL.md / plugin.json / portable-manifest) drives coherence and
  harness `flow_version` telemetry.
- **npm package version** versions the installer CLI only; tag `npm@*` triggers OIDC publish.
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
1. `/flow next` walks stages 00->05; each gate = mechanical (flow.sh) + semantic (gate-rules.md).
2. After stage 05 passes, `/flow card` creates cards; each card is one scoped build session.
3. Cards build to the contract (the seam), are reviewed adversarially, verified on the LIVE
   URL (done = world-state, not "tests pass"), then marked done. `/flow auto` runs this loop
   autonomously with Tier-A/B/C and hard stops. `/flow status` (called far more than any other
   verb in practice) surfaces the same `NEXT ->` decision ladder as `resume` at any point.
4. Every transition writes durable records; deliberate skips open a `DEBT.md` line.

## Components
| Path | Responsibility |
|---|---|
| `skills/flow/SKILL.md` | semantic-layer entry: dispatch + gatekeeper + orchestration |
| `skills/flow/runner/flow.sh` | mechanical engine: lifecycle, gates, debt, design, harness passthrough, loop-engineering (ck-loop wrapper) |
| `skills/flow/harness/` | durable layer (Python CLI + sqlite + Rust toggle) |
| `skills/flow/_templates/` | the 7 gated artifacts (verbatim buildflow) |
| `skills/flow/law/` | CLAUDE.md (build-session law), DESIGN.md (UI law), RETRO.md |
| `skills/flow/references/` | 21 semantic playbooks (gates, agents, loop, design, auto, v0.22 concierge/native-rituals/forge-idea) |
| `skills/flow/eval/` | behavioral-eval fixtures: artifact-vs-gate + v0.22 routing judge (`fixtures/routing/`) |
| `skills/flow/playbooks/` | paid-for stack knowledge (read before, harvest after) |
| `tests/` | 39 suites across runner / harness / scenarios / loop / eval (v0.21: raw-on-INVALID + circuit breaker + prune + envelope-strip; v0.22: routing judge) / resume / status-legibility / concierge / native-rituals / forge-idea / harness trust-align (v0.24: lineage-contract + strict + trust-complete + docs-contract). GitHub Actions `bash-suite` job (ubuntu+macos+windows) is the source of truth. |
| `install.sh` / `install.ps1` | install to ~/.claude or a project |

## Distribution channels

Two parallel installation paths, both syncing the same canonical `skills/flow/` tree:

| Channel | Entry point | Transport | Platform | Use case |
|---|---|---|---|---|
| **npm** (primary) | `npx @manhquy/flow-skill@rc` | Node.js package, 76 files 566 KB unpacked | Cross-OS (no shell dependency) | CI/CD, any environment with Node 22+ |
| **install.sh** (reference) | `bash install.sh global` + doctor step | Direct from repo via Git | UNIX shell (Bash 3.2+) | Dev machines, local skill setup, preserves diagnostic doctor |

The npm channel is the **canonical distribution** for cross-platform adoption (pure Node.js, no `bash`/`git` requirement, fast tarball extraction). The `install.sh` channel is the **reference implementation** used in development and CI matrix testing; it includes the `doctor` diagnostic step to verify the local environment. Both write to the same skill home (`~/.claude/skills/flow`, `~/.codex/skills/flow`, etc.), so a project can switch channels without re-issuing any gates or cards.

## Deep-wired skills (pluggable agents + decision matrix)

`/flow` ships 6 deep-wired ClaudeKit skills (opt-in, never in `cmd_next`/`cmd_check`):
`ck-predict` (ADR), `ck-scenario` (Contract), `review-pr` (Review/Ship), `ck-security`
(security-cards), `retro`, `ck-loop` (loop-engineering). **v0.22 standalone**: 5 of these 6
now have a **native ritual** as the guaranteed baseline (`references/native-rituals.md`) —
persona-debate@ADR, edge-case@Contract, STRIDE@Review, numeric-retro@Retro, native loop
protocol@Build/Verify. The ck skills above are offered as richer alternatives *when installed*,
never a requirement; only `review-pr` has no native equivalent (PR-context-specific).
**Loop vs two-strikes:** operators choose based on repair scope — `ck-loop`/the native loop
protocol iterates toward a numeric metric (Implement→Test→Audit→Fix tail, worktree-isolated,
5-iteration stuck-break); two-strikes gates handle deadlock in review (bounded 2-pass
escalation). Decision matrix in `references/claudekit-skills.md`.

## Concierge front-door (v0.22)

Chat is the default entry: `references/concierge.md` routes any natural-language ask through
`flow.sh status` (mechanical ground truth) → `references/flow-catalog.tsv` (intent-class ×
state → action, TSV) → one proposed action, per a default-deny May-run/Must-ask
classification covering all 27 dispatcher verbs. Typed verbs bypass the concierge entirely.
A sixth ritual, `references/forge-idea.md` (adapted from BMAD-METHOD's `bmad-forge-idea`,
MIT), offers persona-driven idea pressure-testing at Idea/Scope, opt-in, never a gate
condition. The routing judge (`flow.sh eval --stage routing`) is a separate eval modality
from the artifact-vs-gate-rules judge — own manifest, prompt, verdict vocabulary
(MATCH/MISS/INVALID), results stream, and 90-call/batch cost ceiling.
