# Playbook: JSONL telemetry + tests on Windows Git Bash (shell writer / Python reader)

## When to use this
Any card that writes a JSONL/log file from POSIX shell (`flow.sh`) and reads or rolls it up
from Python (`flow_harness.py`), OR any test that seeds a home-relative / temp-relative path
and must run on Git Bash for Windows as well as macOS/Linux. The whole usage-log subsystem.

## ⚠️ THE GOTCHA (this breaks first)
**Bash `$HOME` and Python `os.path.expanduser("~")` resolve to DIFFERENT directories on
Windows.** Git Bash honors `$HOME`; Python on Windows uses `USERPROFILE` (then `HOMEDRIVE`+
`HOMEPATH`). So a test that does `export HOME="$SB/home"` and writes the device-global log
with the shell, then reads it with `python ... usage --global`, silently reads the REAL
`C:\Users\<you>\.claude\flow\usage.jsonl` instead of the sandbox — the test passes against
production data or "finds nothing," and you chase a ghost.

**Fix in tests:** set BOTH for any home-relative Python path:
```sh
export HOME="$SB/home"; export USERPROFILE="$SB/home"
```

## Second gotcha — temp-dir path forms don't match
`$ROOT`/`$PWD` in Git Bash are POSIX (`/c/Users/.../Temp/proj`) but `$TEMP`/`$TMP` are
Windows native (`C:\Users\...\Temp`). A naive `case "$ROOT" in "$TEMP"/*)` NEVER matches on
Windows. Normalize both sides before comparing: backslash→slash, lowercase (Windows is
case-insensitive), and `C:/`→`/c/`:
```sh
_norm_path() { printf '%s' "${1:-}" | tr 'A-Z\\' 'a-z/' | sed -E 's#^([a-z]):/#/\1/#'; }
```
Belt-and-suspenders: also match an mktemp-style basename (`tmp.*`) and a read-time SQL
`project LIKE 'tmp.%'` — the name convention catches what path math misses.

## Third gotcha — there is NO atomic append for regular files
POSIX guarantees atomic writes only for **pipes** ≤ `PIPE_BUF`, NOT regular files. "Keep the
line small so the append is atomic" is folklore for files. And **`flock` is absent in Git
Bash for Windows** (verified) — don't reach for it. For a single-session-per-project tool the
de-facto small-write append is fine; if you ever need real device-wide concurrency, shard the
sink per-process/day and merge at read time (no lock needed). Keep JSON lines small and
strip control chars (`tr -d '\000-\037'`) so one bad field can't corrupt a line the reader
then skips.

## Smoke tests (run before trusting telemetry on Windows)
```sh
# 1) shell writer and python reader agree on the global path
export HOME="$PWD/sb/home"; export USERPROFILE="$PWD/sb/home"; mkdir -p "$PWD/sb/home/.claude/flow"
python -c "import os;print(os.path.join(os.path.expanduser('~'),'.claude','flow','usage.jsonl'))"
#   -> must print a path UNDER $PWD/sb/home, not C:\Users\<you>\...

# 2) a project under $TEMP is detected ephemeral (path branch, non-tmp.* name)
P="${TEMP}/realbuild_$$"; mkdir -p "$P"
FLOW_PROJECT_ROOT="$P" bash runner/flow.sh status >/dev/null 2>&1
grep -o '"ephemeral":[01]' "$P/.flow/events.jsonl" | tail -1   # -> "ephemeral":1
```

## Provenance
flow-skill v0.11.0 usage-log telemetry correctness (2026-06-20). Gotchas 1+2 cost real test
debugging in cards C-001/C-004; gotcha 3 corrected a wrong code comment about PIPE_BUF and
killed the flock approach after verifying flock is missing on this Git Bash.
