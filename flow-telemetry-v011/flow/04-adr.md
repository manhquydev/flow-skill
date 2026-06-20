# Stage 04 — ADR (architecture decisions)

Short. The most valuable section is what you are NOT doing and why.

## Gate — check ALL before `/flow next`
- [x] Each decision has a one-line "why" and a one-line "what I rejected"
- [x] The NOT-doing list is written
- [x] Decisions cover: data storage, auth approach, deploy target
- [x] No FILL placeholders remain in this file

## Decisions

| # | Decision | Why | Rejected alternative |
|---|---|---|---|
| 1 | **Data storage:** keep JSONL flight-recorder + SQLite rollup; add only OPTIONAL new fields (`session_id` already exists; add `ephemeral`) | backward-compat — existing 1739-line log + per-project logs must still roll up; optional fields don't break the cursor | SQLite-WAL canonical sink (rejected: large migration, v1.0) |
| 2 | **cycle_id source:** reuse existing `CYCLE_FILE` (`$LOG_DIR/cycle_id`, format `epoch-host`); stamp it in `cmd_assess` + lazily on any command if absent | the mechanism already exists and is portable; one cycle per project dir is enough | new uuid dependency + JSON state machine (rejected: YAGNI, adds deps) |
| 3 | **Identity/"auth" approach:** auto-derive `session_id` cascade `FLOW_SESSION_ID`→`CLAUDE_CODE_SESSION_ID`→`CODEX_*`/`AGY_*`→`ppid:$PPID:host`; lock reclaim via `kill -0` + TTL | verified present: `CLAUDE_CODE_SESSION_ID` set, `kill -0` works, `tty` unusable under agent | TTY-primary (rejected: `tty`="not a tty" under agent harness); flock (rejected: absent in Git Bash) |
| 4 | **Global-log enrichment (D5/FR6):** add bounded `gate_fail_reason` (+ a couple key fields) to the single global line, truncated to keep it small | POSIX gives no atomic-append guarantee anyway; F5 shows ~1 concurrent session, so de-facto atomicity is acceptable; operator-confirmed interim | per-shard sink now (rejected: deferred to v2 unless concurrency rises) |
| 5 | **dwell metric:** compute wall-clock dwell in `cmd_usage` from existing `stage_from/stage_to`+`epoch_s`; keep old metric but relabel honestly | inputs already logged; no schema/table change; needs cycle_id (decision 2) to group | new `stage_transition` table (rejected: YAGNI, data already present) |
| 6 | **Deploy target (skill):** install into `~/.claude/skills/flow` and prove a real `flow.sh` run reaches its done-definition; bump SKILL.md version → 0.11.0 + CHANGELOG | done = installs+runs for a skill, not "tests pass" | publishing/tagging beyond local install (out of scope) |

## NOT doing in v1 (and why it's safe to skip)

- Per-shard global logs / SQLite-WAL sink — interim enrichment (decision 4) covers the need at ~1-session concurrency; revisit only if multi-session becomes common.
- New-cycle lifecycle policy beyond one-cycle-per-project — YAGNI; current dirs map cleanly to cycles.
- Retroactive backfill of `cycle_id`/`ephemeral` into the existing 1739 lines — read-time `tmp.*` filter handles old data; no destructive rewrite (safer).
- Confirming exact Codex/Antigravity session-var names — cascade falls back to PPID safely; refine when those engines actually run.
