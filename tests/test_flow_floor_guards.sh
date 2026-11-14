#!/usr/bin/env bash
# Language-floor guards: keep the declared compatibility floors honest.
#   - bash 3.2-safe (AGENTS.md): runner + tests must not use bash 4+ constructs
#     (mapfile, readarray, declare -A, &>>, |&).
#   - Python 3.7 floor (skills/flow/harness): harness/*.py must not use walrus,
#     match statements, positional-only params, or PEP 604 / builtin-generics
#     annotations unless the file opts in via `from __future__ import annotations`
#     (then only walrus, match, and runtime generic assignments stay forbidden).
#   - Python checks are AST-exact (python3 stdlib `ast`): safe across Python
#     3.7-3.14 runtimes, any `match` subject form, positional-only parameters,
#     any builtin-generic subscript regardless of spacing (`set [int]`), any
#     PEP 604 union regardless of spacing (`int|float`), runtime generic
#     assignments (`Alias = list[int]`), and `from __future__ import annotations`
#     is honored only as a real top-level import statement.
# Run: bash tests/test_flow_floor_guards.sh
#
# Known limitations:
#   - Strings/heredocs are NOT parsed. A construct quoted inside a string can
#     be flagged; refine only if a false positive lands.
#   - Inline `# comment` text is stripped ONLY on lines without quote or
#     backslash characters; a construct inside a quoted or backslash-escaped
#     string is kept intact to prevent eating actual code.
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
# Whole-line comments are always dropped; on lines WITHOUT quote or backslash
# characters a trailing inline `# comment` is dropped too, so harmless prose
# comments cannot fail the bash floor. Lines with quotes or backslashes are
# kept intact to avoid stripping escaped `#` (e.g. `echo \# &>> output`).
body() { awk -v sq="'" -v dq='"' -v bs='\\' '
  {
    l = $0
    if (l ~ /^[[:space:]]*#/) next
    if (index(l, sq) == 0 && index(l, dq) == 0 && index(l, bs) == 0) sub(/[[:space:]]+#.*$/, "", l)
    print NR ":" l
  }' "$1"; }

# Bash-4 pattern assembled from pieces so this suite's own source stays free
# of the constructs it forbids (no literal '&>>' or spaced '|&' appears here).
B4A='map''file|readar''ray|declar''e -A|&'
B4B='>>'
BASH4PAT="${B4A}${B4B}|[[:space:]][|][&]|(local|declare|typeset)[[:space:]]+-[A-Za-z]*A"

# bash_floor <file> <relname>
bash_floor() {
  local content rc=0
  if ! content=$(body "$1"); then
    viol "$2" "0" "cannot read file"
    return 1
  fi
  hits=$(printf '%s\n' "$content" | grep -E "$BASH4PAT")
  if [ -n "$hits" ]; then
    while IFS= read -r row; do
      ln=${row%%:*}
      viol "$2" "$ln" "bash-4+ construct"
    done <<HITS
$hits
HITS
  fi
}

# AST-exact python floor checker (python3 stdlib only, runnable on py3.7-py3.14).
# Input: file path via argv. Output: one "lineno:reason" line per violation.
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
named_expr_cls = getattr(ast, "NamedExpr", None)

def annotations_of(node):
    out = []
    if isinstance(node, ast.AnnAssign):
        out.append(node.annotation)
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        if node.returns:
            out.append(node.returns)
        a = node.args
        posonly = getattr(a, "posonlyargs", [])
        out += [x.annotation for x in posonly + a.args + a.kwonlyargs if getattr(x, "annotation", None)]
        if getattr(a, "vararg", None) and getattr(a.vararg, "annotation", None):
            out.append(a.vararg.annotation)
        if getattr(a, "kwarg", None) and getattr(a.kwarg, "annotation", None):
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
    if named_expr_cls is not None and isinstance(n, named_expr_cls):
        print("%d:walrus := operator" % n.lineno)
    elif match_cls is not None and isinstance(n, match_cls):
        print("%d:match statement" % n.lineno)
    elif isinstance(n, ast.arguments) and getattr(n, "posonlyargs", []):
        first = n.posonlyargs[0]
        print("%d:positional-only parameters" % getattr(first, "lineno", 1))
    elif isinstance(n, (ast.Assign, ast.AnnAssign)) and getattr(n, "value", None):
        for sub in ast.walk(n.value):
            if isinstance(sub, ast.Subscript) and isinstance(sub.value, ast.Name) and sub.value.id in GEN:
                print("%d:runtime builtin generic subscript (fails py3.7 even with __future__)" % getattr(sub, "lineno", n.lineno))
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

echo "C) AST detector fixtures: feature-isolated test cases"
fixck() {
  if [ "$1" = "$2" ]; then
    ok "$3"
  else
    echo "  FAIL [$3] expected=$1 got=$2"
    fail=$((fail + 1))
  fi
}
tmpf=$(mktemp -d)

# 1. Annotations and runtime generic assignment (syntactically valid on Python 3.7+)
cat > "$tmpf/bad-ann.py" <<'PYF'
def f() -> set [int]:
    return None
def g() -> int|float:
    return None
def h() -> type[int]:
    return None
def k() -> frozenset[int] | None:
    return None
Alias = list[int]
AnnAlias: object = list[int]
PYF

# 2. Walrus operator (AST check on py3.8+, SyntaxError on py3.7) -> exactly 1 line
cat > "$tmpf/bad-walrus.py" <<'PYF'
def w():
    if (n := 1):
        pass
PYF

# 3. Match statement (AST check on py3.10+, SyntaxError on py3.9-) -> exactly 1 line
cat > "$tmpf/bad-match.py" <<'PYF'
match (subject):
    case [1, 2]:
        pass
PYF

# 4. Positional-only parameter (AST check on py3.8+, SyntaxError on py3.7) -> exactly 1 line
cat > "$tmpf/bad-posonly.py" <<'PYF'
def f(x, /):
    return x
PYF

# 5. Comment-only future import is not honored -> exactly 2 lines
cat > "$tmpf/future-comment.py" <<'PYF'
# from __future__ import annotations
def s(x: set [int]) -> int|float:
    return 0
PYF

# 6. Valid Python 3.7 constructs -> 0 lines
cat > "$tmpf/good.py" <<'PYF'
import os
from typing import Optional, Union
FLAGS = os.O_WRONLY | os.O_CREAT
def m(x: Optional[int]) -> Union[str, bytes]:
    return x
PYF

n_ann="$(python3 -c "$PYCHECK" "$tmpf/bad-ann.py" | wc -l | tr -d ' ')"
n_wal="$(python3 -c "$PYCHECK" "$tmpf/bad-walrus.py" | wc -l | tr -d ' ')"
n_match="$(python3 -c "$PYCHECK" "$tmpf/bad-match.py" | wc -l | tr -d ' ')"
n_pos="$(python3 -c "$PYCHECK" "$tmpf/bad-posonly.py" | wc -l | tr -d ' ')"
n_fc="$(python3 -c "$PYCHECK" "$tmpf/future-comment.py" | wc -l | tr -d ' ')"
n_good="$(python3 -c "$PYCHECK" "$tmpf/good.py" | wc -l | tr -d ' ')"

fixck 6 "$n_ann" "bad-ann fixture: all 5 modern annotations + runtime alias and annotated alias flagged"
fixck 1 "$n_wal" "bad-walrus fixture: walrus flagged across all python versions"
fixck 1 "$n_match" "bad-match fixture: match statement flagged across all python versions"
fixck 1 "$n_pos" "bad-posonly fixture: positional-only params flagged across all python versions"
fixck 2 "$n_fc" "comment-only future import is NOT honored (2 lines still flagged)"
fixck 0 "$n_good" "good fixture: typing.Optional/Union and UPPER_CASE OR stay clean"

# 7. Bash 4+ associative array variants (local -A, declare  -A)
# Pieces assembled dynamically so this suite's own source stays clean of forbidden patterns.
printf '#!/usr/bin/env bash\n%s -A items\n%s  -A map\n%s -aA complex\n' "loc""al" "dec""lare" "type""set" > "$tmpf/bad-assoc.sh"
n_assoc=$(body "$tmpf/bad-assoc.sh" | grep -cE "$BASH4PAT" | tr -d '[:space:]')
fixck 3 "$n_assoc" "bad-assoc fixture: associative array declarations detected" 
rm -rf "$tmpf"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
