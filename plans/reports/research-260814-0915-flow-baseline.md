# Flow-skill baseline capability map — research/deepseek-harness-upgrade (Phase 1)

- **Date:** 2026-08-14 09:15
- **Agent:** EVALUATOR (baseline mission — flow-skill side)
- **Scope of this report:** current-state capability map of the **flow skill product** (the buildflow
  gated build pipeline: Idea → Research → Scope → PRD → ADR → Contract → Cards → Build → Review →
  Deploy → Verify → Retro). Architecture, stage/gate engine, card system, attestation/evidence model,
  CLI/npm wrapper, strengths, known limitations/pain points.
- **Explicitly NOT covered here:** upgrade directions/synthesis (Phase 2+), and the deepseek-harness
  repo itself (covered by the two companion reports `research-260814-0915-deepseek-architecture.md` and
  `research-260814-0915-deepseek-tech-stack.md` in this same directory).
- **Basis:** direct source reading of this worktree (branch `research/deepseek-harness-upgrade`,
  checked out from `master` @ 48934b8, skill product v0.29.0), plus repo docs (`README.md`,
  `docs/system-architecture.md`, `docs/quality-metrics.md`, `CHANGELOG.md`, `DEBT.md`, `RETRO.md`,
  `plans/reports/*`). AgentKit `ak` CLI is available (`ak 2.8.0-beta.14`, 142 skills) but the product
  does not depend on it — flow is standalone; see §8.

---

## 1. Product identity & versioning

| Field | Value |
|---|---|
| Name | `flow` — buildflow gated build harness for coding agents |
| Skill product version | **v0.29.0** (`SKILL.md` metadata, `plugin.json`, `portable-manifest.json`) |
| npm installer | `@manhquy/flow-skill` **0.6.0** (installer CLI version ≠ skill version — intentional dual versioning) |
| License | MIT |
| Repo | github.com/manhquydev/flow-skill (public) |
| Primary authors | manhquy (solo-maintained; methodology from ai20k-build-phase/buildflow, harness ancestry from repository-harness protocol v1 which is now EOL) |
| Invocation | `/flow` (Claude Code), `$flow` (Codex CLI), `/flow` (Antigravity), agent-skills hosts |
| Test surface | 58 bash suites; GitHub Actions 3-OS matrix (ubuntu / macOS / windows) as source of truth |
| Runtime deps after install | bash (Git Bash on Windows) required; python3 optional (durable layer); git optional (worktrees / auto) |

**Positioning:** a *gated build process skill* — an idea-to-done-evidence discipline layer for a coding
agent — not an agent framework. It orchestrates stages, gates, cards, evidence, durable memory, and
optional cross-vendor review, while the agent model does all judgment and file work.

---

## 2. Current architecture

Three cooperating layers plus on-disk project artifacts (from `docs/system-architecture.md`, verified
against source):

```
+------------------------------------------------------------------+
| Semantic layer — skills/flow/SKILL.md + references/ (the model)  |
| judgment: hollow content, grade-laundering, adversarial review,  |
| agent orchestration, mode work, /flow auto tiers, concierge      |
+------------------------------------------------------------------+
              | calls (exit code = ground truth)
              v
+------------------------------------------------------------------+
| Mechanical layer — runner/flow.sh (bash, exit 0/1)  4,718 lines  |
| stage/card lifecycle, gate scans ([FILL]/boxes/evidence/status), |
| debt ledger, design/tokens/coherence/consistency/constitution,   |
| workspace (worktrees), converge, eval (LLM), usage telemetry     |
+------------------------------------------------------------------+
              | best-effort, graceful degrade
              v
+------------------------------------------------------------------+
| Durable layer — harness/flow_harness.py (Python 3 + stdlib      |
| sqlite3, flow-owned, ~1,328 lines) + graph_executor.py (~1,339  |
| lines) + schema/ 001-005 (frozen shared ancestry), 009-012, 014  |
+------------------------------------------------------------------+

On-disk artifacts (inside the user's project):
  flow/00-idea.md .. 05-contract.md   gated planning artifacts (+ optional 00-inspect.md brownfield)
  cards/C-NNN.md                      shipping units (gated)
  MODE, PROJECT_TYPE, RETRO.md, DEBT.md, AUTO-LOG.md, DESIGN.md (seeded), flow/constitution.md
  .flow/harness.db                    durable SQLite records
  .flow/events.jsonl                  mechanical flight-recorder (usage log)
  .flow/attestations/…                attestation receipts (v0.28+)
  cards/.inflight                     transient "in flight" registry
```

**Two-layer gate is the core idea:** the runner checks the *cheatable* mechanics deterministically
(unchecked `- [ ]` boxes — including leftover bullets under `## Open decisions` via the same scanner —
`[FILL]` placeholders, card status validity, empty/multi-signal done-evidence). The model applies the
*per-stage semantic challenges* in `references/gate-rules.md` (fabricated research quotes, grade
laundering, invented auth policy, hollow coverage). A gate passes only when **both** layers agree.

