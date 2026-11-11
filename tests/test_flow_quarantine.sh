#!/usr/bin/env bash
# Tests for the flaky-suite quarantine mechanism in tests/run_all.sh.
# Covers: active quarantine skips, expired quarantine still runs, malformed
# lines still run, and empty quarantine.tsv runs everything. Uses a temp dir
# with a copy of run_all.sh + fake manifest/suites to exercise the real logic.
# Run: bash tests/test_flow_quarantine.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_ALL="$HERE/run_all.sh"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }

# make_fixture <quarantine_content> — creates a temp dir with:
#   run_all.sh (copy), manifest.txt (one fake suite), fake suite script,
#   quarantine.tsv (given content). Sets FIXTURE and FAKE_SUITE globals.
make_fixture() {
  FIXTURE="$(mktemp -d)"
  mkdir -p "$FIXTURE/tests"
  cp "$RUN_ALL" "$FIXTURE/tests/run_all.sh"
  printf 'fake_pass_suite.sh\n' > "$FIXTURE/tests/manifest.txt"
  printf '#!/usr/bin/env bash\necho "  ok   [fake suite ran]"\n' > "$FIXTURE/tests/fake_pass_suite.sh"
  chmod +x "$FIXTURE/tests/fake_pass_suite.sh"
  printf '%s\n' "$1" > "$FIXTURE/tests/quarantine.tsv"
}

now="$(date +%s)"
future=$((now + 3600))
past=$((now - 3600))

echo "=== 1. Active quarantine: suite is skipped ==="
make_fixture "$(printf '# comment\nfake_pass_suite.sh\tflaky on CI\t%s' "$future")"
out="$(cd "$FIXTURE" && bash tests/run_all.sh 2>&1)"; rc=$?
ck 0 "$rc" "run_all exits 0 when suite is quarantined (skip is not failure)"
printf '%s' "$out" | grep -q 'SKIP (quarantined until' && ck 0 0 "SKIP message present" || ck 1 0 "SKIP message present"
printf '%s' "$out" | grep -q 'fake suite ran' && ck 1 0 "quarantined suite body must NOT run" || ck 0 0 "quarantined suite body must NOT run"
rm -rf "$FIXTURE"

echo "=== 2. Expired quarantine: suite still runs (fail-closed) ==="
make_fixture "$(printf '# comment\nfake_pass_suite.sh\told flake\t%s' "$past")"
out="$(cd "$FIXTURE" && bash tests/run_all.sh 2>&1)"; rc=$?
ck 0 "$rc" "expired quarantine still exits 0"
printf '%s' "$out" | grep -q 'fake suite ran' && ck 0 0 "expired quarantine runs the suite" || ck 1 0 "expired quarantine runs the suite"
printf '%s' "$out" | grep -q 'SKIP (quarantined' && ck 1 0 "no SKIP for expired entry" || ck 0 0 "no SKIP for expired entry"
rm -rf "$FIXTURE"

echo "=== 3. Malformed lines: suite still runs (silently ignored) ==="
# Missing reason column (only 2 fields)
make_fixture "$(printf 'fake_pass_suite.sh\t%s' "$future")"
out="$(cd "$FIXTURE" && bash tests/run_all.sh 2>&1)"; rc=$?
ck 0 "$rc" "malformed (missing reason) exits 0"
printf '%s' "$out" | grep -q 'fake suite ran' && ck 0 0 "malformed (missing reason) still runs" || ck 1 0 "malformed (missing reason) still runs"
rm -rf "$FIXTURE"
# Non-numeric epoch
make_fixture "$(printf 'fake_pass_suite.sh\tflake\tnot_a_number')"
out="$(cd "$FIXTURE" && bash tests/run_all.sh 2>&1)"; rc=$?
ck 0 "$rc" "malformed (non-numeric epoch) exits 0"
printf '%s' "$out" | grep -q 'fake suite ran' && ck 0 0 "malformed (non-numeric epoch) still runs" || ck 1 0 "malformed (non-numeric epoch) still runs"
rm -rf "$FIXTURE"

echo "=== 4. Empty quarantine.tsv: everything runs ==="
make_fixture "$(printf '# only comments, no data\n')"
out="$(cd "$FIXTURE" && bash tests/run_all.sh 2>&1)"; rc=$?
ck 0 "$rc" "empty quarantine exits 0"
printf '%s' "$out" | grep -q 'fake suite ran' && ck 0 0 "empty quarantine runs the suite" || ck 1 0 "empty quarantine runs the suite"
printf '%s' "$out" | grep -q 'SKIP (quarantined' && ck 1 0 "no SKIP with empty quarantine" || ck 0 0 "no SKIP with empty quarantine"
rm -rf "$FIXTURE"

echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
