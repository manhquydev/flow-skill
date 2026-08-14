#!/usr/bin/env bash
# Manifest <-> disk parity and runner fail-closed on a missing listed suite.
# Run: bash tests/test_manifest_runner.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$HERE/manifest.txt"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }

# Write cleaned suite names from a manifest into $1.
clean_list() {
  : > "$1"
  [ -f "$2" ] || return 0
  while IFS= read -r suite || [ -n "$suite" ]; do
    suite="${suite%$'\r'}"
    case "$suite" in
      ''|\#*) continue ;;
    esac
    printf '%s\n' "$suite" >> "$1"
  done < "$2"
}

# Compare cleaned list vs test_*.sh in $2. Sets n_missing / n_orphan.
count_parity() {
  n_missing=0
  n_orphan=0
  local listed_file="$1"
  local disk="$2"
  local f base
  while IFS= read -r suite || [ -n "$suite" ]; do
    [ -n "$suite" ] || continue
    [ -f "$disk/$suite" ] || n_missing=$((n_missing + 1))
  done < "$listed_file"
  for f in "$disk"/test_*.sh; do
    [ -f "$f" ] || continue
    base="${f##*/}"
    grep -qxF "$base" "$listed_file" || n_orphan=$((n_orphan + 1))
  done
}

listed=$(mktemp)
clean_list "$listed" "$MANIFEST"

echo "A) live tree: every manifest entry exists on disk"
count_parity "$listed" "$HERE"
ck 0 "$n_missing" "manifest -> disk (no missing files)"

echo "B) live tree: every tests/test_*.sh is listed in the manifest"
ck 0 "$n_orphan" "disk -> manifest (no orphans)"

echo "C) synthetic: orphan on disk is detected"
tmp=$(mktemp -d)
mkdir -p "$tmp/tests"
printf 'test_a.sh\n' > "$tmp/tests/manifest.txt"
: > "$tmp/tests/test_a.sh"
: > "$tmp/tests/test_orphan.sh"
syn=$(mktemp)
clean_list "$syn" "$tmp/tests/manifest.txt"
count_parity "$syn" "$tmp/tests"
ck 0 "$n_missing" "orphan fixture has no missing"
ck 1 "$n_orphan" "orphan on disk detected"

echo "D) synthetic: missing listed suite is detected"
rm -f "$tmp/tests/test_orphan.sh"
printf 'test_a.sh\ntest_missing.sh\n' > "$tmp/tests/manifest.txt"
clean_list "$syn" "$tmp/tests/manifest.txt"
count_parity "$syn" "$tmp/tests"
ck 1 "$n_missing" "missing listed suite detected"
ck 0 "$n_orphan" "missing fixture has no orphan"
rm -rf "$tmp"
rm -f "$syn"

echo "E) runner fails when a listed suite is missing"
tmp=$(mktemp -d)
mkdir -p "$tmp/tests"
cp "$HERE/run_all.sh" "$tmp/tests/"
printf 'no_such_suite.sh\n' > "$tmp/tests/manifest.txt"
r=0
out="$(bash "$tmp/tests/run_all.sh" 2>&1)" || r=$?
ck 1 "$r" "runner exits 1 on missing listed suite"
printf '%s' "$out" | grep -q "SOME SUITES FAILED" && ck 0 0 "failed-contract string" || ck 0 1 "failed-contract string"
rm -rf "$tmp"

echo "F) runner fail-closed on empty registry"
tmp=$(mktemp -d)
mkdir -p "$tmp/tests"
cp "$HERE/run_all.sh" "$tmp/tests/"
printf '# comment only\n\n' > "$tmp/tests/manifest.txt"
r=0
out="$(bash "$tmp/tests/run_all.sh" 2>&1)" || r=$?
ck 1 "$r" "runner exits 1 on empty registry"
printf '%s' "$out" | grep -q "SOME SUITES FAILED" && ck 0 0 "empty-registry contract string" || ck 0 1 "empty-registry contract string"
rm -rf "$tmp"

echo "G) runner fail-closed on missing manifest"
tmp=$(mktemp -d)
mkdir -p "$tmp/tests"
cp "$HERE/run_all.sh" "$tmp/tests/"
r=0
out="$(bash "$tmp/tests/run_all.sh" 2>&1)" || r=$?
ck 1 "$r" "runner exits 1 on missing manifest"
printf '%s' "$out" | grep -q "SOME SUITES FAILED" && ck 0 0 "missing-manifest contract string" || ck 0 1 "missing-manifest contract string"
rm -rf "$tmp"

rm -f "$listed"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
