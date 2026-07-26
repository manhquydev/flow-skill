#!/usr/bin/env bash
# Topology lint (Phase 3): shipped topology passes (incl. pin); every lint rule has a
# seeded failing fixture; the shipped cmds smoke-execute as gate verdicts with ZERO
# harness writes; the default no-skip walk equals the legacy 00->05 ladder.
# Run: bash tests/test_flow_graph_lint.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
RUN="$HERE/../skills/flow/runner/flow.sh"
TOPO="$HERE/../skills/flow/references/flow-topology.json"
PY="$(command -v python || command -v python3)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]: $(printf '%.120s' "$1")"; fail=$((fail+1)); fi; }
SB="$(mktemp -d)"

echo "A) shipped topology: lint-clean including the pin"
OUT="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph lint)"
ck 0 $? "graph lint (no args) exits 0 on the shipped topology"
has "$OUT" '"ok": true' "reports ok + canonical hash"

echo "B) seeded fixtures: one per lint rule"
mkfix() { printf '%s' "$2" > "$SB/$1"; }
lint_rc() { FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph lint --topology "$SB/$1" >/dev/null 2>&1; echo $?; }
lint_err() { FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph lint --topology "$SB/$1" 2>&1 >/dev/null; }
BASE_NODES='"s0":{"type":"gate_check","stage":"00-idea"},"s1":{"type":"gate_check","stage":"01-research"}'

mkfix f01.json '{"topology_version":1,"nodes":{'"$BASE_NODES"'},"edges":[{"from":"s0","to":"s1"}]}'
ck 1 "$(lint_rc f01.json)" "missing entry rejected"
mkfix f02.json '{"topology_version":1,"entry":["s0"],"nodes":{'"$BASE_NODES"'},"edges":[{"from":"s0","to":"ghost"}]}'
has "$(lint_err f02.json)" "unknown node ref" "unknown edge ref rejected"
mkfix f03.json '{"topology_version":1,"entry":["s0"],"nodes":{'"$BASE_NODES"'},"edges":[{"from":"s0","to":"s1","when":"reviewgreen"}]}'
has "$(lint_err f03.json)" "unregistered predicate" "unregistered predicate rejected"
mkfix f04.json '{"topology_version":1,"entry":["s0"],"nodes":{'"$BASE_NODES"'},"edges":[{"from":"s0","to":"s1"},{"from":"s1","to":"s0"}]}'
has "$(lint_err f04.json)" "planning subgraph cycle" "planning cycle rejected"
mkfix f05.json '{"topology_version":1,"entry":["a"],"nodes":{"a":{"type":"record_evidence"},"b":{"type":"record_evidence"}},"edges":[{"from":"a","to":"b"},{"from":"b","to":"a"}]}'
has "$(lint_err f05.json)" "unbounded cycle" "cycle without max_visits rejected"
mkfix f06.json '{"topology_version":1,"entry":["s0"],"nodes":{'"$BASE_NODES"',"orphan":{"type":"record_evidence"}},"edges":[{"from":"s0","to":"s1"}]}'
has "$(lint_err f06.json)" "unreachable" "unreachable node rejected"
mkfix f07.json '{"topology_version":1,"entry":["s0"],"nodes":{"s0":{"type":"llm_magic"}},"edges":[]}'
has "$(lint_err f07.json)" "type outside" "node type outside enum rejected"
mkfix f08.json '{"topology_version":1,"entry":["s0"],"nodes":{"s0":{"type":"gate_check","stage":"00-idea","cmd":["bash","x"]}},"edges":[]}'
has "$(lint_err f08.json)" "outside {flow.sh, git}" "argv0 outside allowlist rejected"
mkfix f09.json '{"topology_version":1,"entry":["s0"],"nodes":{"s0":{"type":"gate_check","stage":"00-idea","cmd":["flow.sh","check","{card}"]}},"edges":[]}'
has "$(lint_err f09.json)" "banned in autonomous cmd position" "mutating Must-ask verb (check) banned"
mkfix f10.json '{"topology_version":1,"entry":["s0"],"nodes":{"s0":{"type":"gate_check","stage":"00-idea","cmd":["flow.sh","gate","99-bogus"]}},"edges":[]}'
has "$(lint_err f10.json)" "arg shape" "gate arg outside STAGES rejected"
mkfix f11.json '{"topology_version":1,"entry":["s0"],"nodes":{"s0":{"type":"gate_check","stage":"00-idea","cmd":["flow.sh","gate","{stage}"]}},"edges":[]}'
has "$(lint_err f11.json)" "unknown placeholder" "placeholder outside {card} rejected"
mkfix f12.json '{"topology_version":1,"entry":["c"],"nodes":{"c":{"type":"gate_check","stage":"02-scope"},"d":{"type":"gate_check"},"e":{"type":"gate_check","stage":"05-contract"}},"edges":[{"from":"c","to":"d"},{"from":"d","to":"e"}]}'
has "$(lint_err f12.json)" "needs a .stage." "planning gate_check without stage rejected"
mkfix f13.json '{"topology_version":1,"entry":["c"],"nodes":{"c":{"type":"record_evidence"},"r":{"type":"gate_check","stage":"02-scope"}},"edges":[{"from":"c","to":"r"}]}'
has "$(lint_err f13.json)" "must not declare" "card-subgraph gate_check with a stage rejected (would be debt-skippable)"
mkfix f14.json '{"topology_version":1,"entry":["s0"],"nodes":{'"$BASE_NODES"',"s5":{"type":"gate_check","stage":"05-contract"}},"edges":[{"from":"s0","to":"s1"},{"from":"s1","to":"s5","when":"review_red"}]}'
has "$(lint_err f14.json)" "reachable when skipped\|green-stranded" "skip-powerset dead-end rejected (skipped 01 only exits red)"
mkfix f15.json '{"topology_version":1,"entry":["d"],"nodes":{"d":{"type":"record_evidence"},"r":{"type":"gate_check"},"m":{"type":"git_op"}},"edges":[{"from":"d","to":"r"},{"from":"r","to":"m","when":"review_red"}]}'
has "$(lint_err f15.json)" "green-stranded" "gate whose only exit is red-guarded rejected (would false-complete on green)"
"$PY" - "$TOPO" > "$SB/f16.json" <<'EOF'
import json,sys
t=json.load(open(sys.argv[1])); t["topology_version"]=99
print(json.dumps(t))
EOF
P16="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph lint --topology "$SB/f16.json" --pin "$HDIR/pins/flow-topology.sha256" 2>&1 >/dev/null)"; RC16=$?
ck 1 "$RC16" "lint-clean copy with a semantic edit vs the REAL pin exits 1"
has "$P16" "pin mismatch" "the failure IS the pin mismatch (not another rule)"
PM="$("$PY" - "$HDIR" "$SB" <<'EOF'
import os,sys
sys.path.insert(0, sys.argv[1])
import graph_executor as G
bad=os.path.join(sys.argv[2],"bad.pin"); open(bad,"w").write("0"*64+"  flow-topology.json\n")
G.TOPOLOGY_PIN=bad
try:
    G.load_topology_trusted(); print("no-raise")
