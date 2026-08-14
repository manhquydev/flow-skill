#!/usr/bin/env bash
# Word-budget gate: live tree passes; a temp breach fails; CLAUDE.md names AGENTS.md.
# Run: bash tests/test_doc_budgets.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CHECK="$ROOT/scripts/check-doc-budgets.sh"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }

echo "A) live tree is under budget"
r=0
out="$(bash "$CHECK" 2>&1)" || r=$?
ck 0 "$r" "check-doc-budgets exits 0 on the repo"
printf '%s' "$out" | grep -q 'PASS: doc budgets' && ck 0 0 "pass line" || ck 0 1 "pass line"

echo "B) temp breach fails (not a vacuous OK)"
tmp=$(mktemp -d)
mkdir -p "$tmp/scripts" "$tmp/docs"
cp "$CHECK" "$tmp/scripts/"
printf 'AGENTS.md 5\n' > "$tmp/docs/doc-budgets.txt"
printf 'one two three four five six seven\n' > "$tmp/AGENTS.md"
printf 'See AGENTS.md\n' > "$tmp/CLAUDE.md"
r=0
out="$(bash "$tmp/scripts/check-doc-budgets.sh" 2>&1)" || r=$?
ck 1 "$r" "over-budget file exits 1"
printf '%s' "$out" | grep -q 'AGENTS.md is 7 words (budget 5)' && ck 0 0 "names the breach" || ck 0 1 "names the breach"
rm -rf "$tmp"

echo "C) empty budget manifest fails"
tmp=$(mktemp -d)
mkdir -p "$tmp/scripts" "$tmp/docs"
cp "$CHECK" "$tmp/scripts/"
printf '# comments only\n\n' > "$tmp/docs/doc-budgets.txt"
printf 'ok\n' > "$tmp/AGENTS.md"
printf 'See AGENTS.md\n' > "$tmp/CLAUDE.md"
r=0
out="$(bash "$tmp/scripts/check-doc-budgets.sh" 2>&1)" || r=$?
ck 1 "$r" "empty registry exits 1"
printf '%s' "$out" | grep -q 'empty doc-budgets manifest' && ck 0 0 "empty-manifest message" || ck 0 1 "empty-manifest message"
rm -rf "$tmp"

echo "D) CLAUDE.md must name AGENTS.md"
if [ -L "$ROOT/CLAUDE.md" ]; then
  t="$(readlink "$ROOT/CLAUDE.md")"
  case "$t" in
    AGENTS.md|./AGENTS.md) ck 0 0 "root CLAUDE.md symlink -> AGENTS.md" ;;
    *) ck 0 1 "root CLAUDE.md symlink -> AGENTS.md (got $t)" ;;
  esac
elif grep -q 'AGENTS.md' "$ROOT/CLAUDE.md" 2>/dev/null; then
  ck 0 0 "root CLAUDE.md stub names AGENTS.md"
else
  ck 0 1 "root CLAUDE.md names AGENTS.md"
fi
# Law file is a different home — this suite must not require editing it.
[ -f "$ROOT/skills/flow/law/CLAUDE.md" ] && ck 0 0 "law/CLAUDE.md left in place" || ck 0 1 "law/CLAUDE.md left in place"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
