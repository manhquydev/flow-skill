#!/usr/bin/env bash
# Tests for the .agents/skills/flow/SKILL.md checked-in pointer:
# file exists, frontmatter is valid, canonical target is resolvable, and the
# checked-in copy matches `flow.sh rules agent-skills` output byte-for-byte.
# Run: bash tests/test_flow_rules_agent_skills_pointer.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
RUN="$ROOT/skills/flow/runner/flow.sh"
POINTER="$ROOT/.agents/skills/flow/SKILL.md"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }

echo "=== 1. Pointer file exists and is a regular file ==="
[ -f "$POINTER" ] && ck 0 0 "pointer file exists" || ck 1 0 "pointer file exists"

echo "=== 2. Frontmatter has name: flow and non-empty description ==="
fm_name="$(sed -n 's/^name: //p' "$POINTER" | head -1 | tr -d '\r')"
ck "flow" "$fm_name" "frontmatter name is flow"
fm_desc="$(sed -n 's/^description: //p' "$POINTER" | head -1 | tr -d '\r')"
[ -n "$fm_desc" ] && ck 0 0 "frontmatter description is non-empty" || ck 1 0 "frontmatter description is non-empty"

echo "=== 3. Canonical ../../../skills/flow/SKILL.md is resolvable from .agents/skills/flow/ ==="
canonical="$ROOT/.agents/skills/flow/../../../skills/flow/SKILL.md"
canonical_resolved="$(cd "$(dirname "$canonical")" && basename "$(realpath -- "$canonical" 2>/dev/null || echo "$canonical")")"
[ "$canonical_resolved" = "SKILL.md" ] && [ -f "$canonical" ] && ck 0 0 "canonical path resolves to skills/flow/SKILL.md" || ck 1 0 "canonical path resolves to skills/flow/SKILL.md"

echo "=== 4. Checked-in copy matches rules agent-skills output (diff empty) ==="
# Windows checkouts convert this markdown pointer to CRLF (core.autocrlf; .gitattributes
# only pins .sh/.py/.json). The generated output is always LF. Normalize \r on both
# sides before the equality check — same pattern as test_flow_widelai_packaging.sh.
actual="$(bash "$RUN" rules agent-skills 2>/dev/null | tr -d '\r')"
if [ "$actual" = "$(tr -d '\r' < "$POINTER")" ]; then
  ck 0 0 "rules agent-skills output matches checked-in pointer"
else
  ck 0 1 "rules agent-skills output matches checked-in pointer"
fi

echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