except ValueError as e:
    print("refused" if "pin mismatch" in str(e) else f"wrong: {e}")
EOF
)"
ck "refused" "$PM" "trusted loader refuses on pin mismatch (default execution path)"

echo "C) smoke: every shipped cmd executes as a gate verdict, zero harness writes"
SM="$(mktemp -d)"
CMDS="$("$PY" - "$TOPO" <<'EOF'
import json,sys
t=json.load(open(sys.argv[1]))
for spec in t["nodes"].values():
    c=spec.get("cmd")
    if c: print(" ".join(x.replace("{card}","C-001") for x in c[2:]))
EOF
)"
smoke_fail=0
while IFS= read -r args; do
  [ -z "$args" ] && continue
  OUT="$(cd "$SM" && FLOW_HARNESS_DB="$SM/none.db" bash "$RUN" gate $args 2>&1)"; rc=$?
  case "$rc" in 0|1) : ;; *) smoke_fail=1; echo "  smoke rc=$rc for: gate $args :: $OUT" ;; esac
  case "$OUT" in *usage:*) smoke_fail=1; echo "  smoke usage-error for: gate $args" ;; esac
done <<EOF2
$CMDS
EOF2
ck 0 "$smoke_fail" "all shipped cmds return gate verdicts (0/1), never usage errors"
[ ! -f "$SM/none.db" ]; ck 0 $? "smoke wrote zero harness rows (gate is pure bash)"
rm -rf "$SM"

echo "D) default no-skip walk == legacy ladder"
W="$("$PY" - "$TOPO" <<'EOF'
import json,sys
t=json.load(open(sys.argv[1]))
seq, cur = [], "stage-00"
while cur:
    seq.append(cur)
    nxt=[e["to"] for e in t["edges"] if e["from"]==cur and e.get("when","always")=="always"]
    cur=nxt[0] if nxt else None
print("->".join(seq))
EOF
)"
ck "stage-00->stage-01->stage-02->stage-03->stage-04->stage-05" "$W" "linear default path reproduced exactly"

echo "E) topology-hash policy: skill upgrade refuses, --force-retopology forks on"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
EOLD="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph run --kind planning --topology-hash deadbeef)"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph next --execution "$EOLD" >/dev/null 2>&1
ck 1 $? "next on an execution pinned to an older topology refuses"
E1="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph next --execution "$EOLD" 2>&1 >/dev/null)"
has "$E1" "force-retopology" "refusal names the escape hatch"
N="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph next --execution "$EOLD" --force-retopology)"
ck 0 $? "--force-retopology proceeds"
ck "stage-00" "$N" "walk continues on the current topology"
HN="$("$PY" - "$SB/.flow/harness.db" "$EOLD" <<'EOF'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("SELECT topology_hash FROM graph_execution WHERE id=?",(sys.argv[2],)).fetchone()[0][:8])
EOF
)"
# Derive the expected prefix from the shipped pin: hardcoding it would make every
# intentional topology edit look like a test failure.
EXPH="$(cut -c1-8 < "$HDIR/pins/flow-topology.sha256")"
ck "$EXPH" "$HN" "execution re-pinned to the shipped topology hash"
"$PY" - "$TOPO" > "$SB/tfix.json" <<'EOF'
import json,sys; print(open(sys.argv[1]).read())
EOF
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph next --execution "$EOLD" --topology "$SB/tfix.json" >/dev/null 2>&1
ck 2 $? "--topology without FLOW_GRAPH_TOPOLOGY_FIXTURE=1 refused (trust-model gate)"

echo "F) shipped topology through the executor: default path + debt-skip substitution"
E2="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph run --kind planning)"
mkdir -p "$SB/flow"; printf '03-prd\n' > "$SB/flow/.skipped"
for n in stage-00 stage-01 stage-02; do
  FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph record --execution "$E2" --node "$n" \
    --manifest '{"gate":{"exit":0}}' >/dev/null
done
NF="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph next --execution "$E2")"
ck "stage-04" "$NF" "pin-verified SHIPPED topology walks the debt-skip via plan_next"
rm -f "$SB/flow/.skipped"

rm -rf "$SB"
echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