### 2.1 Semantic layer contents (`skills/flow/`)
- `SKILL.md` — frontmatter (name/description/when_to_use/argument-hint/keywords/version), command
  table, dispatch rules, three underlying laws, agent orchestration, AUTO principles, forbidden list.
- `law/` — `CLAUDE.md` (build-session discipline: one card/session, allowed-files, PR/merge protocol,
  debt, parallel worktree protocol, forbidden), `DESIGN.md` (UI law: tokens, affordance ladder,
  object-first, no emojis/engine-words), `RETRO.md`.
- `references/` — ~24 playbook docs: `gate-rules.md` (the semantic heart), `stage-state-machine.md`,
  `project-types.md`, `artifact-lifecycle.md`, `attestations.md`, `ground-truth-gates.md`,
  `adversarial-review.md`, `auto-run.md`, `debt-and-halts.md`, `gate-eval.md`, `concierge.md`,
  `flow-catalog.tsv` (intent-class × state routing table), `agent-detection.md`,
  `agent-stage-mapping.md`, `claudekit-skills.md`, `codex-integration.md`,
  `antigravity-integration.md`, `mode-work.md`, `native-rituals.md`, `forge-idea.md`, `clarify.md`,
  `converge.md`, `design-review-checklist.md`, `ui-patterns-tcr.md`, `command-dispatch.md`,
  `loop-harness-2026-principles.md`, `flow-topology.json` (graph executor trusted data).
- `_templates/` — 7 gated artifact templates (`00-idea`, `00-inspect`, `01-research`, `02-scope`,
  `03-prd`, `04-adr`, `05-contract`, plus `card.md`); never edited during a run.
- `eval/` — behavioral-eval fixtures: artifact-vs-gate judge (stages 01/02/card), routing judge
  (concierge), converge judge (repo-state gap detection).
- `playbooks/` — paid-for stack knowledge (read before building on a stack, harvest after).
- `runner/` — `flow.sh` (engine), `attestations.sh` (1,476-line attestation library, sourced in),
  `flow.cmd` (Windows launcher that resolves Git Bash, avoiding the WSL-bash trap).

### 2.2 Mechanical layer (`runner/flow.sh`)
29 dispatcher verbs. Command surface (all also exposed as `/flow <verb>`):

| Group | Verbs |
|---|---|
| Core lifecycle | `status` (default), `next`, `card` (`card start C-NNN`, `card done C-NNN`), `check C-NNN`, `gate`, `mode teach\|work`, `project-type web\|cli\|library\|skill`, `skip <stage>`, `ready`, `retro`, `unlock` |
| Context | `resume` (read-only session-story brief), `recall` (durable memory read-back), `usage` (+`--global/--prune`) |
| Trust/auto | `auto` (+`stop`), `attest semantic\|live-verify\|status\|recover` |
| Multi-agent | `workspace add\|list\|enter\|remove\|check\|doctor` (git-worktree isolation), `loop-prep`, `loop-log` |
| Drift/advisory | `contract` (URL-prefix drift), `tokens` (DESIGN.md vs CSS), `coherence` (version drift), `consistency` (FR→card→contract traceability), `constitution` (operator invariants), `clarify` (open decisions), `design <file>` (UI token check), `debt add\|list` |
| Flow-back | `converge [--file <payload>]` (append-only remainder cards, transactional) |
| Eval | `eval [--stage 01\|02\|card\|routing\|converge] [--fixture] [--n 3] [--keep-going] [--report]` |
| Ops | `doctor`, `promote <file>`, `harness <args>` (passthrough to durable CLI), `unlock` |

Key mechanical behaviors:
- **Root resolution:** `FLOW_PROJECT_ROOT` wins; else nearest ancestor with `flow/`/`cards/` is adopted
  (monorepo dual-root guard — prevents fragmented second `.flow` roots); a subdir with its own
  `flow/` is a deliberate sub-project.
- **Concurrency lock:** `flow/.lock`, TTL `FLOW_LOCK_TTL` (default 900s), auto-reclaim of stale locks;
  mutating verbs refuse fresh foreign locks (strong identity via explicit `FLOW_SESSION_ID` or harness
  session id; weak = warn-only). `FLOW_FORCE=1` takes over; `/flow unlock` clears.
- **Portability discipline:** bash 3.2-safe (macOS), no GNU-only flags, `.cmd` launcher on Windows;
  several fixed Git-Bash/MSYS early-pipe-reader-exit hangs documented in comments.
- **Graceful degrade everywhere:** no python → durable layer off, engine still runs; missing `timeout`
  → unbounded; missing agents → built-in fallback; logging never alters exit codes.
- **Usage telemetry:** every invocation self-records to `.flow/events.jsonl` (full) +
  `~/.claude/flow/usage.jsonl` (device-global compact); secret-shaped args masked; local-only, never
  transmitted; `FLOW_LOG_DISABLE=1` / `DO_NOT_TRACK=1` off-switch; `usage` rolls up into SQLite
  `usage_event` mirror and prints cycle-time, gate fail-rate, per-stage dwell, completion, command
  breakdown.

