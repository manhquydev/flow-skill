#!/usr/bin/env bash
# Language-floor guards: keep the declared compatibility floors honest.
#   - bash 3.2-safe (AGENTS.md): runner + tests must not use bash 4+ constructs
#     (mapfile, readarray, declare -A, &>>, |&).
#   - Python 3.7 floor (skills/flow/harness): harness/*.py must not use walrus,
#     match statements, or PEP 604 / builtin-generics annotations unless the
#     file opts in via `from __future__ import annotations` (then only walrus
#     and match stay forbidden).
# Run: bash tests/test_flow_floor_guards.sh
#
# Known limitations:
#   - Comments are stripped; strings/heredocs are NOT. A construct quoted
#     inside a string can be flagged; refine only if a false positive lands.
#   - `|&` is matched only when preceded by whitespace, so unspaced `cmd|&`
#     is missed — accepted to avoid flagging regex strings like '(a|&&)'.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
pass=0
fail=0
viol() { echo "  FAIL [$1:$2 $3]"; fail=$((fail + 1)); }
ok() { echo "  ok   [$1]"; pass=$((pass + 1)); }

# Emit "LINENO:content" for non-comment lines, original numbering preserved.
body() { awk '$0 !~ /^[[:space:]]*#/ { print NR ":" $0 }' "$1"; }

# Bash-4 pattern assembled from pieces so this suite's own source stays free
# of the constructs it forbids (no literal '&>>' or spaced '|&' appears here).
B4A='map''file|readar''ray|declar''e -A|&'
B4B='>>'
BASH4PAT="${B4A}${B4B}|[[:space:]][|][&]"

# bash_floor <file> <relname>
bash_floor() {
  hits=$(body "$1" | grep -E "$BASH4PAT")
  if [ -n "$hits" ]; then
    while IFS= read -r row; do
      ln=${row%%:*}
      viol "$2" "$ln" "bash-4+ construct"
    done <<HITS
$hits
HITS
  fi
}

# py_floor <file> <relname> <has_future:yes|no>
py_floor() {
  f=$1
  rel=$2
  hits=$(body "$f" | grep -E ':=')
  if [ -n "$hits" ]; then
    while IFS= read -r row; do
      ln=${row%%:*}
      viol "$rel" "$ln" "walrus :="
    done <<HITS
$hits
HITS
  fi
  hits=$(body "$f" | grep -E '^[0-9]+:[[:space:]]*match[[:space:]]+[A-Za-z_]+')
  if [ -n "$hits" ]; then
    while IFS= read -r row; do
      ln=${row%%:*}
      viol "$rel" "$ln" "match statement"
    done <<HITS
$hits
HITS
  fi
  if [ "$3" = no ]; then
    hits=$(body "$f" | grep -E 'list\[|dict\[|tuple\[|[[:space:]]\|[[:space:]](None|str)')
    if [ -n "$hits" ]; then
      while IFS= read -r row; do
        ln=${row%%:*}
        viol "$rel" "$ln" "modern annotation without __future__"
      done <<HITS
$hits
HITS
    fi
  fi
}

echo "A) Python 3.7 floor: skills/flow/harness/*.py"
npy=0
for f in "$ROOT"/skills/flow/harness/*.py; do
  [ -f "$f" ] || continue
  npy=$((npy + 1))
  rel=${f#"$ROOT"/}
  if grep -q 'from __future__ import annotations' "$f"; then
    py_floor "$f" "$rel" yes
  else
    py_floor "$f" "$rel" no
  fi
done
ok "harness/*.py scanned ($npy files)"

echo "B) bash 3.2 floor: runner/*.sh + tests/*.sh"
nsh=0
for f in "$ROOT"/skills/flow/runner/*.sh "$ROOT"/tests/*.sh; do
  [ -f "$f" ] || continue
  nsh=$((nsh + 1))
  bash_floor "$f" "${f#"$ROOT"/}"
done
ok "runner/*.sh + tests/*.sh scanned ($nsh files)"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
