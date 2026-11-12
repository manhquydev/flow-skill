#!/usr/bin/env bash
# Tests for flow ready --json and flow auto --parallel.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
unset FLOW_HARNESS_DISABLE
export FLOW_LOG_DISABLE=1
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -qE "$2"; then echo "  FAIL [$3]"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

setup_green() {
  SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
  mkdir -p "$SB/flow" "$SB/cards" "$SB/bin"
  for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
    printf '# %s\n## Gate\n- [x] ok\n\nbody %s\n' "$s" "$s" > "$SB/flow/$s.md"
  done
  printf '# C-001\nstatus: todo\ndeps: none\nimplements: none\nrisk: standard\nrisk-reason: ordinary non-security work\nrisk-ack: none\n## Scope\none\n## Allowed files\nbin/\n## Verify\n- [x] ok\n## Done-evidence\ncli\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$SB/cards/C-001.md"
  cat > "$SB/bin/semantic_owner.sh" <<'EOS'
#!/usr/bin/env bash
set -u
fp=""; while [ $# -gt 0 ]; do case "$1" in --subject-fingerprint) shift; fp="${1:-}";; esac; shift 2>/dev/null || true; done
printf 'schema: flow-semantic-result/v1\nsubject_fingerprint: %s\nverdict: pass\ncritical_count: 0\nhigh_count: 0\nevidence_ref: none\n' "$fp"
EOS
  cat > "$SB/bin/live_probe.sh" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS
  cat > "$SB/bin/live_oracle.sh" <<'EOS'
#!/usr/bin/env bash
set -u
rev=""; while [ $# -gt 0 ]; do case "$1" in --subject-revision) shift; rev="${1:-}";; esac; shift 2>/dev/null || true; done
printf '%s\n' "$rev"
EOS
  chmod +x "$SB/bin/"*.sh
  cat > "$SB/bin/owner_stage.txt" <<EOF
schema: flow-attestation-owner/v1
kind: semantic_gate
subject_id: 05-contract
target_id: none
command: repo:bin/semantic_owner.sh
revision_oracle: none
EOF
  git -C "$SB" init -q
  git -C "$SB" config user.email "t@example.com"
  git -C "$SB" config user.name "T"
  git -C "$SB" add -A && git -C "$SB" commit -qm init
}

echo "A) ready --bogus -> exit 2"
setup_green
out="$(bash "$RUN" ready --bogus 2>&1)"; rc=$?
ck 2 "$rc" "ready --bogus rc 2"
has "$out" 'usage: /flow ready' "ready usage output"
rm -rf "$SB"

echo "B) planning incomplete: ready --json -> exit 1"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
mkdir -p "$SB/.flow"
git -C "$SB" init -q
git -C "$SB" config user.email "t@example.com"
git -C "$SB" config user.name "T"
git -C "$SB" commit --allow-empty -qm init
out="$(bash "$RUN" ready --json 2>&1)"; rc=$?
ck 1 "$rc" "planning incomplete ready --json rc 1"
has "$out" '"kind":"ready.report"' "kind ready.report"
has "$out" '"planning_complete":false' "planning_complete false"
rm -rf "$SB"

echo "C) prose parity on green setup"
setup_green
out="$(bash "$RUN" ready 2>&1)"; rc=$?
ck 0 "$rc" "ready prose rc 0"
has "$out" 'BUILDABLE C-001' "contains BUILDABLE C-001"
has "$out" '^      allowed: bin/' "contains line exactly allowed: bin/"
rm -rf "$SB"

echo "D) ready --json on green setup"
setup_green
out="$(bash "$RUN" ready --json 2>&1)"; rc=$?
ck 0 "$rc" "ready --json rc 0"
py_res="$(python3 -c '
import sys, json
try:
    d = json.loads(sys.argv[1])
    assert d.get("kind") == "ready.report", "bad kind: %s" % d.get("kind")
    b = d.get("buildable", [])
    assert len(b) == 1, "bad buildable len: %s" % len(b)
    assert b[0]["id"] == "C-001", "bad id: %s" % b[0].get("id")
    assert b[0]["deps"] == [], "bad deps: %s" % b[0].get("deps")
    assert b[0]["allowed_files"] == ["bin/"], "bad allowed: %s" % b[0].get("allowed_files")
    assert b[0]["wave"] == 1, "bad wave: %s" % b[0].get("wave")
    assert d.get("groups") == [["C-001"]], "bad groups: %s" % d.get("groups")
    assert d.get("auto") == "INACTIVE", "bad auto: %s" % d.get("auto")
    assert d.get("parallel_policy") is False, "bad parallel_policy: %s" % d.get("parallel_policy")
    print("OK")
except Exception as e:
    print("ERR: %s" % e)
' "$out")"
ck "OK" "$py_res" "python3 json assertions"
rm -rf "$SB"

echo "E) waves partition"
setup_green
printf '# C-002\nstatus: todo\ndeps: none\nimplements: none\nrisk: standard\nrisk-reason: ordinary non-security work\nrisk-ack: none\n## Scope\ntwo\n## Allowed files\nbin/\n## Verify\n- [x] ok\n## Done-evidence\ncli\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$SB/cards/C-002.md"
printf '# C-003\nstatus: todo\ndeps: none\nimplements: none\nrisk: standard\nrisk-reason: ordinary non-security work\nrisk-ack: none\n## Scope\nthree\n## Allowed files\n- `lib/x.py`, lib/y.py\n## Verify\n- [x] ok\n## Done-evidence\ncli\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$SB/cards/C-003.md"
printf '# C-004\nstatus: todo\ndeps: none\nimplements: none\nrisk: standard\nrisk-reason: ordinary non-security work\nrisk-ack: none\n## Scope\nfour\n## Verify\n- [x] ok\n## Done-evidence\ncli\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$SB/cards/C-004.md"
printf '# C-005\nstatus: todo\ndeps: none\nimplements: none\nrisk: standard\nrisk-reason: ordinary non-security work\nrisk-ack: none\n## Scope\nfive\n## Allowed files\n-\n## Verify\n- [x] ok\n## Done-evidence\ncli\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$SB/cards/C-005.md"
printf '# C-006\nstatus: todo\ndeps: none\nimplements: none\nrisk: standard\nrisk-reason: ordinary non-security work\nrisk-ack: none\n## Scope\nsix\n## Allowed files\nlib/y.py\n## Verify\n- [x] ok\n## Done-evidence\ncli\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$SB/cards/C-006.md"
out="$(bash "$RUN" ready --json 2>&1)"; rc=$?
ck 0 "$rc" "ready --json waves rc 0"
py_res="$(python3 -c '
import sys, json
try:
    d = json.loads(sys.argv[1])
    expected_groups = [["C-001", "C-003"], ["C-002", "C-006"], ["C-004"], ["C-005"]]
    assert d.get("groups") == expected_groups, "bad groups: got %s expected %s" % (d.get("groups"), expected_groups)
    b_map = dict((item["id"], item["wave"]) for item in d.get("buildable", []))
    b_allowed = dict((item["id"], item.get("allowed_files", [])) for item in d.get("buildable", []))
    assert b_allowed.get("C-003") == ["lib/x.py", "lib/y.py"], "C-003 allowed: %s" % b_allowed.get("C-003")
    assert b_map.get("C-001") == 1, "C-001 wave: %s" % b_map.get("C-001")
    assert b_map.get("C-003") == 1, "C-003 wave: %s" % b_map.get("C-003")
    assert b_map.get("C-002") == 2, "C-002 wave: %s" % b_map.get("C-002")
    assert b_map.get("C-006") == 2, "C-006 wave: %s" % b_map.get("C-006")
    assert b_map.get("C-004") == 3, "C-004 wave: %s" % b_map.get("C-004")
    assert b_map.get("C-005") == 4, "C-005 wave: %s" % b_map.get("C-005")
    print("OK")
except Exception as e:
    print("ERR: %s" % e)
' "$out")"
ck "OK" "$py_res" "wave partition groups and waves"
rm -rf "$SB"

echo "F) auto --parallel activation"
setup_green
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null
out="$(bash "$RUN" auto --parallel 2>&1)"; rc=$?
ck 0 "$rc" "auto --parallel rc 0"
has "$out" 'wave 1: C-001' "stdout contains wave 1: C-001"
has "$(cat "$SB/.flow/auto-state" 2>/dev/null)" '^parallel: true$' "auto-state contains parallel: true"
r_out="$(bash "$RUN" ready --json 2>&1)"; r_rc=$?
ck 0 "$r_rc" "ready --json after auto --parallel rc 0"
has "$r_out" '"auto":"ACTIVE"' "ready --json shows auto ACTIVE"
has "$r_out" '"parallel_policy":true' "ready --json shows parallel_policy true"
rm -rf "$SB"

echo "G) plain auto activation without parallel"
setup_green
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null
bash "$RUN" auto >/dev/null; ck 0 $? "auto rc 0"
no "$(cat "$SB/.flow/auto-state" 2>/dev/null)" '^parallel:' "no parallel line in state"
st_out="$(bash "$RUN" status 2>&1)"
has "$st_out" 'ACTIVE' "status contains ACTIVE"
rm -rf "$SB"

echo "H) back-compat: auto-state without parallel line shows ACTIVE"
setup_green
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null
bash "$RUN" auto --parallel >/dev/null
sed -i '/^parallel:/d' "$SB/.flow/auto-state" 2>/dev/null || sed -i '' '/^parallel:/d' "$SB/.flow/auto-state"
st_out="$(bash "$RUN" status 2>&1)"
has "$st_out" 'ACTIVE' "status still contains ACTIVE"
rm -rf "$SB"

echo "I) strict value: parallel: maybe -> status shows INVALID"
setup_green
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null
bash "$RUN" auto --parallel >/dev/null
sed -i 's/^parallel: true/parallel: maybe/' "$SB/.flow/auto-state" 2>/dev/null || sed -i '' 's/^parallel: true/parallel: maybe/' "$SB/.flow/auto-state"
st_out="$(bash "$RUN" status 2>&1)"
has "$st_out" 'INVALID' "status shows INVALID"
no "$st_out" 'ACTIVE' "status does not show ACTIVE"
rm -rf "$SB"

echo "J) receipt-blocked JSON"
setup_green
sed -i 's/^status: todo/status: done/' "$SB/cards/C-001.md" 2>/dev/null || sed -i '' 's/^status: todo/status: done/' "$SB/cards/C-001.md"
printf '# C-002\nstatus: todo\ndeps: C-001\nimplements: none\nrisk: standard\nrisk-reason: test\nrisk-ack: none\n## Scope\nscope\n## Allowed files\nbin/\n## Verify\n- [x] ok\n## Done-evidence\ncli\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$SB/cards/C-002.md"
printf '# C-003\nstatus: todo\ndeps: C-002\nimplements: none\nrisk: standard\nrisk-reason: test\nrisk-ack: none\n## Scope\nscope\n## Allowed files\nbin/\n## Verify\n- [x] ok\n## Done-evidence\ncli\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$SB/cards/C-003.md"
mkdir -p "$SB/.flow"
printf 'x' > "$SB/.flow/auto-state"
out="$(bash "$RUN" ready --json 2>&1)"; rc=$?
ck 1 "$rc" "ready --json exit 1 on receipt-blocked"
py_res="$(python3 -c '
import sys, json
try:
    d = json.loads(sys.argv[1])
    assert d.get("buildable") == [], "buildable not empty: %s" % d.get("buildable")
    blocked_ids = [item.get("id") for item in d.get("blocked", [])]
    assert blocked_ids == ["C-002", "C-003"], "bad blocked ids: %s" % blocked_ids
    print("OK")
except Exception as e:
    print("ERR: %s" % e)
' "$out")"
ck "OK" "$py_res" "receipt-blocked buildable empty and blocked has C-002, C-003"
rm -rf "$SB"

echo "K) auto usage errors"
setup_green
out="$(bash "$RUN" auto stop --parallel 2>&1)"; rc=$?
ck 2 "$rc" "auto stop --parallel exit 2"
has "$out" 'usage: /flow auto' "auto stop usage message"
out2="$(bash "$RUN" auto --bogus 2>&1)"; rc2=$?
ck 2 "$rc2" "auto --bogus exit 2"
has "$out2" 'usage: /flow auto' "auto bogus usage message"
rm -rf "$SB"

echo "L) display-only guard: ready --json does not contain NEXT_VERB"
setup_green
out="$(bash "$RUN" ready --json 2>&1)"; rc=$?
ck 0 "$rc" "ready --json exit 0"
no "$out" 'NEXT_VERB' "ready --json has no NEXT_VERB"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
