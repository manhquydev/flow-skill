#!/usr/bin/env bash
# Planning consumer: default-vs-explicit graph parity, real graph ordering,
# debt skips, gate authority and fail-closed runtime/checkpoint failures.
# Requires python. Run: bash tests/test_flow_graph_planning_parity.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
RUN="$HERE/../skills/flow/runner/flow.sh"
. "$HERE/fixture_path_lib.sh"
unset FLOW_GRAPH_EXECUTOR
PY="$(command -v python3 || command -v python)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]: $(printf '%.140s' "$1")"; fail=$((fail+1)); fi; }
no() { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] unexpected /$2/"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

# Make every stage file gate-clean: tick boxes and remove [FILL ...] spans (which are
# MULTI-LINE in the real templates, so a per-line regex cannot see the closing bracket).
fill_stages() { # $1 = dir holding flow/*.md
  "$PY" - "$1" <<'PYEOF'
import pathlib, re, sys
for f in sorted(pathlib.Path(sys.argv[1], "flow").glob("*.md")):
    t = f.read_text(encoding="utf-8")
    t = t.replace("- [ ]", "- [x]")
    t = re.sub(r"\[FILL.*?\]", "filled", t, flags=re.S)
    f.write_text(t, encoding="utf-8")
PYEOF
}

# Walk 00->05 in a sandbox, filling each stage so its gate passes.
walk() { # $1 = sandbox, $2 = "on"|"off" (explicit/default graph)
  local sb="$1" mode="$2" out="" line
  ( cd "$sb" && for i in 1 2 3 4 5 6 7; do
      if [ "$mode" = on ]; then FLOW_GRAPH_EXECUTOR=1 bash "$RUN" next; else bash "$RUN" next; fi
      rc=$?
      fill_stages "$sb"
      echo "step$i rc=$rc files=$(ls flow/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ',')"
    done )
}

echo "A) default vs explicit graph: identical transitions across the full ladder"
SB1="$(mktemp -d)"; SB2="$(mktemp -d)"
W1="$(walk "$SB1" off)"
W2="$(walk "$SB2" on)"
ck "$W1" "$W2" "every cmd_next step produces the same rc + same scaffolded files"
has "$W1" "05-contract.md" "the ladder reaches 05-contract"
rm -rf "$SB1" "$SB2"

echo "B) debt-skip: index advances, stage is NOT re-created, planning completes"
SB="$(mktemp -d)"; cd "$SB" || exit 1
# Walk to 02-scope so 03-prd has NOT been scaffolded yet - that is the real shape of a
# debt skip (you skip the stage before it is created, not after).
bash "$RUN" next >/dev/null 2>&1          # creates 00
for i in 1 2; do                           # creates 01, then 02
  fill_stages "$SB"
  bash "$RUN" next >/dev/null 2>&1
done
fill_stages "$SB"
ck "0" "$([ -f flow/03-prd.md ] && echo 1 || echo 0)" "03-prd not scaffolded yet (pre-skip state)"
printf -- '- [ ] DEBT: skip 03-prd -- small tool, no product surface -- close before: v2 -- opened 2026-07-26\n' > DEBT.md
SK="$(bash "$RUN" skip 03-prd --reason "small internal tool, no product surface" 2>&1)"
has "$SK" "debt-skipped" "cmd_skip accepts the debt-recorded skip"
ck "1" "$([ -f flow/04-adr.md ] && echo 1 || echo 0)" "cmd_skip scaffolds the SUCCESSOR (04-adr), never the skipped stage"
ck "0" "$([ -f flow/03-prd.md ] && echo 1 || echo 0)" "the skipped stage itself is not created"
fill_stages "$SB"
N1="$(bash "$RUN" next 2>&1)"
no  "$N1" "unlocked stage 3" "next does NOT re-scaffold the skipped 03-prd"
ck "0" "$([ -f flow/03-prd.md ] && echo 1 || echo 0)" "03-prd.md still absent after next (skip respected)"
has "$N1" "05-contract\|already exists" "next advanced past the skip to 05-contract"
fill_stages "$SB"
N2="$(bash "$RUN" next 2>&1)"
has "$N2" "Planning is COMPLETE" "planning_complete() true with a debt-skipped stage"
CARD="$(bash "$RUN" card 2>&1)"
no "$CARD" "planning not complete" "/flow card unlocks after the skip"
ST="$(bash "$RUN" status 2>&1)"
has "$ST" "04-adr\|05-contract" "status reports a post-skip stage, not the pinned pre-skip one"
cd /; rm -rf "$SB"

