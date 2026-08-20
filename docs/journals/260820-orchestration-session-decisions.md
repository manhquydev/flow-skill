# Session memory — 2026-08-20 orchestration (flow-skill + flow-deck)

End-state record of the 2026-08-20 Herdr-orchestrated session. A coordinator agent (pane
`wS:p1`) spawned parallel `omp` workers across Herdr tabs/panes to research → critique →
plan → cook → QA → fix, in parallel. Worker reports were kept under `/tmp/flow-research/`
(ephemeral); the durable decisions and shipped state are captured here.

## Shipped to master (this session)

| PR | Commit | What |
|---|---|---|
| [#11](https://github.com/manhquydev/flow-skill/pull/11) | `bb1a679` | **Eval hardening** (DeepSeek-harness-inspired): hash-only `prompt_sha` judge-input receipt (skip-if-absent, mismatch hard-fail, no committed prompt bodies); CI fixture-impossibility linter that *protects* `fcdd`/`fcdc` as mechanical-PASS; doctor `timeout: full\|partial\|absent` + `timed_out` JSONL at the caller; `FLOW_EVAL_ISOLATED_CWD` + `CLAUDE_CODE_SAFE_MODE=1` isolated cheap live-eval. Eval STOP held (`_eval_engine_run`/`_run_with_timeout` byte-identical); B1 stays locked; no new dispatcher verb. |
| [#12](https://github.com/manhquydev/flow-skill/pull/12) | `7b8ae79` | **Host-agnostic parallel law** (`references/host-agnostic-parallel.md`) + pointers + doc-contract test. Parks a future own-runtime `flow-orch` in ADR-0001 Deferred as a **separate** product (reopen only on flip-tripwire + tripwire 5). |
| [#13](https://github.com/manhquydev/flow-skill/pull/13) | `2d3cae7` | **Value-first docs (A-E)**: `/docs/` rewrite EN+VI (install → what-you-get → features → analysis last), curated ≤14 sidebar (greenfield + commands one hop), complete security-halt page, first-run T3 (gate-fail kept as optional depth), landing reorder (PRODUCT.md + DESIGN.md reopen), 47→13 pages/locale with a 132-row 301 redirect surface, and a Sätteri hast plugin so `{#id}` heading anchors are real HTML ids (crawl 63/63). |

## Locked decisions

- **Phase 2 identity:** flow stays a **lightweight host-agnostic discipline layer** (owns
  gates + receipts, never the runtime). It uses whatever host the operator already runs
  (Herdr/tmux/Task/shell); it depends on no named multiplexer. The "flow owns its own
  terminal" idea is a **separate product** (`flow-orch`/`flow-deck`), reopened only on a
  named flip-tripwire **and** capacity (ADR-0001 Deferred). Never inside `@manhquy/flow-skill`.
- **Phase 1 D:** the isolated cheap-eval plumbing shipped (env/cwd only, no engine edit). A
  live billable Claude floor batch was **not** run (no paid Claude Code plan / OAuth expired).

## flow-deck — new sibling product

- Repo at `/home/manhquy/Downloads/flow-deck` (branch `main`, local; **no GitHub remote yet**).
- Commits: `e48aa15` (v1 web MVP), `12bb57f` (QA fixes).
- A **gate-aware operator dashboard** (web-first): reads flow world-state + execs `flow.sh
  check` in each card's worktree; local web board on `127.0.0.1:7420`. NOT a terminal, NOT a
  multiplexer, NOT flow. Constitution: `flow-deck/docs/adr/0001-dashboard-identity.md`.
  Dependency arrow: flow-deck → flow.sh; flow-skill never depends on flow-deck. No PTY, no
  daemon, no agent spawn. Node, zero runtime deps. `node --test` 12/12.

## Cross-vendor eval spike (live, no paid Claude)

Ran flow's real judge prompt on the 9 heading-mapped fixtures, judged by 4 available engines
via Herdr: **omp/Grok 4.6 9/9, agy/Gemini 3.7 Flash 9/9, grok/Grok 4.6 (Build) 9/9,
cursor/Claude Opus 4.8 8/9**. The only divergence is `fcdc` (the deliberately-hard decoy;
Claude Opus passed it) — which validates keeping `fcdc` semantic and not mechanizing rule 8.
This is a spike, **not** flow's official floor (a non-`claude` / combined-prompt judge is a
different measurand and does not count toward the eval floor or tripwire-2).

## QA + fixes

A 5-agent QA wave (review/test/red-team/validate) caught real defects the cook agents missed
and they were fixed before merge: P3 Starlight `{#id}` anchors were dangling + a forbidden
"stop switch on the agent" phrase (both fixed in #13); flow-deck could green a wrong-tree
check (`cwdUnsafe` + rc0) and trusted unverified jsonl worktree paths (fixed in `12bb57f`);
P1 recipe leaked `CLAUDE_CODE_SAFE_MODE` globally (fixed in #11); P2 "never spawn" wording +
ADR process-token direction + two non-binding assertions (fixed in #12).

## Open / next

- flow-deck has no remote — create one (e.g. via the new-repo flow) if it should be pushed.
- Phase 1 D floor batch remains available cheaply (`FLOW_EVAL_ISOLATED_CWD`) once a paid
  Claude Code plan / auth is present; the first isolated batch is a NEW baseline.

## Release

Skill product **0.31.0** + npm installer **0.7.1-next.0** (dist-tag `next`).
Version mirrors bumped on `release/skill-0.31.0`; publish pending GitHub-environment
`npm-publish` approval. No git tag / npm publish in this session.