### 2.3 Durable layer (`harness/`)
A Python stdlib-sqlite3 CLI (`flow_harness.py`) with 11 command families — the "external memory that
fights context rot":
- `intake` — task specification + risk classification (lanes `tiny|normal|high_risk`; hard gates →
  high_risk; `--narrow-scope` operator-ack downgrade).
- `story add|update|verify|verify-all|complete` — story packets + proof status. **Trust boundary:**
  `story update --status implemented` is rejected; `story complete --proof-source card_markdown_gate|
  manual|verify_command` is the honest path (never forges `last_verified_result=pass`).
- `trace` — auto-scored execution traces (tier 1/2/3 by lane).
- `decision add|verify|outcome` — durable ADR rows + predicted-vs-actual loop.
- `backlog add|close`, `audit` (entropy 0-100), `propose [--commit]` (deterministic improvement
  proposals from repeated friction ≥2), `tool register|check|remove` (kind-aware registry:
  cli|binary|mcp|skill|http, presence probing), `intervention add`, `query
  matrix|backlog|friction|tools|decisions` (accessed_count reuse ordering; security rows always first).
- `graph` family (schema band 014) — record/advance API over a pinned topology; no resident process;
  short-lived invocations; exit contract 0/3/4/1-2 fail-closed.
- Schema lineage: 001-005 frozen shared ancestry with EOL repository-harness; 009-012 flow-owned
  (accessed-count, usage-event mirror, gate-reason, ephemeral); 014 graph-executor; 013 reserved.
  Rust backend seam frozen and compat-guarded (refuses flow-lineage DBs).
- Engine wiring (best-effort): `next` past stage 01 seeds intake; `next` past stage 04 reminds
  decision-add; `card` seeds story; `check` updates/complete + trace; `recall` reads back; `retro`
  surfaces proposals. `FLOW_HARNESS_STRICT=fail` propagates durable failures on card/check paths.

---

## 3. Stage/gate engine

### 3.1 State machine (`references/stage-state-machine.md`)
Current stage = highest contiguous stage file present in `flow/`. `/flow next` gate-checks the current
stage; on pass, unlocks the next (copies template). Planning complete when all six stage gates are
clean (or debt-skipped); only then `/flow card` unlocks.

```
(no flow/)          --/flow next-->  flow/00-idea.md        [stage 00 unlocked]
00 clean            --next-->  01-research … 02-scope … 03-prd … 04-adr … 05-contract
05 clean            --next-->  PLANNING COMPLETE           [/flow card unlocks]
all 6 gates clean   --/flow card-->  cards/C-001.md, …
cards built+verified --/flow check-> per-card exit gate (status done + evidence)
all cards done      --/flow retro->  one line in RETRO.md
```

- **Kill at any gate is a valid, honored terminal outcome** (cheapest at Scope).
- **Shipping stages live inside cards:** Build → Review → Deploy → Verify-live are NOT `/flow next`
  stages — they happen per card (`## Verify` run for real, `## Evidence` = world-state proof).
- **Stage → artifact → must-contain** table (idea: 3-sentence pitch + one named real person; research:
  3 opened competitors + 3 quoted complaints + real prices + one named first-10 channel; scope:
  Impact+Grade per feature, cut list, GO/KILL; prd: numeric success metric + pain&gain table; adr:
  decisions with why+rejected covering storage/auth/deploy + NOT-doing list; contract: feature→
  interface shapes + access/effects).
- **Gate mechanics (scan_gate):** unchecked `- [ ]` boxes, `[FILL]` placeholders, and (v0.29) leftover
  `- [ ]` under `## Open decisions` all fail the scan, reported with line numbers. Exit 0 = pass.
- **Open decisions / clarify (v0.29):** unresolved product decisions are `- [ ]` bullets under
  `## Open decisions` (Scope/PRD/Contract) — the existing scanner counts them, so `next` blocks;
  `/flow clarify` is an advisory printer; `references/clarify.md` is the bounded write-back ritual.
- **Skip/debt:** `/flow skip <stage> --reason` advances only when an open `DEBT.md` line names that
  exact stage; the contract (05) can **never** be skipped; security-class-sounding reasons HALT
  (operator-only). `planning_complete` tolerates debt-skipped stages.

### 3.2 Semantic gate (`references/gate-rules.md`)
Per-stage challenges the model applies after mechanical PASS; a mismatch is reported as
"mechanically passed, but qualitatively weak: <reason>" — never silently advanced, never silently
blocked. Recurring semantic themes:
- **Material-authority stops:** open product-law choices (quota, tenancy, identity key, response
  contract, enforcement owner, access/effects) that lack operator/ADR authority → stop or
  open-decision bullet; never invent auth/tenancy/billing to clear `[FILL]`.
- **Grade laundering** (Scope): expensive features graded B when really C; C-justification paths
  (C IS the product → first; re-architected C→B; irreducible → kill).