echo "B2) forward skip whose successor file is gone still advances (no permanent no-op)"
SBF="$(mktemp -d)"; cd "$SBF" || exit 1
bash "$RUN" next >/dev/null 2>&1
for i in 1 2; do fill_stages "$SBF"; bash "$RUN" next >/dev/null 2>&1; done
fill_stages "$SBF"
printf -- '- [ ] DEBT: skip 03-prd -- small tool -- close before: v2 -- opened 2026-07-27\n' > DEBT.md
bash "$RUN" skip 03-prd --reason "small internal tool" >/dev/null 2>&1
rm -f flow/04-adr.md          # cmd_skip scaffolded it; simulate a failed/undone scaffold
OUTF="$(bash "$RUN" next 2>&1)"
has "$OUTF" "unlocked stage 4" "next walks PAST the skipped stage to the first real one"
ck "1" "$([ -f flow/04-adr.md ] && echo 1 || echo 0)" "04-adr scaffolded (project not wedged)"
ck "0" "$([ -f flow/03-prd.md ] && echo 1 || echo 0)" "the skipped stage is still not re-created"
cd /; rm -rf "$SBF"
cd "$SB" 2>/dev/null || cd /

echo "C) executor mode records planning boundaries in the planning lane"
SB="$(mktemp -d)"; cd "$SB" || exit 1
unset FLOW_GRAPH_EXECUTOR
bash "$RUN" next >/dev/null 2>&1
for i in 1 2; do
  fill_stages "$SB"
  bash "$RUN" next >/dev/null 2>&1
done
K="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print("|".join(f"{k}:{n}" for k,n in c.execute(
  "SELECT e.kind, COUNT(cp.checkpoint_id) FROM graph_execution e "
  "LEFT JOIN graph_checkpoint cp ON cp.execution_id=e.id GROUP BY e.kind ORDER BY e.kind")))
EOF
)"
has "$K" "planning:" "a planning-lane execution exists"
NSR="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT COUNT(*) FROM graph_checkpoint WHERE ns=''").fetchone()[0])
EOF
)"
[ "$NSR" -ge 1 ]; ck 0 $? "stage boundaries journaled in the root namespace ($NSR)"
NODES="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(",".join(r[0] for r in c.execute(
  "SELECT node FROM graph_checkpoint WHERE ns='' ORDER BY checkpoint_id")))
EOF
)"
has "$NODES" "stage-0" "recorded node ids are topology stage nodes"
BEFORE_N="$(printf '%s' "$NODES" | tr ',' '\n' | grep -c .)"
bash "$RUN" next >/dev/null 2>&1; bash "$RUN" next >/dev/null 2>&1
AFTER_N="$("$PY" - "$SB/.flow/harness.db" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT COUNT(*) FROM graph_checkpoint WHERE ns=''").fetchone()[0])
EOF
)"
ck "$BEFORE_N" "$AFTER_N" "re-running next with unchanged evidence records NOTHING (boundary, not heartbeat)"

echo "C2) a blocked earlier stage is never journaled as planning-complete"
SBB="$(mktemp -d)"; cd "$SBB" || exit 1
export FLOW_GRAPH_EXECUTOR=1
bash "$RUN" next >/dev/null 2>&1
for i in 1 2 3 4 5; do
  fill_stages "$SBB"
  bash "$RUN" next >/dev/null 2>&1
