#!/usr/bin/env bash
# Schema contract test: pins the exact key-set of `flow ready --json` so any
# key addition/removal is caught before the lab dispatch bridge (which keys on
# EXPECTED_READY_REPORT_KEYS + validate_ready_report) drifts out of sync.
#
# IMPORTANT: if this suite fails, update BOTH:
#   1. plans/261101-0002-flowskill-agent-lab/lab-ready-dispatch.py
#      (EXPECTED_READY_REPORT_KEYS + validate_ready_report)
#   2. this test file's pinned key-sets
# in the same change, then re-run both suites.
#
# Uses the same setup_green fixture pattern as tests/test_flow_parallel_auto.sh.
# Run: bash tests/test_flow_ready_report_schema.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
unset FLOW_HARNESS_DISABLE
export FLOW_LOG_DISABLE=1
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }

EXPECTED_KEYS='schema_version,kind,planning_complete,note,buildable,blocked,warnings,groups,auto,parallel_policy'
EXPECTED_ITEM_KEYS='deps,id,allowed_files,wave'

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

pin_keys() {
  # $1 = JSON output, $2 = python3 expression prefix, $3 = test label
  python3 -c "
import json, sys
data = json.loads(sys.argv[1])
keys = sorted(data.keys())
expected = sorted('$2'.split(','))
if keys != expected:
    print(f'KEY-MISMATCH: got {keys}, expected {expected}')
    sys.exit(1)
print('OK')
" "$1" 2>&1
}

echo "=== A) ready --json on green setup: top-level key-set + buildable sub-keys ==="
setup_green
out="$(bash "$RUN" ready --json 2>&1)"; rc=$?
ck 0 "$rc" "ready --json rc 0"
py_res="$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
keys = sorted(data.keys())
expected = sorted('$EXPECTED_KEYS'.split(','))
if keys != expected:
    print(f'KEY-MISMATCH: got {keys}, expected {expected}')
    sys.exit(1)
assert data['schema_version'] == 1
assert data['kind'] == 'ready.report'
assert data['planning_complete'] is True
b = data['buildable']
assert len(b) >= 1, 'buildable must be non-empty'
expected_item = sorted('$EXPECTED_ITEM_KEYS'.split(','))
for item in b:
    item_keys = sorted(item.keys())
    if item_keys != expected_item:
        print(f'ITEM-KEY-MISMATCH: got {item_keys}, expected {expected_item}')
        sys.exit(1)
assert isinstance(data['groups'], list), 'groups must be a list'
for g in data['groups']:
    assert isinstance(g, list), 'each group must be a list of card-id strings'
    assert all(isinstance(card_id, str) for card_id in g), 'each group must contain card-id strings'
print('OK')
" "$out" 2>&1)"
ck "OK" "$py_res" "key-set + buildable sub-keys + groups structure"
if [ "$py_res" != "OK" ]; then
  echo "  >>> SYNC REQUIRED: update EXPECTED_READY_REPORT_KEYS in dispatch components AND this test in the same change."
  fail=$((fail + 1))
fi
rm -rf "$SB"

echo "=== B) ready --json with auto --parallel (ACTIVE): key-set unchanged, parallel_policy=true ==="
setup_green
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null
bash "$RUN" auto --parallel >/dev/null 2>&1
out="$(bash "$RUN" ready --json 2>&1)"; rc=$?
ck 0 "$rc" "ready --json with auto --parallel rc 0"
py_res="$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
keys = sorted(data.keys())
expected = sorted('$EXPECTED_KEYS'.split(','))
if keys != expected:
    print(f'KEY-MISMATCH: got {keys}, expected {expected}')
    sys.exit(1)
assert data.get('auto') == 'ACTIVE', f'auto should be ACTIVE, got {data.get(\"auto\")}'
assert data.get('parallel_policy') is True, f'parallel_policy should be True, got {data.get(\"parallel_policy\")}'
print('OK')
" "$out" 2>&1)"
ck "OK" "$py_res" "auto --parallel key-set unchanged, parallel_policy=true, auto=ACTIVE"
if [ "$py_res" != "OK" ]; then
  echo "  >>> SYNC REQUIRED: update EXPECTED_READY_REPORT_KEYS in dispatch components AND this test in the same change."
  fail=$((fail + 1))
fi
rm -rf "$SB"

echo "=== C) ready --json planning incomplete: same key-set, planning_complete=false ==="
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
mkdir -p "$SB/.flow"
git -C "$SB" init -q
git -C "$SB" config user.email "t@example.com"
git -C "$SB" config user.name "T"
git -C "$SB" commit --allow-empty -qm init
out="$(bash "$RUN" ready --json 2>&1)"; rc=$?
ck 1 "$rc" "planning incomplete ready --json rc 1"
py_res="$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
keys = sorted(data.keys())
expected = sorted('$EXPECTED_KEYS'.split(','))
if keys != expected:
    print(f'KEY-MISMATCH: got {keys}, expected {expected}')
    sys.exit(1)
assert data['planning_complete'] is False
assert data['buildable'] == []
assert data['groups'] == []
print('OK')
" "$out" 2>&1)"
ck "OK" "$py_res" "planning incomplete key-set unchanged"
rm -rf "$SB"

echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
