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
ck "8" "$ver" "migration 008 applied (schema_version 8)"
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

echo "9) usage --global rolls up the device-global log in ONE command (no manual pre-rollup)"
# Align bash \$HOME and python expanduser (USERPROFILE on Windows) to the same sandbox home so
# the shell writer and the python --global reader resolve the SAME global log file.
SBG="$HERE/.usageglobal_$$"; rm -rf "$SBG"; mkdir -p "$SBG/home/.claude/flow"
export FLOW_PROJECT_ROOT="$SBG"; export HOME="$SBG/home"; export USERPROFILE="$SBG/home"
printf '%s\n' '{"ts":"2026-01-01T00:00:00Z","epoch_s":1700000000,"session_id":"s","cycle_id":"c","project":"seedproj","command":"next","exit_code":0,"gate_pass":true,"duration_s":1,"stage_to":"00-idea","flow_version":"0.11.0","read_only":false}' > "$SBG/home/.claude/flow/usage.jsonl"
ug="$(bash "$RUN" usage --global 2>&1)"
has "$ug" "events total" "usage --global shows analytics in one command"
no  "$ug" "no events yet"  "usage --global did NOT falsely report empty"
rm -rf "$SBG"

echo "10) cycle_id is stamped at brownfield assess AND lazily on a pre-existing project"
SBA="$HERE/.cycleassess_$$"; rm -rf "$SBA"; mkdir -p "$SBA/home"
export FLOW_PROJECT_ROOT="$SBA"; export HOME="$SBA/home"; export USERPROFILE="$SBA/home"
bash "$RUN" assess >/dev/null 2>&1
has "$(cat "$SBA/.flow/cycle_id" 2>/dev/null)" "-" "assess stamps a cycle_id"
no  "$(grep -o '"cycle_id":""' "$SBA/.flow/events.jsonl" 2>/dev/null)" '"cycle_id":""' "assess events carry non-empty cycle_id"
rm -rf "$SBA"
SBL="$HERE/.cyclelazy_$$"; rm -rf "$SBL"; mkdir -p "$SBL/home" "$SBL/flow"   # pre-existing flow/, no cycle_id
export FLOW_PROJECT_ROOT="$SBL"; export HOME="$SBL/home"; export USERPROFILE="$SBL/home"
bash "$RUN" status >/dev/null 2>&1
has "$(cat "$SBL/.flow/cycle_id" 2>/dev/null)" "-" "pre-existing project lazily stamps a cycle_id on any command"
rm -rf "$SBL"

echo "11) ephemeral runs are tagged and excluded from analytics by default (--include-ephemeral overrides)"
SBE="$HERE/.ephem_$$"; rm -rf "$SBE"; mkdir -p "$SBE/home/.claude/flow"
export FLOW_PROJECT_ROOT="$SBE"; export HOME="$SBE/home"; export USERPROFILE="$SBE/home"
printf '%s\n%s\n' \
 '{"ts":"2026-01-01T00:00:00Z","epoch_s":1700000000,"session_id":"s","cycle_id":"c","project":"realproj","command":"next","exit_code":0,"gate_pass":true,"duration_s":1,"stage_to":"00-idea","flow_version":"0.11.0","read_only":false,"ephemeral":0}' \
 '{"ts":"2026-01-01T00:00:01Z","epoch_s":1700000001,"session_id":"s","cycle_id":"d","project":"tmp.ABC","command":"next","exit_code":0,"gate_pass":true,"duration_s":1,"stage_to":"00-idea","flow_version":"0.11.0","read_only":false,"ephemeral":1}' > "$SBE/home/.claude/flow/usage.jsonl"
ud="$(bash "$RUN" usage --global --json 2>/dev/null)"
has "$ud" '"events_total": 1' "default view excludes the ephemeral tmp.* event"
ui="$(bash "$RUN" usage --global --include-ephemeral --json 2>/dev/null)"
has "$ui" '"events_total": 3' "--include-ephemeral counts every event (incl. ephemeral + the usage cmd)"
# a tmp.* sandbox tags its own events ephemeral:1
TMPSB="$(mktemp -d)"; FLOW_PROJECT_ROOT="$TMPSB" bash "$RUN" status >/dev/null 2>&1
has "$(tail -1 "$TMPSB/.flow/events.jsonl" 2>/dev/null)" '"ephemeral":1' "a tmp.* project tags its events ephemeral:1"
rm -rf "$TMPSB"
# a normal project tags ephemeral:0
SBN="$HERE/.notephem_$$"; rm -rf "$SBN"; mkdir -p "$SBN"; FLOW_PROJECT_ROOT="$SBN" bash "$RUN" status >/dev/null 2>&1
has "$(tail -1 "$SBN/.flow/events.jsonl" 2>/dev/null)" '"ephemeral":0' "a normal project tags its events ephemeral:0"
rm -rf "$SBN" "$SBE"

