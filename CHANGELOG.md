# Changelog

## [Unreleased]
- fix(attest): `_att_chain_verify` temp files (latest-entry index and ledger key index) now call `mktemp` with an explicit `${TMPDIR:-/tmp}/.att-chain*` template, so BSD `mktemp` honors `TMPDIR` on macOS; an invalid/unwritable `TMPDIR` fails closed (`BROKEN`, never a false pass), while an unset `TMPDIR` defaults to `/tmp` and verification proceeds normally; `skills/flow/references/attestations.md` documents the exact six-field link hash order and trailing newline, excluding `v1`.
- feat(attest): tamper-evident receipt chain ledger (`chain.log` sidecar, one line per minted receipt) and `flow attest verify-chain` (`OK`/`BROKEN`/`MISMATCH`/`MISSING`/`UNTRACKED`/`NO-LEDGER`/`EMPTY`); chain hashes are filter-immune (`git hash-object --no-filters` on raw receipt bytes), so clean filters and CRLF conversion cannot mask an edit. Receipt schema v1 unchanged; the chain stays warning-only, never gate authority.
- fix(doctor): verify `timeout --version` or `-s` capability in doctor timeout check; avoid falsely reporting Windows System32 timeout as full GNU timeout.
- fix(runner): convert project ROOT to Windows-native paths on MSYS for the native Python ranking invocation (`assess_scan`), and the install root plus manifest path for receipt verification (`verify-receipt`). Runner Eval STOP bodies (`_with_timeout` and `_eval_engine_run`) remain strictly untouched.
- test(rules): isolate diagnostic outputs under `$SCRATCH` rather than shared `/tmp/probe2.out`; align timeout fallback tests in `test_flow_rules.sh` to distinguish absent converter from nonexistent target.
- docs(rules): clarify rule regeneration in `skills/flow/references/command-dispatch.md` when destination already exists (remove stale scaffold first) and qualify WSL reference to match runner output.
- fix(rules): preserve timeout subprocess arguments when cygpath fails or returns empty output; cover failed, empty, successful and missing-target conversion through the Python fallback. Generated Windows instructions qualify Git Bash only; WSL path mapping is unverified.
- fix(rules): scaffolded-rule operations work from installed layouts whose path contains shell metacharacters (e.g. `Flow space [x]+(y)&`). Root cause (PR93, CI-diagnosed): MSYS/Git Bash skip automatic POSIX→Windows argument conversion for such paths, so native Windows python received a literal `/tmp/...` harness path and exited 2 before printing anything; the GNU-timeout probe branch made earlier fallback fixes unreachable. The runner now converts install-tree paths explicitly for every native python consumer (harness script, graph DB probe, flow topology, repo map, doctor helper) when `cygpath` exists (identity otherwise); POSIX existence checks and display keep the original path. Same family: the Aider `test-cmd` template built its `bash -c` program with `printf %q`, whose outer-layer backslash form is bash-version-dependent and stripped the inner layer's path escapes on Git Bash (syntax error near `(` when running card checks); the program is now wrapped in single quotes, which restore verbatim for the inner shell. Regression: `tests/test_flow_rules.sh` section N verifies the conversion contract against a stub converter mapping to a real file; the layout matrix re-runs the Aider injection path on all three layouts.

