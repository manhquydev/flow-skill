#!/usr/bin/env bash
# Language-floor guards: keep the declared compatibility floors honest.
#   - bash 3.2-safe (AGENTS.md): runner + tests must not use bash 4+ constructs
#     (mapfile, readarray, declare -A, &>>, |&).
#   - Python 3.7 floor (skills/flow/harness): harness/*.py must not use walrus,
#     match statements, or PEP 604 / builtin-generics annotations unless the
#     file opts in via `from __future__ import annotations` (then only walrus
#     and match stay forbidden).
#   - Python checks are AST-exact (python3 stdlib `ast`): any `match` subject
#     form, any builtin-generic subscript regardless of spacing (`set [int]`),
#     any PEP 604 union regardless of spacing (`int|float`), and `from
#     __future__ import annotations` is honored only as a real top-level
#     import statement (comments/docstrings never count).
# Run: bash tests/test_flow_floor_guards.sh
#
# Known limitations:
#   - Strings/heredocs are NOT parsed. A construct quoted inside a string can
#     be flagged; refine only if a false positive lands.
#   - Inline `# comment` text is stripped ONLY on lines without quote
#     characters; a construct inside a quoted string on such a line can still
#     be flagged (quote-aware stripping needs a tokenizer — refused here to
#     keep the guard dependency-free).
#   - `|&` is matched only when preceded by whitespace, so unspaced `cmd|&`
#     is missed — accepted to avoid flagging regex strings like '(a|&&)'.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
pass=0
fail=0
viol() { echo "  FAIL [$1:$2 $3]"; fail=$((fail + 1)); }
ok() { echo "  ok   [$1]"; pass=$((pass + 1)); }