echo "12) device-global compact line carries a (bounded) gate_fail_reason on a real gate failure"
SBR="$HERE/.greason_$$"; rm -rf "$SBR"; mkdir -p "$SBR/home/.claude/flow"
export FLOW_PROJECT_ROOT="$SBR"; export HOME="$SBR/home"; export USERPROFILE="$SBR/home"
bash "$RUN" next >/dev/null 2>&1   # unlock 00-idea (has [FILL])
bash "$RUN" next >/dev/null 2>&1   # gate fails on the unfilled stage
gl="$(grep '"gate_pass":false' "$SBR/home/.claude/flow/usage.jsonl" | tail -1)"
has "$gl" '"gate_fail_reason":"fill:' "global compact line records the gate_fail_reason"
len="$(printf '%s' "$gl" | wc -c)"
if [ "$len" -lt 4096 ]; then echo "  ok   [compact line bounded < 4096 bytes ($len)]"; pass=$((pass+1));
else echo "  FAIL [compact line too large: $len]"; fail=$((fail+1)); fi
rm -rf "$SBR"

echo "13) per-stage dwell reports WALL-CLOCK time-in-stage from transitions (not runner exec time)"
PY="$(command -v python || command -v python3)"
SBW="$HERE/.dwell_$$"; rm -rf "$SBW"; mkdir -p "$SBW/.flow"
"$PY" - "$SBW/.flow/events.jsonl" <<'PY'
import json,sys
E=1700000000
rows=[{"command":"next","cycle_id":"A","project":"realproj","stage_from":"","stage_to":"00-idea","epoch_s":E,"ephemeral":0,"exit_code":0,"gate_pass":True},
      {"command":"next","cycle_id":"A","project":"realproj","stage_from":"00-idea","stage_to":"01-research","epoch_s":E+3600,"ephemeral":0,"exit_code":0,"gate_pass":True}]
open(sys.argv[1],"w").write("\n".join(json.dumps(r) for r in rows)+"\n")
PY
FLOW_PROJECT_ROOT="$SBW" "$PY" "$HARN" rollup >/dev/null 2>&1
jw="$(FLOW_PROJECT_ROOT="$SBW" "$PY" "$HARN" usage --json 2>/dev/null)"
if printf '%s' "$jw" | "$PY" -c "import json,sys; d=json.load(sys.stdin); sd={x['stage']:x['avg_s'] for x in d['stage_dwell']}; sys.exit(0 if sd.get('00-idea')==3600.0 else 1)"; then
  echo "  ok   [00-idea wall-clock dwell = 3600s (1h gap), not the ~0s exec time]"; pass=$((pass+1))
else echo "  FAIL [00-idea wall-clock dwell wrong]"; fail=$((fail+1)); fi
tw="$(FLOW_PROJECT_ROOT="$SBW" "$PY" "$HARN" usage 2>/dev/null)"
has "$tw" "wall-clock"        "text output labels the dwell line wall-clock"
has "$tw" "command exec time" "text output keeps exec-time, distinctly relabeled"
rm -rf "$SBW"

echo "15) compact global line format carries stage_from field"
newsb
bash "$RUN" next >/dev/null 2>&1
gl="$(cat "$SB/home/.claude/flow/usage.jsonl" 2>/dev/null | tail -1)"
has "$gl" '"stage_from"' "compact global line contains stage_from key"
rm -rf "$SB"

