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
│   ├── references/              # 13 semantic playbooks (gates, state machine, agents,
│   │                            #   mode-work, auto-run, loop principles, ground-truth,
│   │                            #   adversarial, debt-and-halts, design checklist, ui-tcr)
│   └── playbooks/               # 3 stack playbooks + README (read before / harvest after)
├── npm-wrapper/                 # npm distribution channel (cross-OS Node)
│   ├── bin/cli.mjs              # entry point: npx @manhquy/flow-skill@rc
│   ├── src/installer.mjs        # detect + verify harness install
│   ├── src/detect.mjs           # harness detection (claude/codex/agy)
│   ├── src/prompt.mjs           # interactive install prompts
│   ├── scripts/sync.mjs         # keep npm wrapper aligned with repo
│   ├── test/                    # 35 tests via node:test (4 suites)
│   ├── .github/workflows/publish-npm-wrapper.yml
│   ├── .github/workflows/ci.yml
│   └── .github/workflows/nightly-registry-health.yml
├── tests/                       # run_all.sh + runner(13) + harness(19) + scenarios(14) = 46
├── install.sh / install.ps1     # global or per-project install + doctor
├── portable-manifest.json
├── docs/                        # this file + system-architecture.md
├── plans/260613-1021-.../       # the implementation plan (6 phases, all done)
└── README.md
```

## Commands (`/flow ...`)
`resume` (read-only session-story brief: last session, in-flight + dwell, gate state, NEXT ->;
run first when entering a project mid-cycle) · `next` (gate-check + unlock stage) · `card` (new
build card) · `check C-NNN` (validate card) · `status` (NEXT -> line, stage dwell, card
list/compact summary) · `mode teach|work` · `ready` (parallel-safe cards) · `auto` (autonomous
run) · `retro` · `loop-prep` / `loop-log` (ck-loop iteration) · `harness <args>` (durable layer)
· `debt add|list` · `design <file>` (UI check) · `usage [--global|--prune]` (telemetry analytics)
· `eval` (behavioral gate proof) — plus coherence/consistency/constitution/contract/tokens/
workspace/doctor/promote/unlock/project-type/skip. 30 verbs total; see README.md's full table.

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
`bash tests/run_all.sh` — 31 suites, all green on the 3-OS CI matrix (ubuntu / macos / windows).
Covers gate pass/fail, lifecycle, card validation, intake classification, trace tiers, story
verify, debt, design, the 6 buildflow scenario rounds, loop-engineering (ck-loop wrapper),
behavioral gate proof (`eval`, 22 sections incl. v0.21 raw-on-INVALID + circuit breaker +
envelope strip + run_id-epoch prune), the `resume`/`status` legibility surface, and graceful
degrade. Real numbers surface in each release's per-release journal note; CI matrix is the
source of truth (`gh run view <id>`), not local-only runs.

## Status
v0.21.0 (2026-07-11, commit `17677b1` on the v0.21.0 line, CI GREEN 3/3 OS on run
`29141602431`). v1 core complete (Phases 1-6, see `plans/260613-1021-flow-skill-engine/`);
ongoing releases add capability on top (durable-layer deep integration, cross-vendor agent tiers,
usage-log telemetry, behavioral gate eval + trust hardening, mission-control legibility,
express-lane KILLED by data). See CHANGELOG.md and `docs/quality-metrics.md` for the per-release
history + the roadmap-A anti-FOMO log.