done
fill_stages "$SBB"          # 05-contract was created by the last next; make it clean too
# now re-block an EARLIER stage: the current stage passes, an earlier one does not
printf '\n- [ ] deliberately unchecked\n' >> flow/02-scope.md
OUTB="$(bash "$RUN" next 2>&1)"
has "$OUTB" "earlier stage is still BLOCKED" "flow.sh reports the blocked earlier stage"
BLOCK_STATUS="$(bash "$RUN" status 2>&1)"
no "$BLOCK_STATUS" "planning complete. '/flow card' is unlocked" "status never claims completion over an earlier blocked gate"
PEID="$(FLOW_PROJECT_ROOT="$SBB" "$PY" "$H" graph session --kind planning)"
GN="$(FLOW_PROJECT_ROOT="$SBB" "$PY" "$H" graph next --execution "$PEID" 2>/dev/null)"; grc=$?
[ -n "$GN" ]; ck 0 $? "executor advises a real node (non-empty) for a blocked project"
ck "0" "$grc" "graph next still advises a node (rc 0), never rc 3 while blocked"
unset FLOW_GRAPH_EXECUTOR
cd /; rm -rf "$SBB"
cd "$SB" || exit 1
export FLOW_GRAPH_EXECUTOR=1
unset FLOW_GRAPH_EXECUTOR
cd /; rm -rf "$SB"

echo "D) fail-closed: harness disabled never fabricates progress"
SB="$(mktemp -d)"; cd "$SB" || exit 1
D1="$(FLOW_GRAPH_EXECUTOR=1 FLOW_HARNESS_DISABLE=1 bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "disabled harness refuses product operations"
has "$D1" "Unset it; see docs/migration-v1.md" "disable refusal is actionable"
ck "0" "$([ -d flow ] && echo 1 || echo 0)" "startup refusal creates no locks or stage directory"
ck "0" "$([ -d .flow ] && echo 1 || echo 0)" "startup refusal does not write EXIT telemetry"
ck "0" "$([ -f .flow/harness.db ] && echo 1 || echo 0)" "no DB minted when the harness is disabled"
for verb in status resume ready assess card check gate mode project-type skip workspace loop-prep loop-log auto attest recall unlock retro harness debt design contract tokens coherence consistency constitution clarify converge promote eval usage rules; do
  REFUSED="$(FLOW_HARNESS_DISABLE=disabled bash "$RUN" "$verb" 2>&1)"; rc=$?
  ck 1 "$rc" "nonempty disable refuses product verb $verb"
  has "$REFUSED" 'FLOW_HARNESS_DISABLE is no longer supported' "$verb refusal occurs before argument parsing or product writes"
done
OPT_OUT="$(FLOW_GRAPH_EXECUTOR=0 bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "explicit graph opt-out refuses product operations"
has "$OPT_OUT" 'docs/migration-v1.md' "graph opt-out refusal points to migration guide"
ck no "$([ -d flow ] && echo yes || echo no)" "graph opt-out cannot scaffold"
cd /; rm -rf "$SB"

echo "E) required checkpoint, pause and topology failures never scaffold"
SB="$(mktemp -d)"; cd "$SB" || exit 1
bash "$RUN" next >/dev/null 2>&1; fill_stages "$SB"
FAIL_REC="$(FLOW_GRAPH_FAILPOINT=before-commit bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "real aborted planning checkpoint propagates failure"
no "$FAIL_REC" 'PASS:' "failed checkpoint emits no progression PASS"
ck no "$([ -f flow/01-research.md ] && echo yes || echo no)" "record failure cannot scaffold successor"
PEID="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph session --kind planning)"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph record --execution "$PEID" --node stage-00 \
  --interrupt --prompt review >/dev/null 2>&1
