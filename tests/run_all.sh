#!/usr/bin/env bash
# Run every /flow test suite. Exit 0 only if all pass. Run: bash tests/run_all.sh
# Prints per-suite wall-clock seconds so CI timeouts can be diagnosed (Windows vs Linux).
# Suite registry: tests/manifest.txt (one filename per line; # comments / blanks skipped).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$HERE/manifest.txt"
rc=0
n=0
if [ ! -f "$MANIFEST" ]; then
  echo "missing suite manifest: $MANIFEST" >&2
  echo "SOME SUITES FAILED"
  exit 1
fi
total_t0=$(date +%s 2>/dev/null || echo 0)
while IFS= read -r suite || [ -n "$suite" ]; do
  suite="${suite%$'\r'}"
  case "$suite" in
    ''|\#*) continue ;;
  esac
  n=$((n + 1))
  echo "==================== $suite ===================="
  t0=$(date +%s 2>/dev/null || echo 0)
  bash "$HERE/$suite" || rc=1
  t1=$(date +%s 2>/dev/null || echo 0)
  if [ "$t0" != 0 ] && [ "$t1" != 0 ]; then
    echo "---- $suite wall_s=$((t1 - t0)) ----"
  fi
  echo
done < "$MANIFEST"
if [ "$n" -eq 0 ]; then
  echo "empty suite registry: $MANIFEST" >&2
  echo "SOME SUITES FAILED"
  exit 1
fi
total_t1=$(date +%s 2>/dev/null || echo 0)
if [ "$total_t0" != 0 ] && [ "$total_t1" != 0 ]; then
  echo "TOTAL wall_s=$((total_t1 - total_t0))"
fi
if [ "$rc" -eq 0 ]; then echo "ALL SUITES PASSED"; else echo "SOME SUITES FAILED"; fi
exit $rc