- **Fabrication risk** (Research): real quotes with working links, real prices, specific channels.
- **Hollow coverage / conflicting requirements / cut-list contradiction / terminology drift**
  (consistency semantic passes the runner's ID-based check can't judge).
- **Contract seam** (Stage 05): both input+output shapes with drift-proof names, real access/effects
  per interface, self-consistency re-read (a passed-but-inconsistent seam is the most expensive
  downstream failure class), optional cross-model check when Codex tier usable.
- **Card gate** (check): one-thing scope, independent test, allowed-files containment, contract-shape
  exactness, DESIGN.md compliance for UI, world-state evidence (not "tests pass"/"merged"), red→green
  proof for bug-fix cards.
- **Ground-truth gates** (`references/ground-truth-gates.md`): at every advancing/merging/done
  decision the gate condition must be a mechanical signal (runner exit, real curl/click output,
  receipt) — the model never grades its own gate; self-assessment is color, not verdict.

### 3.3 Project-type adaptation (`references/project-types.md`)
`flow.sh project-type web|cli|library|skill` (stored in `PROJECT_TYPE`; default web; locked after
planning unless `FLOW_FORCE=1` + DEBT line). Adapts: the contract seam (endpoint / command+flags+exit /
public API surface / skill command+files), the standard card sequence, and what **done-evidence** means
(live URL+curl / installs+runs / imports+usage+coverage / installed+real run). Known residual
web-flavoring in gate wording (backlog #4, acknowledged in-project).

### 3.4 Mode axes
Four independent axes: authoring (`teach` = operator writes artifacts, AI gatekeeps / `work` = AI
drafts 00-05, pauses at scope sign-off, gates identical), project type, run mode (manual vs `/flow
auto` with Tier-A auto-merge / Tier-B two-strikes+loop / Tier-C security HALT), and
greenfield vs brownfield (`/flow assess` → gated `flow/00-inspect.md` with an evidence ledger).

---

## 4. Card system

- **Creation:** `/flow card` only after all 6 planning gates pass; template `_templates/card.md` →
  `cards/C-NNN.md` (sequential ids). Frontmatter: `status: todo|done`, `deps:`, `implements:`,
  `risk`, `risk-reason`, `risk-ack`. Sections: `## Scope` (one thing), `## Independent test`
  (user-visible slice proof or `infra`/`none` — v0.29), `## Allowed files`, `## Verify` (checked,
  run for real), `## Done-evidence` (named before building), `## Evidence` (pasted world-state proof).
- **Lifecycle:** 2-state `status:` field (todo|done) is the gated truth; a side registry
  `cards/.inflight` tracks transient "in flight" (operator-marked via `card start`, shown in status);
  `/flow card done C-NNN` is a CLI-owned flip to done gated by the same done-rules as `check`
  (reverts to todo on gate fail, never leaves hollow done; fail-closed on INT/TERM).
- **Validation (`/flow check C-NNN`):** no `[FILL]`, valid status, `deps:` present, required sections,
  and when done: all Verify boxes checked + Evidence non-empty + **multi-signal floor** (see §5) +
  attestation enforcement when auto active. On pass it also updates durable story state and records a
  graph card-review node; on fail it records gate-exit 1.
- **Done-deps / parallel:** `/flow ready` computes buildable todo cards (deps done **and** evidence
  multi-signal floor **and** no allowed-files overlap); `workspace` provides git-worktree isolation so
  multiple agents can build different cards in parallel without branch-flip interference. Merge in
  card-number order, one at a time; conflicts = overlap check was gamed.
- **Card sequence law (`law/CLAUDE.md`):** scaffold+CI → vertical slice → backend → contract-test →
  UI mock → frontend → e2e; no models-only/layer-only cards (Independent test requirement); main =
  deployable after scaffold; PR per card; merge ≠ shipped (live-verify after merge).
- **Flow-back (`/flow converge`, v0.29):** appends remainder cards for declared `FRn`/interface/MUST
  the tree still owes, transactionally (all-or-nothing, never edits an existing card, byte-identical
  cards/ when nothing remains), from a `flow-converge/v1` payload the model assesses per
  `references/converge.md`.
- **Artifact lifecycle:** living plan + append-only cards (default); three named models (living /
  cycle-forward / flow-back); explicitly forbids `specs/NNN-slug/` parallel spec trees.

---

## 5. Attestation / evidence model

### 5.1 Evidence model (the "done" contract)
- **Done = world-state proof**, per project type (web: live URL + real curl; cli: installs + expected
  output/exit; library: imports + usage runs + coverage; skill: installed + real run reaches its own
  done-definition). "Tests pass"/"code merged"/"deploy succeeded" are mid-pipeline, never done.
- **Mechanical multi-signal floor (v0.28, `_evidence_signal_score`):** a done card's `## Evidence`
  must score ≥2 distinct categories from: A non-denylist URL, B command/curl/exit/HTTP-status,
  C positive test-log tokens (never inside URLs; `fail`/`failed` don't award), D existing repo-relative
  media/log path, E DB-row proof (rows=N / SELECT / sqlite / inserted), F skill-install path. Denylist
  hosts (example.com etc.) ignored; `:port` spoofing handled. Process-only prose (PR/CI/release notes)
  without the floor fails.
- **Honest limits documented:** the multi-signal floor is a floor, not a ceiling — a decoy URL +
  positive tokens can still score ≥2 (fixture `fcdc`); that residual is left to the offline semantic
  eval (`flow.sh eval`), never claimed closed by regex. Durable `card_markdown_gate` proof-source
  records only that the markdown floor passed.

### 5.2 Attestation receipts (v0.28+, `references/attestations.md` canonical)
- **Risk fields** on cards: `risk: standard|security-class|unknown` + `risk-reason` + `risk-ack`
  (none or `git:<full-oid>` DEBT-commit ack for security-class, with author-distinct check via
  `git blame`).
- **Receipts** under `.flow/attestations/`: `semantic_gate/<stage-or-card>.receipt` and
  `live_verify/<card>.receipt` (+ `.attempt` markers). Schema `flow-attestation/v1`: subject
  type/id, subject fingerprint (`git-<format>:<object-id>`), verdict (pass|fail|override), actor,
  engine, evidence_ref, timestamp, override_ref, owner_ref + owner fingerprint, kind-specific fields
  (subject_revision / base/tree / command_fingerprint / result_code / result_fingerprint /
  duration_ms / target_id / revision_oracle_*).
- **Fingerprints detect staleness, not identity:** subjects reference committed repo-relative owner
  manifests (`flow-attestation-owner/v1`, semantic_gate vs live_verify forms); stage fingerprint =
  committed blob OID; card semantic fingerprint = canonical card projection (deps/implements/risk/
  Scope/Allowed-files/Verify/Done-evidence) + base/head/tree OIDs + changed-path manifest; live
  fingerprint = deployed revision + verify/evidence projection + owner/oracle + target + argv digest.
  Mutable `status`/`Evidence` are excluded from the semantic projection so CLI-owned completion doesn't
  invalidate a current review.
- **Auto-active policy:** `.flow/auto-state` (`flow-auto/v1`) written only after full preflight (git
  repo + integration branch, reliable process-group supervisor, planning complete + ≥1 card, valid risk
  set, current accepted Stage 05 semantic receipt). While active, `check` done / `card done` / ready
  deps / merged workspace remove hard-require current fingerprint-bound receipts; stale/invalid →
  Block. No hidden bypass; `flow auto stop` is the manual continuation.
- **Process supervisor:** argv-safe, process-group ownership, streaming caps, TERM→grace→KILL; fails
  closed if unreliable (no unbounded fallback).
- **Explicit trust boundary:** receipts do NOT authenticate a human or model; actor labels and unsigned
  files are forgeable by a filesystem/repo owner; git authorship is forgeable by an agent with
  git-config control. This layer is workflow integrity, not a hostile-host or crypto-identity boundary.

---

## 6. CLI / npm wrapper & distribution

### 6.1 Distribution channels (two parallel, same canonical tree `skills/flow/`)
| Channel | Entry | Transport | Platform | Use case |
|---|---|---|---|---|
| **npm (primary)** | `npx @manhquy/flow-skill@latest` | Node ≥ 22.14 package; ~76 files / 566 KB unpacked | cross-OS | CI/CD, any Node env |
| **install.sh / install.ps1** (reference) | `bash install.sh global\|project` | direct from repo | UNIX / PowerShell | dev machines, air-gapped, doctor step |

- npm → `npm run sync` (scripts/sync.mjs) copies `skills/flow` into `npm-wrapper/skills/flow` →
  `npm pack` → registry. `@latest` dist-tag pinning is heavily emphasized in docs (npx cache pitfall);
  `@rc` retired. Publish via OIDC Trusted Publisher on `npm@*` tags.
- **npm wrapper CLI (`bin/cli.mjs` + `src/`):** interactive multi-select of detected agents, `--yes`,
  `-t/--target` (claude, codex, agents, antigravity, cursor), `--all`, `--project --dir`,
  `--dry-run --json` (JSONL events for CI), `--help` (prints dual versions). Node version guard
  (≥ 22.14.0) hard-fails loudly. Installer hardening: retry on Windows EBUSY/EPERM/ENOTEMPTY,
  recursive symlink rejection (ESYMLINK), advisory exclusive-create lock. 41 node:test cases.
- **Install targets:** `~/.claude/skills/flow`, `~/.codex/skills/flow`, `~/.agents/skills/flow`,
  `~/.gemini/antigravity-cli/skills/flow` + `~/.gemini/config/skills/flow`, `~/.cursor/skills/flow`,
  or project `.claude/skills/flow`. Same SKILL.md bundle everywhere.
- **Claude plugin:** `.claude-plugin/plugin.json` + marketplace.json (plugin install path).
- **CI:** `.github/workflows/ci.yml` (bash-suite 3-OS matrix; windows 45m budget), 
  `publish-npm-wrapper.yml`, `nightly-registry-health.yml`. Azure Pipelines yml is demoted/unused
  fallback. Release: `docs/release-process.md`, `scripts/release-preflight.sh`,
  `check-release-coherence.sh`, `npm-wrapper/RELEASE_CHECKLIST.md`.

### 6.2 Verification of install
`flow.sh doctor` (env self-check), `npx … --help` (dual version), `grep version: SKILL.md`.
Windows gotcha documented everywhere: bare `bash` may resolve to WSL → use `runner/flow.cmd`.

---

## 7. Agent orchestration & autonomy

- **Agent ladder:** `ck:` agents first → `bmad-*` skills alternative → built-in fallback (detection +
  degrade; a missing agent never breaks a run, never lowers a gate — `references/agent-detection.md`).
- **Cross-vendor engines (optional, detected-not-required):** Codex/GPT-5.x second engine (v0.4) and
  Antigravity/Gemini-3 third engine (v0.8) at three gated moments: two-strikes rescue, cross-model
  adversarial review, opt-in primary drafting. Strict usability checks (Codex `setup --json` auth;
  Antigravity: exit code lies → route on non-empty output, interactive default). 3-trigger cost gate
  (billable). Gate parity absolute — engines draft/critique, the same gate judges.
- **Stage → agent map** (`agent-stage-mapping.md`): research→researcher, scope/PRD→planner,
  ADR→architect, contract→bmad-spec kernel, build→fullstack-developer, review→code-reviewer/bmad-code-
  review (3-layer adversarial; language-specialist + security-reviewer lenses; STRIDE native ritual),
  verify-live→tester.
- **Deep-wired ck skills (opt-in enrichment):** ck-predict@ADR, ck-scenario@Contract, review-pr@Review/
  Ship, ck-security@security-cards, retro@Retro, ck-loop@Build/Verify — each with a native ritual as
  the guaranteed baseline (v0.22 standalone: persona-debate, edge-case, STRIDE, numeric-retro, native
  loop). Skill INFORMS / gate JUDGES.
- **AUTO loop** (`/flow auto`): tier-classify → scoped subagent in own worktree → build → adversarial
  review → semantic receipt → `flow.sh check` PASS → merge (Tier-A) → deploy → live_verify → evidence
  → `card done` → durable trace + AUTO-LOG.md. Tier-B: fresh-subagent repair (two-strikes), then
  cross-vendor engine; Tier-C security-class: HALT + written DEBT acceptance. Hard stops on
  iteration/token/time caps; ground-truth gates mandatory.
- **Concierge (v0.22, default entry):** natural-language routing via `status` → `flow-catalog.tsv`
  intent×state row → one proposed plain-language action; May-run/Must-ask default-deny classification;
  new-user consent question before `mode work`. Typed verbs always win.
- **Graph executor (v0.25+, schema 014):** records executions/checkpoints/interrupts over the pinned
  topology (`flow-topology.json` + sha256 pin; `graph lint` guards edits); dark until
  `FLOW_GRAPH_EXECUTOR=1`; instrumented via verbs agents already call (workspace add → card-dispatch,
  check → card-review, card done → card-verify-live, workspace remove → merge proof). No resident
  process; short-lived invocations; security-class interrupt resolution requires committed DEBT
  artifact.

---

## 8. AgentKit (`ak`) relationship

The AgentKit `ak` CLI (`2.8.0-beta.14`, 142 skills installed under `~/.agents/skills/`) is present on
this host and was available to this evaluation (scout-style navigation was done natively in the main
agent per ak-scout's own guidance when no explicit delegation is requested). **The flow skill itself
does not depend on AgentKit** — it is standalone by design (v0.22 "standalone" positioning: ck:/bmad/
AgentKit are optional enrichment; native rituals are the guaranteed baseline). The only overlap of note
for the upgrade research: flow's *concepts* (gate, evidence, durable traces, worktree parallelism,
adversarial review, loop protocol) parallel some AgentKit skills (ak-plan/ak-cook/ak-orchestrate/
ak-worktree/ak-loop/ak-journal), but there is no integration seam between them today beyond the
optional ck-skill deep-wiring.

---

## 9. Testing & verification surface

- 58 bash suites in `tests/` (run_all.sh, wall-clock timing) — covering runner, harness (python),
  scenarios, project types, gate wording, coverage gaps, concurrency lock, recall, accessed-count,
  gate capture, propose/audit, contract, tokens, coherence, assess, codex/antigravity/claudekit
  integration, card lifecycle, done-evidence + auto-done path, usage log, workspace, monorepo root,
  harness args/lineage/strict/trust-complete/docs-contract, schema migration, tool registry, loop,
  eval (large), resume, status legibility, concierge, native rituals, forge-idea, graph schema/
  executor/crash-resume/lint/auto-run/parallel-cards/planning-parity, attestation contract/risk/
  supervisor/attestations/auto-enforcement/harden, release coherence, harness-CLI-optional smoke.
- CI = GitHub Actions `bash-suite` 3-OS matrix; windows cell is slow (18-25m measured, 45m budget).
- **Behavioral LLM eval** (`/flow eval`, opt-in, billable, never in CI): fresh-judge lower bound that
  a hollow-but-mechanically-clean fixture gets flagged; 3 judge modalities (gate / routing / converge),
  nonce-protected verdicts, `--report` drift; routing max 90 calls/batch hard ceiling.
- npm wrapper: 41 node:test cases (installer, detect, cli, lock-atomicity, sync-manifest).

---

## 10. Strengths

1. **Two-layer gate with honest division of labor.** Deterministic mechanical floor (unchecked boxes,
   `[FILL]`, open-decision bullets, evidence multi-signal) + explicit semantic challenges — the model
   is told exactly what to look for, and both must agree. Ground-truth gates everywhere: the model
   never grades its own gate.
2. **"Done = world-state proof" is enforced mechanically, not just preached.** The multi-signal
   evidence floor (URL/curl/log/DB/skill categories) catches the hollow-done failure class; auto
   receipts hard-require fingerprint-bound semantic + live verification at every transition.
3. **Deep, durable memory loop** (capture → reuse → improve): engine-fired intake/story/trace/
   decision/backlog + recall + audit/propose + cross-project playbook promotion. Fights context rot
   with zero third-party deps (stdlib sqlite).
4. **Extreme portability and graceful degradation.** Bash 3.2-safe (macOS), Git-Bash/Windows handled
   via flow.cmd, python optional, git optional, agents optional, engines optional — every missing piece
   degrades loudly but never breaks a run or lowers a gate.
5. **Kill-at-any-gate and debt-as-loan culture.** Killing a weak idea at Scope is a first-class
   outcome; deliberate skips are written down with exposures and close conditions; security-class
   skips are operator-only halts.
6. **Standalone + optional enrichment.** Native rituals for every deep-wired skill, concierge chat
   front-door, forge-idea, clarify, converge — no dependency on AgentKit/claudekit, while richer
   multi-vendor review (Codex, Antigravity) is detected and used when present.
7. **Measured, self-dogfooding product.** The repo builds itself with `/flow`; quality-metrics.md
   tracks real numbers (gate false-pass, first-pass rate, cross-platform pass, dogfood close rate,
   reviews-to-clean); CI is a real 3-OS gate. Behavioral eval (`flow.sh eval`) turns the semantic
   layer's effectiveness into a number.
8. **Project-type adaptation** (web/cli/library/skill) changes the contract seam, card sequence, and
   done-rule — not just copy.
9. **Parallel multi-agent safety:** git-worktree workspace isolation + allowed-files overlap checks +
   deps-based ready + ordered merge protocol; concurrency lock prevents plan stomping.
10. **Small, auditable core.** Pure-bash engine + stdlib-python harness; no heavyweight runtime
    (rust seam frozen); pinned topology for graph data; secret masking in logs; no telemetry sent
    anywhere.

---

## 11. Known limitations / pain points (baseline, no synthesis)

**Operational / environment**
- **DEBT.md open item (macOS):** eval's `_run_with_timeout` fallback doesn't bound a slow/stuck
  `claude` call on macOS (bash 3.2 stock `/bin/sh`; no real `timeout`/`gtimeout`) — a billable eval
  verb could run past `--timeout` on macOS; ubuntu+windows unaffected. Three targeted fixes tried
  against real 3-OS CI; unresolved without macOS access. Close-before: running eval against
  untrusted/slow prompts on macOS or relying on `--timeout` as a hard cost cap there.
- **Windows WSL-bash trap:** bare `bash` in PowerShell/Codex may resolve to WSL and fail to read
  `C:/` paths; must use `runner/flow.cmd`. High DX friction for Windows/Codex users.
- **Windows CI is slow** (18-25m for the bash suite; 45m budget) — test iteration cost.
- **npm wrapper requires Node ≥ 22.14** (hard guard; Node 20 EOL rationale documented).
- **Concurrency lock is coordination-only without an explicit `FLOW_SESSION_ID`** — without it the
  runner can only warn (can't prove a different session, so it never self-blocks). `FLOW_FORCE=1` can
  take over a lock that's actually live (documented as operator responsibility).

**Trust/identity (documented residual limits)**
- **Attestations detect staleness, not authenticity.** Fingerprints/actor labels/unsigned receipts are
  forgeable by a filesystem/repository owner; git authorship is forgeable by an agent with git-config
  control. Not a crypto/identity boundary — workflow integrity only.
- **Same-model gate blind spot (DF-2, recurring).** Builder and reviewer share one model; correlated
  mistakes slip through green gates. Mitigated by optional cross-vendor engines and the fresh-judge
  eval, but the **authorship-bias limitation of the semantic layer in `work` mode is a recorded
  design boundary**: the model self-challenges its own artifacts; the eval proves a *fresh* judge can
  flag hollow fixtures, not that a real build's self-review caught everything (gate-eval.md).
- **Mechanical evidence floor residual:** decoy multi-signal (staging host + PASS tokens) can still
  score ≥2 (fixture `fcdc`) — closed only by the offline semantic eval, which is opt-in/billable and
  never in CI.

**Semantic/process gaps (from dogfood findings, quality-metrics.md)**
- **DF-3 (open):** harness CLI verb inconsistency — `decision add --id` vs `intervention` takes no
  `add` subverb and `--description` (not `--note`); `intake` differs again. 3 usage errors hit in one
  session. DX friction.
- **DF-4 (open, recurring):** auto-traces stay tier 1/3 (lane `normal` wants 2) because card→trace
  fields aren't auto-populated from a card — harness nags each check.
- **DF-5 (documented):** card allowed-files containment conflicts with cross-cutting review fixes —
  a HIGH finding spanning 3 docs owned by a 1-file card needs an honest-drift escape hatch.
- **Gate-wording web-flavoring** (backlog #4): stage-05 text says "endpoint"/"auth (public/token/admin)"
  even for non-web types; adaptation is licensed in prose but the wording itself is web-shaped.
- **Consistency mechanical coverage can be gamed** by pasting an FR id without delivering the work
  (hollow coverage is a semantic pass); "no FR ids found" = coverage-unverified, not coverage-clean.
- **`consistency`/`clarify`/`constitution` are advisory** — nothing hard-forces running them at the
  right seams; they depend on the agent/operator's discipline (a one-line nudge exists for consistency
  at planning-complete, but not for the others).
- **Deploy has no verb** — `/flow` stops at verify; deployment execution stays operator/CI (by design,
  but the pipeline's last mile is outside the skill).

**Eval/cost**
- **LLM eval is billable and opt-in** (never in CI); a batch at `--n 3` can be ~37 calls, routing max
  90/batch hard ceiling; `--keep-going` needed to run full batches; rate-limit/backoff env-injectable.
  Cost/scope limitations are honestly documented but mean the semantic-layer quality signal is
  operator-run, not continuous.
- **DF-1 history:** the skill's own coherence tool once missed its own version drift (fixed later —
  the detector now reads SKILL.md frontmatter); stale-count classes recurred multiple times and were
  eventually addressed by regenerating counts from `run_all.sh`. Points at a general fragility:
  *documented counts* (tests, metrics) drift from reality unless regenerated.

**Scope/shape constraints (by design, but worth naming)**
- One product cycle in one `flow/` + `cards/`; no `specs/` parallel universe (deliberate). v2 = new
  cards + plan amendment.
- Cards are append-only; plan is living — requires discipline to keep PRD/contract honest (a stranger
  must still be able to build v1 from them).
- Teach mode leans on operator discipline (never tick boxes on their behalf); work mode shifts
  authorship bias to the model (see trust limits above).
- Solo-maintainer project with a large, growing reference surface (~24 reference docs + 58 test suites
  + 29 verbs) — documentation-coherence and test-suite maintenance are recurring friction (repeated
  stale-count incidents in RETRO.md).

**Structural observability note (for the upgrade research, factual only):** the mechanical engine is
one 4,718-line bash file (`flow.sh`) plus a 1,476-line sourced `attestations.sh`; the durable layer is
two Python files (~1,328 + ~1,339 lines) plus sqlite schema; the graph executor is a pinned-topology
*recording* layer (no resident process, LLM/agent owns sequencing). This shape is deliberate
(portable, auditable, degrade-friendly) but is the baseline against which the companion deepseek-harness
reports should be read — no direction implied here.

---

## 12. Baseline metrics snapshot (for later comparison)

| Metric | Current value |
|---|---|
| Skill product version | 0.29.0 |
| npm installer version | 0.6.0 |
| Dispatcher verbs | 29 |
| Reference docs (`references/`) | ~24 (+ flow-topology.json, flow-catalog.tsv) |
| Templates | 7 artifacts (+ card) |
| Test suites | 58 bash (3-OS CI) + 41 node:test (npm wrapper) |
| Engine size | flow.sh 4,718 lines; attestations.sh 1,476 lines |
| Durable layer | flow_harness.py 1,328 lines; graph_executor.py 1,339 lines; _db/_domain/_presence ~670 lines |
| Schema bands | 001-005 (shared ancestry), 009-012 (flow-owned), 014 (graph), 013 reserved |
| Attestation receipts | semantic_gate (stage/card) + live_verify (card) under `.flow/attestations/` |
| Eval modalities | 3 (gate / routing / converge); routing cap 90 calls/batch |
| Card lifecycle | `status: todo|done` + `.inflight` side registry + CLI-owned `card done` |
| Evidence floor | ≥2 of 6 signal categories (A-F) for done cards |
| Open debt (repo-level) | 1 (macOS eval `--timeout` unbounded) |

---

*End of Phase 1 baseline. This report intentionally contains no upgrade directions or synthesis; the
deepseek-harness architecture/tech-stack reports are the companion inputs for that phase. Awaiting next
instruction.*
