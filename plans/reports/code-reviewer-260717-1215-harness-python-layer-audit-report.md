# Advisory Audit: Harness Python Layer — Doc/Code Drift & Dead Artifacts

Scope: `skills/flow/harness/{README.md,flow_harness.py,_db.py,_domain.py,_presence.py,repo_map.py,schema/*.sql}`,
cross-checked against `tests/test_flow_harness*.sh`, `tests/test_flow_schema_migration.sh`,
`tests/test_flow_tool_registry.sh`. Advisory only — no files edited. All claims below are grep/read/run-verified,
not inferred from the plan or prior memory.

## 1. Schema files present (ground truth)

```
skills/flow/harness/schema/001-init.sql
skills/flow/harness/schema/002-story-verify.sql
skills/flow/harness/schema/003-tool-registry.sql
skills/flow/harness/schema/004-intervention.sql
skills/flow/harness/schema/005-tool-extensions.sql
skills/flow/harness/schema/009-accessed-count.sql
skills/flow/harness/schema/010-usage-event.sql
skills/flow/harness/schema/011-usage-gate-reason.sql
skills/flow/harness/schema/012-usage-ephemeral.sql
```

Highest-numbered migration: **012** (`012-usage-ephemeral.sql`). Versions 006-008 are intentionally
free (each `009-012` file's own header comment says "re-homed from 005/006/007/008"). This numbering
is confirmed correct and self-consistent by:
- `_db.py:3-4` docstring ("001-005 a faithful port... 009-012 flow-specific")
- `flow_harness.py:16-22,30-32` (`_flow_lineage_db` detects `schema_version >= 9`)
- `CHANGELOG.md:326-356` (0.17.0 entry, "P0 — schema-005 collision fixed")
- `tests/test_flow_schema_migration.sh` (asserts `sv == "5, 9, 10, 11, 12"` on fresh init) — **ran
  live, 11/11 pass**, confirming the numbering matches actual runtime behavior, not just file names.

No drift between `SKILL.md` / `docs/system-architecture.md` and the schema dir — neither file
references a schema/migration number at all (grep returned no matches).

## 2. CRITICAL-adjacent: stale schema-number references inside `harness/README.md` itself

The README's own **Backends** section (lines 16-22) and **Files** section (lines 113-117) correctly
describe the re-homing (009-012, "leaving 006-008 free"). But three other sections in the *same file*
still cite the **pre-rehome** numbers, contradicting the file's own stated ground truth:

- `skills/flow/harness/README.md:70` — `## Usage signal: accessed_count (read-only, schema 005)`
  Ground truth: accessed_count is `009-accessed-count.sql` (`009-accessed-count.sql:1`: "migration 009
  (re-homed from 005 to free version 5 for the upstream tool-extensions migration)"). **005 is now
  tool-extensions** (the kind-aware tool registry), not accessed-count. A reader who greps schema 005
  for "accessed_count" will find the wrong file.
- `skills/flow/harness/README.md:79` — `## Usage log: mechanical flight-recorder (schema 006)`
  Ground truth: the usage_event mirror is `010-usage-event.sql` (self-documented as "re-homed from
  006"). No `006-*.sql` file exists.
- `skills/flow/harness/README.md:96` — `**Closed feedback loop (schema 007).**`
  Ground truth: `gate_fail_reason` is `011-usage-gate-reason.sql` ("re-homed from 007"). No
  `007-*.sql` file exists.

Impact: these three inline citations are guidance for a future maintainer trying to locate the DDL for
a described feature; all three currently point at either the wrong migration (005 → now
tool-extensions) or a migration number that doesn't exist on disk (006, 007). This is real drift, not
stylistic — the same README explicitly documents the re-homing elsewhere but never updated these three
older section headers when the migrations were renumbered (v0.17.0, per CHANGELOG).

## 3. Dead/no-op CLI flag: `query tools --summary`

`flow_harness.py:1037` defines `--summary` on the `query tools` subparser:
```python
q4 = pqs.add_parser("tools"); q4.add_argument("--responsibility"); q4.add_argument("--json", action="store_true"); q4.add_argument("--summary", action="store_true")
```
But `cmd_query`'s `tools` branch (`flow_harness.py:395-412`) never reads `a.summary` — the only
reads in that branch are `a.responsibility`, `a.capability`, `a.status`, `a.json`. Grepping the whole
file for `a.summary` / `getattr(a, "summary"...)` shows the only real consumers are `cmd_usage`
(`flow_harness.py:682,740`, where `--summary` genuinely changes output) — `query tools --summary` has
no corresponding read anywhere.

Verified empirically (not just by inspection): registered one tool, then ran `query tools` and
`query tools --summary` against the same DB — **byte-identical stdout** in both cases. The flag is
accepted, silently parsed, and has zero effect. It is undocumented in README (which is otherwise
correct: `README.md:39` describes `query tools` flags as `[--capability <kebab>] [--status
present|missing|unknown] [--responsibility <r>]` — no `--summary` mentioned, matching that it does
nothing). Likely leftover from a copy-paste of the `usage` subparser's flag list, or an incomplete
port of a summary view.

## 4. Minor: implemented-but-undocumented flags / undocumented commands (informational, not blocking)

- `README.md`'s command table (lines 26-39) omits `init`, `rollup`, `usage`, `prune` — these four ARE
  documented in the "Usage log" prose section (lines 79-104) with accurate flag descriptions
  (`--global`, `--summary`, `--keep`), just not in the main table. No behavioral drift, just table
  incompleteness.
- `usage`'s `--json`, `--include-ephemeral`, `--builds-only` flags (`flow_harness.py:1048-1054`) and
  `query`'s `--json`/`--numeric` flags across subcommands are not enumerated in README. Consistent
  omission across the whole doc (README documents concepts, not every flag) — not treating as a
  defect, just noting for completeness.

## 5. Dead code check (functions in `_db.py`, `_domain.py`, `_presence.py`, `repo_map.py`)

Grepped every function name for call sites across `skills/flow/harness/`, `skills/flow/runner/`, and
`tests/`. **No dead functions found** — every function defined in the four files has at least one call
site outside its own definition (either from `flow_harness.py`, from within the same module, or from
`tests/test_flow_schema_migration.sh` which imports `_db` directly to test `_db.connect`/migration
healing). `repo_map.py` is a standalone CLI invoked from `skills/flow/runner/flow.sh:1499-1507`
(`ranked surfaces` step in `/flow assess`) — its usage signature (`python repo_map.py <project_root>
[top_n]`) matches the caller exactly.

## 6. TODO/FIXME/XXX sweep

No `TODO`, `FIXME`, or `XXX` comments found in `flow_harness.py`, `_db.py`, `_domain.py`,
`_presence.py`, or `repo_map.py`. Clean.

## 7. Test files vs. actual implementation

Ran all four suites live:
- `tests/test_flow_harness.sh` — 19/19 pass
- `tests/test_flow_harness_args.sh` — 6/6 pass
- `tests/test_flow_schema_migration.sh` — 11/11 pass
- `tests/test_flow_tool_registry.sh` — 19/19 pass

All function/command/flag/schema-file references inside these four test files match current code
exactly (e.g. `test_flow_schema_migration.sh:31,83,108` assert the exact version sequences
`5, 9, 10, 11, 12` and `1, 2, 3, 4, 5, 9, 10, 11, 12`, matching the schema dir listing in §1; `--card`,
`--actions_taken`, `--files_changed`, `--files_read` aliases in `test_flow_harness_args.sh` match the
argparse aliases at `flow_harness.py:988-994`). No renamed/removed symbol references found — no test
drift.

## 8. Out-of-scope observation (not part of requested file set, flagged for visibility only)

`old_flow.sh` (repo root, 2219 lines, untracked, dated 2026-07-10) sits alongside the real
`skills/flow/runner/flow.sh` (3656 lines, dated 2026-07-16) and appears to be a stale manual backup —
it still contains the pre-rehome `FLOW_HARNESS_DISABLE` wiring at old line numbers matching an older
`flow.sh` shape. Not part of the harness/ scope requested and not committed to git, so not scored as a
finding — mentioned only because it is an orphaned artifact adjacent to the reviewed area. Advisory
only: leave disposition (delete vs. keep) to the operator, since it's outside this audit's assigned
scope and I made no code changes.

## Summary of findings by severity

- **High (2):** stale schema-number citations in `harness/README.md` (lines 70, 79, 96 — 3 citations,
  1 finding class); dead/no-op `--summary` flag on `query tools` (silently accepted, zero effect,
  confirmed by live run).
- **Medium (0)**
- **Low (1):** README command table omits `init`/`rollup`/`usage`/`prune` from the main table (covered
  elsewhere in prose, so cosmetic only).
- **Informational (1):** orphaned `old_flow.sh` at repo root, out of requested scope.
- **Clean:** schema file/migration-count claims (CHANGELOG, `_db.py`, tests all agree — 012 is
  correctly the highest); no dead functions in `_db.py`/`_domain.py`/`_presence.py`/`repo_map.py`; no
  TODO/FIXME/XXX; all 4 test suites pass and reference only real, current symbols/files (55/55 checks
  green).

## Unresolved Questions

- Should the three stale schema-number citations (`README.md:70,79,96`) be corrected to 009/010/011,
  or should they be reworded to say "re-homed, see schema/009-012" to avoid needing another edit next
  re-home? Judgment call for whoever picks up the fix.
- Is `query tools --summary` intended to eventually print a compact one-line view (mirroring `usage
  --summary`), or is it dead weight to remove? No git history/CHANGELOG entry found describing intent
  for this flag specifically.

Status: DONE
Summary: 2 High (stale schema-number refs in README + dead `query tools --summary` flag), 1 Low (README table omits 4 commands, documented elsewhere), 1 informational (orphaned old_flow.sh, out of scope); 0 dead functions, 0 TODO/FIXME, 0 test drift — all 55 test assertions pass live.
