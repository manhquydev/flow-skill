#!/usr/bin/env bash
# Regression suite for F7 (coherence: version drift) + cross-project KB (promote + recall global).
# Run: bash tests/test_flow_coherence_kb.sh
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
exists() { [ -f "$1" ] && echo 0 || echo 1; }
newsb() { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; }

echo "A) coherence: no version fields -> skip"
newsb
out="$(bash "$RUN" coherence 2>&1)"; ck 0 $? "exit 0"
has "$out" "no declared version" "skips with no version fields"
rm -rf "$SB"

echo "B) coherence: agreeing versions -> PASS"
newsb
printf '{"version":"2.3.0"}\n' > "$SB/package.json"
mkdir -p "$SB/frontend"; printf '{"version":"2.3.0"}\n' > "$SB/frontend/package.json"
out="$(bash "$RUN" coherence 2>&1)"; ck 0 $? "exit 0 when versions agree"
has "$out" "PASS" "agreeing versions pass"
rm -rf "$SB"

echo "C) coherence: version drift across files -> flagged"
newsb
printf '{"version":"2.3.0"}\n' > "$SB/package.json"
printf 'version = "2.0.0"\n' > "$SB/pyproject.toml"
out="$(bash "$RUN" coherence 2>&1)"; rc=$?
ck 1 "$rc" "exit 1 on version drift"
has "$out" "version drift" "drift flagged"
has "$out" "2.0.0" "shows the drifted version"
rm -rf "$SB"

echo "D) cross-project: promote a playbook + recall surfaces it as GLOBAL"
newsb
export FLOW_GLOBAL_KB="$SB/gkb"
printf '# heroku stale-cache fix\n' > "$SB/my-lesson.md"
out="$(bash "$RUN" promote "$SB/my-lesson.md" 2>&1)"; ck 0 $? "promote exit 0"
has "$out" "promoted" "promote confirms"
ck 0 "$(exists "$SB/gkb/my-lesson.md")" "file copied into the global KB"
out="$(FLOW_HARNESS_DISABLE=1 bash "$RUN" recall 2>&1)"
has "$out" "GLOBAL PLAYBOOKS" "recall surfaces the cross-project section"
has "$out" "my-lesson" "recall lists the promoted playbook"
unset FLOW_GLOBAL_KB
rm -rf "$SB"

echo "E) promote with a missing file -> usage error, exit 1"
newsb; export FLOW_GLOBAL_KB="$SB/gkb"
out="$(bash "$RUN" promote /no/such/file.md 2>&1)"; ck 1 $? "exit 1 on missing file"
has "$out" "usage" "usage shown"
unset FLOW_GLOBAL_KB; rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
