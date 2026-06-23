# Phase 02 (P1): port kind-aware tool/capability registry

**Depends on:** Phase 01 (tool-extensions columns land as real 005) · **Effort:** 12–18h

## Goal

Bring flow's `tool` registry to upstream v0.1.10 parity in pure stdlib Python: typed tools
(cli/binary/mcp/skill/http), capability binding, mechanical presence scanning, capability lookup.
This mechanizes the **17 hand-wired skill↔stage associations** in `references/claudekit-skills.md`
into `query tools --capability X --status present`.

## Verified research adjustments (apply these)

- **Keep** kind+capability+presence-scan for `cli`/`binary`/`http` — no standard scanner exists; genuinely flow's job.
- `kind=skill`: presence by native skill discovery (path resolve under skills dirs); do NOT re-implement progressive disclosure.
- `kind=mcp`: presence by scan_target path resolve; optionally (future) read connected-server `tools/list`.
- **Do NOT** build tool-RAG / tool-search-over-tools (solves 50–10k-tool context pressure flow doesn't have — FOMO).
- This round = **data layer only**. Wiring `query tools` into gate prose is a follow-up cycle.

## Files to change (skills/flow/harness/)

- schema columns already added by Phase 01's adopted `005-tool-extensions.sql` (kind, capability, scan_target, status, checked_at).
- `flow_harness.py` — extend `cmd_tool` (register flags + `check` + `remove`), extend `query tools`.
- `_domain.py` — TOOL_KINDS (5), 11 responsibilities vocabulary, capability kebab-case normalizer/validator.
- new `harness/_presence.py` — the 5 stdlib presence probes (kept testable in isolation, mirrors _domain/_db split).
- tests — new `tests/test_flow_tool_registry.sh`.

## Implementation steps

1. **Domain (`_domain.py`):** add `TOOL_KINDS = {cli,binary,mcp,skill,http}`, the 11 fixed responsibilities
   (port from upstream `domain.rs`), `normalize_capability()` (kebab-case, validate) — pure functions, unit-testable.
2. **Presence probes (`_presence.py`, stdlib only):**
   - `cli`/`binary`: `shutil.which(cmd)` or `Path(cmd).exists()` / repo-relative join.
   - `mcp`/`skill`: `Path(scan_target).expanduser()` resolves (abs or repo-relative); no target → `unknown`.
   - `http`: `socket.create_connection((host,port), timeout=2)`; fallback to path resolve; no target → `unknown`.
   - `scan_tool_status(repo_root, kind, command, scan_target) -> (status, detail)` dispatcher; never raises.
3. **`cmd_tool` (flow_harness.py):**
   - `register`: add `--kind` (default cli), `--capability`, `--scan-target`, `--force` (skip presence check for cli/binary).
   - `check [--name N] [--json]`: scan all/one, persist `status` + `checked_at`.
   - `remove --name N`.
4. **`query tools`:** add `--capability`, `--status` filters (compose with existing `--responsibility`/`--json`/`--summary`).
5. **Backfill:** Phase-01 adopted 005 backfills `kind='mcp' WHERE command LIKE 'mcp:%'`; verify flow's pre-existing
   tool rows (if any) get a sane default kind.
6. **Tests (`tests/test_flow_tool_registry.sh`):** register each kind; `check` sets present/missing/unknown correctly
   (use a real on-PATH binary like `git` for present, a bogus name for missing, a no-target mcp for unknown);
   `query tools --capability X --status present` returns the right rows; `remove` works; capability normalization rejects junk.

## Acceptance

- 5 kinds register + scan correctly, 0 non-stdlib deps.
- `query tools --capability <c> --status present` is the mechanical replacement for a hand-wired stage→skill line.
- existing tool `register` calls (old 4-arg form) still work (back-compat: kind defaults to cli).

## Risk

- Windows PATH / Git-Bash path resolution + socket timeout cross-platform → covered by test on present/missing/unknown
  across the 3 CI OS legs. `http` probe must hard-cap at 2s and swallow all socket errors.
