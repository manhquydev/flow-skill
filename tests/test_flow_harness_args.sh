#!/usr/bin/env bash
# Regression suite for harness CLI forgiveness (Fix A): the natural flag variants real agents typed
# in the CMC/C2-App-001 logs (--actions_taken/--files_changed/--files_read/--card) must SUCCEED
# instead of silently dropping the record to argparse exit-2; a bad form must print a guiding hint.
# Run: bash tests/test_flow_harness_args.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HARNESS="$HERE/../skills/flow/harness/flow_harness.py"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }

PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ] || ! "$PY" -c 'import sqlite3' >/dev/null 2>&1; then
  echo "  skip [harness-args] (no python3 with sqlite3 — durable layer unavailable here)"
  echo "RESULT: 0 passed, 0 failed"; exit 0
fi

newsb() { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/.flow"; "$PY" "$HARNESS" init >/dev/null 2>&1; }
clean() { rm -rf "$SB"; unset FLOW_PROJECT_ROOT; }

echo "A) trace with the underscore aliases (--actions_taken/--files_changed/--files_read) -> exit 0"
newsb
"$PY" "$HARNESS" trace --summary "did work" --lane normal --actions_taken "edited" --files_changed "a.py" --files_read "c.md" --outcome completed >/dev/null 2>&1
ck 0 "$?" "underscore-variant trace succeeds (was exit-2 before)"
clean

echo "B) --card is accepted as an alias of --story -> exit 0"
newsb
"$PY" "$HARNESS" story add --id C-058 --title webhook --lane normal >/dev/null 2>&1
"$PY" "$HARNESS" trace --summary "card work" --card C-058 --outcome completed >/dev/null 2>&1
ck 0 "$?" "--card C-058 maps to --story and the trace persists"
clean

echo "C) a bad/missing-flag form prints the guiding 'common forms' hint (exit 2, not silent)"
newsb
out="$("$PY" "$HARNESS" intake "freeform with no flags" 2>&1)"; rc=$?
ck 2 "$rc" "bad form still exits 2 (argparse contract preserved)"
has "$out" "command not accepted" "non-silent: prints the guiding hint header"
has "$out" "decision add --id" "hint lists the correct common forms"
clean

echo "D) canonical hyphen forms still work (no regression)"
newsb
"$PY" "$HARNESS" trace --summary "canonical" --lane normal --actions "x" --files-changed "a.py" --files-read "b.md" --outcome completed >/dev/null 2>&1
ck 0 "$?" "canonical --files-changed/--files-read/--actions still accepted"
clean

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
