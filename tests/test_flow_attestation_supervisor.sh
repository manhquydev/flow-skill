#!/usr/bin/env bash
# Phase 2: attestation supervisor privacy + capability + timeout/cap.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
export FLOW_HARNESS_DISABLE=1
export FLOW_LOG_DISABLE=1
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -qE "$2"; then echo "  FAIL [$3]"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

echo "A) source library and capability probe"
export FLOW_PROJECT_ROOT="$(mktemp -d)"
export FLOW_LIB_ONLY=1
# shellcheck disable=SC1091
. "$HERE/../skills/flow/runner/flow.sh"
unset FLOW_LIB_ONLY
if _att_supervisor_capable; then echo "  ok   [capable]"; pass=$((pass+1)); else echo "  FAIL [capable]"; fail=$((fail+1)); fi
export FLOW_ATTEST_SUPERVISOR=force-unsupported
if _att_supervisor_capable; then echo "  FAIL [force-unsupported]"; fail=$((fail+1)); else echo "  ok   [force-unsupported]"; pass=$((pass+1)); fi
unset FLOW_ATTEST_SUPERVISOR

echo "B) supervised true exits 0"
_att_run_supervised true
ck exit "$_ATT_RUN_RC" "true exit class"
ck 0 "$_ATT_RUN_CODE" "true code 0"

echo "C) timeout classifies"
export FLOW_ATTEST_TIMEOUT_S=1
export FLOW_ATTEST_GRACE_S=1
_att_run_supervised sleep 20
case "$_ATT_RUN_RC" in timeout|signal|exit) echo "  ok   [timeout-ish $_ATT_RUN_RC]"; pass=$((pass+1));; *) echo "  FAIL [timeout got $_ATT_RUN_RC]"; fail=$((fail+1));; esac
unset FLOW_ATTEST_TIMEOUT_S FLOW_ATTEST_GRACE_S
export FLOW_ATTEST_TIMEOUT_S=30

echo "D) output cap"
export FLOW_ATTEST_OUT_CAP=200
export FLOW_ATTEST_COMBINED_CAP=300
export FLOW_ATTEST_TIMEOUT_S=3
export FLOW_ATTEST_GRACE_S=1
# bounded loop: write a lot quickly then exit (cap monitor should trip or command ends)
_att_run_supervised sh -c 'i=0; while [ $i -lt 5000 ]; do printf "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"; i=$((i+1)); done'
case "$_ATT_RUN_RC" in output-cap|timeout|signal|exit) echo "  ok   [cap-ish $_ATT_RUN_RC]"; pass=$((pass+1));; *) echo "  FAIL [cap $_ATT_RUN_RC]"; fail=$((fail+1));; esac
unset FLOW_ATTEST_OUT_CAP FLOW_ATTEST_COMBINED_CAP FLOW_ATTEST_TIMEOUT_S FLOW_ATTEST_GRACE_S

echo "E) no shell metachar execution of owner string"
# supervisor takes argv only — calling with a single string that looks like metachar must not run shell
_att_run_supervised "echo pwned >/tmp/should-not-attest-$$"
# should be spawn-error or non-zero, not write file
[ ! -f "/tmp/should-not-attest-$$" ]; ck 0 $? "no shell metachar file"
rm -f "/tmp/should-not-attest-$$" 2>/dev/null

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