PAUSE="$(bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "real rc3 paused execution is not completion"
no "$PAUSE" 'Planning is COMPLETE\|PASS:' "pause never claims completion or progression"
for verb in status resume ready; do
  DIAG="$(bash "$RUN" "$verb" --json 2>&1)"; rc=$?
  ck 1 "$rc" "$verb refuses paused planning instead of advertising readiness"
done
ck no "$([ -f flow/01-research.md ] && echo yes || echo no)" "pause cannot scaffold successor"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph abandon --execution "$PEID" >/dev/null
PEID="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph session --kind planning)"
"$PY" - "$SB/.flow/harness.db" "$PEID" <<'PYEOF'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.execute("UPDATE graph_execution SET topology_hash='outdated' WHERE id=?", (sys.argv[2],))
c.commit()
PYEOF
MISMATCH="$(bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "real topology hash mismatch refuses progression"
has "$MISMATCH" 'hash mismatch' "topology refusal retains recovery guidance"
ck no "$([ -f flow/01-research.md ] && echo yes || echo no)" "mismatch cannot scaffold successor"
has "$MISMATCH" 'force-retopology' "runner surfaces explicit topology recovery flag"
RECOVER="$(bash "$RUN" next --force-retopology 2>&1)"; rc=$?
ck 0 "$rc" "runner forwards explicit force-retopology and advances"
ck yes "$([ -f flow/01-research.md ] && echo yes || echo no)" "explicit topology recovery scaffolds graph successor"
PINNED="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph status --execution "$PEID")"
REPINNED="$(printf '%s' "$PINNED" | "$PY" -c 'import json,sys; print(json.load(sys.stdin)["execution"]["topology_hash"] != "outdated")')"
ck True "$REPINNED" "runner recovery re-pins the execution topology"
cd /; rm -rf "$SB"

echo "F) real shipped-topology mapping, not legacy integer successor, determines ordering"
SB="$(mktemp -d)"; cp -R "$HERE/../skills/flow" "$SB/install"
"$PY" - "$SB/install" <<'PYEOF'
import hashlib, json, pathlib, sys
p = pathlib.Path(sys.argv[1])
f = p / "references/flow-topology.json"
t = json.loads(f.read_text())
# Keep the same valid nodes but make the planning chain 00 -> 02 -> 01 -> 03.
for edge in t["edges"]:
    if edge["from"] == "stage-00": edge["to"] = "stage-02"
    elif edge["from"] == "stage-02": edge["to"] = "stage-01"
    elif edge["from"] == "stage-01": edge["to"] = "stage-03"
