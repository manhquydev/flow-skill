# /flow — codebase summary

A Claude Code skill that runs the buildflow gated process (idea -> deployed URL), backed by
a durable harness and pluggable agent orchestration. Dev workspace: `D:\project\flow\flow-skill`.

## Layout
```
flow-skill/
├── skills/flow/                  # the installable skill (-> ~/.claude/skills/flow)
│   ├── SKILL.md                 # frontmatter + dispatch + semantic gatekeeper + orchestration
│   ├── runner/flow.sh           # bash gate engine: status/next/card/check/mode/ready/auto/retro/
│   │                            #   harness/debt/design  (exit 0/1)
│   ├── harness/                 # durable layer
│   │   ├── flow_harness.py      # CLI: init/intake/story/trace/decision/backlog/tool/intervention/query
│   │   ├── _db.py               # sqlite connect + atomic migrations
│   │   ├── _domain.py           # pure rules: input types, risk lanes, hard gates, trace tiers
│   │   ├── schema/00N-*.sql     # DDL verbatim from repository-harness
│   │   └── README.md
│   ├── _templates/              # 00-idea..05-contract + card (verbatim buildflow)
│   ├── law/                     # CLAUDE.md, DESIGN.md, RETRO.md
│   ├── references/              # 21 semantic playbooks (gates, state machine, agents,
│   │                            #   mode-work, auto-run, loop principles, ground-truth,
│   │                            #   adversarial, debt-and-halts, design checklist, ui-tcr,
│   │                            #   concierge, native-rituals, forge-idea — v0.22)
│   ├── eval/                    # behavioral-eval fixtures: artifact-vs-gate + v0.22 routing judge
│   └── playbooks/               # 3 stack playbooks + README (read before / harvest after)
├── npm-wrapper/                 # npm channel (cross-OS Node installer)
│   ├── bin/cli.mjs              # npx @manhquy/flow-skill@rc — dual-version help
│   ├── src/                     # installer, detect (5 targets), prompts
│   ├── scripts/sync.mjs         # skills/flow → bundle for tarball
│   ├── scripts/smoke.mjs        # registry smoke (empty cwd required)
│   ├── RELEASE_CHECKLIST.md     # OIDC + dist-tag token ops
│   └── test/                    # 41 node:test cases
├── .github/workflows/           # ci · publish-npm-wrapper · nightly-registry-health
├── tests/                       # run_all.sh (wall_s timing) + 33 suite scripts
├── install.sh / install.ps1     # global or per-project install + doctor
├── portable-manifest.json       # skill product version (with SKILL.md, plugin.json)
├── docs/                        # architecture, quality-metrics, release-process, journals
└── README.md
```

**Release / versioning:** skill product (`0.24.x`) ≠ npm package (`0.1.x`, GA on `latest`).  
See [`docs/release-process.md`](release-process.md).

## Commands (`/flow ...`)
`resume` (read-only session-story brief: last session, in-flight + dwell, gate state, NEXT ->;
run first when entering a project mid-cycle) · `next` (gate-check + unlock stage) · `card` (new
build card) · `check C-NNN` (validate card) · `status` (NEXT -> line, stage dwell, card
list/compact summary) · `mode teach|work` · `ready` (parallel-safe cards) · `auto` (autonomous
run) · `retro` · `loop-prep` / `loop-log` (ck-loop iteration) · `harness <args>` (durable layer)
· `debt add|list` · `design <file>` (UI check) · `usage [--global|--prune]` (telemetry analytics)
· `eval --stage 01|02|card|routing` (behavioral gate proof + v0.22 concierge routing judge) —
plus coherence/consistency/constitution/contract/tokens/workspace/doctor/promote/unlock/
project-type/skip. 27 dispatcher verbs; see README.md's full table. **v0.22**: chat is now the
default entry — see `references/concierge.md`; typed verbs above still work unchanged.

## Key invariants
- A gate passes only when mechanical (`flow.sh` exit 0) AND semantic (Claude) agree.
- Done = world-state proof (live URL/curl/DB row), never "tests pass" / "merged".
- Contract (stage 05) is the seam: written before code, asserted against the live spec.
- Security-class skips (auth/authz/admin/tenancy/payments/data/validation) are operator-only,
  Tier-C halt in auto.
- The durable layer degrades gracefully (no python -> engine still runs).

## Stack
bash (Git Bash on Windows) for the engine; Python 3 + stdlib sqlite3 for the durable layer
(optional Rust `harness-cli` power-path); no third-party install required.

## Tests
`bash tests/run_all.sh` — 39 suites, all green (GitHub Actions `bash-suite` job,
ubuntu/macos/windows matrix — replaces the parked Azure Pipelines setup as of v0.22).
Covers gate pass/fail, lifecycle, card validation, intake classification, trace tiers, story
verify, debt, design, the 6 buildflow scenario rounds, loop-engineering (ck-loop wrapper),
behavioral gate proof (`eval --stage 01|02|card`, v0.21 raw-on-INVALID + circuit breaker +
envelope strip + run_id-epoch prune) plus the v0.22 routing judge (`eval --stage routing`,
own manifest/verdict/scorecard), the `resume`/`status` legibility surface, the v0.22 concierge
routing table + native rituals + forge-idea ritual, and graceful degrade. Real numbers surface
in each release's per-release journal note; CI matrix is the source of truth (`gh run view
<id>`), not local-only runs.

## Status
v0.22.0 (2026-07-16) — concierge chat-first front-door + standalone self-sufficiency (native
gate rituals; ck/BMAD demoted to optional enrichment). v1 core complete (Phases 1-6, see
`plans/260613-1021-flow-skill-engine/`); ongoing releases add capability on top (durable-layer
deep integration, cross-vendor agent tiers, usage-log telemetry, behavioral gate eval + trust
hardening, mission-control legibility, express-lane KILLED by data, v0.22 concierge/standalone).
See CHANGELOG.md and `docs/quality-metrics.md` for the per-release history + the roadmap-A
anti-FOMO log.
