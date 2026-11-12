#!/usr/bin/env bash
# Run every /flow test suite. Exit 0 only if all pass. Run: bash tests/run_all.sh
# Prints per-suite wall-clock seconds so CI timeouts can be diagnosed (Windows vs Linux).
# Suite registry: tests/manifest.txt (one filename per line; # comments / blanks skipped).
# Opt in with FLOW_SUITE_SHARD=i/n (1-based): C-sorted suites, round-robin.
# Unset preserves the manifest's serial order; explicitly empty is invalid.
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
shard_i=0
shard_n=1
if [ "${FLOW_SUITE_SHARD+x}" = x ]; then
  if [[ "$FLOW_SUITE_SHARD" =~ ^([1-9][0-9]*)/([1-9][0-9]*)$ ]]; then
    shard_i="${BASH_REMATCH[1]}"
    shard_n="${BASH_REMATCH[2]}"
  fi
  # test also rejects integers outside the shell's supported numeric range.
  if [ "$shard_i" = 0 ] || ! [ "$shard_i" -le "$shard_n" ] 2>/dev/null; then
    echo "invalid FLOW_SUITE_SHARD='$FLOW_SUITE_SHARD': expected i/n with 1 <= i <= n" >&2
    echo "SOME SUITES FAILED"
    exit 1
  fi
fi

suite_list() {
  while IFS= read -r suite || [ -n "$suite" ]; do
    suite="${suite%$'\r'}"
    case "$suite" in
      ''|\#*) continue ;;
    esac
    printf '%s\n' "$suite"
  done < "$MANIFEST"
}

suite_inputs() {
  if [ "$shard_i" -eq 0 ]; then
    suite_list
  else
    suite_list | LC_ALL=C sort
  fi
}
ordinal=0
total_t0=$(date +%s 2>/dev/null || echo 0)
while IFS= read -r suite || [ -n "$suite" ]; do
  ordinal=$((ordinal + 1))
  if [ "$shard_i" -ne 0 ] && [ "$(((ordinal - 1) % shard_n + 1))" -ne "$shard_i" ]; then
    continue
  fi
  n=$((n + 1))
  echo "==================== $suite ===================="
  t0=$(date +%s 2>/dev/null || echo 0)
  bash "$HERE/$suite" || rc=1
  t1=$(date +%s 2>/dev/null || echo 0)
  if [ "$t0" != 0 ] && [ "$t1" != 0 ]; then
    echo "---- $suite wall_s=$((t1 - t0)) ----"
  fi
  echo
done < <(suite_inputs)
if [ "$n" -eq 0 ]; then
  if [ "$shard_i" -ne 0 ] && [ "$ordinal" -ne 0 ]; then
    echo "empty suite shard: FLOW_SUITE_SHARD='$FLOW_SUITE_SHARD' ($ordinal registered suites)" >&2
  else
    echo "empty suite registry: $MANIFEST" >&2
  fi
  echo "SOME SUITES FAILED"
  exit 1
fi
total_t1=$(date +%s 2>/dev/null || echo 0)
if [ "$total_t0" != 0 ] && [ "$total_t1" != 0 ]; then
  echo "TOTAL wall_s=$((total_t1 - total_t0))"
fi
if [ "$rc" -eq 0 ]; then echo "ALL SUITES PASSED"; else echo "SOME SUITES FAILED"; fi
exit $rc
