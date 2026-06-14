#!/usr/bin/env bash
# Regression suite for F4: design-token divergence (flow.sh tokens).
# Run: bash tests/test_flow_tokens.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
newsb() { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; }
css() { mkdir -p "$SB/frontend/src"; printf '%s\n' "$1" > "$SB/frontend/src/tokens.css"; }

echo "A) DESIGN.md tokens but no CSS -> skip cleanly"
newsb
printf '# Design\n| \`--bg-base\` | #fff |\n| \`--accent\` | #4F46E5 |\n' > "$SB/DESIGN.md"
out="$(bash "$RUN" tokens 2>&1)"; ck 0 $? "exit 0"
has "$out" "no CSS custom properties" "skips when no CSS found"
rm -rf "$SB"

echo "B) divergence: a DESIGN.md token the CSS never uses -> flagged"
newsb
printf '# Design\n| \`--bg-base\` | #fff |\n| \`--accent\` | #4F46E5 |\n' > "$SB/DESIGN.md"
css ':root{ --accent:#0969DA; } .x{ color: var(--accent); }'
out="$(bash "$RUN" tokens 2>&1)"; rc=$?
ck 1 "$rc" "exit 1 when a declared token is unused"
has "$out" "never uses" "flags DESIGN.md token not used by CSS"
has "$out" "bg-base" "names the unused token"
rm -rf "$SB"

echo "C) aligned: every DESIGN.md token used by CSS -> PASS"
newsb
printf '# Design\n| \`--accent\` | x |\n| \`--bg-base\` | y |\n' > "$SB/DESIGN.md"
css ':root{ --accent:#000; --bg-base:#fff; }'
out="$(bash "$RUN" tokens 2>&1)"; rc=$?
ck 0 "$rc" "exit 0 when aligned"
has "$out" "PASS" "aligned tokens pass"
rm -rf "$SB"

echo "D) orphan CSS vars are info-only (not a flag): all declared used, extras reported"
newsb
printf '# Design\n| \`--accent\` | x |\n' > "$SB/DESIGN.md"
css ':root{ --accent:#000; --text:#111; --canvas:#fff; }'
out="$(bash "$RUN" tokens 2>&1)"; rc=$?
ck 0 "$rc" "exit 0: orphan CSS vars do not fail the check"
has "$out" "not declared in DESIGN.md" "reports orphan CSS vars as info"
has "$out" "PASS" "still PASS (orphans are informational)"
rm -rf "$SB"

echo "G) value mismatch: same token, different value in DESIGN.md vs CSS -> flagged"
newsb
printf '# Design\n| \`--accent\` | \`#4F46E5\` |\n' > "$SB/DESIGN.md"
css ':root{ --accent: #0969DA; } .x{ color: var(--accent); }'
out="$(bash "$RUN" tokens 2>&1)"; rc=$?
ck 1 "$rc" "exit 1 on value mismatch"
has "$out" "VALUE mismatch" "value mismatch flagged"
has "$out" "0969DA" "shows the CSS value"
rm -rf "$SB"

echo "H) matching value -> no value-mismatch flag"
newsb
printf '# Design\n| \`--accent\` | \`#0969DA\` |\n' > "$SB/DESIGN.md"
css ':root{ --accent: #0969DA; }'
out="$(bash "$RUN" tokens 2>&1)"; rc=$?
ck 0 "$rc" "exit 0 when values match"
no  "$out" "VALUE mismatch" "no false value-mismatch when aligned"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