echo "16) EQUIVALENCE: --global dwell for new (post-fix) rows equals project-local dwell for same transitions"
PY="$(command -v python || command -v python3)"
# Use two completely separate sandbox dirs each with their own DB so src paths do not collide.
SBL="$HERE/.dwell_local_$$"; SBG="$HERE/.dwell_global_$$"
rm -rf "$SBL" "$SBG"
mkdir -p "$SBL/.flow" "$SBG/home/.claude/flow"
# Write identical post-fix transitions (with stage_from) to project-local and global-log files.
"$PY" - "$SBL/.flow/events.jsonl" "$SBG/home/.claude/flow/usage.jsonl" <<'PY'
import json, sys
E = 1700000000
rows = [
    {"command":"next","cycle_id":"X","project":"myproj","stage_from":"",           "stage_to":"00-idea",     "epoch_s":E,       "ephemeral":0,"exit_code":0,"gate_pass":True},
    {"command":"next","cycle_id":"X","project":"myproj","stage_from":"00-idea",    "stage_to":"01-research", "epoch_s":E+7200,  "ephemeral":0,"exit_code":0,"gate_pass":True},
    {"command":"next","cycle_id":"X","project":"myproj","stage_from":"01-research","stage_to":"02-design",   "epoch_s":E+10800, "ephemeral":0,"exit_code":0,"gate_pass":True},
]
body = "\n".join(json.dumps(r) for r in rows) + "\n"
for p in sys.argv[1:]:
    open(p, "w").write(body)
PY
# Roll up project-local into SBL's DB; global log into SBG's DB (using --global on separate root).
export FLOW_PROJECT_ROOT="$SBL"
FLOW_PROJECT_ROOT="$SBL" "$PY" "$HARN" rollup >/dev/null 2>&1
jl="$(FLOW_PROJECT_ROOT="$SBL" "$PY" "$HARN" usage --json 2>/dev/null)"
# For global: roll up the global log into SBG's DB, then query it.
export HOME="$SBG/home"; export USERPROFILE="$SBG/home"; export FLOW_PROJECT_ROOT="$SBG"
mkdir -p "$SBG/.flow"
FLOW_PROJECT_ROOT="$SBG" HOME="$SBG/home" USERPROFILE="$SBG/home" "$PY" "$HARN" rollup --global >/dev/null 2>&1
jg="$(FLOW_PROJECT_ROOT="$SBG" HOME="$SBG/home" USERPROFILE="$SBG/home" "$PY" "$HARN" usage --global --json 2>/dev/null)"
# Both must report 00-idea dwell=7200s and 01-research dwell=3600s (identical reconstruction).
"$PY" - "$jl" "$jg" <<'PY'
import json, sys
ld = json.loads(sys.argv[1])['stage_dwell']
gd = json.loads(sys.argv[2])['stage_dwell']
local_d  = {x['stage']: x['avg_s'] for x in ld}
global_d = {x['stage']: x['avg_s'] for x in gd}
ok = (local_d == global_d
      and local_d.get('00-idea') == 7200.0
      and local_d.get('01-research') == 3600.0)
sys.exit(0 if ok else 1)
PY
if [ $? -eq 0 ]; then echo "  ok   [global dwell equals project-local dwell for new rows with stage_from]"; pass=$((pass+1));
else echo "  FAIL [global dwell diverges from project-local dwell] local=$jl global=$jg"; fail=$((fail+1)); fi
rm -rf "$SBL" "$SBG"

