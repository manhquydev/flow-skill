#!/usr/bin/env bash
# Fail if EN/VI docs trees drift from website/slugs.txt.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLUGS="$ROOT/slugs.txt"
EN_ROOT="$ROOT/src/content/docs/docs"
VI_ROOT="$ROOT/src/content/docs/vi/docs"

fail() { echo "parity: $*" >&2; exit 1; }

[[ -f "$SLUGS" ]] || fail "missing slugs.txt"
mapfile -t WANT < <(grep -v '^[[:space:]]*$' "$SLUGS")
[[ ${#WANT[@]} -eq 13 ]] || fail "slugs.txt must have exactly 13 non-empty lines (got ${#WANT[@]})"

en_files=()
vi_files=()
while IFS= read -r -d '' f; do en_files+=("${f#"$EN_ROOT"/}"); done < <(find "$EN_ROOT" -name '*.md' -print0 | sort -z)
while IFS= read -r -d '' f; do vi_files+=("${f#"$VI_ROOT"/}"); done < <(find "$VI_ROOT" -name '*.md' -print0 | sort -z)

expect_extra="index.md"

slug_ok() {
  local slug="$1"
  local extra="$2"
  local -n files=$3
  local found=0
  for f in "${files[@]}"; do
    if [[ "$f" == "$slug.md" ]]; then found=1; break; fi
  done
  [[ $found -eq 1 ]] || fail "missing $extra $slug.md"
}

for slug in "${WANT[@]}"; do
  slug_ok "$slug" "EN" en_files
  slug_ok "$slug" "VI" vi_files
done

en_extra=0
vi_extra=0
for f in "${en_files[@]}"; do
  if [[ "$f" == "$expect_extra" ]]; then continue; fi
  ok=0
  for slug in "${WANT[@]}"; do
    [[ "$f" == "$slug.md" ]] && { ok=1; break; }
  done
  [[ $ok -eq 1 ]] || fail "extra EN file $f"
done
for f in "${vi_files[@]}"; do
  if [[ "$f" == "$expect_extra" ]]; then continue; fi
  ok=0
  for slug in "${WANT[@]}"; do
    [[ "$f" == "$slug.md" ]] && { ok=1; break; }
  done
  [[ $ok -eq 1 ]] || fail "extra VI file $f"
done

[[ -f "$EN_ROOT/index.md" ]] || fail "missing EN docs index.md"
[[ -f "$VI_ROOT/index.md" ]] || fail "missing VI docs index.md"

body_after_yaml() {
  python3 - "$1" <<'PY'
import sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
if not text.startswith("---"):
    sys.stdout.write(text)
    raise SystemExit
end = text.find("\n---", 3)
if end == -1:
    sys.stdout.write(text)
    raise SystemExit
sys.stdout.write(text[end + 4 :])
PY
}

while IFS= read -r -d '' vf; do
  rel="${vf#"$VI_ROOT"/}"
  ef="$EN_ROOT/$rel"
  [[ -f "$ef" ]] || fail "VI $rel has no EN sibling"
  grep -q 'lang: vi' "$vf" || fail "$rel frontmatter missing literal lang: vi"
  vb="$(body_after_yaml "$vf")"
  eb="$(body_after_yaml "$ef")"
  [[ "$vb" != "$eb" ]] || fail "$rel VI body is byte-identical to EN"
done < <(find "$VI_ROOT" -name '*.md' -print0)

echo "parity: ok (${#WANT[@]} slugs + index.md × 2)"
