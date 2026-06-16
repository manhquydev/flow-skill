#!/usr/bin/env python3
"""Reference-count repo-map: rank source files by how widely the symbols they DEFINE are
referenced across the codebase (Aider's ranking idea, stdlib-only — no tree-sitter dependency,
so it runs anywhere python 3 does). Best-effort: prints nothing and exits 0 when there is nothing
rankable, so the caller (flow.sh assess) falls back to its flat scan.

Usage: python repo_map.py <project_root> [top_n]
"""
import os
import re
import sys
from collections import Counter

SKIP_DIRS = {".git", "node_modules", ".flow", "plans", "dist", "build", "__pycache__",
             ".venv", "venv", "vendor", ".idea", ".vscode", "target", "coverage", "cards",
             "tests", "test", "spec", "__tests__", "e2e"}
EXTS = {".py", ".js", ".ts", ".tsx", ".jsx", ".go", ".rs", ".sh", ".rb", ".java", ".kt"}
MAX_BYTES = 512 * 1024  # skip very large files (binary-adjacent / generated) to bound memory + time
# generic identifiers that carry no "this file is important" signal even when frequent
STOPWORDS = {"main", "init", "name", "self", "this", "data", "value", "values", "item", "items",
             "list", "index", "test", "tests", "args", "kwargs", "result", "results", "error",
             "get", "set", "run", "make", "type", "config", "setup", "build", "parse", "func"}
WORD = re.compile(r"[A-Za-z_]\w+")
DEF_PATTERNS = [
    re.compile(r"^\s*(?:async\s+)?def\s+([A-Za-z_]\w+)"),                    # python
    re.compile(r"^\s*class\s+([A-Za-z_]\w+)"),                              # python/js/ts/java/kt
    re.compile(r"^\s*(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_]\w+)"),  # js/ts
    re.compile(r"^\s*(?:export\s+)?const\s+([A-Za-z_]\w+)\s*(?::[^=]+)?="),  # js/ts (incl. typed arrows: const x: T = )
    re.compile(r"^\s*func\s+([A-Za-z_]\w+)"),                               # go
    re.compile(r"^\s*(?:pub\s+)?fn\s+([A-Za-z_]\w+)"),                      # rust
    re.compile(r"^\s*(?:pub\s+)?struct\s+([A-Za-z_]\w+)"),                  # rust
    re.compile(r"^\s*([A-Za-z_]\w+)\s*\(\)\s*\{"),                          # shell  name() {
]


def iter_files(root):
    # os.walk does NOT follow symlinks by default (no symlink-loop risk).
    for dp, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith(".")]
        for fn in files:
            if os.path.splitext(fn)[1] in EXTS:
                yield os.path.join(dp, fn)


def _defs_in(lines):
    syms = set()
    for ln in lines:
        for pat in DEF_PATTERNS:
            m = pat.match(ln)
            if m:
                name = m.group(1)
                if len(name) >= 4 and name.lower() not in STOPWORDS:
                    syms.add(name)
    return syms


def main(argv):
    root = argv[1] if len(argv) > 1 else "."
    top_n = int(argv[2]) if len(argv) > 2 else 10
    files = list(iter_files(root))
    if not files:
        return 0
    defs, def_files, freq = {}, Counter(), Counter()
    for f in files:
        try:
            if os.path.getsize(f) > MAX_BYTES:
                continue
            with open(f, "r", encoding="utf-8", errors="ignore") as fh:
                lines = fh.read().splitlines()
        except OSError:
            continue
        syms = _defs_in(lines)
        defs[f] = syms
        for s in syms:
            def_files[s] += 1
        freq.update(WORD.findall("\n".join(lines)))   # tokenize ONCE per file (O(corpus) total)
    ranked = []
    for f in files:
        # only symbols UNIQUELY defined in this file score it — a name defined in many files
        # (utils, helper) is ambiguous and would give every definer the same inflated count.
        uniq = [s for s in defs.get(f, ()) if def_files[s] == 1]
        score = sum(max(0, freq.get(s, 0) - 1) for s in uniq)   # minus the definition itself
        if score > 0:
            top = sorted(uniq, key=lambda s: -freq.get(s, 0))[:3]
            ranked.append((score, os.path.relpath(f, root).replace("\\", "/"), top))
    ranked.sort(key=lambda x: (-x[0], x[1]))
    for i, (score, rel, top) in enumerate(ranked[:top_n], 1):
        print(f"{i}. {rel}  (score {score}; {', '.join(top)})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
