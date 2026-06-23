#!/usr/bin/env bash
# Regression suite for the kind-aware inbound tool/capability registry (P1, ported from
# repository-harness v0.1.10). Covers: register with kind/capability/scan-target, presence
# probing per kind (cli/binary/mcp/skill/http), `tool check`, capability+status lookup,
# remove, back-compat with the old 4-arg register, and capability normalization.
# Requires python (stdlib sqlite3). Run: bash tests/test_flow_tool_registry.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
H="$HERE/../skills/flow/harness/flow_harness.py"
PY="$(command -v python || command -v python3)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected $1 got $2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]: $1"; fail=$((fail+1)); fi; }
no() { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3]: unexpected $2"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
py() { "$PY" "$H" "$@"; }
py init >/dev/null
GIT="$(command -v git || echo git)"   # git is on PATH in this environment

echo "A) register cli — records present vs missing status (register always succeeds)"
has "$(py tool register --name git-vcs --command "$GIT" --description 'vcs' --responsibility 'Verification' --kind cli --capability 'version-control')" "status=present" "cli on PATH registers present"
py tool register --name ghost --command no_such_cmd_xyz --description x --responsibility 'Tool access' --kind cli >/dev/null 2>&1; ck 0 $? "missing cli still registers (no install gate)"
has "$(py tool register --name ghost --command no_such_cmd_xyz --description x --responsibility 'Tool access' --kind cli)" "status=missing" "missing cli recorded with status=missing"
py tool register --name wsonly --command '   ' --description x --responsibility 'Tool access' --kind cli >/dev/null 2>&1; ck 0 $? "whitespace-only command never crashes the probe (no IndexError)"

echo "B) skill / mcp / http presence by kind"
SKILLDIR="$SB/skills/ck-scenario"; mkdir -p "$SKILLDIR"
has "$(py tool register --name ck-scenario --command 'skill:ck-scenario' --description 'edge cases' --responsibility 'Task specification' --kind skill --capability 'Edge Case Expansion' --scan-target "$SKILLDIR")" "status=present" "skill with resolving scan-target is present"
has "$(py tool register --name ck-missing --command 'skill:nope' --description x --responsibility 'Task specification' --kind skill --scan-target '/no/such/skill/path')" "status=missing" "skill with bad path is missing"
has "$(py tool register --name mcp-foo --command 'mcp:foo' --description x --responsibility 'Context selection' --kind mcp)" "status=unknown" "mcp without scan-target is unknown"
has "$(py tool register --name web-svc --command 'http' --description x --responsibility 'Verification' --kind http --scan-target 'http://127.0.0.1:65500')" "status=missing" "http unreachable is missing"
py tool register --name badresp --command "$GIT" --description x --responsibility 'Nope Not Real' --kind cli >/dev/null 2>&1; ck 1 $? "invalid responsibility rejected (fixed vocab enforced)"
# non-http scheme must NOT trigger a slow DNS/TCP probe: bounded + missing, never a multi-second stall
t0=$(date +%s); py tool register --name ftp-svc --command 'x' --description x --responsibility 'Verification' --kind http --scan-target 'ftp://example.invalid' >/dev/null 2>&1; t1=$(date +%s)
ck 0 $(( (t1-t0) > 3 ? 1 : 0 )) "non-http scan-target probe is fast (no foreign-scheme TCP stall)"

echo "C) capability normalization"
has "$(py query tools --capability edge-case-expansion --json)" '"name": "ck-scenario"' "'Edge Case Expansion' normalized to edge-case-expansion and queryable"

echo "D) capability + status lookup (the mechanized stage->skill replacement)"
out="$(py query tools --capability edge-case-expansion --status present)"
has "$out" "ck-scenario" "present skill returned for capability"
out2="$(py query tools --status missing)"
has "$out2" "ghost" "status filter surfaces missing tools"
no "$out2" "git-vcs" "status=missing excludes present tools"

echo "E) tool check re-probes and persists status"
# ghost is recorded missing; create the path it scans? cli uses PATH, so it stays missing.
has "$(py tool check --name ck-scenario --json)" '"status": "present"' "check reports present for resolving skill"
rm -rf "$SKILLDIR"
has "$(py tool check --name ck-scenario --json)" '"status": "missing"' "check flips to missing after scan-target removed"

echo "F) remove + back-compat (old 4-arg register defaults kind=cli)"
has "$(py tool register --name legacy --command "$GIT" --description 'old form' --responsibility 'Tool access')" "kind=cli" "register without --kind defaults to cli"
py tool remove --name legacy >/dev/null; ck 0 $? "remove existing tool"
py tool remove --name legacy >/dev/null 2>&1; ck 1 $? "remove missing tool returns 1"

rm -rf "$SB"
echo; echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
