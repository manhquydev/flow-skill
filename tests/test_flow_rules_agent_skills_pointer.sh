#!/usr/bin/env bash
# Tests for the .agents/skills/flow/SKILL.md checked-in pointer:
# file exists, frontmatter is valid, canonical target is resolvable, and the
# checked-in copy matches `flow.sh rules agent-skills` output byte-for-byte
# (including trailing newline; CRLF stripped for Windows checkouts).
# Run: bash tests/test_flow_rules_agent_skills_pointer.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
RUN="$ROOT/skills/flow/runner/flow.sh"
POINTER="$ROOT/.agents/skills/flow/SKILL.md"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }

echo "=== 1. Pointer file exists and is a regular file ==="
[ -f "$POINTER" ] && ck 0 0 "pointer file exists" || ck 1 0 "pointer file exists"

echo "=== 2. Frontmatter has name: flow and non-empty description ==="
fm_name="$(sed -n 's/^name: //p' "$POINTER" | head -1 | tr -d '\r')"
ck "flow" "$fm_name" "frontmatter name is flow"
fm_desc="$(sed -n 's/^description: //p' "$POINTER" | head -1 | tr -d '\r')"
[ -n "$fm_desc" ] && ck 0 0 "frontmatter description is non-empty" || ck 1 0 "frontmatter description is non-empty"

echo "=== 3. Extracted markdown target inside pointer resolves to skills/flow/SKILL.md ==="
link_target="$(sed -nE 's/.*\[the canonical skill\]\(([^)]+)\).*/\1/p' "$POINTER" | head -1 | tr -d '\r')"
[ -n "$link_target" ] && ck 0 0 "extracted canonical markdown link target ($link_target)" || ck 1 0 "extracted canonical markdown link target"
ptr_dir="$(dirname "$POINTER")"
canonical_resolved=""
expected_canonical=""
if [ -n "$link_target" ] && [ -f "$ptr_dir/$link_target" ]; then
  canonical_resolved="$(cd "$ptr_dir/$(dirname "$link_target")" 2>/dev/null && pwd -P)/$(basename "$link_target")"
fi
if [ -f "$ROOT/skills/flow/SKILL.md" ]; then
  expected_canonical="$(cd "$ROOT/skills/flow" 2>/dev/null && pwd -P)/SKILL.md"
fi
[ -n "$canonical_resolved" ] && [ "$canonical_resolved" = "$expected_canonical" ] && ck 0 0 "extracted target resolves to skills/flow/SKILL.md" || ck 0 1 "extracted target resolves to skills/flow/SKILL.md (got=${canonical_resolved:-empty})"

echo "=== 4. Checked-in copy matches rules agent-skills output byte-for-byte (preserving trailing LF) ==="
# Windows checkouts convert this markdown pointer to CRLF (core.autocrlf; .gitattributes
# only pins .sh/.py/.json). Strip \r to temp files rather than $(...) so trailing \n
# differences are preserved and caught by cmp -s.
actual_f="$SCRATCH/actual.md"
ptr_f="$SCRATCH/pointer.md"
bash "$RUN" rules agent-skills 2>/dev/null | tr -d '\r' > "$actual_f"
tr -d '\r' < "$POINTER" > "$ptr_f"
cmp -s "$actual_f" "$ptr_f"
ck 0 $? "rules agent-skills output matches checked-in pointer byte-for-byte"

# Negative control: adding or removing a trailing newline must be caught by cmp -s.
extra_nl="$SCRATCH/extra-nl.md"
cp "$ptr_f" "$extra_nl"
printf '\n' >> "$extra_nl"
cmp -s "$actual_f" "$extra_nl" >/dev/null 2>&1
[ $? -ne 0 ] && ck 0 0 "extra trailing newline detected as drift by cmp -s" || ck 0 1 "extra trailing newline detected as drift by cmp -s"

no_nl="$SCRATCH/no-nl.md"
awk '{printf "%s%s", (NR>1 ? "\n" : ""), $0}' "$ptr_f" > "$no_nl"
cmp -s "$actual_f" "$no_nl" >/dev/null 2>&1
[ $? -ne 0 ] && ck 0 0 "missing trailing newline detected as drift by cmp -s" || ck 0 1 "missing trailing newline detected as drift by cmp -s"

echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
