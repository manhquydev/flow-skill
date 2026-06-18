#!/usr/bin/env bash
# Regression suite for the mechanical usage log: flow.sh self-records every invocation to
# JSONL (full per-project + compact global), masks secret-shaped args, never breaks a command
# on a logging failure, honors disable envs, and rolls up into usage_event for `flow usage`.
# Run: bash tests/test_flow_usage_log.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
HARN="$HERE/../skills/flow/harness/flow_harness.py"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
harness_ok() { local py; py="$(command -v python || command -v python3 || true)"; [ -n "$py" ] && "$py" --version >/dev/null 2>&1; }

# Shell-only sandbox (mktemp is fine: Git Bash both writes AND reads the JSONL here).
newsb() { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; export HOME="$SB/home"; mkdir -p "$SB/home"; }

echo "1) status self-records one FULL event (per-project) + COMPACT event (global)"
newsb
ec=0; bash "$RUN" status >/dev/null 2>&1 || ec=$?
ck 0 "$ec" "status exits 0"
ev="$(cat "$SB/.flow/events.jsonl" 2>/dev/null)"
has "$ev" '"command":"status"' "full event records the command"
has "$ev" '"read_only":true' "status classified read_only"
gl="$(cat "$SB/home/.claude/flow/usage.jsonl" 2>/dev/null)"
has "$gl" '"command":"status"' "compact global event written"
no  "$gl" '"args":' "compact line omits args (stays small)"
rm -rf "$SB"

echo "2) secret-shaped args are masked before disk"
newsb
bash "$RUN" harness --summary "api_key=AKIA_LEAK_1234" >/dev/null 2>&1 || true
ev="$(tail -1 "$SB/.flow/events.jsonl" 2>/dev/null)"
has "$ev" 'redacted' "args field masked"
no  "$ev" 'AKIA_LEAK_1234' "raw secret not on disk"
rm -rf "$SB"

echo "3) no-fail: an unwritable sink never breaks the command"
newsb
mkdir -p "$SB/.flow/events.jsonl"   # make the sink a directory -> append must fail
ec=0; out="$(bash "$RUN" status 2>&1)" || ec=$?
ck 0 "$ec" "status still exits 0 when the sink is unwritable"
has "$out" "flow status" "command output intact despite logging failure"
rm -rf "$SB"

echo "4) disable envs suppress logging (FLOW_LOG_DISABLE + DO_NOT_TRACK)"
newsb
bash "$RUN" status >/dev/null 2>&1
before="$(wc -l < "$SB/.flow/events.jsonl" 2>/dev/null | tr -d ' ')"
FLOW_LOG_DISABLE=1 bash "$RUN" status >/dev/null 2>&1
DO_NOT_TRACK=1     bash "$RUN" status >/dev/null 2>&1
after="$(wc -l < "$SB/.flow/events.jsonl" 2>/dev/null | tr -d ' ')"
ck "$before" "$after" "no events appended while disabled"
rm -rf "$SB"

echo "5) next (greenfield) stamps a cycle_id and carries stage_to"
newsb
bash "$RUN" next >/dev/null 2>&1
has "$(cat "$SB/.flow/cycle_id" 2>/dev/null)" "-" "cycle_id stamped at stage 00 unlock"
has "$(tail -1 "$SB/.flow/events.jsonl")" '"stage_to":"00-idea"' "event carries stage_to"
rm -rf "$SB"

if ! harness_ok; then
  echo "6,7) skipped [no python -> rollup/usage unavailable]"
  echo; echo "RESULT: $pass passed, $fail failed"; [ "$fail" -eq 0 ]; exit $?
fi

