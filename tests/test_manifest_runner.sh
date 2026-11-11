#!/usr/bin/env bash
# Manifest parity, runner failures, and exact-once deterministic shard coverage.
# Run: bash tests/test_manifest_runner.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$HERE/manifest.txt"
# Runner fixtures must not inherit the CI shard running this test suite.
unset FLOW_SUITE_SHARD
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

echo "H) shard filter: default order, sorted round-robin, and failure propagation"
tmp=$(mktemp -d)
mkdir -p "$tmp/tests"
cp "$HERE/run_all.sh" "$tmp/tests/"
# Deliberately unordered, with CRLF, comments, blanks and no final newline.
printf 'test_e.sh\r\n# ignored\r\n\r\ntest_a.sh\ntest_d.sh\ntest_b.sh\ntest_c.sh' > "$tmp/tests/manifest.txt"
for suite in test_a.sh test_b.sh test_c.sh test_d.sh test_e.sh; do
  printf '%s\n' 'printf "%s\n" "${0##*/}" >> "$FLOW_SUITE_TEST_LOG"' > "$tmp/tests/$suite"
done
export FLOW_SUITE_TEST_LOG="$tmp/executed"
: > "$FLOW_SUITE_TEST_LOG"
r=0
out="$(bash "$tmp/tests/run_all.sh" 2>&1)" || r=$?
ck 0 "$r" "unset shard runs full manifest"
ck "$(printf 'test_e.sh\ntest_a.sh\ntest_d.sh\ntest_b.sh\ntest_c.sh')" "$(cat "$FLOW_SUITE_TEST_LOG")" "default preserves manifest order"
: > "$FLOW_SUITE_TEST_LOG"
r=0
out="$(FLOW_SUITE_SHARD=1/1 bash "$tmp/tests/run_all.sh" 2>&1)" || r=$?
ck 0 "$r" "single shard runs full manifest"
ck "$(printf 'test_a.sh\ntest_b.sh\ntest_c.sh\ntest_d.sh\ntest_e.sh')" "$(cat "$FLOW_SUITE_TEST_LOG")" "shard order is C-sorted"
: > "$tmp/union"
for shard in 1 2 3; do
  : > "$FLOW_SUITE_TEST_LOG"
  r=0
  out="$(FLOW_SUITE_SHARD="$shard/3" bash "$tmp/tests/run_all.sh" 2>&1)" || r=$?
  ck 0 "$r" "synthetic shard $shard/3 succeeds"
  cat "$FLOW_SUITE_TEST_LOG" >> "$tmp/union"
  case "$shard" in
    1) expected="$(printf 'test_a.sh\ntest_d.sh')" ;;
    2) expected="$(printf 'test_b.sh\ntest_e.sh')" ;;
    3) expected=test_c.sh ;;
  esac
  ck "$expected" "$(cat "$FLOW_SUITE_TEST_LOG")" "sorted round-robin shard $shard/3"
done
printf 'test_a.sh\ntest_b.sh\ntest_c.sh\ntest_d.sh\ntest_e.sh\n' > "$tmp/expected"
LC_ALL=C sort "$tmp/union" > "$tmp/actual"
r=0; cmp -s "$tmp/expected" "$tmp/actual" || r=$?
ck 0 "$r" "synthetic shards cover every suite exactly once"
printf 'test_a.sh\ntest_b.sh\ntest_c.sh\ntest_d.sh\ntest_e.sh\n' > "$tmp/tests/manifest.txt"
: > "$FLOW_SUITE_TEST_LOG"
r=0
out="$(FLOW_SUITE_SHARD=1/3 bash "$tmp/tests/run_all.sh" 2>&1)" || r=$?
ck 0 "$r" "reordered manifest shard succeeds"
ck "$(printf 'test_a.sh\ntest_d.sh')" "$(cat "$FLOW_SUITE_TEST_LOG")" "manifest order cannot change shard membership"
printf 'exit 7\n' >> "$tmp/tests/test_a.sh"
: > "$FLOW_SUITE_TEST_LOG"
r=0
out="$(FLOW_SUITE_SHARD=1/3 bash "$tmp/tests/run_all.sh" 2>&1)" || r=$?
ck 1 "$r" "selected suite failure fails shard"
ck "$(printf 'test_a.sh\ntest_d.sh')" "$(cat "$FLOW_SUITE_TEST_LOG")" "shard still runs later selected suites after failure"

