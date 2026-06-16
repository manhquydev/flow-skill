#!/usr/bin/env bash
# Regression suite for the accessed_count read-only reuse signal (schema 005).
# Verifies: increment-on-read, most-reused-first ordering, security-class-sorts-first,
# and the load-bearing invariant that reads NEVER delete a row. Needs python; skips without it.
# Run: bash tests/test_flow_accessed_count.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HARNESS="$HERE/../skills/flow/harness/flow_harness.py"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
lt()  { if [ "$1" -lt "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] ($1 !< $2)"; fail=$((fail+1)); fi; }

py="$(command -v python || command -v python3 || true)"
if [ -z "$py" ] || ! "$py" --version >/dev/null 2>&1; then
  echo "SKIP: no python -> durable layer unavailable"; echo "RESULT: 0 passed, 0 failed"; exit 0
fi
# Pin an explicit shared --db path so the test reader and the harness open the SAME file
# (default_db_path applies OS-specific translation; reconstructing it in the test is fragile).
H() { FLOW_PROJECT_ROOT="$SB" "$py" "$HARNESS" --db "$DB" "$@"; }
dbscalar() { "$py" -c "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); print(c.execute(sys.argv[2], tuple(sys.argv[3:])).fetchone()[0])" "$DB" "$@"; }
linepos() { printf '%s\n' "$1" | grep -n "$2" | head -1 | cut -d: -f1; }
newsb() { SB="$(mktemp -d)"; DB="$SB/h.db"; }

echo "A) compile + migration 005 is idempotent + accessed_count exposed"
"$py" -m py_compile "$HARNESS"; ck 0 $? "flow_harness.py compiles"
newsb
H init >/dev/null; ck 0 $? "init applies migrations"
H init >/dev/null; ck 0 $? "init twice = idempotent (no re-ALTER error)"
H decision add --id d-1 --title "use sqlite" >/dev/null
out="$(H query decisions --json)"; has "$out" "accessed_count" "accessed_count present in decisions json"
rm -rf "$SB"

echo "B) accessed_count increments on each query read (read-only signal)"
newsb
H decision add --id d-x --title "plain decision" >/dev/null
ck "0" "$(dbscalar 'SELECT accessed_count FROM decision WHERE id=?' d-x)" "fresh row starts at 0"
H query decisions >/dev/null
H query decisions >/dev/null
ck "2" "$(dbscalar 'SELECT accessed_count FROM decision WHERE id=?' d-x)" "incremented to 2 after two reads"
rm -rf "$SB"

echo "C) most-reused-first ordering (an earlier, more-read decision sorts above a late one)"
newsb
H decision add --id d-first --title "early decision" >/dev/null
H query decisions >/dev/null; H query decisions >/dev/null; H query decisions >/dev/null
H decision add --id d-late --title "late decision" >/dev/null
out="$(H query decisions)"
lt "$(linepos "$out" 'd-first')" "$(linepos "$out" 'd-late')" "higher-reuse decision sorts first"
rm -rf "$SB"

echo "D) reads NEVER delete a row (the load-bearing no-prune invariant)"
newsb
H decision add --id d-1 --title "one" >/dev/null
H decision add --id d-2 --title "two" >/dev/null
for i in 1 2 3 4 5; do H query decisions >/dev/null; done
ck "2" "$(dbscalar 'SELECT COUNT(*) FROM decision')" "still 2 rows after 5 reads - nothing pruned"
rm -rf "$SB"

echo "E) security-class row sorts FIRST despite a low access count (never deprioritized)"
newsb
H decision add --id d-plain --title "plain ui tweak" >/dev/null
for i in 1 2 3 4 5; do H query decisions >/dev/null; done   # d-plain reaches count 5
H decision add --id d-sec --title "auth token rotation policy" >/dev/null   # count 0, security-class
out="$(H query decisions)"
lt "$(linepos "$out" 'd-sec')" "$(linepos "$out" 'd-plain')" "security-class (count 0) outranks plain (count 5)"
rm -rf "$SB"

echo "F) friction (trace) reads also increment + are read-only"
newsb
H trace --summary t1 --friction "some recurring friction here" --lane tiny >/dev/null
H query friction >/dev/null
H query friction >/dev/null
ck "2" "$(dbscalar 'SELECT accessed_count FROM trace')" "trace friction reads increment accessed_count"
ck "1" "$(dbscalar 'SELECT COUNT(*) FROM trace')" "trace row not deleted by reads"
rm -rf "$SB"

echo "G) expanded security terms (jwt/token/login) also sort first despite low count"
newsb
H decision add --id d-plain --title "homepage copy wording" >/dev/null
for i in 1 2 3 4 5; do H query decisions >/dev/null; done   # d-plain count 5
H decision add --id d-jwt --title "JWT signing key rotation" >/dev/null   # count 0, jwt term
out="$(H query decisions)"
lt "$(linepos "$out" 'd-jwt')" "$(linepos "$out" 'd-plain')" "jwt-class decision (count 0) sorts above plain (count 5)"
rm -rf "$SB"

# NOTE: the read-only-DB best-effort path (_touch_accessed swallows a write error so the query
# still returns) is not unit-tested here: making sqlite reliably read-only across Git Bash +
# native Windows python is flaky (chmod vs ACLs). The guard is a try/except by design.

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