f.write_text(json.dumps(t))
canonical = json.dumps(t, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
(p / "harness/pins/flow-topology.sha256").write_text(hashlib.sha256(canonical).hexdigest() + "\n")
PYEOF
mkdir "$SB/project"; cd "$SB/project" || exit 1
bash "$SB/install/runner/flow.sh" next >/dev/null 2>&1; fill_stages "$SB/project"
ORDER="$(bash "$SB/install/runner/flow.sh" next 2>&1)"; rc=$?
ck 0 "$rc" "runner follows a real verified alternate planning order"
ck yes "$([ -f flow/02-scope.md ] && echo yes || echo no)" "graph-selected stage 02 is scaffolded after stage 00"
ck no "$([ -f flow/01-research.md ] && echo yes || echo no)" "legacy integer successor stage 01 is NOT scaffolded"
mv "$SB/install/harness/flow_harness.py" "$SB/install/harness/flow_harness.saved"
MISSING_H="$(bash "$SB/install/runner/flow.sh" next 2>&1)"; rc=$?
ck 1 "$rc" "missing required harness refuses startup"
has "$MISSING_H" 'required harness missing' "missing harness refusal tells operator to reinstall"
HELP="$(bash "$SB/install/runner/flow.sh" --help 2>&1)"; rc=$?
ck 0 "$rc" "missing harness does not remove help"
cd /; rm -rf "$SB"

echo "G) chained skips, existing-file preservation and non-skippable terminal"
SB="$(mktemp -d)"; cd "$SB" || exit 1
mkdir flow
printf '00-idea\n01-research\n02-scope\n03-prd\n04-adr\n' > flow/.skipped
CHAIN="$(bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "all skippable entry stages can be skipped in one graph walk"
ck yes "$([ -f flow/05-contract.md ] && echo yes || echo no)" "non-skippable contract remains required"
fill_stages "$SB"
BEFORE="$(cat flow/05-contract.md)"
CHAIN="$(bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "all debt-skipped predecessors plus clean contract complete"
has "$CHAIN" 'Planning is COMPLETE' "terminal graph result agrees with gate completion"
ck "$BEFORE" "$(cat flow/05-contract.md)" "existing stage contents are never overwritten"
SKIP05="$(bash "$RUN" skip 05-contract --reason small 2>&1)"; rc=$?
ck 1 "$rc" "05-contract skip refusal preserved"
SEC="$(bash "$RUN" skip 03-prd --reason 'auth boundary' 2>&1)"; rc=$?
ck 1 "$rc" "security-class skip HALT preserved"
has "$SEC" 'HALT' "security HALT is explicit"
cd /; rm -rf "$SB"

echo "G2) a valid skip cannot scaffold past an earlier blocked gate"
SB="$(mktemp -d)"; cd "$SB" || exit 1
bash "$RUN" next >/dev/null 2>&1
printf -- '- [ ] DEBT: skip 02-scope -- small tool -- close before: v2\n' > DEBT.md
BLOCK_SKIP="$(bash "$RUN" skip 02-scope --reason 'small tool' 2>&1)"; rc=$?
ck 1 "$rc" "valid debt skip reports earlier gate refusal"
has "$BLOCK_SKIP" 'debt-skipped (logged)' "valid skip is still recorded under DEBT governance"
has "$BLOCK_SKIP" 'gate for stage 00-idea is not clean' "earlier blocked stage remains the gate authority"
no "$BLOCK_SKIP" 'PASS:' "valid skip plus blocked predecessor cannot emit progression PASS"
ck no "$([ -f flow/03-prd.md ] && echo yes || echo no)" "valid skip cannot scaffold its successor over blocked predecessor"
INSPECT="$(printf '# inspect\n- [ ] assess first\n' > flow/00-inspect.md; bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "brownfield assessment remains a prerequisite"
has "$INSPECT" 'brownfield assessment gate' "brownfield gate refusal is explicit"
cd /; rm -rf "$SB"

echo "H) interpreter floor, stubs, Python-only fallback and diagnostic survival"
SB="$(mktemp -d)"; mkdir "$SB/bin" "$SB/project"
# A controlled PATH retains shell utilities but deliberately excludes both Python names.
for tool in bash dirname pwd tr uname hostname date git head tail sed grep awk mkdir cat wc sort cut rm sleep timeout env; do
  loc="$(type -P "$tool" 2>/dev/null || true)"
  [ -n "$loc" ] && fixture_forward_tool "$SB/bin" "$tool" "$loc"
done
cd "$SB/project" || exit 1
for mode in missing old stub; do
  case "$mode" in
    old) printf '#!/bin/sh\necho unsupported\n' > "$SB/bin/python3"; chmod +x "$SB/bin/python3" ;;
    stub) printf '#!/bin/sh\nexit 0\n' > "$SB/bin/python3"; chmod +x "$SB/bin/python3" ;;
  esac
  START="$(PATH="$SB/bin" bash "$RUN" next 2>&1)"; rc=$?
  ck 1 "$rc" "$mode Python refuses before startup writes"
  has "$START" 'working Python >=3.7' "$mode Python diagnostic names measured floor"
  HELP="$(PATH="$SB/bin" bash "$RUN" --help 2>&1)"; rc=$?
  ck 0 "$rc" "$mode Python help survives"
  DOC="$(PATH="$SB/bin" bash "$RUN" doctor --check python 2>&1)"; rc=$?
  ck 1 "$rc" "$mode Python doctor reports failing runtime"