echo "17) PARTITION: legacy rows without stage_from infer dwell per (project,cycle_id) — no cross-cycle bleed; no crash"
PY="$(command -v python || command -v python3)"
SBP="$HERE/.dwell_part_$$"; rm -rf "$SBP"; mkdir -p "$SBP/.flow"
export FLOW_PROJECT_ROOT="$SBP"
# Two interleaved cycles A (dwell=1000s) and B (dwell=2000s) in the same project, NO stage_from.
# Rows are written in epoch_s order that interleaves A and B — ordering must not bleed A into B.
"$PY" - "$SBP/.flow/events.jsonl" <<'PY'
import json, sys
E = 1700000000
rows = [
    # cycle A enters 00-idea at E
    {"command":"next","cycle_id":"A","project":"P","stage_from":"","stage_to":"00-idea",    "epoch_s":E,       "ephemeral":0,"exit_code":0,"gate_pass":True},
    # cycle B enters 00-idea at E+100  (physically interleaved)
    {"command":"next","cycle_id":"B","project":"P","stage_from":"","stage_to":"00-idea",    "epoch_s":E+100,   "ephemeral":0,"exit_code":0,"gate_pass":True},
    # cycle A exits 00-idea at E+1000  -> dwell A = 1000s
    {"command":"next","cycle_id":"A","project":"P","stage_from":"","stage_to":"01-research","epoch_s":E+1000,  "ephemeral":0,"exit_code":0,"gate_pass":True},
    # cycle B exits 00-idea at E+2100  -> dwell B = 2000s
    {"command":"next","cycle_id":"B","project":"P","stage_from":"","stage_to":"01-research","epoch_s":E+2100,  "ephemeral":0,"exit_code":0,"gate_pass":True},
]
open(sys.argv[1],"w").write("\n".join(json.dumps(r) for r in rows)+"\n")
PY
FLOW_PROJECT_ROOT="$SBP" "$PY" "$HARN" rollup >/dev/null 2>&1
jp="$(FLOW_PROJECT_ROOT="$SBP" "$PY" "$HARN" usage --json 2>/dev/null)"
# Expect: 00-idea n=2, avg_s=1500 (mean of 1000 and 2000) — no cross-cycle bleed.
"$PY" - "$jp" <<'PY'
import json, sys
d  = json.loads(sys.argv[1])
sd = {x['stage']: x for x in d['stage_dwell']}
idea = sd.get('00-idea', {})
ok = idea.get('avg_s') == 1500.0 and idea.get('n') == 2
sys.exit(0 if ok else 1)
PY
if [ $? -eq 0 ]; then echo "  ok   [legacy-inferred dwell partitions by cycle_id: avg=1500s, n=2, no cross-cycle bleed]"; pass=$((pass+1));
else echo "  FAIL [legacy dwell cross-cycle bleed or wrong avg] json=$jp"; fail=$((fail+1)); fi
# Also verify legacy rows without stage_from do not crash the rollup (idempotent re-run).
has "$(FLOW_PROJECT_ROOT="$SBP" "$PY" "$HARN" rollup 2>/dev/null)" '"rolled": 0' "legacy rows without stage_from do not crash rollup (idempotent re-run)"
rm -rf "$SBP"

echo "18) CROSS-PROJECT BLEED: two projects sharing the same cycle_id get independent dwell (--global path)"
PY="$(command -v python || command -v python3)"
SBX="$HERE/.dwell_xproj_$$"; rm -rf "$SBX"; mkdir -p "$SBX/home/.claude/flow"
export HOME="$SBX/home"; export USERPROFILE="$SBX/home"; export FLOW_PROJECT_ROOT="$SBX"
# Project P, cycle A: 00-idea dwell = 500s  (enter=E, exit=E+500)
# Project Q, cycle A: 00-idea dwell = 9000s (enter=E+100, exit=E+9100)
# Same cycle_id "A" in both projects — old cyc_id-only keying merges them into n=1, avg=9100.
"$PY" - "$SBX/home/.claude/flow/usage.jsonl" <<'PY'
import json, sys
E = 1700000000
rows = [
    {"command":"next","cycle_id":"A","project":"P","stage_from":"",        "stage_to":"00-idea",    "epoch_s":E,       "ephemeral":0,"exit_code":0,"gate_pass":True},
    {"command":"next","cycle_id":"A","project":"Q","stage_from":"",        "stage_to":"00-idea",    "epoch_s":E+100,   "ephemeral":0,"exit_code":0,"gate_pass":True},
    {"command":"next","cycle_id":"A","project":"P","stage_from":"00-idea", "stage_to":"01-research","epoch_s":E+500,   "ephemeral":0,"exit_code":0,"gate_pass":True},
    {"command":"next","cycle_id":"A","project":"Q","stage_from":"00-idea", "stage_to":"01-research","epoch_s":E+9100,  "ephemeral":0,"exit_code":0,"gate_pass":True},
]
open(sys.argv[1],"w").write("\n".join(json.dumps(r) for r in rows)+"\n")
PY
mkdir -p "$SBX/.flow"
HOME="$SBX/home" USERPROFILE="$SBX/home" FLOW_PROJECT_ROOT="$SBX" "$PY" "$HARN" rollup --global >/dev/null 2>&1
jx="$(HOME="$SBX/home" USERPROFILE="$SBX/home" FLOW_PROJECT_ROOT="$SBX" "$PY" "$HARN" usage --global --json 2>/dev/null)"
# OLD bug (cyc_id-only keying, stage_from present so no inference path):
#   _enter["A"]["00-idea"] = E          (setdefault; Q's E+100 is a no-op — enters same bucket)
#   _exit["A"]["00-idea"]  = E+9100     (Q's row overwrites P's E+500)
#   -> single sample: eout-ein = 9100s, n=1, avg=9100
#
# FIXED (composite pkey=(project,cycle_id)):
#   P/A: enter=E, exit=E+500   -> 500s
#   Q/A: enter=E+100, exit=E+9100 -> 9000s
#   -> two samples: avg=4750s, n=2
# Assert n=2 and avg=4750 — old code yields n=1, avg=9100, so this assertion catches the bug.
"$PY" - "$jx" <<'PY'
import json, sys
d  = json.loads(sys.argv[1])
sd = {x['stage']: x for x in d['stage_dwell']}
idea = sd.get('00-idea', {})
ok = idea.get('n') == 2 and idea.get('avg_s') == 4750.0
if not ok:
    sys.stderr.write(f"00-idea n={idea.get('n')} avg_s={idea.get('avg_s')} (expected n=2, avg_s=4750.0)\n")
