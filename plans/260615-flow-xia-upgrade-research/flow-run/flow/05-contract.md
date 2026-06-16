# Stage 05 — Interface Contract (the seam)

Project type `skill` → the seam is **commands + flags + output shapes + exit codes** (no served
web spec). Every FR maps to a command interface with shapes written before code.

## Gate — check ALL before `/flow next`
- [x] Every PRD feature maps to at least one INTERFACE below (skill: command/file)
- [x] Every interface has its INPUT and OUTPUT shapes written (cli: flags + output/exit code)
- [x] Access/effects column filled for every interface (writes/side-effects, or "none")
- [x] No FILL placeholders remain in this file

## OpenAPI / Swagger rule

N/A — non-web. The "no producer/consumer drift" equivalent is the per-type done-evidence: the
command runs on the installed skill and reaches the skill done-definition.

## Interfaces (skill: commands)

| Interface (command) | Name | Access/Effects | Input shape | Output shape |
|---|---|---|---|---|
| `bash flow.sh constitution` | `cmd_constitution` | reads `flow/constitution.md` + project files; **no writes**; NOT called by `cmd_next` | `flow/constitution.md` invariant table (see shapes) | advisory report; **exit 0** = clean or advisory-warn, **exit 1** = structural fail (leftover placeholder / missing ID), graceful skip if no constitution file |
| `bash flow.sh recall` | `cmd_recall` (extended) | **writes** `accessed_count` (UPDATE on surfaced rows); never deletes | none (reads harness DB) | recall report ordered most-reused-first; **exit 0** |
| `bash flow.sh assess` | `cmd_assess` (extended) | writes `flow/00-inspect.md` | project tree | `00-inspect.md` seeded with a **ranked surfaces** section (stdlib reference-count ranker, `harness/repo_map.py`) OR a graceful "ranking unavailable" note when python/helper absent; **exit 0** either way |

## Shared shapes (objects used by multiple interfaces)

```
constitution invariant row : ID | invariant text | applies-at (stage list) | grep-marker (optional) | rationale
exit codes (all 3)         : 0 = ok / advisory-warn ; 1 = structural gate fail ; 2 = usage error
accessed_count             : INTEGER NOT NULL DEFAULT 0, on the recall-surfaced query tables {decision, trace, backlog}
                             (story matrix is a status view, intentionally NOT reordered)
                             incremented on query/recall read; NEVER decremented or used to delete a row;
                             security-class rows (auth|authoriz|admin|tenan|payment|migrat|valid|secret|credential) sort FIRST (never deprioritized)
ranked surface             : { path, symbol_ref_count, rank } — top-N listed in 00-inspect.md
migration                  : harness/schema/005-accessed-count.sql, idempotent, bumps schema_version
```

## Feature → interface map

- **FR1** → `bash flow.sh constitution` (+ new `_templates/constitution.md`, `gate-rules.md` semantic section)
- **FR2** → `bash flow.sh recall` (+ `harness/schema/005-accessed-count.sql`, increment in `flow_harness.py`)
- **FR3** → `bash flow.sh assess` (+ optional `harness/repo_map.py`, `00-inspect.md` ranked section)