done
ck no "$([ -d .flow ] && echo yes || echo no)" "refused runtime and diagnostics do not write telemetry"
ck no "$([ -d flow ] && echo yes || echo no)" "refused runtime and diagnostics do not create locks"
fixture_add_python "$SB/bin" python "$PY"
FALLBACK="$(PATH="$SB/bin" FLOW_LIB_ONLY=1 bash -c '. "$1"; _python' _ "$RUN")"; rc=$?
ck 0 "$rc" "broken python3 does not mask working python"
ck "$SB/bin/python" "$FALLBACK" "working python-only interpreter selected"
PY_ONLY="$(PATH="$SB/bin" FLOW_LIB_ONLY=1 bash -c '. "$1"; _runtime_required' _ "$RUN" 2>&1)"; rc=$?
ck 0 "$rc" "working python-only runtime starts the real harness"
OPTOUT="$(FLOW_GRAPH_EXECUTOR=0 bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "explicit graph opt-out refuses instead of restoring legacy ordering"
HELP="$(FLOW_HARNESS_DISABLE=1 bash "$RUN" --help 2>&1)"; rc=$?
ck 0 "$rc" "disabled harness help survives"
DOC="$(FLOW_HARNESS_DISABLE=1 bash "$RUN" doctor --check harness 2>&1)"; rc=$?
ck 1 "$rc" "disabled harness doctor reports actionable refusal"
cd /; rm -rf "$SB"

echo "I) simulated adapter rc4, error, empty value, unknown node and timeout fail closed"
SB="$(mktemp -d)"
for mode in unavailable failure empty unknown timeout session; do
  SIM="$(FLOW_LIB_ONLY=1 FLOW_PROJECT_ROOT="$SB/$mode" bash -c '
    mkdir -p "$FLOW_PROJECT_ROOT"
    . "$1"
    mode="$2"
    harness_capture_checked() {
      case "$2" in
        session) [ "$mode" = session ] && return 1; echo test-execution ;;
        next)
          case "$mode" in
            unavailable) return 4 ;; failure) return 2 ;; empty) return 0 ;;
            unknown) echo not-a-stage ;; timeout) echo "flow-harness: call timed out" >&2; return 4 ;;
          esac ;;
      esac
    }
    cmd_next
  ' _ "$RUN" "$mode" 2>&1)"; rc=$?
  ck 1 "$rc" "simulated $mode adapter cannot progress"
  no "$SIM" 'PASS:' "simulated $mode adapter cannot emit PASS"
  ck no "$([ -f "$SB/$mode/flow/00-idea.md" ] && echo yes || echo no)" "simulated $mode adapter cannot scaffold"
done
cd /; rm -rf "$SB"

echo "J) bounded transport maps an actual timed-out harness to unavailable"
SB="$(mktemp -d)"
printf 'import time\ntime.sleep(5)\n' > "$SB/sleep.py"
TIMED="$(FLOW_LIB_ONLY=1 FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_TIMEOUT=0.1 bash -c '
  . "$1"; HARNESS_PY="$2"; harness_capture_checked graph next --execution timeout
' _ "$RUN" "$SB/sleep.py" 2>&1)"; rc=$?
ck 4 "$rc" "actual harness transport timeout returns unavailable rc4"
has "$TIMED" 'call timed out' "actual timeout is actionable rather than silent"
TIMED="$(FLOW_LIB_ONLY=1 FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_TIMEOUT=0.1 bash -c '
  . "$1"; HARNESS_PY="$2"
  command() { case "${2:-}" in timeout|gtimeout) return 1 ;; esac; builtin command "$@"; }
  harness_capture_checked graph next --execution timeout
' _ "$RUN" "$SB/sleep.py" 2>&1)"; rc=$?
ck 4 "$rc" "stdlib fallback actually bounds the harness without timeout/gtimeout"
has "$TIMED" 'call timed out' "stdlib fallback timeout remains explicit"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