sys.exit(0 if ok else 1)
PY
if [ $? -eq 0 ]; then echo "  ok   [cross-project dwell: P=500s + Q=9000s -> avg=4750, n=2; no cross-project epoch bleed]"; pass=$((pass+1));
else echo "  FAIL [cross-project cycle_id bleed detected in --global dwell] json=$jx"; fail=$((fail+1)); fi
rm -rf "$SBX"

echo "14) a non-tmp.* project UNDER the system temp dir is tagged ephemeral (normalized path branch)"
TD="$(mktemp -d)"; TBASE="$(dirname "$TD")"; rm -rf "$TD"   # TBASE = real system temp dir (POSIX/Windows)
PP="$TBASE/realbuild_$$"; rm -rf "$PP"; mkdir -p "$PP"
FLOW_PROJECT_ROOT="$PP" bash "$RUN" status >/dev/null 2>&1
has "$(tail -1 "$PP/.flow/events.jsonl" 2>/dev/null)" '"ephemeral":1' "non-tmp.*-named project under the temp dir is ephemeral (path match survives Windows C:\\ vs /c/)"
rm -rf "$PP"

echo "19) C-012: build-intent vs diagnostic classification (read-time, retroactive)"
PY="$(command -v python || command -v python3)"
SBI="$HERE/.intentclass_$$"; rm -rf "$SBI"; mkdir -p "$SBI/.flow"
export FLOW_PROJECT_ROOT="$SBI"

# fixture: 3 cycles
# cycle D1 — diagnostic-only (status + doctor + usage; all read_only=true)
# cycle D2 — diagnostic-only with NULL read_only (legacy): classify by command name
# cycle B1 — build-intent: contains 'next' (non-read_only)
# cycle B2 — build-intent: contains 'assess' (non-read_only)
"$PY" - "$SBI/.flow/events.jsonl" <<'PY'
import json, sys
rows = [
    # cycle D1: diagnostic-only — read_only field present
    {"command":"status",  "cycle_id":"D1","project":"p","epoch_s":100,"exit_code":0,"gate_pass":None,"read_only":True,  "ephemeral":0},
    {"command":"doctor",  "cycle_id":"D1","project":"p","epoch_s":101,"exit_code":0,"gate_pass":None,"read_only":True,  "ephemeral":0},
    {"command":"usage",   "cycle_id":"D1","project":"p","epoch_s":102,"exit_code":0,"gate_pass":None,"read_only":True,  "ephemeral":0},
    # cycle D2: legacy — read_only field ABSENT (NULL), classify by command name
    {"command":"status",  "cycle_id":"D2","project":"p","epoch_s":200,"exit_code":0,"gate_pass":None,                  "ephemeral":0},
    {"command":"recall",  "cycle_id":"D2","project":"p","epoch_s":201,"exit_code":0,"gate_pass":None,                  "ephemeral":0},
    {"command":"coherence","cycle_id":"D2","project":"p","epoch_s":202,"exit_code":0,"gate_pass":None,                 "ephemeral":0},
    # cycle B1: build-intent — contains next (non-read_only, read_only field present)
    {"command":"status",  "cycle_id":"B1","project":"p","epoch_s":300,"exit_code":0,"gate_pass":None,"read_only":True, "ephemeral":0},
    {"command":"next",    "cycle_id":"B1","project":"p","epoch_s":301,"exit_code":0,"gate_pass":True,"read_only":False,"ephemeral":0},
    # cycle B2: build-intent — contains assess (non-read_only, read_only field present)
    {"command":"assess",  "cycle_id":"B2","project":"p","epoch_s":400,"exit_code":0,"gate_pass":None,"read_only":False,"ephemeral":0},
]
# write read_only as JSON null when the key is absent
out = []
for r in rows:
    if "read_only" not in r:
        r["read_only"] = None
    out.append(json.dumps(r))
