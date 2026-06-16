#!/usr/bin/env bash
# Regression suite for `flow.sh constitution` (operator-authored per-project invariants, advisory).
# Run: bash tests/test_flow_constitution.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fi; [ "$1" = "$2" ] || fail=$((fail+1)); }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
newsb() { SB="$(mktemp -d)"; mkdir -p "$SB/flow"; }
C() { FLOW_PROJECT_ROOT="$SB" bash "$RUN" constitution 2>&1; }
clean_table() { cat > "$SB/flow/constitution.md" <<'EOF'
# Project Constitution
| ID | Invariant | Applies-at | grep-marker (optional) | Rationale |
|----|-----------|-----------|------------------------|-----------|
| INV-1 | all PII facility-scoped | scope,prd | - | privacy |
EOF
}

echo "A) no constitution file -> graceful skip, exit 0 (optional feature)"
newsb
out="$(C)"; ck 0 $? "no-file exits 0"
has "$out" "skipped (optional)" "prints the optional-skip hint"
rm -rf "$SB"

echo "B) clean filled table -> PASS, exit 0"
newsb; clean_table
out="$(C)"; ck 0 $? "clean exits 0"
has "$out" "PASS (structure clean)" "reports PASS"
has "$out" "INV-1" "lists the invariant id"
rm -rf "$SB"

echo "C) leftover placeholder -> FAIL, exit 1"
newsb; clean_table
printf '| INV-2 | [FILL: a rule] | scope | - | why |\n' >> "$SB/flow/constitution.md"
out="$(C)"; ck 1 $? "placeholder exits 1"
has "$out" "unfilled placeholder" "names the placeholder failure"
rm -rf "$SB"

echo "D) invariant row with no ID -> FAIL, exit 1"
newsb
cat > "$SB/flow/constitution.md" <<'EOF'
# Project Constitution
| ID | Invariant | Applies-at | grep-marker (optional) | Rationale |
|----|-----------|-----------|------------------------|-----------|
|  | a rule with no id | scope | - | why |
EOF
out="$(C)"; ck 1 $? "missing-id exits 1"
has "$out" "no ID" "names the missing-id failure"
rm -rf "$SB"

echo "E) grep-marker present in src/ -> ok; absent -> advisory warn but still exit 0"
newsb; mkdir -p "$SB/src"
printf 'def q(): return facility_id\n' > "$SB/src/app.py"
cat > "$SB/flow/constitution.md" <<'EOF'
# Project Constitution
| ID | Invariant | Applies-at | grep-marker (optional) | Rationale |
|----|-----------|-----------|------------------------|-----------|
| INV-1 | PII facility-scoped | scope | facility_id | privacy |
| INV-2 | uses audit_log | scope | audit_log | traceability |
EOF
out="$(C)"; ck 0 $? "present+unmet markers still exit 0 (advisory)"
has "$out" "INV-1 (grep-marker present)" "present marker reported ok"
has "$out" "INV-2 - declared grep-marker" "absent marker is an advisory warning"
rm -rf "$SB"

echo "F) malformed row (ID but missing columns) -> FAIL, exit 1"
newsb
cat > "$SB/flow/constitution.md" <<'EOF'
# Project Constitution
| ID | Invariant | Applies-at | grep-marker (optional) | Rationale |
|----|-----------|-----------|------------------------|-----------|
| INV-1 | only-two-cells |
EOF
out="$(C)"; ck 1 $? "2-cell malformed row exits 1"
has "$out" "malformed row" "names the malformed-row failure"
rm -rf "$SB"

echo "G) pipe-rows inside a fenced code block are NOT parsed as invariants"
newsb
cat > "$SB/flow/constitution.md" <<'EOF'
# Project Constitution
| ID | Invariant | Applies-at | grep-marker (optional) | Rationale |
|----|-----------|-----------|------------------------|-----------|
| INV-1 | real invariant | scope | - | why |

Example of a bad row (must be ignored):
```
|  | not a real invariant | scope | - | x |
```
EOF
out="$(C)"; ck 0 $? "fenced example ignored -> still exit 0"
has "$out" "PASS (structure clean)" "code-fence pipe-rows do not trip missing-ID"
rm -rf "$SB"

echo "H) LAW: constitution is NOT wired into cmd_next (no hot-path coupling)"
body="$(sed -n '/^cmd_next()/,/^}/p' "$RUN"; sed -n '/^function cmd_next/,/^}/p' "$RUN")"
has "$body" "cmd_next" "cmd_next body extracted (range non-empty - guards a silent pass)"
n="$(printf '%s' "$body" | grep -c 'cmd_constitution' || true)"
ck 0 "$n" "cmd_next never calls cmd_constitution"
has "$(grep -A2 '^  constitution)' "$RUN")" "cmd_constitution" "constitution IS reachable via dispatch"

echo "I) recall surfaces the project constitution when present"
newsb; clean_table
out="$(FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_DISABLE=1 bash "$RUN" recall 2>&1)"
has "$out" "PROJECT CONSTITUTION" "recall shows the constitution section"
has "$out" "INV-1" "recall lists the invariant"
rm -rf "$SB"

echo "J) marker with escaped \\| alternation survives the table |-split (regression)"
newsb; mkdir -p "$SB/src"
printf 'def q(): return tenant_id\n' > "$SB/src/app.py"
cat > "$SB/flow/constitution.md" <<'EOF'
# Project Constitution
| ID | Invariant | Applies-at | grep-marker (optional) | Rationale |
|----|-----------|-----------|------------------------|-----------|
| INV-1 | scope marker | scope | facility_id\|tenant_id | privacy |
EOF
out="$(C)"; ck 0 $? "escaped-pipe marker exits 0"
has "$out" "INV-1 (grep-marker present)" "alternation marker matches via tenant_id branch (pipe not lost to split)"
rm -rf "$SB"

echo "K) a cell containing the reserved sentinel token fails LOUD (no silent mangle)"
newsb
cat > "$SB/flow/constitution.md" <<'EOF'
# Project Constitution
| ID | Invariant | Applies-at | grep-marker (optional) | Rationale |
|----|-----------|-----------|------------------------|-----------|
| INV-1 | rule mentioning __FLOW_ESC_PIPE__ literally | scope | - | why |
EOF
out="$(C)"; ck 1 $? "reserved-token cell exits 1"
has "$out" "reserved token" "names the reserved-token collision (loud, not silent)"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