echo "I) malformed and empty shards fail closed before executing suites"
for spec in '' / 1/ /3 0/3 1/0 4/3 a/3 1/b 1/2/3 -1/3 1/-3 '1 /3' 01/3 1/03 999999999999999999999999999999/3 1/999999999999999999999999999999; do
  : > "$FLOW_SUITE_TEST_LOG"
  r=0
  out="$(FLOW_SUITE_SHARD="$spec" bash "$tmp/tests/run_all.sh" 2>&1)" || r=$?
  ck 1 "$r" "invalid shard '$spec' exits 1"
  printf '%s' "$out" | grep -q 'invalid FLOW_SUITE_SHARD' && ck 0 0 "invalid shard '$spec' diagnostic" || ck 0 1 "invalid shard '$spec' diagnostic"
  ck '' "$(cat "$FLOW_SUITE_TEST_LOG")" "invalid shard '$spec' executes nothing"
done
r=0
out="$(FLOW_SUITE_SHARD=6/6 bash "$tmp/tests/run_all.sh" 2>&1)" || r=$?
ck 1 "$r" "valid range selecting no suites fails closed"
printf '%s' "$out" | grep -q 'empty suite shard' && ck 0 0 "empty shard diagnostic" || ck 0 1 "empty shard diagnostic"
rm -rf "$tmp"

echo "J) live manifest: shard union equals registry with no omissions or duplicates"
tmp=$(mktemp -d)
mkdir -p "$tmp/tests"
cp "$HERE/run_all.sh" "$MANIFEST" "$tmp/tests/"
while IFS= read -r suite || [ -n "$suite" ]; do
  printf '%s\n' 'printf "%s\n" "${0##*/}" >> "$FLOW_SUITE_TEST_LOG"' > "$tmp/tests/$suite"
done < "$listed"
export FLOW_SUITE_TEST_LOG="$tmp/union"
: > "$FLOW_SUITE_TEST_LOG"
for shard in 1 2 3; do
  r=0
  out="$(FLOW_SUITE_SHARD="$shard/3" bash "$tmp/tests/run_all.sh" 2>&1)" || r=$?
  ck 0 "$r" "live-manifest fixture shard $shard/3 succeeds"
done
LC_ALL=C sort "$listed" > "$tmp/expected"
# Independent oracle: sorted multiset equality PLUS explicit duplicate rejection.
partition_complete() {
  LC_ALL=C sort "$1" > "$tmp/actual"
  uniq -d "$tmp/actual" > "$tmp/duplicates"
  cmp -s "$tmp/expected" "$tmp/actual" && [ ! -s "$tmp/duplicates" ]
}
r=0; partition_complete "$tmp/union" || r=$?
ck 0 "$r" "sound partition: complete exact-once live manifest passes"
first=''
{
  IFS= read -r first
  cat > "$tmp/dropped"
} < "$tmp/union"
r=0; partition_complete "$tmp/dropped" || r=$?
ck 1 "$r" "hollow partition: dropping a suite fails"
cp "$tmp/union" "$tmp/duplicated"
printf '%s\n' "$first" >> "$tmp/duplicated"
r=0; partition_complete "$tmp/duplicated" || r=$?
ck 1 "$r" "hollow partition: duplicating a suite fails"
cp "$tmp/dropped" "$tmp/replaced"
IFS= read -r replacement < "$tmp/dropped"
printf '%s\n' "$replacement" >> "$tmp/replaced"
r=0; partition_complete "$tmp/replaced" || r=$?
ck 1 "$r" "hollow partition: omission plus duplicate with unchanged count fails"
rm -rf "$tmp"
unset FLOW_SUITE_TEST_LOG

rm -f "$listed"

echo "=== doc suite-count drift guard ==="
doc_count="$(grep -oE '[0-9]+ suite scripts' "$HERE/../docs/codebase-summary.md" | grep -oE '[0-9]+')"
manifest_count="$(grep -cE '^test_' "$MANIFEST")"
ck "$manifest_count" "$doc_count" "codebase-summary suite scripts count matches manifest ($manifest_count)"

rm -f "$listed"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
