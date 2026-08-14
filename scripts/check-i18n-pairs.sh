#!/usr/bin/env bash
# check-i18n-pairs.sh — verify or record EN/VI committed-blob hashes.
#
# Usage (from repo root, or any cwd; ROOT is this script's parent):
#   bash scripts/check-i18n-pairs.sh              # verify (default)
#   bash scripts/check-i18n-pairs.sh verify
#   bash scripts/check-i18n-pairs.sh record <en_path>
#
# Record refresh flow (do this after a confirmed-consistent pair edit):
#   1. Edit BOTH sides so they describe the same content.
#   2. Commit the pair. record hashes HEAD blobs, never the working tree.
#   3. bash scripts/check-i18n-pairs.sh record <en_path>
#   4. Commit the updated docs/i18n-pairs.txt.
#
# Hashing: `git rev-parse HEAD:<path>` only. Never `git hash-object` /
# `git hash-object --path` — those hash a dirty working tree, and
# `.gitattributes` leaves `*.md` to the platform default (CRLF trap).
# Dirty-tree edits are invisible to verify until commit (CI sees HEAD).
#
# bash-3.2-safe. Zero deps beyond git.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/docs/i18n-pairs.txt"
cd "$ROOT" || exit 2

usage() {
  echo "usage: check-i18n-pairs.sh [verify] | record <en_path>" >&2
  exit 2
}

# Print the committed blob for $1 (repo-relative path). Empty + exit 1 if missing.
head_blob() {
  git -C "$ROOT" rev-parse --verify --quiet "HEAD:$1" 2>/dev/null
}

# Split a pair line into en_path vi_path en_blob vi_blob. Returns 1 if not 4 fields.
parse_pair() {
  en_path=; vi_path=; rec_en=; rec_vi=
  set -f
  # word-split; paths and hashes have no spaces
  # shellcheck disable=SC2086
  set -- $1
  set +f
  [ "$#" -eq 4 ] || return 1
  en_path="$1"
  vi_path="$2"
  rec_en="$3"
  rec_vi="$4"
}

mode="${1:-verify}"
case "$mode" in
  verify) ;;
  record)
    [ -n "${2:-}" ] || usage
    [ -z "${3:-}" ] || usage
    ;;
  *) usage ;;
esac

[ -f "$MANIFEST" ] || { echo "FAIL: missing $MANIFEST" >&2; exit 1; }

if [ "$mode" = "record" ]; then
  want="$2"
  found=0
  tmpf="$(mktemp)"
  while IFS= read -r line || [ -n "$line" ]; do
    stripped="${line%$'\r'}"
    case "$stripped" in
      ''|\#*) printf '%s\n' "$line" >> "$tmpf"; continue ;;
    esac
    if ! parse_pair "$stripped"; then
      echo "FAIL: bad pair line: $stripped" >&2
      rm -f "$tmpf"
      exit 1
    fi
    if [ "$en_path" = "$want" ]; then
      new_en="$(head_blob "$en_path")" || new_en=
      new_vi="$(head_blob "$vi_path")" || new_vi=
      if [ -z "$new_en" ]; then
        echo "FAIL: no committed blob for $en_path (HEAD:$en_path)" >&2
        rm -f "$tmpf"
        exit 1
      fi
      if [ -z "$new_vi" ]; then
        echo "FAIL: no committed blob for $vi_path (HEAD:$vi_path)" >&2
        rm -f "$tmpf"
        exit 1
      fi
      printf '%s %s %s %s\n' "$en_path" "$vi_path" "$new_en" "$new_vi" >> "$tmpf"
      echo "OK: recorded $en_path $vi_path EN=$new_en VI=$new_vi"
      found=1
    else
      printf '%s\n' "$line" >> "$tmpf"
    fi
  done < "$MANIFEST"
  if [ "$found" -eq 0 ]; then
    echo "FAIL: no pair with en_path=$want" >&2
    rm -f "$tmpf"
    exit 1
  fi
  cat "$tmpf" > "$MANIFEST"
  rm -f "$tmpf"
  exit 0
fi

# verify
rc=0
n=0
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in
    ''|\#*) continue ;;
  esac
  if ! parse_pair "$line"; then
    echo "FAIL: bad pair line: $line" >&2
    rc=1
    continue
  fi
  n=$((n + 1))
  cur_en="$(head_blob "$en_path")" || cur_en=
  cur_vi="$(head_blob "$vi_path")" || cur_vi=
  if [ -z "$cur_en" ]; then
    echo "FAIL: no committed blob for $en_path (HEAD:$en_path)" >&2
    rc=1
    continue
  fi
  if [ -z "$cur_vi" ]; then
    echo "FAIL: no committed blob for $vi_path (HEAD:$vi_path)" >&2
    rc=1
    continue
  fi
  en_ok=0
  vi_ok=0
  [ "$cur_en" = "$rec_en" ] && en_ok=1
  [ "$cur_vi" = "$rec_vi" ] && vi_ok=1
  if [ "$en_ok" -eq 1 ] && [ "$vi_ok" -eq 1 ]; then
    echo "OK: $en_path <-> $vi_path"
  elif [ "$en_ok" -eq 0 ] && [ "$vi_ok" -eq 1 ]; then
    echo "FAIL: $en_path EN moved (HEAD=$cur_en recorded=$rec_en)" >&2
    rc=1
  elif [ "$en_ok" -eq 1 ] && [ "$vi_ok" -eq 0 ]; then
    echo "FAIL: $vi_path VI moved (HEAD=$cur_vi recorded=$rec_vi)" >&2
    rc=1
  else
    echo "FAIL: $en_path both sides moved (EN HEAD=$cur_en recorded=$rec_en; VI HEAD=$cur_vi recorded=$rec_vi)" >&2
    rc=1
  fi
done < "$MANIFEST"

if [ "$n" -eq 0 ]; then
  echo "FAIL: empty i18n-pairs manifest" >&2
  exit 1
fi
if [ "$rc" -eq 0 ]; then
  echo "PASS: i18n pairs ($n)"
fi
exit "$rc"
