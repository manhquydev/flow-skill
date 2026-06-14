#!/usr/bin/env bash
# Regression suite for F3: contract path-resolution drift (flow.sh contract).
# Run: bash tests/test_flow_contract.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
newsb() { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"; }
contract_md() { { echo "# Stage 05"; echo "## Interfaces"; for p in "$@"; do echo "| GET | \`$p\` | super | - | - |"; done; } > "$SB/flow/05-contract.md"; }

echo "A) no spec -> skip cleanly"
newsb
out="$(bash "$RUN" contract 2>&1)"; ck 0 $? "exit 0"
has "$out" "no served paths" "skips when no contract/openapi"
rm -rf "$SB"

echo "B) non-web project type -> skip"
newsb; printf 'cli\n' > "$SB/PROJECT_TYPE"; contract_md /api/x
out="$(bash "$RUN" contract 2>&1)"; ck 0 $? "exit 0 for cli"
has "$out" "not web" "skips non-web project"
rm -rf "$SB"

echo "C) mixed prefixes + base ending /api -> flags double-prefix AND mixed (the real bug)"
newsb
contract_md /api/admin/users /auth/admin/login /health
printf 'VITE_API_BASE=http://localhost:8000/api\n' > "$SB/.env"
out="$(bash "$RUN" contract 2>&1)"; rc=$?
ck 1 "$rc" "exit 1 when flagged"
has "$out" "double-prefix risk" "double-prefix flagged (base /api + /api paths)"
has "$out" "mixed served prefixes" "mixed prefixes flagged (/api vs /auth vs /health)"
rm -rf "$SB"

echo "D) clean: single prefix + origin-only base -> PASS, no false positives"
newsb
contract_md /api/admin/users /api/admin/orgs
printf 'VITE_API_BASE=http://localhost:8000\n' > "$SB/.env"
out="$(bash "$RUN" contract 2>&1)"; rc=$?
ck 0 "$rc" "exit 0 when clean"
has "$out" "PASS" "clean composition passes"
no  "$out" "double-prefix" "no false double-prefix on origin-only base"
no  "$out" "mixed served prefixes" "no false mixed flag on single prefix"
rm -rf "$SB"

echo "E) base value with URL colons is parsed correctly (not truncated at :8000)"
newsb
contract_md /api/x
printf 'VITE_API_BASE=https://api.example.com:8443/api\n' > "$SB/.env"
out="$(bash "$RUN" contract 2>&1)"
has "$out" "https://api.example.com:8443/api" "full base URL parsed (colons preserved)"
rm -rf "$SB"

echo "F) origin-only base + mixed prefixes -> NOT flagged (both resolve under the origin)"
newsb
contract_md /api/admin/users /auth/admin/login
printf 'VITE_API_BASE=http://localhost:3000\n' > "$SB/.env"
out="$(bash "$RUN" contract 2>&1)"; rc=$?
ck 0 "$rc" "exit 0: origin-only base resolves all prefixes"
no  "$out" "mixed served prefixes" "no false mixed-prefix flag on origin-only base"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