# python-dependent: use a sandbox UNDER $HERE (a real drive path) so the Git-Bash JSONL writer
# and the Windows-python reader resolve the SAME file (a /tmp sandbox would mismatch on Windows;
# production roots are real drive paths, which this mirrors). On POSIX this is a normal abs path.
echo "6) rollup is idempotent and skips malformed lines"
SB="$HERE/.usagesb_$$"; rm -rf "$SB"; mkdir -p "$SB"; export FLOW_PROJECT_ROOT="$SB"; export HOME="$SB/home"; mkdir -p "$SB/home"
bash "$RUN" next        >/dev/null 2>&1
bash "$RUN" next        >/dev/null 2>&1   # gate fail
bash "$RUN" check C-999 >/dev/null 2>&1   # check fail
bash "$RUN" status      >/dev/null 2>&1
echo '{ not valid json' >> "$SB/.flow/events.jsonl"
r1="$(FLOW_PROJECT_ROOT="$SB" python "$HARN" rollup 2>/dev/null || FLOW_PROJECT_ROOT="$SB" python3 "$HARN" rollup 2>/dev/null)"
has "$r1" '"skipped": 1' "malformed line skipped, not fatal"
no  "$r1" '"rolled": 0' "first rollup ingested >0 rows"
r2="$(FLOW_PROJECT_ROOT="$SB" python "$HARN" rollup 2>/dev/null || FLOW_PROJECT_ROOT="$SB" python3 "$HARN" rollup 2>/dev/null)"
has "$r2" '"rolled": 0' "second rollup is idempotent (0 new rows)"

echo "7) flow usage prints numeric analytics"
u="$(bash "$RUN" usage 2>&1)"
has "$u" "gate fail-rate" "usage shows gate fail-rate"
has "$u" "cycles started" "usage shows cycle count"
has "$u" "cycle-time" "usage shows cycle-time"
has "$u" "per-stage dwell" "usage shows per-stage dwell"

echo "8) v2 loop-closing: migration 007 + usage --summary + recall block + gate-reason + prune + propose"
PY="$(command -v python || command -v python3)"
ver="$("$PY" - "$SB/.flow/harness.db" <<'PY'
import sqlite3,sys
print(sqlite3.connect(sys.argv[1]).execute("select max(version) from schema_version").fetchone()[0])
PY
)"
ck "7" "$ver" "migration 007 applied (schema_version 7)"
s="$(bash "$RUN" usage --summary 2>/dev/null)"
has "$s" "USAGE (mechanical log)" "usage --summary prints one-line digest"
SE="$HERE/.usageempty_$$"; rm -rf "$SE"; mkdir -p "$SE"
es="$(FLOW_PROJECT_ROOT="$SE" "$PY" "$HARN" usage --summary 2>/dev/null)"
ck "" "$es" "usage --summary silent on no data"
rm -rf "$SE"
rc="$(bash "$RUN" recall 2>&1)"
has "$rc" "USAGE (mechanical log)" "recall surfaces the usage block"
rd="$(FLOW_HARNESS_DISABLE=1 bash "$RUN" recall 2>&1)"
no  "$rd" "USAGE (mechanical log)" "recall omits usage block when harness disabled"
gr="$("$PY" - "$SB/.flow/events.jsonl" <<'PY'
import json,sys
print(next((o.get("gate_fail_reason") or "" for o in (json.loads(l) for l in open(sys.argv[1]) if l.strip()) if o.get("gate_pass") is False), ""))
PY
)"
has "$gr" "fill:" "failing gate records gate_fail_reason"
pr="$(bash "$RUN" usage --prune --keep 1 2>/dev/null)"
has "$pr" '"kept": 1' "usage --prune caps to keep N"
SP="$HERE/.usageprop_$$"; rm -rf "$SP"; mkdir -p "$SP/.flow"
"$PY" - "$SP/.flow/events.jsonl" <<'PY'
import json,sys
rows=[{"command":"next","stage_to":"03-prd","gate_pass":False,"cycle_id":"A","epoch_s":1,"exit_code":1},
      {"command":"next","stage_to":"03-prd","gate_pass":False,"cycle_id":"B","epoch_s":2,"exit_code":1},
      {"command":"next","stage_to":"03-prd","gate_pass":True,"cycle_id":"B","epoch_s":3,"exit_code":0}]
open(sys.argv[1],"w").write("\n".join(json.dumps(r) for r in rows)+"\n")
PY
FLOW_PROJECT_ROOT="$SP" "$PY" "$HARN" rollup >/dev/null 2>&1
pp="$(FLOW_PROJECT_ROOT="$SP" "$PY" "$HARN" propose 2>&1)"
has "$pp" "03-prd" "propose surfaces a stage-fail proposal from the usage log"
rm -rf "$SP"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
