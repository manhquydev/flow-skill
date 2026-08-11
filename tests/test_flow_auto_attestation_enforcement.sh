#!/usr/bin/env bash
# Phase 5: auto activation + transition enforcement.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
export FLOW_HARNESS_DISABLE=1
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
  cat > "$SB/bin/owner_card.txt" <<EOF
schema: flow-attestation-owner/v1
kind: semantic_gate
subject_id: C-001
target_id: none
command: repo:bin/semantic_owner.sh
revision_oracle: none
EOF
  cat > "$SB/bin/owner_live.txt" <<EOF
schema: flow-attestation-owner/v1
kind: live_verify
subject_id: C-001
target_id: local
command: repo:bin/live_probe.sh
revision_oracle: repo:bin/live_oracle.sh
EOF
  git -C "$SB" init -q
  git -C "$SB" config user.email "t@example.com"
  git -C "$SB" config user.name "T"
  git -C "$SB" add -A && git -C "$SB" commit -qm init
}

echo "A) auto refuses without Stage 05 receipt"
setup_green
out="$(bash "$RUN" auto 2>&1)"; ck 1 $? "auto no stage receipt"
has "$out" '05-contract|semantic' "mentions stage receipt"
no "$(ls "$SB/.flow/auto-state" 2>/dev/null)" '.' "no state file" 2>/dev/null || {
  [ ! -f "$SB/.flow/auto-state" ]; ck 0 $? "no auto-state written"
}
rm -rf "$SB"

echo "B) auto activates after stage receipt + risk"
setup_green
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null
out="$(bash "$RUN" auto 2>&1)"; ck 0 $? "auto activates"
has "$out" 'ACTIVE|PASS: auto' "active"
[ -f "$SB/.flow/auto-state" ]; ck 0 $? "state file"
rm -rf "$SB"

echo "C) active check without card semantic blocks"
setup_green
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null
bash "$RUN" auto >/dev/null
# card is done status with evidence — but no semantic receipt
out="$(bash "$RUN" check C-001 2>&1)"; ck 1 $? "check blocked"
has "$out" 'BLOCK|semantic' "block semantic"
rm -rf "$SB"

echo "D) active check with semantic+live on done passes"
setup_green
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null
base="$(git -C "$SB" rev-parse HEAD)"
bash "$RUN" attest semantic --card C-001 --base "$base" --revision HEAD --owner bin/owner_card.txt >/dev/null
bash "$RUN" attest live-verify C-001 --revision HEAD --owner bin/owner_live.txt >/dev/null
bash "$RUN" auto >/dev/null
bash "$RUN" check C-001 >/dev/null; ck 0 $? "check green with receipts"
rm -rf "$SB"

echo "E) auto stop clears enforcement"
setup_green
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null
bash "$RUN" auto >/dev/null
bash "$RUN" auto stop >/dev/null; ck 0 $? "stop"
[ ! -f "$SB/.flow/auto-state" ]; ck 0 $? "state cleared"
# without auto, check on done with evidence still works (warnings ok)
bash "$RUN" check C-001 >/dev/null; ck 0 $? "manual check after stop"
rm -rf "$SB"

echo "F) status shows auto"
setup_green
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null
bash "$RUN" auto >/dev/null
out="$(bash "$RUN" status 2>&1)"
has "$out" 'auto:.*ACTIVE|auto:    ACTIVE' "status active"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