open(sys.argv[1], "w").write("\n".join(out) + "\n")
PY

FLOW_PROJECT_ROOT="$SBI" "$PY" "$HARN" rollup >/dev/null 2>&1

# 19a: diagnostic-only cycle (D1) should NOT count as build-intent
ji="$(FLOW_PROJECT_ROOT="$SBI" "$PY" "$HARN" usage --json 2>/dev/null)"
# build-intent should be 2 (B1 + B2), diagnostic should be 2 (D1 + D2)
"$PY" - "$ji" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
ok = d.get("cycles_build_intent") == 2 and d.get("cycles_diagnostic_only") == 2 and d.get("cycles_started") == 4
sys.exit(0 if ok else 1)
PY
if [ $? -eq 0 ]; then echo "  ok   [19a: 2 build-intent + 2 diagnostic-only out of 4 total cycles]"; pass=$((pass+1));
else echo "  FAIL [19a: wrong build-intent/diagnostic-only split] json=$ji"; fail=$((fail+1)); fi

# 19b: text output carries the breakdown on the 'cycles started' line
tu="$(FLOW_PROJECT_ROOT="$SBI" "$PY" "$HARN" usage 2>/dev/null)"
has "$tu" "build-intent: 2" "19b: text output shows build-intent count"
has "$tu" "diagnostic-only: 2" "19b: text output shows diagnostic-only count"

# 19c: cycle with 'next' is build-intent (B1)
"$PY" - "$ji" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
# B1 contains 'next'; the JSON build count must be >=1 to confirm it's included
sys.exit(0 if d.get("cycles_build_intent", 0) >= 1 else 1)
PY
if [ $? -eq 0 ]; then echo "  ok   [19c: cycle containing 'next' is classified build-intent]"; pass=$((pass+1));
else echo "  FAIL [19c: 'next' cycle not counted as build-intent]"; fail=$((fail+1)); fi

# 19d: cycle with 'assess' is build-intent (B2)
"$PY" - "$ji" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
# B2 contains 'assess'; build count must be 2 to confirm both B1+B2 are included
sys.exit(0 if d.get("cycles_build_intent", 0) == 2 else 1)
PY
if [ $? -eq 0 ]; then echo "  ok   [19d: cycle containing 'assess' is classified build-intent]"; pass=$((pass+1));
else echo "  FAIL [19d: 'assess' cycle not counted as build-intent]"; fail=$((fail+1)); fi

# 19e: retroactive classification on legacy fixture (D2 has NULL read_only, classified by command name)
"$PY" - "$ji" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
# D2 must be diagnostic-only (coalesced from command names status/recall/coherence)
sys.exit(0 if d.get("cycles_diagnostic_only", 0) == 2 else 1)
PY
if [ $? -eq 0 ]; then echo "  ok   [19e: legacy rows without read_only field classified by command name (retroactive COALESCE)]"; pass=$((pass+1));
else echo "  FAIL [19e: legacy COALESCE by command name failed]"; fail=$((fail+1)); fi

# 19f: _ensure_cycle logging is unchanged — grep proves no intent-gate was added
ec_grep=0
grep -n '_ensure_cycle' "$HERE/../skills/flow/runner/flow.sh" | grep -qiE '(if|&&|\|\|).*(read.only|build|intent|diag)' && ec_grep=1 || ec_grep=0
if [ "$ec_grep" -eq 0 ]; then echo "  ok   [19f: _ensure_cycle has no intent-gate (FR2 intact)]"; pass=$((pass+1));
else echo "  FAIL [19f: _ensure_cycle appears to have an intent-gate added — FR2 violated]"; fail=$((fail+1)); fi

rm -rf "$SBI"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