## [1.0.0] - 2026-10-24 — breaking release, owner-approved v1 contract
- **BREAKING `skills/flow`:** Python 3 is required for product operations; `flow` refuses them with complete install guidance when Python is absent (help/`doctor` remain usable). Python floor, gates, skip/card behavior, stdlib constraint, and ADR identity preserved; runner Eval STOP bodies untouched.
- **BREAKING ordering:** the graph executor owns `/flow next` ordering and recovery pinning; a Windows-eval root cause was fixed and the runner hash re-pinned (`4dcd127`).
- **BREAKING flag:** `FLOW_HARNESS_DISABLE` refuses product operations instead of silently degrading.
- fix(workspace): stop suggesting the Claude `--worktree` alternative after Flow already creates a worktree (PR #84).
- Windows CI: bash-suite runs as three shards (`FLOW_SUITE_SHARD=1/3..3/3`) with per-shard budgets; Ubuntu timeout diagnosis landed fail-fast cancelled-run detection with 14 watcher regressions; `tests/test_flow_eval.sh` Windows fixtures fixed.
- Tests: new suites `test_flow_v1_runtime_required` (every primary verb refuses with install guidance), graph parity/executor/lint/auto-run, manifest-runner coverage; `tests/manifest.txt` registry updated.
- Migration + rollback: `docs/migration-v1.md`; pre-migration SQLite backup/refusal/restore verified by `V1RollbackVerifier` on candidate `db0328cdd`; database changes are not undone by reinstalling an old npm package.
- Acceptance evidence: PR #87 CI `40059003951` 16/16 green including `all-checks-passed`; post-merge master CI `40063546827` green.

## [0.34.9] - 2026-10-22
- **Actionable doctor diagnostics:** Known missing environment dependencies and install homes include static platform-specific remedy advice in human output and an optional JSON `remedy` field, without changing check outcomes or executing installers.
- **Cross-harness AGENTS.md rules target:** Additive `flow rules agents-md` previews or safely writes a root `AGENTS.md` instruction file establishing Flow build discipline, stage sequence, and honest evidence verification. Existing files and symlinks are strictly refused; no live harness activation claimed.
- **Compatibility:** Backwards-compatible patch; no security or service-rights expansion. Release preparation only, not a publication receipt.

## [0.34.8] - 2026-10-22
- **Terminal retro guidance:** Completed flows direct the host to the terminal retro step rather than implying another build stage.
- **Project Agent Skills:** Additive Codex/Gemini project discovery recognizes `.agents/skills/flow`; `flow rules agent-skills` previews or safely writes a rules pointer only when the canonical project Flow bundle is installed. This does not claim live Codex/Gemini activation or expand npm installer project scope.
- **Release guidance:** Align release preparation and preflight guidance with reviewed, dual-axis promotion. Backwards-compatible; no security or service-rights expansion.

## [0.34.7] - 2026-10-21
- **Brownfield status guidance:** When `flow/00-inspect.md` exists but its assessment gate is dirty, `/flow status` directs the user to `/flow assess` instead of suggesting `/flow next`; the gate still blocks planning until clean. Merged after the v0.34.6 release and first ships in v0.34.7. Regression coverage: A5/A6 in `tests/test_flow_assess.sh` covers dirty, clean, and greenfield guidance.

## [0.34.6] - 2026-10-20
- **Brownfield next-guard fix:** A dirty `flow/00-inspect.md` with a failing gate blocks `next` before `00-idea` creation, with `FLOW_LAST_GATE_FAIL` attribution on the failure path. Regression coverage: A5 in `tests/test_flow_assess.sh` asserts the block/unblock transition and that no `00-idea` is minted while the assessment is dirty.

## [0.34.5] - 2026-10-19
- **Telemetry run-state hygiene:** Write pure run-state (`.flow/events.jsonl`, `flow/.lock*`, `cards/.inflight`, `MODE`, `PROJECT_TYPE`) to clone-local `.git/info/exclude` via `git rev-parse --git-path`, keeping `.flow/` telemetry and locks uncommitted during `git add -A` without modifying tracked `.gitignore` files or opening tolerance bypasses.
- **Root discovery and ancestor adoption:** `flow` announces new flow root initialization only when no Flow signature exists in the current directory or its ancestors; automatically adopts ancestor flow projects from subdirectories, displaying the adoption notice to stderr and the stdout marker (`note: adopting flow root ...`) while qualifying stage-00 PASS artifacts.
- **Dependency-seam ledger for Stage 05:** Contract gate validates dependency seam integrity before stage advancement.
- **Machine-readable debt list envelope:** `flow debt --json` provides structured debt reporting for host orchestrators.
- **Unattended release policy & verification:** Automated GitHub Actions publishing workflow (`publish-npm-wrapper.yml`) with fail-closed eligibility evaluation, master-only environment boundary, pack-once tarball integrity verification, and verify-only recovery mode (`docs/adr/0002-unattended-release-policy.md`).
- **Promotion-only release pipeline & fail-closed gates:** Refactored `scripts/sync-release.mjs` release execution from mutating in-place ship into promotion-only mode; enforces zero modifications/commits on master, requiring prior PR preparation with strict working tree cleanliness (deleting `ALLOWED_RELEASE_FILES`), master branch and remote origin equality, non-drift synchronization, non-existing tags, exact-HEAD CI verification (`all-checks-passed` with authoritative `github-actions` app slug validation), environment `npm-publish` required reviewer protection gate, and verification battery before atomic tag creation, push, and GitHub Release creation; unified README transforms under shared `getExpectedReadmeTransforms`; updated documentation and checklist to reflect operator blocked state and executor enforcement pending repository owner environment reviewer configuration.
- **Release test & pack-rehearsal physical path fix:** `scripts/pack-rehearsal.sh` resolves temporary directories to physical paths (`pwd -P`) before installer invocations so macOS `/var` symlink ancestors under `/var/folders` do not trigger destination ancestor symlink refusals during release rehearsal; `tests/test_sync_release.sh` Case K captures and echoes abort output on failure and ensures master branch in test fixture.
- **Windows release battery npm.cmd EINVAL fix:** `scripts/sync-release.mjs` invokes the npm-wrapper sync and node --test battery steps directly via `process.execPath` (node) instead of `npm.cmd`, which Node 22 on Windows refuses with `spawnSync EINVAL`; a regression (Case L) asserts the exported spawn helpers never reference `npm.cmd`. `tests/test_flow_rules.sh` translates the `.aider.conf.yml` path via `cygpath -w` for Windows python so the `flow status` fallback assertion sees the file.
- **macOS CLI entry guard realpathSync fix:** `scripts/sync-release.mjs` compares `realpathSync(fileURLToPath(import.meta.url))` with `realpathSync(process.argv[1])` so symlink aliases such as macOS `/var` -> `/private/var` do not cause a silent no-op exit; regression in `tests/test_sync_release.sh` (Case M) asserts symlink invocation executes `main()` where `ln -s` creates a real symlink.
- **Windows release pipeline & fixture path fixes:** `scripts/sync-release.mjs` checks `git diff --cached --quiet` before committing release preparation and i18n files to prevent failures when CRLF normalization makes `git add` a no-op; wraps `gh` execution through `cmd.exe /d /c` with bare `gh` on Windows so mock `gh.cmd` wins from PATH directory precedence; `tests/test_sync_release.sh` uses `winpath` for paths passed to `node` in test fixtures.
- **CI Windows bash-suite timeout:** Increased `ci.yml` `bash-suite` Windows job timeout budget to 80m (measured 54m37s–59m53s across all registered bash suites with variance) to prevent timeout cancellation before the PowerShell installer step; updated `docs/release-process.md` CI facts.
- **CI eval test isolation:** `tests/test_flow_eval.sh` Case K isolates the full 13-fixture batch under a dedicated private `TMPDIR` root to eliminate ambient directory noise on shared runner hosts while strictly asserting exact zero residual temp directories.
- **CI macOS bash-suite timeout:** Increased `ci.yml` `bash-suite` macOS job timeout budget to 25m (measured 14m51s suite plus post-job need, exceeding previous 15m limit) to prevent workflow timeout cancellation after suite pass; updated `docs/release-process.md` CI facts.
- `flow gate <stage> --json` and `flow gate --card C-NNN --json`: closed `gate.report` envelope (schema_version 1, target, clean, findings array) for machine consumers; unknown arguments fail loudly with exit 2.

## [0.34.4] - 2026-10-16
- `flow ready --json`: closed `ready.report` envelope (buildable cards with deps/allowed-files/wave, blocked reasons, warnings, advisory parallel groups, auto state) for host orchestrators; unknown arguments now fail loudly (exit 2) instead of being ignored.
- `flow auto --parallel`: records the parallel policy (`parallel: true`) in auto-state after the same attested preflight and prints advisory first-fit waves; the host still places and waits (ADR-0001: no scheduler).
## [0.34.3] - 2026-10-15
- **Unified release automation (scripts/sync-release.mjs + scripts/release.sh):** Fail-closed dual-axis coherence, strictly non-mutating dry-run (recursive SHA-256 tree hash), fail-closed local+remote tag suppression, and portable read-only battery.

## [0.34.2] - 2026-10-15

- **Comprehensive 21-Harness Market Expansion:** Formally authored, validated, and integrated desk intake evaluations for 21 market harnesses across Tier 1, Tier 2, and Tier 3 categories (including Cursor, Zed, Roo Code, Cline, Windsurf, OpenHands, Aider, Copilot, Goose, Amazon Q Developer, Devin, SWE-agent, GitLab Duo, Sourcegraph Cody, Augment Code, Tabnine, Plandex, Trae Dual A/B, PearAI, AutoCodeRover, and historical profiles for Void and Mentat).
- **Unified Release Pipeline & Fail-Closed Gate Automation:** Built `scripts/sync-release.mjs` with `--check` and `--sync` modes, automated dual-axis release coherence validation, hardened multi-locale README synchronization, and fail-closed local/remote tag suppression to eliminate release drift.
- **Dedicated Release Test Suite:** Added `tests/test_sync_release.sh` registered in `tests/manifest.txt` covering read-only coherence, table row validation, prerelease protection, and remote tag failure suppression.

## [0.34.1] - 2026-10-14

- **Transactional ownership installer (npm channel):** upgrades replace the destructive rm-then-copy contract with a receipt-driven transaction — strict input validation, read-only conflict/collision/root-mismatch survey (no `--force`), staged candidate preserving user files (inside managed dirs too), rename-only backup/promote with promoted-tree verification against the staged expectation, and `recoveryPath` reporting when a rollback rename fails. Installed receipts are regenerated from staged bytes and own only source files, so preserved customs are never pruned later. `CLEANUP_SUBDIRS` removed (clean cutover). Details: `npm-wrapper/SECURITY.md`, `docs/system-architecture.md`.
- **Windows junction refusal & path parsing hardening:** `installer_helper.py` unifies symlink and NTFS reparse point / junction detection across all target, source, root, and receipt traversals using a shared `is_link_or_junction` predicate (refusing junctions with exit 7 before file modifications); component parsing preserves raw Windows drive letter prefixes (`C:\`) and UNC paths (`\\server\share`) without stripping or corruption; native capability detection skips FIFO assertions on platforms lacking `mkfifo` while enforcing link/junction rejection.
- **`omp` install target (npm channel):** explicit `--target omp` → `~/.omp/agent/skills/flow`; autodetection only on the genuine `~/.omp/agent/skills` dir (bare `~/.omp` never triggers); project scope stays claude-only.
- **Named doctor registry & CLI flags:** `flow doctor` now provides 12 registered checks with `--list`, `--check <csv>`, and `--json`. Early validation rejects unknown or empty check names with exit 1 and valid JSON error envelopes.
- **Full bundled-tree receipt integrity:** `sync.mjs` generates tree-wide `manifest-hashes.json` covering all packaged skill files (the receipt is generated from the current source tree at pack time, so the file count always matches what `sync.mjs` produces for the single install home — no second home). `flow doctor` verifies the entire installed tree with ancestor symlink checks, path traversal guards, duplicate key rejection, and SHA-256 validation (clean cutover, loud FAIL on drift, advisory skip on dev checkouts).
- **Dedicated doctor test suite:** `tests/test_flow_doctor.sh` exercising registry listing, filtering, NUL record framing, JSON error envelopes, and tamper/symlink boundaries (40 tests).
- **Opt-in host lifecycle context adapters:** Operator-installed context adapters (`skills/flow/adapter-hooks/`) under ADR-0001 addendum providing advisory SessionStart/PreCompact status handoff and private snapshot mutation (`.flow/context-handoff/snapshot.json`).
- **Windows process containment & Job Object launch gate:** `context_handler.py` eliminates the pre-launch spawn race on Windows via a trusted Python launch-gate child blocking on a 1-byte stdin `GO` signal until the parent assigns its handle to an anonymous kill-on-close Job Object (`JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`). Creation or assignment failures abort before `GO`, killing the gate child so target `bash` never executes. Synchronous `PeekNamedPipe` polling handles standard input and process pipes with total monotonic deadlines and bounded buffer caps (excess drained without stalls); unexpected OS pipe errors fail open immediately; `JobHolder.close()` verifies `CloseHandle` and falls back to `TerminateJobObject`. Runner invocation normalizes `RUNNER` and `FLOW_PROJECT_ROOT` to forward slashes for Bash compatibility while preserving native Windows working directory on `Popen`. Supported on Windows with fresh-only handoff (explicit refusal of snapshot read/write due to absence of `O_NOFOLLOW`); registered regression suite `tests/test_flow_windows_lifecycle.sh` (15 assertions passing on Linux with Windows Job tests pending Windows host/CI execution).

## 0.34.0 — 2026-10-12 — PIN v1 + runner hardening + brand identity

Skill product bump to **v0.34.0** shipping PIN v1 status/resume contract,
atomic concurrency lock, runner integrity verification (C1–C7 wave),
and brand identity system. npm installer → **0.7.7** (dist-tag `latest`
after `npm@0.7.7` publish).

### Added
- **npm installer v0.7.7:** Release installer CLI v0.7.7 shipping skill product
  v0.34.0 with PIN v1 status/resume contract, runner concurrency lock guard,
  cross-platform CI hardening, and brand/docs/UX parity.
- **PIN v1 status/resume contract:** exact STOP body excerpts reprinted after
  `NEXT_VERB` on status/resume so compact hosts recover `FLOW_FORCE`, `HALT`,
  and hollow-done rules (`skills/flow/references/pin-v1.txt`). JSON remains
  7-field state (`flow_context/v1`).
- **AgentKit (`ak:*`) aliases:** cross-vendor agent mapping across references
  (`claudekit-skills.md`, `agent-stage-mapping.md`, `adversarial-review.md`).
- **C5 runner integrity check:** pack-time runner SHA-256 hash in
  `portable-manifest.json` and bundled `manifest-hashes.json` receipt;
  verified via `flow doctor`.
- **Brand identity system:** Direction A gate symbol + `flow-04-gate-o-v2` wordmark
  (32u corridor), guidelines/tokens/gallery, 12 wordmark studies, prior-art collision audit.
- **README brand headers:** light/dark `<picture>` blocks in `README.md`, `README_VN.md`, `npm-wrapper/README.md`.
- **Production asset pack:** `brand-lockup` light/dark SVGs, glyph, favicon/app-icon/og-image/sticker suite under `brand/icons/`.
- **`brand/WEBSITE-HANDOFF.md`:** handoff for feat/flow-website adoption.
- **omp-inspired landing redesign:** living flow-field canvas hero, tabbed install widget, agent marquee, numbered full-width gate bands (01–06), scroll/hover motion; desktop squeeze bug fixed.
- **Six gates immersive elevation + site-wide docs branding:** artifact-preview gate bands with bilingual taglines, Starlight docs theme (Ink/Mist + teal), favicon/og on docs pages.
- **Version automation:** registry-driven `versions.ts` + version-cache fallback, `website-scheduled-rebuild.yml` (cron + `npm-published` dispatch), `publish-npm-wrapper.yml` dispatch step; flowskill.io.vn no longer hardcodes versions.

### Fixed
- **Runner concurrency lock:** Atomic `set -C` lock claim guard in `flow.sh` and
  `attestations.sh` to prevent `mkdir` race condition (#22).
- **MSYS path normalization:** Normalized harness `_db.py` path for Windows MSYS (#21).
- **i18n CRLF handling:** Fixed i18n pairs verification on Windows Git with CRLF (#24).
- **Windows CI timeout:** Increased Windows bash-suite timeout from 45m to 60m for
  the full 67-suite set (#27).

### Tests
- `test_flow_status_legibility.sh` PIN v1 assertions.
- Pack-rehearsal exercises `flow doctor` on installed artifact.

PR: [#28](https://github.com/manhquydev/flow-skill/pull/28).

## 0.33.0 — 2026-09-17 — status --json + Stage 05 heading map

Mid-tier hosts lose gate state after compact. Additive `status --json` /
`resume --json` (`flow_context/v1`) plus heading-map Stage 05 so shipped
f05a/f05b actually judge. ADR-0001 held. Eval STOP held. npm installer →
**0.7.3** (dist-tag `latest` after `npm@0.7.3` publish).

### Added
- **`status --json` / `resume --json`:** one closed `flow_context/v1` object
  (`v,stage,gate,next_verb,card,dwell,load`). Display-only. No `receipts.*`.
  No `.flow/context.*` pack. Inherits EXIT logger like prose status.
- **Heading-map Stage 05:** `_eval_heading_pattern` / `_eval_extract_section`
  read `gate-05.md` only (no `gate-shared.md` cat). Eval census 9→11.

### Changed
- **`NEXT_VERB=` / JSON `next_verb`:** hosts MUST NOT auto-exec the whole
  enum (`next`/`card`/`card-start`/`check`/`fix-gate`/`auto`/`skip`), not
  only `auto`/`skip`.
- Unknown extra args on `status`/`resume` exit **2**.

### Tests
- `test_flow_status_legibility.sh` JSON arms (empty-events, `gate=PASS`,
  `load=law/CLAUDE.md`, extras exit 2). `test_eval_fixture_lint.sh` treats
  05 as a heading-mapped pair. `test_flow_eval.sh` `of 11 evaluated`.

PR: [#19](https://github.com/manhquydev/flow-skill/pull/19).

## 0.32.0 — 2026-09-11 — mid-tier gates, scanners, disclosure

Host-agnostic discipline for Gemini Flash / DeepSeek without owning a runtime
(ADR-0001). npm installer → **0.7.2** (dist-tag `latest` after `npm@0.7.2` publish).

### Added
- **`law/CODING.md`:** six portable MUST/NEVER laws (explicit resolve, fail-loud, behavior-named tests, no empty catch, cite the seam, library over hand-roll).
- **`gate-examples.md`:** hot-path PASS/FLAG few-shots for stages 01/02/03/05 and cards. `fcdb` labeled mechanical FAIL.
- **`_scan_midtier` in `scan_gate`:** typed-web ≥3 research entries, L-above-A (optional colon), PRD adjectives, OD>5. Card path stays box/FILL only.
- **`NEXT_VERB=`** advisory closed enum from `_next_action` (hosts must not auto-exec `auto`/`skip`).
- **Split `gate-rules.md`:** index + per-section files + `gate-shared.md`. Eval extract maps 01/02/card; sha is an explicit file list; `_eval_engine_run` / `_run_with_timeout` unchanged.

### Changed
- **Dispatcher `SKILL.md`:** PTC_ONLY load table; no `YOU (Claude)`; next-PASS extra is `gate-examples.md` only; type-aware done-evidence; ≤1600w.
- **Templates 01/02/03/card:** one worked PASS-shaped row (Splitwise corpus matches f01a/§01); remaining rows FILL.
- **Child briefs:** STATUS examples docs-only; AutoDecision unique home `auto-run.md`; VN copy opt-in.

### Fixed
- Project-type lock uses planning artifacts on disk, not `scan_gate` cleanliness.
- Darwin live-eval SKIP (exit 0, unmeasured) when `claude` is absent.
- Host-neutral repair ladder (`debugger if present`) before Codex; scenarios suite retargeted.

## 0.31.0 — 2026-08-20 — eval receipts, host-agnostic parallel, value-first docs

Eval receipt+linter+doctor+isolated-eval, host-agnostic parallel law, value-first
docs A-E, macOS grep hotfix. npm installer → **0.7.1** (dist-tag `latest`; first cut **0.7.1-next.0** / `next`).

### Added
- **Eval hardening** ([#11](https://github.com/manhquydev/flow-skill/pull/11)): hash-only `prompt_sha` judge-input receipt (skip-if-absent, mismatch hard-fail, no committed prompt bodies); CI fixture-impossibility linter that protects `fcdd`/`fcdc` as mechanical-PASS; doctor `timeout: full|partial|absent` + `timed_out` JSONL at the caller; `FLOW_EVAL_ISOLATED_CWD` + `CLAUDE_CODE_SAFE_MODE=1` isolated cheap live-eval. Eval STOP held (`_eval_engine_run`/`_run_with_timeout` byte-identical).
- **Host-agnostic parallel law** ([#12](https://github.com/manhquydev/flow-skill/pull/12)): `references/host-agnostic-parallel.md` + pointers + doc-contract test. Parks a future own-runtime `flow-orch` in ADR-0001 Deferred as a **separate** product.

### Changed
- **Value-first docs A-E** ([#13](https://github.com/manhquydev/flow-skill/pull/13)): `/docs/` rewrite EN+VI (install → what-you-get → features → analysis last), curated ≤14 sidebar, complete security-halt page, first-run T3, landing reorder, 47→13 pages/locale with a 132-row 301 redirect surface, `{#id}` heading anchors.

### Fixed
- **macOS BSD grep** ([#14](https://github.com/manhquydev/flow-skill/pull/14)): cap grep interval at 200 (`RE_DUP_MAX=255`) in the host-agnostic parallel test so the assertion is valid on macOS BSD grep as well as GNU grep.

## 0.30.0 — 2026-08-14 — discipline-layer identity + CI/eval hardening

Identity ADR: flow owns gates and receipts, never the runtime. npm installer → **0.7.0**.

### Added
- **Identity ADR** (`docs/adr/0001-discipline-layer-identity.md`): process-token invariant, five flip-tripwires, proportional eval floor, replay-never-counts, fixture-pair-per-new-gate-rule, monetization cap.
- **`flow.sh eval --record` / `--replay`**: keyless artifact-eval replay through parse→vote→per-fixture match (no scorecard). Stale `gate-rules` hash hard-fails. Replay verdicts never count toward the eval floor. `_eval_engine_run` / `_run_with_timeout` bodies unchanged.
- **B1-S named-artifact evidence**: every done-evidence item must name its artifact or producing command (semantic card gate + `fcdd`/`fcde` fixture pair). Mechanical scoring unchanged.
- **CI `all-checks-passed`**: single required aggregation job (`needs` + `if: always()`). `tests/run_all.sh` reads `tests/manifest.txt`. `paths` filters removed so docs-only PRs still report.
- **Credentialless pack-rehearsal**: every-PR ubuntu job packs the npm wrapper, byte-compares tarball `skills/flow/` vs repo, installs into a temp DEST, drives `e2e-installed-drive.sh`.
- **Root `AGENTS.md`** (symlinked `CLAUDE.md`) + word-budget verify; EN/VI README blob-hash pairing (`docs/i18n-pairs.txt`).
- **macOS live-eval refuse-by-default** when no real `timeout`/`gtimeout` is on PATH; opt-in `FLOW_EVAL_UNBOUNDED=1`. Replay never hits the guard.

### Changed
- README test badge points at `tests/manifest.txt` instead of a hardcoded suite count.

## 0.29.0 — 2026-08-13 — spec-kit imports + converge (flow-back closer)

Mined from GitHub spec-kit, redesigned to flow's DNA (mechanical half via the existing
scanner; semantic half as a ritual). npm installer → **0.6.0**.

### Added
- **Open decisions + `/flow clarify`.** Unresolved product decisions are `- [ ]` bullets
  under `## Open decisions` on Scope/PRD/Contract, counted by the *existing* `scan_gate`
  box scanner (no new scan code, no self-poisoning `[ASK]` token). `/flow clarify` is an
  advisory, section-scoped printer; `references/clarify.md` is the bounded write-back ritual.
  Not wired into the `cmd_next` hot path.
- **Card `## Independent test`** field (user-visible slice proof, or `infra`/`none`); leftover
  `[FILL]` there fails `check`. PRD/contract "requirements-quality" Gate boxes. `law` forbids
  models-only cards. `references/artifact-lifecycle.md` names the 3 mutation models.
- **`/flow converge`** — append-only remainder cards reconciling present code vs plan.
  Transactional (validate all, commit all-or-nothing); never edits an existing card; prints
  `CONVERGED` + writes nothing when there is no gap; `unrequested` → review card, never a
  delete. Payload schema `flow-converge/v1` (`references/converge.md`).
- **Converge eval modality** — `flow.sh eval --stage converge`: a third judge (alongside
  gate + routing) that feeds a repo-state (flow docs + card claims + allow-listed source) and
  asks `GAP|CONVERGED`. Fixtures `gap-01` / `conv-01`; fully offline-tested (mock engine).

### Tests
- `test_flow_open_decisions.sh`, `test_flow_slice_quality.sh`, `test_flow_converge.sh`, and
  7 converge-modality cases in `test_flow_eval.sh`. All 3 OS `bash-suite` green.

## 0.28.1 — 2026-08-11 — attestation harden package

### Security / trust
- Mint executes **committed blobs** at `--revision` (materialized temp), not dirty worktree bytes; owner/command/oracle require regular-file blob equality.
- Live receipts require **exact HEAD tip** plus recomputed owner/oracle fingerprints.
- Cleanliness on mint/consume/auto: allow `.flow/`, `flow/.lock*`, status/Evidence-only card dirt; reject empty `base==rev` card semantic.
- Supervisor: real `setsid` PGID kill + capability probe; auto preflight order prints risk before clean gate.

### Tests
- `test_flow_attestation_harden.sh`; coverage_gaps auto expects v0.28 fail-closed without git/receipts.

## 0.28.0 — 2026-08-11 — attested execution / trust control plane

### Added
- Card risk fields (`risk`, `risk-reason`, `risk-ack`) with auto fail-closed preflight.
- Attestation receipts (`semantic_gate`, `live_verify`) under `.flow/attestations/`.
- `flow attest semantic|live-verify|status|recover` and `flow auto stop`.
- Active-auto enforcement on `check` / `card done` / ready deps / merged worktree remove.
- Canonical contract: `skills/flow/references/attestations.md`.

### Changed
- `/flow auto` activates shared policy only after full risk set + Stage 05 semantic receipt.
- Process supervisor for attestation owner/oracle (streaming caps, process-group cleanup).
- npm prerelease operational tag policy: `next` (not `rc`).

### Security
- Receipts detect subject staleness; they do not authenticate actors or resist a hostile host.
- Attestation usage logs omit argv after `--` and raw command output.


All notable changes to the flow skill. Versions follow the `version:` field in

## 0.27.0 — 2026-08-11 — harness authority continuity

Post repository-harness protocol-v1 EOL: durable layer is **flow-owned**; live pin
narrative for `harness-cli` 0.1.14/0.1.17 removed; improve + assess protocol ports.

- **Live authority** table in `harness/README.md` (flow_harness.py + flow.sh + gate-rules).
- **GAP-MATRIX SUPERSEDED**: no further upstream schema sync; historical archive notes
  (last published `harness-cli-v0.1.22` per upstream ADR 0027).
- **Contract tests flipped**: require flow-owned / no-sync; keep story-complete trust greps.
- **R-IMPROVE-HARNESS** native ritual (fresh-agent rerun before keep); native-rituals 6.
- **Brownfield assess**: Evidence ledger claim tags + gate-rules section; material-authority
  stop on Scope/PRD/Contract.
- **harness-skill** redirects to `/flow harness`; complete-only preserved; no live pin claim.
- Pin file + optional smoke reframed as historical archive only.
- Plan: `plans/260811-1405-flow-harness-authority-continuity/`.

## 0.26.0 — 2026-08-11 — hollow-done mechanical trust floor

Mechanical multi-signal floor for card `## Evidence` when `status: done`, so process-only
prose (PR approvals / CI green / release notes) cannot mark a card done or unblock
dependents via hand-edit. Residual decoy multi-signal remains offline semantic (`fcdc`).

- **World-state signal score ≥ 2** (categories URL / command-curl / positive test tokens /
  existing path / DB rows / skill path) in `cmd_check` and `cmd_card_done`.
- **`ready` + graph deps-met re-validate** done deps: Evidence multi-signal + no unchecked
  Verify + no `[FILL]` (hand-edit hollow cannot unblock parallel/auto dependents).
- **Host denylist** for category A (`example.com`, localhost, `*.invalid`, port-stripped).
- **C-tokens** not matched inside URLs; `fail`/`failed` do not award C; fence needs positive
  tokens.
- **`card done` fail-closed**: INT/TERM restores `todo` + exit 130; gate fail always forces
  `todo` (never hollow `done`).
- **Project-type lock** after planning when a type file exists (`FLOW_FORCE=1` to flip).
- **Eval fixtures**: `fcdb` process-only → mechanical FAIL; **`fcdc`** hollow-with-signal for
  offline LLM FLAG; seven-fixture manifest; CI stays mechanical-only (no billable `eval`).
- **Tests**: `test_flow_done_evidence.sh`, `test_flow_auto_done_path.sh`; full suite **48**
  suites green. Docs: `ground-truth-gates.md`, `gate-eval.md` scorecard, `auto-run.md`.

Plan: `plans/260811-1120-flow-hollow-done-trust-eval/`. Independent review report:
`plans/reports/code-review-independent-260811-hollow-done-vi.md`.

## 0.25.0 — 2026-07-27 — graph executor (opt-in, default off)

A graph executor lands in the durable layer, porting LangGraph **concepts** — not code —
into flow's own Python harness: a checkpoint journal, resume by evidence rather than by
replay, and gates as durable interrupts. It is **off by default**; nothing changes for an
existing project until `FLOW_GRAPH_EXECUTOR=1` is set. Flag-off behavior was verified
byte-identical to 0.24.0 across the full planning ladder, card lifecycle, and workspace verbs.

- **Schema band 014+** (`graph_execution`/`graph_checkpoint`/`graph_step_write`/
  `graph_interrupt`), additive; 013 stays reserved for upstream. This supersedes the
  GAP-MATRIX "work-graph out of scope" red line — flow owns its work-graph now.
- **`flow harness graph …`**: `session` (one execution per project, arbitrated by SQLite,
  not a lock file), `record`, `next`, `resume`, `status`, `cards`, `finish`, `abandon`,
  `gc`, `lint`, `root`. Manifests are built from typed flags, so card text can never forge
  a gate verdict.
- **Topology as trusted data**: `references/flow-topology.json`, pin-verified
  (`harness/pins/flow-topology.sha256`), loaded only from the skill install dir, and
  validated by a 16-rule `graph lint` wired into CI. `cmd` entries are argv arrays limited
  to the new read-only `gate` verb — mutating verbs are lint-banned from autonomous
  execution.
- **`/flow gate <stage>|--card C-NNN`** (new, May-run): mechanical scan only — no unlock,
  no template copy, no durable write. Exit 0 clean / 1 findings / 2 usage or card-not-found.
- **Debt-skip fix (applies with the flag off)**: `/flow next` no longer re-creates a
  debt-skipped stage, and no longer stalls when that stage's successor file is missing —
  it advances to the first stage that is neither present nor skipped.
- **Worktree-aware durable state**: a linked worktree resolves to the main worktree's DB so
  parallel cards share one journal. Submodule and `--separate-git-dir` checkouts keep their
  own DB (git does not expose the checkout there) — documented, not guessed.
- **Worktree telemetry survives path spelling**: the lifecycle key for a merged worktree
  sink is now canonicalized, and its path travels in its own argument (`--src-key-path` +
  `--src-key-tag`). Pre-joining path and tag with `#` produced a string that Git-Bash path
  translation would not rewrite, so on Windows the rows were keyed differently from the
  sink the harness resolves for itself — written, then invisible to `usage` and unreachable
  by `prune`. The same split hit any macOS path reached through a symlink.
- Python floor is **measured at 3.7** and enforced by `scripts/release-preflight.sh`; CI
  pins the interpreter and proves the engine still gates a project with no python on PATH.

## 0.24.0 — 2026-07-18 — harness trust-align (repository-harness 0.1.17 spirit)

> Skill version jumps 0.22.0 → 0.24.0. The **0.23 milestone was the cross-agent installer**
> (Cursor target + universal Agent-Skills home + per-agent restart-guidance), which shipped
> via the **npm wrapper `0.1.0-rc.2`/`rc.3`** with no flow-skill version bump — see
> `plans/260717-0925-cross-agent-installer-expansion/`. The `0.23.x` skill number is
> intentionally skipped to keep skill and installer milestones distinct.


Align flow durable layer + skills with **repository-harness authority** (protocol floor
`harness-cli-v0.1.14`, trust CLI **`harness-cli-v0.1.17`**, never use **0.1.16** assets).  
No full schema 006–013 merge; no rust unfreeze on flow-lineage DBs.

- **Trust boundary:** `story update --status implemented` **rejected**; use
  `story complete --id … --proof-source card_markdown_gate|manual|verify_command`.
  Card markdown gate records honest `proof_source=` in notes and **does not** forge
  `last_verified_result=pass` (only `story verify` may set shell-verify pass).
- **`/flow check` done** wires `story complete --proof-source card_markdown_gate` + enriched
  auto-trace (no fake `--lane tiny` override).
- **STRICT durable writes:** `FLOW_HARNESS_STRICT` unset|`1`|`fail` — soft warn vs loud vs
  propagate nonzero; `harness_call_checked` for observed exit codes.
- **Gap matrix** `skills/flow/harness/GAP-MATRIX-0.1.17.md` + lineage/docs contract tests.
- **Canonical harness skill** `skills/harness-skill/SKILL.md` (CI-tested; optional install to
  `~/.agents/skills/harness`).
- **Docs purge:** agent-stage-mapping / auto-run / harness README no longer teach bare
  implemented updates.
- **Optional** `HARNESS_CLI_SMOKE=1` release binary smoke + sha256 sidecars.
- Tests: `test_flow_harness_lineage_contract`, `test_flow_harness_strict`,
  `test_flow_harness_trust_complete`, `test_flow_skill_harness_docs_contract`,
  `test_harness_cli_optional_smoke`.

Plan: `plans/260718-0840-harness-v017-flow-skill-trust-align/`.

`skills/flow/SKILL.md` (mirrored in `.claude-plugin/plugin.json` and `portable-manifest.json`;
`/flow coherence` enforces agreement). Earlier history lives in git and the README status line.

## 0.22.0 — 2026-07-16 — concierge front-door + standalone self-sufficiency

Two operator-approved workstreams from a brainstorm→plan→red-team→validate→cook pipeline
(3-agent hostile red-team, 21 raw findings → 13 accepted after dedup, all applied; 4-question
validation interview). Full plan: `plans/260716-1342-flow-v022-concierge-standalone/`.

**WS-A — Concierge front-door.** Chat is now the default entry to `/flow`: any natural-language
ask routes through `references/concierge.md` — run `flow.sh status` (ground truth, never a
guess) → look up the closest row in the new `references/flow-catalog.tsv` → propose exactly ONE
next action in plain language → offer to run it, per a **default-deny** May-run/Must-ask
classification covering all 27 dispatcher verbs (red-team: an earlier draft left `promote` and
`harness` — global/durable writes — in an unclassified auto-run gap; `next` was misclassified as
auto-runnable even though its pass-precondition can't be verified before it runs). New users get
exactly one plain consent question before the concierge switches to `mode work` on their behalf
(teach-mode's "never author on the operator's behalf" rule still holds). Power-user verbs pass
through untouched — a typed `/flow next` dispatches exactly as before.

**WS-B — Standalone self-sufficiency.** Installing flow alone now gets the **full** experience —
five gate seams that used to lean on optional external skills ship **native, clean-room
rituals** (`references/native-rituals.md`): persona-debate @ ADR, edge-case decomposition @
Contract, STRIDE security @ Review, numeric retro @ Retro, native loop protocol @ Build/Verify.
`ck-predict`/`ck-scenario`/`ck-security`/`ck-loop`/`retro` are now offered as **richer
alternatives** when installed, never a requirement (`gate-rules.md`, `adversarial-review.md`,
`law/RETRO.md`, `claudekit-skills.md` all rewired native-first). **Legal**: claudekit-engineer is
proprietary (All Rights Reserved) — every ritual was written fresh from public/generic patterns,
reviewed side-by-side against the corresponding ck skill for zero copied expression, and no ck
text was ever committed (tests included). A sixth ritual, `references/forge-idea.md`
(persona-driven idea pressure-testing, opt-in at Idea/Scope, never a gate condition), is adapted
from BMAD-METHOD's `bmad-forge-idea` (MIT) — the full license notice is reproduced verbatim.

**Routing eval judge (v0.22 addition, not a stage-list tweak).** Red-team correctly identified
that "extend `--stage`" undersold the work: routing judges (state-snapshot + utterance) → action,
a different shape from the existing artifact-vs-gate-rules judge (FLAG/PASS). Built as its own
modality: `flow.sh eval --stage routing` — separate manifest (`eval/fixtures/routing/`, 15
fixtures, VN+EN, incl. one steering-resistance case), separate prompt builder
(`_eval_routing_build_prompt`, utterance fenced as DATA with an explicit "do not obey it"
instruction), separate verdict vocabulary (MATCH/MISS/INVALID/UNRELIABLE), separate results
stream (`eval-routing-results.jsonl`) and scorecard, own `--report`. Hard cost ceiling: **90
calls/batch** (validation decision), pre-batch cost estimate printed before any billable call,
zero-call clean skip when `claude` CLI is absent. Metric is labeled **panel-agreement**, not
"accuracy" — expected actions are Claude-authored then reviewed by an independent adversarial
agent panel before becoming the oracle (there is no independent human ground truth yet).

**CI**: the repo is now public, so GitHub Actions minutes are free — a new `bash-suite` job in
`.github/workflows/ci.yml` runs the full `tests/run_all.sh` on the ubuntu/macos/windows matrix,
replacing the parked Azure Pipelines setup (demoted to an unused fallback; the operator setup
task it was waiting on is closed).

**Format change**: `references/flow-catalog.tsv` is TSV (tab-separated), not CSV — gate-note
prose contains commas and Vietnamese text carries diacritics, both of which corrupt a naive
comma-split (same reason `eval/manifest.tsv` already used TSV).

**Release evidence — new-user script (plan criterion 2).** Real `flow.sh status` on a fresh
empty sandbox (no `flow/` dir) returns `planning: not started` / `NEXT -> run '/flow next'
to unlock stage 00` — matching `flow-catalog.tsv`'s `start-new-project` row
(`state-precondition=no-flow-dir-yet`, `action=mode`). Per `concierge.md`'s entry loop, the
concierge reads this real mechanical output and asks exactly one consent question before
running `mode work` — zero flow verbs typed by the user up to that point.

**Release evidence — cross-vendor routing spot-check (plan criterion 6).** 3 catalog
utterances run for real through Antigravity (`agy -p`, Gemini-3), built from the actual
routing prompt (`_eval_routing_build_prompt`): "where am I?" → `resume` ✓, "card nay xong
chua?" → `check` ✓, "lam retro di" → `retro` ✓ — 3/3 matched the catalog's expected
action. Codex CLI was attempted first but the workspace returned `402 deactivated_workspace`
(installed but not usable — the exact "installed≠usable" distinction `codex-integration.md`
already documents); Antigravity was the available second engine. Claim is honest per plan
criterion 6: Claude-verified (Phase 1 manual table + Phase 4 routing-judge batch), Codex/
Gemini best-effort — backed by this real spot-check, not assertion.

23 files changed (7 created: `concierge.md`, `flow-catalog.tsv`, `native-rituals.md`,
`forge-idea.md`, `eval/fixtures/routing/*`, `tests/test_flow_concierge.sh`,
`tests/test_flow_native_rituals.sh`, `tests/test_flow_forge_idea.sh`); 34 suites / 926 checks
green (was 31/799).

## 0.21.0 — 2026-07-11 — eval-trust hardening + express-lane kill (A killed by telemetry)

Two-part release, both evidence-driven from the first REAL gate-eval baseline run.

**Motivating incident (260710, run `…-1783695631-…`).** The very first real batch after v0.19
shipped came back **17/18 INVALID** despite the existing in-run retry — the storm produced no
usable votes and burned all 18 billable calls. The only diagnostic signal (`SessionEnd hook
cancelled` ×18 on **stderr**) was thrown away because the seam captured stdout only. A single
call + one full rerun immediately after came back clean (hollow-flag 3/3 stages 100%, 0
INVALID/18) — mechanism unconfirmed at the time. The **next** storm has to be diagnosable, and
the aborted-batch cost has to be capped. That's the whole shape of Phase 1.

**Express-lane KILL (roadmap A → rejected by data).** Same-day per-cycle telemetry mining
dissolved the original justification for an express-lane verb: cycles that ran ≥1 successful
`next` reach Cards at **14/15 (93%)**, contract-stage dwell median is **40s** (n=12; the "1.3h
bottleneck" was a measurement artifact of `usage --global` averaging), and "33% abandonment"
decomposes into exploration pokes + CMC brownfield card-mode. Roadmap A is formally killed with
a re-trigger condition; the anti-FOMO log entry captures the numbers so future FOMO can be
answered directly. See `docs/quality-metrics.md` §A-kill.

**Red-team pass** (3 hostile lenses, all findings `file:line`-backed, 26 raw → 14 accepted after
dedup) drove the final Phase 1 spec: `.claude-plugin/plans/…/plan.md → ## Red Team Review`.

### Phase 1 — eval robustness

- **Raw capture on final-INVALID** — both attempts' `stdout` + `stderr` + `rc` persisted to
  `.flow/eval-raw/<run_id>/<fixture>-v<vote>-a<attempt>.{out,err,rc}`. Envelope stripped down to
  `assistant`/`result`/`rate_limit_event` records — `cwd` (which embeds the Windows username on
  this dev OS), `session_id` (resumable via `claude --resume`), plugin/memory paths, `apiKeySource`
  are all removed. `cmd_eval` now calls `_ignore_run_state` so `.flow/eval-raw/` is git-ignored
  on any project that runs the verb (previously only next/card/skip paths ignored `.flow/`).
- **Circuit breaker on first UNRELIABLE.** Trip after the FIRST fixture returns UNRELIABLE
  (`invalid_count*3 > n` — the existing reliability floor), print an abort line naming the raw
  dir + file count, set an `aborted` flag, and skip the `done` trailer so `--report`/drift never
  surface the junk batch as canonical baseline (a `--fixture`-filtered aborted run would
  otherwise satisfy `n_written == n_expected` and slip through). Distinct nonzero exit **2**.
  `--keep-going` overrides; worst-case cost of `--keep-going` in a full storm is documented next
  to the flag (≤ N_fixtures × n × 2 + probe ≈ 37 calls at defaults).
- **Injectable backoff.** `FLOW_EVAL_RETRY_BACKOFF` env (default 5s, tests set 0) delays the
  retry so it doesn't hammer the same window. Retry is now also **skipped when a rate-limit
  signal fired on attempt 1** — the retry is documented for "a formatting slip, not infra"
  (`flow.sh:2792`); retrying into a live rate-limit window just doubles spend. A greppable
  `retrying vote N` line makes the retry path assertable via text, not stopwatch (existing
  wall-clock asserts were already fragile on 3-OS CI).
- **Rate-limit visibility (advisory).** New `_eval_parse_rate_limited` anchored to
  `rate_limit_info`'s own `status` value. Empirical: on cli 2.1.201 a **healthy** `allowed` event
  carries `"overageStatus":"rejected"` as a separate field in the same envelope — a naive
  `grep '"status":"' | grep -v allowed` would false-positive on every healthy call, and fixture
  prose could mint the string. Documented best-effort/advisory until a real throttled sample
  lands in the corpus. Results rows gain `retries` (0/1 per fixture) + `rate_limited`
  (`true|false`) — additive, PIPE_BUF < 4096B invariant preserved.
- **Pre-batch raw-dir prune.** Keep the 3 newest run dirs by the **epoch embedded in `run_id`**
  (deterministic, mount-independent, unforgeable by `touch` — mtime was ruled out because
  Windows FAT/network mounts spoof it, and a `touch` of the storm dir would delete the very
  evidence being diagnosed). TTL guard: never prune a dir whose embedded epoch is within
  `FLOW_LOCK_TTL` (900s) seconds of now (guards a concurrent lock-free run — `cmd_eval`
  deliberately takes no lock, so cross-run coordination is via epoch, not lock).
- **Fixture-id sanitized for write paths.** The v1 trust boundary was read-side only; the new
  raw-capture is the first write keyed by `fid`, so it is sanitized through the nonce charset
  (`[A-Za-z0-9-]` collapsed) before touching the filesystem — a hand-edited or
  `FLOW_EVAL_MANIFEST`-overridden manifest cannot traverse out of `eval-raw/`.
- **Raw-write failure is LOUD**, not the file's usual `2>/dev/null || true` telemetry-sink
  pattern — this is diagnostic-critical; a full disk (which correlates with long sessions →
  storms) must not silently emit an empty raw dir the operator then reads as "engine returned
  nothing".
- **Invariant comments** at `_eval_emit_batch_marker` updated to reflect the two paths to a
  missing trailer (INT/TERM + v0.21 breaker) instead of only the interrupt one.

### Red-team findings that shaped the spec (14 accepted, ranked)

- **Critical C1** — original spec of the breaker (all-INVALID first fixture) would NOT have
  fired on the 17/18 storm (one vote parsed), so the trip condition became **first-UNRELIABLE**
  (which the 17/18 case satisfies at fixture 1 by the reliability-floor math).
- **Critical C2** — original spec captured stdout only; storm signature was on stderr.
- **High H3** — `_eval_emit_batch_marker done` runs unconditionally after the loop; a bare
  `break` still writes the trailer, and a `--fixture`-filtered aborted run then satisfies
  `n_written == n_expected` → recorded COMPLETE, poisons the drift baseline. Fixed by the
  `aborted` flag guard.
- **High H4** — the earlier "no secrets in raw" claim was wrong; envelope carries cwd + session +
  plugin paths; stripping is now real, `.flow/` is ignored explicitly.
- **High H5** — `rate_limit_event` shape was guessed at plan time; empirical shows an `allowed`
  event carries `overageStatus":"rejected"` → the parser is now anchored, the field is doc'd
  as advisory.
- **High H6** — hardcoded `sleep 5` was untestable + slow on 3-OS CI → `FLOW_EVAL_RETRY_BACKOFF`
  env + text-based assert on the `retrying vote N` line.
- **High H7** — the plan's 6/6 AC had no contingency for f01a resisting repair; Phase 3 gained
  a fallback ship path (Phase 1 + docs = v0.21.0 with the canonical baseline deferred).
- **Mediums** — cost math correction (worst case ≤7, not "~3"; `--keep-going` up to ~37);
  prune-by-mtime → prune-by-epoch + TTL; write-path traversal via `fid` → sanitized; house
  silent-sink pattern for raw writes → loud warning; phantom "both call sites" → the single call
  site (`flow.sh:2833`) is named; Phase 2 `dependencies: []` → `[1]` + line range 36-41 → 38-41
  + deny-list token note (test N will hard-fail a rewrite that names the pattern being tested).

### Tests

- Existing tests D/E/G updated for the v0.21 breaker (single-fixture UNRELIABLE now exits 2 with
  a distinct ABORT line, previously exited 1 with UNRELIABLE line only).
- New: **O** raw-capture persists stdout+stderr+rc for both attempts (with a mock that writes
  stderr + exits 1 on empty stdout — proves the stderr channel this whole feature exists for);
  **P** `--keep-going` full-batch override; **Q** aborted batch writes NO `done` trailer +
  `--report` cannot surface it; **R** rate_limited false-positive-proof against
  `overageStatus":"rejected"` in a healthy `allowed` event; **S** retry emits greppable
  `retrying vote N` text line (path-asserted, not wall-clock); **T** `--report` tolerates
  additive `retries`/`rate_limited` fields; **U** raw-prune keeps 3 newest by run_id epoch + TTL
  guard for fresh dirs + prunes gibberish-named dirs (epoch=0); **V** envelope strip removes
  cwd/session_id/plugin_paths from persisted raw.

### Docs

- `references/gate-eval.md` — new **Failure modes and postmortem (v0.21)** section: 260710
  storm reconstruction, INVALID-storm playbook, no-lock caveat, `rate_limited` advisory framing.
- `SKILL.md` — eval-verb doc updated with `--keep-going` + `FLOW_EVAL_RETRY_BACKOFF` + raw-capture
  behavior.
- `docs/quality-metrics.md` — new anti-FOMO §Roadmap A killed by data (numbers + re-trigger).

### Canonical v0.21.0 baseline (billable, verified)

Run `…-1783743592-…` (260711, 14 min, ~$6-7): **6/6 MATCH, 0 unreliable, 0 invalid, 18/18 calls
parsed.** Per-stage `hollow-flag-rate 1/1 sound-pass-rate 1/1` across `01-research`, `02-scope`,
`card`. Judge `claude-opus-4-7`, CLI `2.1.201`, `gate_rules_sha 3672145322`. Recorded in
`.flow/eval-results.jsonl`; `eval --report` surfaces the drift-baseline. Fixture f01a's
repaired complaint #3 flipped its verdict from 5/5 FLAG (pre-repair) to 2/3 PASS (post-repair,
still a majority pass with one dissent, consistent with the fixture's other imperfections being
left in place per the Risk Assessment).

### Post-ship CI fixes (v0.21.0 line, no version bump)

Two macOS-only CI regressions caught on the v0.21.0 push, fixed in commit `82a67c0`:

- Retry now skips on `rc=124` timeout (same policy as rate-limit; both are infra, not formatting
  slips). Without this, the retry hit the macOS `_run_with_timeout` watchdog-fallback DEBT
  TWICE per vote — test E measured ~66s under a 20s cap. Ubuntu and Windows are unaffected
  (both have real `timeout` binaries).
- `_eval_prune_raw_dirs` refactored to eliminate `local` inside a piped-`while` subshell
  (unreliable on macOS `/bin/bash 3.2.57`). The sorted list is materialized into a real
  **tempfile** (`mktemp`) in the outer function shell, then iterated with
  `while read line < "$tmpf"` — a **redirect, NOT a pipe**, so the loop stays in the current
  shell. The round-1 attempt (commit `82a67c0`) tried a `set --` with newline-IFS approach on
  a `$(...)` here-string; that worked on bash 5.x (windows Git Bash + ubuntu) but silently
  no-op'd on macOS 3.2, so the round-2 commit (`17677b1`) moved to the tempfile+redirect design
  that is rock-solid across every bash version the 3-OS matrix has thrown at it. Restores test
  U's `gibberish pruned` + `4th-oldest pruned` assertions on the macOS leg. **Do NOT "restore"
  the here-string variant** thinking it was simpler — it did not survive the macOS-3.2 leg.

Lesson recorded: local-run success on bash 5.x (Windows Git Bash, Ubuntu) is not a substitute
for testing the macOS bash-3.2 leg — the 3-OS CI matrix is the source of truth.

### Deferred, disclosed

- macOS `_run_with_timeout` fallback watchdog debt (DEBT.md) — unchanged by this release, still
  needs real macOS to diagnose.
- Azure Pipelines operator setup — still parked.
- A real throttled `rate_limit_info` sample so `rate_limited` can become authoritative rather
  than best-effort — will land the next time a storm actually throttles.

## 0.20.0 — 2026-07-10 — mission-control legibility (resume verb + status upgrade + per-card dwell)

Evidence-driven (1079-event dogfood telemetry): `status` is the most-called verb (287, 2.8x
`next`) yet had no next-action line or dwell; nothing gave a fresh agent session a resume brief
(industry's top unsolved "AI context amnesia" complaint); per-card dwell was blind in `usage
--global` because the compact log row omitted `card`/`args`. Composition of already-existing
data (per-project events log, `cards/.inflight`, gate state) — no new infrastructure.

- **New `flow.sh resume`** (read-only, no lock): last session (command names + exit + stage
  transitions, absolute timestamps — **never raw args**, since `_mask_secrets` is keyword-only
  and a quote-blind extractor would truncate escaped-quote values anyway), in-flight card(s) +
  dwell, current gate state, exactly one `NEXT ->` recommendation. Honest degradation: fresh
  project → "nothing to resume"; no telemetry → "no telemetry — showing gate state only" + gate
  state + NEXT. Torn-line defense (rejects a truncated OR mid-corrupted glued-together final
  log line). SKILL.md now instructs: run `/flow resume` first when entering a project mid-cycle.
- **`status` upgrade**: first content line after the header is `NEXT -> <action>` (shared
  `_next_action` helper with `resume` — the two verbs can never disagree); current-stage dwell
  anchored on a genuine entry transition (`exit_code=0`, not a failed-`next` retry — see fix
  below); card list compacts to `cards: N created (X done · Y in flight · Z todo)` past 10 cards
  (in-flight + todo cards always listed individually, only `done` cards summarized). Existing
  anchor strings (`gate: PASS`, `gate: BLOCKED`, `cards: N created`, `planning: at stage`) frozen
  byte-for-byte for the two known consumer suites; ≤10-card output is byte-identical beyond the
  two new lines.
- **`usage --global` dwell-blind fix**: the compact GLOBAL log row gains `card` + a
  charset-guarded, 32-char-bounded `args` field, populated ONLY when `command=card` (constant
  key shape otherwise) — reuses the existing pairing reader, no schema migration. `flow_harness.py`'s
  `cmd_rollup` (and `cmd_prune`, found missing by review) gain `errors="replace"` decode
  tolerance + a cursor-hold on a final unparseable line so one bad byte can no longer kill the
  whole rollup or permanently drop a torn-then-completed `card done` pairing.
- **Caught and fixed during the per-phase code-review pass** (independent `code-reviewer`
  subagent, one pass per phase):
  - **Critical — Windows/Git-Bash hang.** Piping `_gate_state_brief`'s nested `scan_gate`
    output into a `while read` consumer (a new Phase-3 construct) froze indefinitely whenever
    the current stage's gate was genuinely BLOCKED — a Git-Bash/MSYS early-pipe-reader-exit
    class issue. The review also found this was not new: the pre-existing Phase-2
    `_next_action` reason-lookup pipe (`scan_gate | grep -m1 | sed`) had the identical latent
    bug, previously confined to the rarely-called `resume`, now exposed on the highest-traffic
    verb by this release's own `NEXT ->` wiring. Fixed by eliminating both pipes:
    `_gate_state_brief` takes the dwell string as a plain arg and is called directly (no
    subshell); `_next_action` captures `scan_gate`'s output into a variable first, then
    greps/seds the already-drained string. A `timeout`-guarded regression test was added so CI
    can never wedge on this class again.
  - **Critical — wrong stage-dwell anchor.** A failed `/flow next` retry writes
    `stage_to=<same stage>` but never sets `stage_from` (stays at its script default `""`), so
    the original `stage_from != cur` filter did not actually exclude failed retries — dwell kept
    shrinking toward the latest failure, the exact bug the design was meant to prevent. Fixed by
    anchoring on `exit_code=0`, the field that actually discriminates a genuine entry from a
    failed retry.
  - **Medium** — the compact card-summary's displayed total could drift from the real
    done+in-flight+todo sum under sparse card numbering (`highest_card()` returns the max
    suffix, not a file count); now computed from the real per-file count.
  - **Low** — a redundant double file-loop in the compaction branch merged into one pass.
- **Tests**: new `test_flow_resume.sh` (29) and `test_flow_status_legibility.sh` (24, incl. a
  `timeout`-guarded BLOCKED-gate regression case) wired into `run_all.sh`. Full suite:
  **31 suites / 799 checks**, all green.

Also bundled (originally scoped as a separate 0.19.0, shipped together since both landed in the
same cycle):

- **New `flow.sh eval`**: behavioral proof for the semantic gate layer. Runs the real per-stage
  `gate-rules.md` challenge text against 6 curated sound/hollow fixture pairs (Stage 01
  fabricated-quote pattern, Stage 02 grade-laundering, card "merge≈shipped" evidence),
  majority-votes a nonce-protected verdict (N=3, injection-resistant), prints a per-stage
  scorecard. Opt-in and billable (clean zero-call skip if `claude` CLI absent); `--report`
  re-reads a prior batch offline for free. Proves a fresh-judge lower bound, not the work-mode
  self-challenge — see `references/gate-eval.md`. A Step-0 contract spike found `claude -p` runs
  a full agentic loop with live tool access by default; locked down with `--tools ""`. Code
  review caught and fixed a critical stdin-consumption batch-truncation bug, a shared-helper
  space-path bug, an unanchored verdict-parse regex, and a misleading drift comparison across
  differently-scoped batches.
- **Post-ship hardening (found only by the first real 3-OS CI run, invisible to local
  Windows/Linux testing):** macOS ships bash 3.2.57 as `/bin/bash` (bash < 4.4 treats a
  zero-element array as unset under `set -u`) — `_cleanup_tds()`'s unconditional
  `"${_CLEANUP_TDS[@]}"` threw "unbound variable" inside the EXIT trap on every single flow.sh
  invocation on macOS, silently breaking telemetry entirely; fixed by guarding with
  `${#arr[@]}` first. A new CI regression test called `timeout` directly, which macOS doesn't
  ship (BSD userland); fixed with a small portable wrapper. `_run_with_timeout`'s macOS fallback
  watchdog does not reliably bound a slow/stuck `claude` call on macOS specifically (confirmed
  across 3 targeted fix attempts against real CI, root cause still unconfirmed without live
  macOS access) — tracked as open debt (`DEBT.md`, opened 2026-07-10); scoped to the opt-in,
  billable, never-auto-invoked `eval` verb only. Ubuntu + Windows CI fully green including e2e.

## 0.17.0 — 2026-06-24 — repository-harness v0.1.10 deep integration (schema reconcile + kind-aware tool registry)

Reconciles flow's ported durable layer with freshly-pulled upstream `repository-harness`
(Rust `harness-cli` v0.1.10) and adopts its headline capability. Research was multi-agent +
verified-external (anti-FOMO): P1 confirmed aligned with 2025-26 tool-discovery practice
(Anthropic Tool Search); P2 (score-context) **deferred** with evidence (flow has no context-rules
surface to score against; a naive port would reward the context-bloat Chroma "Context Rot" measures).

- **P0 — schema-005 collision fixed (latent data-corruption).** flow once numbered its accessed-count
  migration `005`, colliding with upstream's `005-tool-extensions`. Adopted upstream's `005` verbatim
  and **re-homed flow's migrations to 009-012** (accessed-count + usage-log mirror), restoring 001-005
  as a faithful upstream port. The migration runner is now **column-idempotent** (skips an ADD COLUMN
  whose column exists, `CREATE … IF NOT EXISTS`, `INSERT OR IGNORE` schema_version) and a **legacy
  reconciliation** heals DBs built under the old numbering on the next `init` — no duplicate-column
  crash, no data loss (verified against a seeded legacy DB).
- **Rust seam frozen + guarded.** `_maybe_forward_to_rust` now **refuses** to forward a flow-lineage DB
  (usage mirror present, or `schema_version >= 9`) to an external `harness-cli` — exit 2 with a guiding
  message — since the lineages diverge past the shared 001-005 base. flow does not build/ship the binary.
- **P1 — kind-aware inbound tool registry** (ported from upstream, pure stdlib, 0 new deps). `tool`
  gains kind/capability/scan_target/status/checked_at; `tool register --kind cli|binary|mcp|skill|http
  [--capability] [--scan-target]`, `tool check`, `tool remove`; `query tools --capability --status`.
  Presence is probed mechanically (cli/binary on PATH incl. Windows PATHEXT, mcp/skill by path, http by
  2s TCP) so a step asks "what is equipped for purpose X" and clean-skips an absent tool. Registration
  always succeeds and records status (declared intent + last-scanned reality) — the old 4-arg
  `register` stays back-compatible (kind defaults to cli).
- **Tests:** new `test_flow_schema_migration.sh` (11: fresh + legacy-heal + crash-at-v3 heal + idempotency
  + guard) and `test_flow_tool_registry.sh` (19: 5 kinds + capability/status lookup + check + remove +
  back-compat + responsibility-reject + http-scheme), both wired into `run_all.sh`. `test_flow_usage_log.sh`
  updated for the re-homed version numbers. Full suite **27 suites / 633 checks**.
- **Release-close audit hardening** (4-agent adversarial pass, edge + happy, distrusting the first run):
  - BLOCKER fixed — `migrate()` now applies by **missing-version set** (not `version <= MAX`), so an init
    crash between migrations 003 and 004 (reconcile inserting 005) can no longer skip 004 / drop the
    `intervention` table. Regression test added.
  - http presence probe now **only probes http/https** schemes (matches upstream) — a foreign-scheme or
    bare-word `scan_target` no longer triggers a multi-second DNS/TCP stall.
  - `tool register` now **validates `--responsibility`** against the fixed 11-vocab (like `--kind`), so a
    typo can't silently break `query tools --responsibility` routing. The upsert is wrapped in an explicit
    transaction (atomic replace).
  - **Deferred / known low-probability edges** (revisit if observed): a `schema_version` row recorded while
    base tables are absent is now self-healed for the common case but not guaranteed for hand-corrupted DBs;
    `tool check` over many dead http rows scans them serially (2s each).

## 0.16.2 — 2026-06-23 — release-close polish (honesty + coverage punch-list)

A 3-agent release-readiness audit found v0.16.1 had zero code blockers but four small
honesty/coverage gaps worth closing before sealing the version. All fixed here:

- **CI-badge honesty (README EN+VN)** — the front-door claim "checks green on macOS·Ubuntu·Windows"
  implied a passing hosted CI, but GitHub Actions has been billing-blocked since v0.14.0 (every run
  fails to start). Reworded to "green **locally** … hosted CI parked on the Azure-Pipelines migration",
  so the README no longer contradicts the (red) badge. The CHANGELOG already disclosed this each release;
  now the README does too.
- **`command-dispatch.md` completed** — it billed itself the "exact mapping" but listed only 18 of the
  runner's commands. Added the 9 missing rows (consistency, constitution, project-type, usage, skip, debt,
  design, harness, doctor) so every runner verb has its documented duty.
- **Per-card dwell: failed-`done` exclusion now tested** — the "a reverted/failed `card done` never closes
  a dwell" guarantee was advertised but untested; added a negative end-to-end assertion (a gate-failed
  `card done` produces no `card_dwell` pair).
- **`--global` per-card-dwell empty-state message fixed** — it told users to "mark cards" even though the
  metric is project-local by design (the compact global log omits card ids); now says so plainly under
  `--global`.

No behavior change beyond the dwell empty-state copy. Full suite green; coherence PASS. **This seals the
v0.16 line.** Still parked (disclosed, not blocking the close): Azure CI org-setup + free grant; Phase-2
`card archive`; `docs/` refresh (CHANGELOG remains the source of truth).

## 0.16.1 — 2026-06-23 — per-card dwell metric + README sync (completes v0.16.0)

Closes the loop on v0.16.0: the `card start` stamp is now turned into a real analytics number, and
the user-facing docs are brought current (they had lagged at v0.13.1, three releases behind).

- **Per-card dwell in `/flow usage`** — pairs each operator-marked `card start` with its successful
  `card done` (both `command='card'`, the verb in `args`) per (project, cycle, card) and reports the
  start→done wall-clock. Earliest start × latest *successful* done; a failed/reverted `done`
  (exit_code≠0) never closes a dwell; cards finished by hand-edit + `check` (no `card done` event)
  simply have no pair. Surfaced in both the human view and `--json` (`card_dwell`). Rollup-only —
  the FR2 logging is unchanged; no new event type, no hot-path cost.
- **README + README_VN synced v0.13.1 → v0.16.1** — status banner now covers the v0.14–0.15
  claudekit skill-layer and the v0.16 card lifecycle; command tables document `card start|done` and
  the per-card dwell line.

New assertions in `test_flow_usage_log.sh` (end-to-end: real `card start`→`card done`→`usage`).
Full suite green; coherence PASS. CI remains parked on the Azure-Pipelines migration (GitHub billing
block) — tracked, not forgotten.

## 0.16.0 — 2026-06-23 — legible card lifecycle (operator-marked start + CLI-owned done)

Closes the one real gap a 3-agent analysis found when the operator asked whether flow underuses
ck:plan: flow already has a richer lifecycle than ck:plan (a 5-state harness story + world-state
done-gates) but only ever SHOWED the operator a 2-state card (`todo|done`) — the "what am I
mid-flight on" state was invisible, buried in the harness. ck:plan's value was never its drafter
(a real twin of flow's planner — correctly stays dropped) but its *legible* status model. This
borrows that legibility natively, portably, with zero `ck`-CLI / server dependency.

**Two new verbs (both opt-in; they COEXIST with hand-editing `status:` + `/flow check`):**
- `flow.sh card start C-NNN` — marks a card **in flight**. Tracked in a portable side registry
  (`cards/.inflight`: `<id> <epoch>`) that never touches the gate-validated `status:` frontmatter,
  so it shows even when python/harness is absent; best-effort mirrors to the harness story as
  `in_progress`. The start stamp is the foundation for a future per-card dwell metric.
- `flow.sh card done C-NNN` — a **CLI-owned** flip to `done` that removes the markdown-hand-edit
  drift risk. It is gated by the SAME done-rules as `check` (real `## Evidence` + checked Verify)
  and **reverts** to the prior status if the gate fails — never leaves a hollow `done`.

`flow.sh status` now prints an "in flight" section listing started-but-not-done cards with elapsed
time (GNU/BSD-portable integer math, no `date -d/-r`). Bare `/flow card` still creates as before
(dispatch only intercepts `start`/`done`). New suite `test_flow_card_lifecycle.sh` (16 assertions);
full suite green. **Deliberately NOT built** (adjudicated FOMO for flow's CLI-first single-cycle
use): a visual kanban board, cross-plan/cross-cycle dependency graph, the `ck config ui` server,
and `--html`/`--wiki` plan export. Analysis: `plans/260623-flow-ckplan-lifecycle-analysis/`.

## 0.15.0 — 2026-06-23 — claudekit skill-layer orchestration (Round-2: complete the wirings)

Completes the skill layer started in 0.14.0 by wiring the remaining 3 high-ROI skills into
their gate rituals and turning on lazy skill-telemetry. Docs+wiring only — still **no runner
change**. Operator decisions adopted: Q1 telemetry = yes/lazy, Q2 `suggest` verb = no, Q3 graph
tool = ck-graphify, Q4 = opt-in-with-prompt.

**3 skills wired into their gate rituals** (all opt-in-with-prompt, INFORM-only, degrade silently):
- `review-pr` @ Review — a new PR-context lens in `adversarial-review.md` (duplicate-work,
  AI-slop, breaking-change, CI-blocker, `--fix`), distinct from the wired `code-reviewer` diff
  lens (not a twin); offered only when the card ships as a GitHub PR, never on local-only builds.
- `ck-security` @ security-class cards — an explicit opt-in offer in `adversarial-review.md`
  (STRIDE+OWASP attacker personas); it **never auto-passes the Tier-C operator HALT** (the HALT
  stays classification-triggered, operator-released in `DEBT.md`).
- `retro` @ Retro — offered in `law/RETRO.md` for git-history numbers; the **operator still
  writes the retro line** (teach-mode rule holds); distinct from the `journal-writer` narrative.

**Lazy skill-telemetry ON (Q1).** After a deep-wired skill runs at its gate, its use is recorded
via the **existing** `flow.sh harness intervention add` (the same durable-metric channel the
Codex/Antigravity lenses use) — **only at the 5 wired gates**, never on every skill, never on the
`cmd_next`/`cmd_check` hot path, no new runner verb. Feeds a future usage-weighted whitelist.

Test suite `test_flow_claudekit_integration.sh` grows 27 → 42 clause-bound assertions (Round-2
adds the 3 wirings + telemetry + no-new-verb guard). Full suite green; coherence PASS (0.15.0 ×3).
Note: GitHub Actions CI is currently blocked by an account billing issue (jobs refuse to start) —
local suite is the available ground truth until billing is restored.

## 0.14.0 — 2026-06-23 — claudekit skill-layer orchestration (Round-1)

Flow already orchestrated claudekit at the **agent layer** (13 ck: agents, ck:→bmad→built-in
degrade). This release extends the same seam to the **skill layer** — a curated per-stage
whitelist answering "the kit has ~87 skills, which do I use when?". Built engine-design-first
via a 3-agent flow-skill dev team (flow-internals + catalog-triage + synthesis/red-team); the
red-teamer cut its own teammate's proposed `flow.sh suggest` verb as unproven ceremony, so
Round-1 ships docs + wiring only, no runner change.

**New `references/claudekit-skills.md`** — the single source of truth for the skill map: a
<15-skill build whitelist (the ~60% marketing catalog curated out), each pinned to its stage and
the **distinct verb** it adds beyond the wired agent (pure skill/agent twins deliberately
dropped). Carries the binding rules, identical to the Codex/Antigravity seam: a skill **INFORMS**
a stage and the gate **JUDGES** (never auto-pass/auto-fail); detection is **Claude-side** and
degrades silently (the runner can't see the skill registry and the 5 install homes differ, so
skill detection is never put in `flow.sh`); enrichments are **opt-in-with-prompt, off the hot
path** (the constitution/Codex cost-gate discipline).

**5 deep-wired high-ROI skills** at the gates where a miss is most expensive: `ck-predict` @ ADR
(5-persona pre-decision debate), `ck-scenario` @ Contract (12-dim edge-case → acceptance +
contract tests), `review-pr` @ Review/Ship, `ck-security` @ security-class cards (never
auto-passes the Tier-C operator HALT), `retro` @ Retro. ck-predict@ADR and ck-scenario@Contract
are wired into the gate ritual itself (`gate-rules.md`) this round; the rest are catalogued.

**Cuts (FOMO, not ROI):** competing orchestrators (cook/vibe/ship/bootstrap run inside a stage),
skill/agent twins, the `worktree` skill (dup of `flow.sh workspace`), `bmad-spec` as a gate (dup
of `/flow consistency`), all marketing skills. Graph tool resolved to a single pick: **ck-graphify**
(gkg not wired). New regression suite `tests/test_flow_claudekit_integration.sh` (27 clause-bound
doc-contract assertions). Operator decisions deferred to Round-2: skill-invocation telemetry
(lazy, off by default), the `suggest` verb (cut unless demand shown). Backward-compatible;
additive only.

## 0.13.1 — 2026-06-23 — real-usage fixes (harness CLI forgiveness + monorepo root guard)

Two defects found by auditing flow's OWN telemetry from two real builds it drove
(`D:\project\CMC`, 118 invocations; `D:\project\AI20K\C2-App-001`, 214 — its heaviest
real project). Both caused silent loss/fragmentation of durable data. Backward-compatible.

**Harness CLI forgiveness + non-silent errors** — in both projects, `flow harness
trace/decision/intake` calls were silently dropped to argparse **exit-2** (the durable
record never reached `harness.db`) because agents typed natural variants the parser
rejected. Now `trace` accepts the underscore variants (`--actions_taken`, `--files_changed`,
`--files_read`) and `--card` as an alias of `--story`; and **any** parse failure prints a
guiding "common forms" hint to stderr instead of a bare usage line, so a bad call is
actionable rather than a silent data loss. Canonical hyphen flags are unchanged.

**Monorepo dual-root guard** — running flow from a monorepo subdir (e.g. `frontend/`)
silently minted a **second** `.flow` root with its own `cycle_id` and `project` label,
fragmenting telemetry and double-counting cards (the real C2-App-001 failure mode). The
runner now resolves the root by adopting the nearest **ancestor** flow project (one that
has `flow/` or `cards/`) when the CWD has none of its own — printing a one-line note to
stderr. A subdir with its own `flow/`/`cards/` (a deliberate sub-project) and an explicit
`FLOW_PROJECT_ROOT` are both respected unchanged.

New suites `tests/test_flow_harness_args.sh` (6) + `tests/test_flow_monorepo_root.sh` (9).
Capability-erosion audit across v0.3→v0.13 (separate pass): **no erosion** — every past
command/gate/telemetry-field/agent-tier/test suite is still present and unweakened.

## 0.13.0 — 2026-06-22 — multi-agent worktree workspaces

A new `flow.sh workspace` command family that lets one operator run several agents
(Claude Code / Codex / Antigravity, many terminals) in **parallel without the
"one agent switches branch → every terminal flips" trap**. Each agent gets its own
`git worktree` (own HEAD/index/files, shared object store); git stays the source of
truth (`git worktree list`) and a lean append-only JSONL side-file
(`.flow/workspaces.jsonl`, 10 fields) adds the four things git can't know:
vendor, card, port-offset, task. Backward-compatible; advisory (not a `next` gate).

**`workspace add|list|enter|remove|check|doctor`**
- `add <branch> [--card C-NNN] [--vendor claude|codex|antigravity] [--task "…"] [--copy-env]` —
  provisions a worktree (reuses an existing branch or `-b` a new one), derives a
  **distinct per-worktree port-offset** under the held lock, appends one active record,
  and prints a paste-ready `cd` + `PORT`/`CODEX_HOME` block. git's refusal to check out
  one branch in two worktrees is relayed **verbatim** — that refusal is the real collision lock.
- `list` — joins `git worktree list` with the registry: BRANCH/VENDOR/CARD/HEAD/PORT/TASK,
  plus orphan-record callouts. `enter <branch>` re-prints a crashed terminal's env block.
- `check <branch> [--card C-NNN]` — pre-flight: branch already claimed? + **allowed-files
  overlap** vs other active cards (computed from the card's `## Allowed files`, the same
  invariant `/flow ready` uses — no second declaration surface).
- `remove <branch> [--force]` — safe teardown: relays git's dirty refusal verbatim,
  **never auto-forces**, tombstones only on clean success, then prunes.
- `doctor` — reconciles orphan trees / orphan records / prunable trees (exit 1 on drift);
  duplicate-port and `>FLOW_WORKSPACE_MAX` (default 4) are advisory warnings, never blocking.

New env: `FLOW_WORKSPACE_BASEPORT` (default 3000), `FLOW_WORKSPACE_MAX` (default 4).
Internals reuse the existing atomic-mkdir lock + `_json_str`/`_now`/`_norm_path`; the
line-820 `## Allowed files` extractor was lifted into a shared `_card_allowed_files`
(cmd_ready unchanged). New suite `tests/test_flow_workspace.sh` (43 assertions incl.
torn-line skip + concurrent-add registry integrity). Coexists with `/flow auto`'s internal
`card/C-NNN` worktrees via identical branch naming.

## 0.12.2 — 2026-06-21 — language-aware review

Two improvements closing the last v0.12 backlog item. All backward-compatible.

**language-specialist Review lens [C-021]**

- **`typescript-reviewer` dispatched for `.ts`/`.js` files.** When the file set under review
  contains TypeScript or JavaScript source, the Review seam now routes to `typescript-reviewer`
  as a specialist pass layered on top of the standard `code-reviewer`. The specialist findings
  INFORM triage; they never auto-pass or auto-fail the gate (gate-parity preserved).
- **`python-reviewer` dispatched for `.py` files.** Same pattern: `python-reviewer` runs as an
  advisory specialist alongside `code-reviewer` when `.py` files are in scope.
- **Composes with the security lens.** The language-specialist pass stacks with the existing
  `security-reviewer` lens (C-014) — both can fire in the same Review invocation; neither
  blocks the other.
- **Detect-first degrade.** When the specialist agent is absent or returns empty output, the
  review falls back to `code-reviewer`-only; a missing specialist is never treated as an
  approval. Documented as a "Specialist absent" degrade rung in `adversarial-review.md`.
- **Both agents wired** in `agent-stage-mapping.md` (Review seam) and listed in
  `agent-detection.md` (ck: priority list), so the existing agent-wiring tripwire
  (`test_flow_coverage_gaps.sh`) guards them automatically. +12 checks.

**Portability fix: POSIX `sed -E` replaces GNU-only `grep -oP` in the agent-wiring tripwire [C-018 latent defect]**

- **Root cause.** The C-018 tripwire (`test_flow_coverage_gaps.sh`) used `grep -oP` with a
  Perl-compatible regex to parse the derived agent set from `agent-detection.md`. GNU `grep -P`
  is not available on macOS BSD grep — a CI target. This was a latent portability defect
  introduced in v0.12.1: the tripwire passed on Linux/Windows (GNU grep) but would have failed
  on macOS CI with `grep: invalid option -- P`.
- **Fix.** The parse was rewritten using POSIX `sed -E`, which is supported on both BSD (macOS)
  and GNU (Linux/Windows) grep environments. No change to what the tripwire asserts — only the
  tool used to extract the agent list changed.

## 0.12.1 — 2026-06-21 — v0.12 polish round

Three polish items closing the v0.12 backlog. All backward-compatible.

**telemetry-honesty [C-017]**

- **Legacy-dwell `~approx` label.** `flow usage` now marks dwell figures inferred from legacy
  rows (rows that pre-date the compact global-sink `stage_from` field) with a `~approx` suffix
  so the operator can distinguish reliable wall-clock data from estimated dwell.
- **`--builds-only` build-cycle count.** `flow usage --builds-only` now filters the cycle-time
  line to show only build-intent cycles (excludes diagnostic-only sessions), labeled
  `[N build cycles]` for clarity.
- **Dead variable removed.** `display_count` was assigned but never consumed; the assignment is
  removed so the variable is not a latent confusion risk for future readers.

**orchestration completeness [C-018]**

- **`git-manager` + `docs-manager` seam rows wired.** Both agents now appear as explicit entries
  in `agent-stage-mapping.md` (previously listed in `agent-detection.md` but absent from the
  mapping — a declared-but-unwired gap of the same class as the C-013 `debugger` defect).
- **Agent-wiring tripwire DERIVES its set from `agent-detection.md`.** The `test_flow_coverage_gaps.sh`
  tripwire no longer hard-codes the agent list; it reads the priority list from `agent-detection.md`
  at test time, so a newly added agent that is not wired into `agent-stage-mapping.md` will
  automatically turn the assertion red — no manual maintenance of the test's expected set.
- **Repair-discipline rule.** A new law entry states: when a control-flow or runner repair is
  applied, the FULL test suite must be re-run before advancing the gate (partial re-runs are
  insufficient for changes that touch shared runner paths).

**engine hygiene [C-019]**

- **Advisory-probe tempdir cleaned on SIGINT and early-return.** The tempdir created during
  an advisory probe is now removed via a dual `RETURN`+`EXIT` guard, so a SIGINT mid-probe or
  an early function return leaves no leftover temp directories under `$TMPDIR`.

## 0.12.0 — 2026-06-20 — telemetry truth + orchestration depth

Six improvements across three themes, plus a new CI tripwire that catches "declared but unwired"
agent gaps before they ship. All changes are backward-compatible (optional fields, additive seams,
no gate-contract change).

**telemetry-truth**

- **`usage --global` per-stage dwell now works.** The compact global-sink line carries `stage_from`
  for new rows; for legacy rows the harness infers dwell by partitioning `next`-transition pairs on
  `(project, cycle_id)`. The device-wide dwell view now reflects real stage time instead of
  always zero. [C-011]
- **Honest cycle accounting.** `flow usage` now breaks cycles into build-intent vs diagnostic-only
  using the existing `read_only` field: a session that only ran `status`/`recall`/`usage` is counted
  separately from one that advanced a gate or touched a card. The FR2 logging path is unchanged;
  reclassification happens at read-time and is retroactively correct across the existing log. [C-012]

**orchestration-depth**

- **`debugger` wired into the two-strikes repair ladder.** When a same-ladder agent returns BLOCKED
  a second time, the repair order is now: `debugger` (Claude diagnostic, scoped brief) → Codex
  (if USABLE) → Antigravity (if USABLE) → operator. Previously the `debugger` agent was listed in
  `agent-detection.md` but absent from `agent-stage-mapping.md`'s Repair row — a declared-but-unwired
  gap. The degrade rung ("if `debugger` absent → inline root-cause + fresh same-ladder subagent")
  is explicit and tested. [C-013]
- **Security-class Review lens.** `security-reviewer` is layered into the Review seam alongside
  `code-reviewer` — it runs as an advisory pass (informing triage, flagging OWASP/secrets/injection
  patterns) but never releases a Tier-C operator HALT on its own: the gate still judges. The lens
  is absent-safe (degrade to `code-reviewer` only when `security-reviewer` is not in the host
  registry). [C-014]

**engine-hardening**

- **Atomic `mkdir`-guard concurrency lock, TOCTOU-safe.** The lock acquire now uses a single
  `mkdir` (atomic on POSIX + NTFS) instead of a test-then-create sequence, closing the acquire
  race. FR4 metadata (session_id, PID, timestamp) is written inside the directory after acquire,
  and a crash-recovery self-heal (`kill -0` dead-PID reclaim) runs before each acquire attempt.
  The existing lock TTL and unlock command are unchanged. [C-015 W5]
- **Honest `_python` exit code.** The `_python` dispatcher now propagates the Python subprocess
  exit code to the caller instead of always returning 0; callers that relied on the swallowed exit
  code degrade gracefully (the harness is optional). [C-015 W6]

**agent-wiring tripwire (this card)**

- New test block in `tests/test_flow_coverage_gaps.sh` asserts that every ck: agent named in
  `references/agent-detection.md`'s priority list appears in `agent-stage-mapping.md` as either a
  stage row entry OR an explicitly-labelled repair/diagnostic/review seam. The test is backed by a
  negative-control proof: the assertion turns red if any agent is removed from the wiring. The exact
  `debugger`-unwired defect fixed in C-013 would have been caught by this tripwire at CI time.

## 0.11.0 — 2026-06-20 — usage-log telemetry correctness

Self-assessment of the shipped usage-log (driven by `/flow` on flow itself) audited real logs
from two external projects plus the 1739-line device-global log and found the telemetry was
empty or misleading on real, brownfield, agent-driven usage. v0.11.0 fixes the six defects so
the usage-log is a correct, honest, decision-grade signal. All changes are backward-compatible
(optional fields; the existing logs roll up without rewrite).

- **FR1 — `usage --global` works out of the box.** `cmd_usage` now forwards `--global` to the
  preliminary rollup, so the device-wide view returns analytics in one command instead of
  falsely reporting "no events". (runner)
- **FR2 — `cycle_id` at every entry point.** A new idempotent `_ensure_cycle` stamps the cycle id
  from `_log_event` (universal), `cmd_assess`, and the stage-00 unlock (now reuse-not-overwrite,
  so assess+plan is one cycle). Brownfield/pre-existing projects are no longer blind on cycle
  metrics. (runner)
- **FR3 — wall-clock per-stage dwell.** `usage` reconstructs real time-in-stage from `next`
  transitions (enter = `stage_to` epoch, exit = `stage_from` epoch) instead of reporting the
  runner's own ~1-2s exec time; both metrics are now labeled honestly. New json keys
  `stage_dwell` (wall-clock) + `stage_exec_time`. (harness)
- **FR4 — the concurrency lock can actually hard-block.** `session_id` auto-derives from a cascade
  (`FLOW_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → Codex/Antigravity vars → tty → ppid), so it is
  populated with no operator action; the lock gains same-host `kill -0` dead-process reclaim
  (no more waiting out the 900s TTL for a crashed session). (runner)
- **FR5 — test runs no longer pollute analytics.** Events carry an `ephemeral` flag (project under
  a temp dir or named `tmp.*`); `usage`/`rollup` default-exclude them (read-time `tmp.%` fallback
  covers the legacy log with no rewrite); `--include-ephemeral` opts back in. Schema migration
  `008-usage-ephemeral.sql`. (runner + harness)
- **FR6 — device-wide gate failures are explainable.** The compact device-global line now carries
  a bounded (`≤120` char) `gate_fail_reason`, so "why does stage X fail" is answerable across all
  projects, not just per-project. (runner)

Tests: 20 suites / 413 checks green (`tests/test_flow_usage_log.sh` §9–§14, plus updated
concurrency §L/§M and schema-version assertion). Built and gated through `/flow` itself.
A pre-tag adversarial review fixed two MED issues: cross-platform ephemeral-path
normalization (Windows `C:\` vs `/c/`, and macOS trailing-slash `$TMPDIR` — the latter
caught by CI on macOS, fixed in `_norm_path`) and `_json_str` now strips all control
characters. CI green on macOS · Ubuntu · Windows.
(plan in `plans/reports/historical-runs/v011-flow-telemetry/`, research in `plans/260620-flow-telemetry-assessment/`).