# Emit "LINENO:content" for non-comment lines, original numbering preserved.
# Whole-line comments are always dropped; on lines WITHOUT quote characters a
# trailing inline `# comment` is dropped too (no quotes = nothing to protect),
# so harmless prose comments can never fail the bash floor. Lines containing
# quotes are kept intact (a real bash-4 construct inside a quoted string is
# data, but flagging it is the safer false positive, per known limitation 1).
body() { awk -v sq="'" -v dq='"' '
  {
    l = $0
    if (l ~ /^[[:space:]]*#/) next
    if (index(l, sq) == 0 && index(l, dq) == 0) sub(/[[:space:]]*#.*$/, "", l)
    print NR ":" l
  }' "$1"; }

# Bash-4 pattern assembled from pieces so this suite's own source stays free
# of the constructs it forbids (no literal '&>>' or spaced '|&' appears here).
B4A='map''file|readar''ray|declar''e -A|&'
B4B='>>'
BASH4PAT="${B4A}${B4B}|[[:space:]][|][&]"

# bash_floor <file> <relname>
bash_floor() {
  hits=$(body "$1" | grep -E "$BASH4PAT")
  if [ -n "$hits" ]; then
    while IFS= read -r row; do
      ln=${row%%:*}
      viol "$2" "$ln" "bash-4+ construct"
    done <<HITS
$hits
HITS
  fi
}

# AST-exact python floor checker (python3 stdlib only). Input: file path via
# argv. Output: one "lineno:reason" line per violation; exit 0 even when
# violations are found (bash decides pass/fail); nonzero only on crash.
#   - always forbidden: walrus (NamedExpr), match statements (ast.Match)
#   - forbidden WITHOUT `from __future__ import annotations` at module level:
#     builtin-generic subscripts (list/dict/tuple/set/frozenset/type) and
#     PEP 604 BitOr unions inside annotations
#   - honored: real top-level `from __future__ import annotations` (an
#     ImportFrom node — comments/docstrings can never create one)
PYCHECK='
import ast, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    src = f.read()
try:
    tree = ast.parse(src, filename=path)
except SyntaxError as e:
    line = e.lineno or 1
    print("%d:syntax not parseable on the py3.7 floor" % line)
    sys.exit(0)
has_future = any(
    isinstance(n, ast.ImportFrom) and n.module == "__future__"
    and any(a.name == "annotations" for a in n.names)
    for n in tree.body
)
GEN = {"list", "dict", "tuple", "set", "frozenset", "type"}
match_cls = getattr(ast, "Match", None)

def annotations_of(node):
    out = []
    if isinstance(node, ast.AnnAssign):
        out.append(node.annotation)
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        if node.returns:
            out.append(node.returns)
        a = node.args
        out += [x.annotation for x in a.posonlyargs + a.args + a.kwonlyargs if x.annotation]
        if a.vararg:
            out.append(a.vararg.annotation)
        if a.kwarg:
            out.append(a.kwarg.annotation)
    return out

def bad_annotation(ann):
    for sub in ast.walk(ann):
        if isinstance(sub, ast.Subscript) and isinstance(sub.value, ast.Name) \
                and sub.value.id in GEN:
            return True
        if isinstance(sub, ast.BinOp) and isinstance(sub.op, ast.BitOr):
            return True
    return False

for n in ast.walk(tree):
    if isinstance(n, ast.NamedExpr):
        print("%d:walrus := operator" % n.lineno)
    elif match_cls is not None and isinstance(n, match_cls):
        print("%d:match statement" % n.lineno)
    if not has_future:
        for ann in annotations_of(n):
            if ann is None:
                continue
            if bad_annotation(ann):
                line = getattr(ann, "lineno", getattr(n, "lineno", 1))
                print("%d:modern annotation (builtin generic / PEP 604 union) without __future__" % line)
'

# py_floor <file> <relname> — AST-exact; infrastructure failure (rc != 0) is
# fail-closed so a broken checker can never pass the floor vacuously.
py_floor() { # <file> <relname>
  local f=$1 rel=$2 hits rc
  if ! hits=$(python3 -c "$PYCHECK" "$f"); then
    viol "$rel" "0" "python3 floor checker infrastructure failure"
    return 1
  fi
  if [ -n "$hits" ]; then
    while IFS= read -r row; do
      ln=${row%%:*}
      viol "$rel" "$ln" "${row#*:}"
    done <<HITS
$hits
HITS
  fi
}

echo "A) Python 3.7 floor: skills/flow/harness/*.py (AST-exact)"
npy=0
for f in "$ROOT"/skills/flow/harness/*.py; do
  [ -f "$f" ] || continue
  npy=$((npy + 1))
  rel=${f#"$ROOT"/}
  py_floor "$f" "$rel"
done
ok "harness/*.py scanned ($npy files)"

echo "B) bash 3.2 floor: runner/*.sh + tests/*.sh"
nsh=0
for f in "$ROOT"/skills/flow/runner/*.sh "$ROOT"/tests/*.sh; do
  [ -f "$f" ] || continue
  nsh=$((nsh + 1))
  bash_floor "$f" "${f#"$ROOT"/}"
done
ok "runner/*.sh + tests/*.sh scanned ($nsh files)"

echo "C) AST detector fixtures: each thread-reported bypass must be flagged"
fixck() {
  if [ "$1" = "$2" ]; then
    ok "$3"
  else
    echo "  FAIL [$3] expected=$1 got=$2"
    fail=$((fail + 1))
  fi
}
tmpf=$(mktemp -d)
cat > "$tmpf/bad.py" <<'PYF'
def f() -> set [int]:
    return None
def g() -> int|float:
    return None
def h() -> type[int]:
    return None
def k() -> frozenset[int] | None:
    return None
def w():
    if (n := 1):
        pass
match (subject):
    case [1, 2]:
        pass
PYF
cat > "$tmpf/future-comment.py" <<'PYF'
# from __future__ import annotations
def s(x: set [int]) -> int|float:
    return 0
PYF
cat > "$tmpf/good.py" <<'PYF'
import os
from typing import Optional, Union
FLAGS = os.O_WRONLY | os.O_CREAT
def m(x: Optional[int]) -> Union[str, bytes]:
    return x
PYF
nbad="$(python3 -c "$PYCHECK" "$tmpf/bad.py" | wc -l)"
nfc="$(python3 -c "$PYCHECK" "$tmpf/future-comment.py" | wc -l)"
ngood="$(python3 -c "$PYCHECK" "$tmpf/good.py" | wc -l)"
fixck 6 "$nbad" "bad fixture: all 6 violation lines flagged (spaced bracket, unspaced union, frozenset/None union, type[int], walrus, match (subject))"
fixck 2 "$nfc" "comment-only future import is NOT honored (2 lines still flagged)"
fixck 0 "$ngood" "good fixture: typing.Optional/Union and UPPER_CASE OR stay clean"
rm -rf "$tmpf"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
