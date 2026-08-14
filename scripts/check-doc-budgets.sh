#!/usr/bin/env bash
# Compare wc -w of listed docs against docs/doc-budgets.txt. Exit 1 on breach.
# bash-3.2-safe. From repo root: bash scripts/check-doc-budgets.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/docs/doc-budgets.txt"
rc=0
n=0

[ -f "$MANIFEST" ] || { echo "FAIL: missing $MANIFEST" >&2; exit 1; }

# CLAUDE.md must resolve to AGENTS.md (symlink) or be a stub that names it.
# Windows/core.symlinks=false may materialize a text file whose contents are the
# target name; that still names AGENTS.md and is accepted.
claude="$ROOT/CLAUDE.md"
agents="$ROOT/AGENTS.md"
if [ ! -e "$claude" ]; then
  echo "FAIL: missing $claude" >&2
  rc=1
elif [ -L "$claude" ]; then
  target="$(readlink "$claude")"
  case "$target" in
    AGENTS.md|./AGENTS.md) ;;
    *) echo "FAIL: CLAUDE.md symlink target is $target (want AGENTS.md)" >&2; rc=1 ;;
  esac
elif ! grep -q 'AGENTS.md' "$claude" 2>/dev/null; then
  echo "FAIL: CLAUDE.md is not a symlink and does not name AGENTS.md" >&2
  rc=1
fi
[ -f "$agents" ] || { echo "FAIL: missing $agents" >&2; rc=1; }

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in
    ''|\#*) continue ;;
  esac
  path="${line%% *}"
  max="${line##* }"
  case "$max" in
    ''|*[!0-9]*) echo "FAIL: bad budget line: $line" >&2; rc=1; continue ;;
  esac
  n=$((n + 1))
  if [ ! -f "$ROOT/$path" ]; then
    echo "FAIL: missing $path" >&2
    rc=1
    continue
  fi
  words="$(wc -w < "$ROOT/$path" | tr -d '[:space:]')"
  if [ "$words" -gt "$max" ]; then
    echo "FAIL: $path is $words words (budget $max)" >&2
    rc=1
  else
    echo "OK: $path $words / $max"
  fi
done < "$MANIFEST"

if [ "$n" -eq 0 ]; then
  echo "FAIL: empty doc-budgets manifest" >&2
  exit 1
fi
if [ "$rc" -eq 0 ]; then
  echo "PASS: doc budgets ($n files)"
fi
exit "$rc"
