#!/usr/bin/env bash
# EN/VI blob-hash gate: committed-edit mismatch names the side; record/verify;
# dirty-tree CRLF rewrite still verifies against HEAD:path.
# Run: bash tests/test_i18n_pairs.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CHECK="$ROOT/scripts/check-i18n-pairs.sh"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }

# Hasher pin: the live script must never dirty-tree hash (comments may name it).
if grep -v '^[[:space:]]*#' "$CHECK" | grep -q 'hash-object'; then
  echo "  FAIL [script must not call git hash-object]"
  fail=$((fail + 1))
else
  echo "  ok   [script hashes HEAD:path only]"
  pass=$((pass + 1))
fi

echo "A) live tree verify is green"
r=0
out="$(bash "$CHECK" 2>&1)" || r=$?
ck 0 "$r" "check-i18n-pairs verify exits 0"
printf '%s' "$out" | grep -q 'PASS: i18n pairs' && ck 0 0 "pass line" || ck 0 1 "pass line"

# Isolated git repo with one pair. Commits are required — HEAD:path is the gate.
setup_repo() {
  tmp=$(mktemp -d)
  mkdir -p "$tmp/docs" "$tmp/scripts"
  cp "$CHECK" "$tmp/scripts/"
  printf 'hello en\n' > "$tmp/README.md"
  printf 'xin chao\n' > "$tmp/README_VN.md"
  git -C "$tmp" init -q
  git -C "$tmp" config user.email t@t
  git -C "$tmp" config user.name t
  git -C "$tmp" add README.md README_VN.md
  git -C "$tmp" commit -q -m init
  en_b="$(git -C "$tmp" rev-parse HEAD:README.md)"
  vi_b="$(git -C "$tmp" rev-parse HEAD:README_VN.md)"
  printf 'README.md README_VN.md %s %s\n' "$en_b" "$vi_b" > "$tmp/docs/i18n-pairs.txt"
}

echo "B) record then verify passes"
setup_repo
# smash recorded hashes, then record from HEAD
printf 'README.md README_VN.md deadbeef cafebeef\n' > "$tmp/docs/i18n-pairs.txt"
r=0
out="$(bash "$tmp/scripts/check-i18n-pairs.sh" record README.md 2>&1)" || r=$?
ck 0 "$r" "record exits 0"
r=0
out="$(bash "$tmp/scripts/check-i18n-pairs.sh" 2>&1)" || r=$?
ck 0 "$r" "verify after record exits 0"
printf '%s' "$out" | grep -q 'PASS: i18n pairs' && ck 0 0 "verify after record pass line" || ck 0 1 "verify after record pass line"
rm -rf "$tmp"

echo "C) committed EN-only edit fails and names EN"
setup_repo
printf 'hello en edited\n' > "$tmp/README.md"
git -C "$tmp" add README.md
git -C "$tmp" commit -q -m 'en only'
r=0
out="$(bash "$tmp/scripts/check-i18n-pairs.sh" 2>&1)" || r=$?
ck 1 "$r" "EN-only committed edit exits 1"
printf '%s' "$out" | grep -q 'EN moved' && ck 0 0 "names EN side" || ck 0 1 "names EN side"
printf '%s' "$out" | grep -q 'VI moved' && ck 1 0 "must not name VI" || ck 0 0 "does not name VI"
rm -rf "$tmp"

echo "D) committed VI-only edit fails and names VI"
setup_repo
printf 'xin chao edited\n' > "$tmp/README_VN.md"
git -C "$tmp" add README_VN.md
git -C "$tmp" commit -q -m 'vi only'
r=0
out="$(bash "$tmp/scripts/check-i18n-pairs.sh" 2>&1)" || r=$?
ck 1 "$r" "VI-only committed edit exits 1"
printf '%s' "$out" | grep -q 'VI moved' && ck 0 0 "names VI side" || ck 0 1 "names VI side"
printf '%s' "$out" | grep -q 'EN moved' && ck 1 0 "must not name EN" || ck 0 0 "does not name EN"
rm -rf "$tmp"

echo "E) matching VI commit + record → verify passes"
setup_repo
printf 'hello en edited\n' > "$tmp/README.md"
git -C "$tmp" add README.md
git -C "$tmp" commit -q -m 'en only'
printf 'xin chao edited\n' > "$tmp/README_VN.md"
git -C "$tmp" add README_VN.md
git -C "$tmp" commit -q -m 'matching vi'
r=0
out="$(bash "$tmp/scripts/check-i18n-pairs.sh" record README.md 2>&1)" || r=$?
ck 0 "$r" "record after matching pair exits 0"
r=0
out="$(bash "$tmp/scripts/check-i18n-pairs.sh" 2>&1)" || r=$?
ck 0 "$r" "verify after matching record exits 0"
rm -rf "$tmp"

echo "F) dirty working-tree CRLF rewrite still verifies against HEAD:path"
setup_repo
# Rewrite listed .md to CRLF without committing. HEAD:path stays LF.
crlf_tmp="$(mktemp)"
while IFS= read -r line || [ -n "$line" ]; do
  printf '%s\r\n' "$line"
done < "$tmp/README.md" > "$crlf_tmp"
cat "$crlf_tmp" > "$tmp/README.md"
rm -f "$crlf_tmp"
# Prove the working tree is dirty-CRLF and would fool hash-object.
if grep -q $'\r' "$tmp/README.md"; then
  ck 0 0 "working tree now has CR"
else
  ck 0 1 "working tree now has CR"
fi
dirty="$(git -C "$tmp" hash-object "$tmp/README.md")"
headb="$(git -C "$tmp" rev-parse HEAD:README.md)"
[ "$dirty" != "$headb" ] && ck 0 0 "hash-object(dirty) != HEAD:path" || ck 0 1 "hash-object(dirty) != HEAD:path"
r=0
out="$(bash "$tmp/scripts/check-i18n-pairs.sh" 2>&1)" || r=$?
ck 0 "$r" "CRLF dirty tree still verifies green"
printf '%s' "$out" | grep -q 'PASS: i18n pairs' && ck 0 0 "CRLF dirty pass line" || ck 0 1 "CRLF dirty pass line"
rm -rf "$tmp"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
