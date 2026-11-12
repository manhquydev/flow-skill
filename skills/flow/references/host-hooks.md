# Host-context adapters (opt-in, operator-installed)

Flow's adapter hands a hosting agent's lifecycle events into flow's existing read-only
verbs, so a fresh session opens with real build state instead of nothing. It exists under
the ADR-0001 Addendum — *Host-fired lifecycle context adapters* (2026-10-13,
`docs/adr/0001-discipline-layer-identity.md`): operator-installed, host-invoked, advisory,
fail-open, never gate-bearing, zero tool interposition, no daemon. **Flow never registers
any hook.** You install it; you remove it; without it nothing changes.

## The honest event model

| Event | What the host does with stdout | What the adapter does |
|---|---|---|
| `SessionStart` | stdout is added to session context | Recomputes fresh authoritative `flow.sh status`, labels the source line, prints a bounded handoff. The pre-compact snapshot is only cited as a staleness reference — or used as an explicitly `STALE SOURCE`-labeled fallback when fresh computation fails. |
| `PreCompact` | **stdout is NOT injected after compaction** (per the host's own hook implementation). | Never prints. Captures one bounded snapshot of `flow.sh status` into the project's private `.flow/context-handoff/snapshot.json` (file 0600, dir 0700) so the next SessionStart can reference — or, only if fresh status fails, fall back to it with a stale warning. |

Both events exit 0 on every path (fail-open). A fresh-computation failure produces an
explicit `flow-context: WARNING ...` on stderr and — when a valid pre-compact snapshot
exists — an explicitly `STALE SOURCE`-labeled fallback instead of the fresh handoff;
with no usable snapshot there is no handoff content. A hook never blocks or alters the
host.

## Install (Claude Code)

1. Merge the `hooks` block from `skills/flow/adapter-hooks/claude-settings-snippet.json`
   into your `.claude/settings.json` (or `~/.claude/settings.json`). Adjust the command
   path to your flow skill home and **keep it quoted** so paths with spaces survive:
   `"$HOME/.claude/skills/flow/adapter-hooks/flow-context-handler"`. Direct execution of
   the launcher (it is an executable script) is equally fine.
2. If your flow skill home is non-standard, set `FLOW_SKILL_DIR` in the hook command's
   environment, quoting paths with spaces:
   `FLOW_SKILL_DIR="/opt/my flow/skills/flow" bash "$HOME/.claude/skills/flow/adapter-hooks/flow-context-handler"`
   — or rely on the launcher's home probing (`~/.claude`, `~/.codex`, `~/.agents`,
   `~/.omp/agent`).
3. Recommended `timeout` for each hook entry: **20** seconds (handler default runner bound
   is 10 s, stdin deadline 5 s; the hard maximum is 120 s via `FLOW_HOOK_TIMEOUT`).
4. Restart the session. Verify: start a session in a flow project and look for the
   `[flow context handoff - SessionStart ...]` block. Removal = delete the two hook
   entries. The adapter's only persisted artifact is its private
   `.flow/context-handoff/` directory; if you want that gone too, delete exactly that
   directory (it is owned by the adapter and read by no gate).

## Per-host support disclosure

| Host | Status | Notes |
|---|---|---|
| Claude Code | **Supported** (SessionStart, PreCompact) | Native hook surfaces; snippet provided. |
| Codex | Not supported for these events | No equivalent SessionStart/PreCompact hook surface is projected; keep the adapter uninstalled. |
| Oh My Pi (OMP) | Not claimed | OMP hook surfaces ship inactive on the observed installs; no live OMP hook registration is claimed or asserted by this feature. |
| Antigravity / agy | Not supported | No equivalent lifecycle hook surface wired. |
| Windows | Via POSIX shell only — **not verified** | Requires Git Bash + python3; `flow.cmd` is the runner's console shim, not a hook adapter. No runtime claim is made for Windows. |

Unsupported hosts are a capability disclosure, not a failure: the adapter simply stays
uninstalled and flow works exactly as before.

## Requirements and knobs

- **python3** (stdlib only). Absent or unusable → the launcher warns and exits 0; flow
  itself is unaffected. Use `/flow status` manually.
- `FLOW_SKILL_DIR` — explicit skill home (wins over home probing).
- `FLOW_HOOK_TIMEOUT` — runner bound, 1..120 s, default 10.
- `FLOW_HOOK_MAX_BYTES` — session-output cap, 1024..1048576 bytes, default 4000
  (UTF-8-safe truncation; labels included in the cap). The persisted snapshot is capped
  separately at the 1 MiB hard maximum **including JSON overhead** (the serialized
  document, not the raw body, is what is bounded).
- `FLOW_HOOK_SNAPSHOT=0` — disable the pre-compact snapshot write (fresh-only handoff).

## Safety boundaries

Verified on Linux via controlled event replay in `tests/test_flow_host_hooks.sh`:
persistence contract and modes, strict/duplicate-key/oversize payload parsing, symlink and
mode/owner refusals, cross-project snapshot refusal, byte caps, process-group timeout kill
with orphan evidence, telemetry suppression, and the inherited-`FLOW_PROJECT_ROOT` shield.
NOT exercised by this suite and therefore not claimed: wrong-owner (non-euid) refusals,
platforms lacking `O_NOFOLLOW`/`O_DIRECTORY` (there the snapshot is skipped and only
fresh-only handoff runs), and any Windows/macOS behavior.

- Sole permitted write: `.flow/context-handoff/snapshot.json` inside an **existing**
  `.flow`. `.flow` itself is never created, never chmodded; a symlinked, foreign-owned,
  group/world-writable, or non-0700 private dir is **refused, never repaired**. Local cwd
  marker behavior is unchanged; without local markers, adopt only the nearest signature
  within 24 physical ancestors: `flow/00-idea.md`, `flow/00-inspect.md`, `.flow/`, or an
  actual file `cards/C-*.md`; otherwise skip (no auto-init or arbitrary fallback).
- Snapshot reads use `O_NOFOLLOW` + `fstat` (regular file, owner, 0600) and refuse
  snapshots whose recorded project differs from the current one; strict JSON, duplicate
  keys rejected. Platforms without `O_NOFOLLOW`: snapshot refused (fresh-only handoff).
- Hook-triggered runner calls pin `FLOW_PROJECT_ROOT` to the validated payload project
  and set the runner's own `FLOW_LOG_DISABLE=1`: no telemetry, no cross-project leaks.
- The payload is parsed strictly and never eval'd; payload values, cwd, event class, and
  runner stderr are never echoed into output or warnings.
- On timeout the runner is killed by its saved process group (descendants included) and
  reaped; the event is marked as a timeout and the stale fallback applies.
