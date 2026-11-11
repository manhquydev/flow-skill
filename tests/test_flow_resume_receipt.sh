#!/usr/bin/env bash
# Tests for receipt verification in flow resume (FEAT-RESUME-RECEIPT-VERIFY).
# Verifies:
#   1. Stage resume warns when semantic receipt is missing/stale/red, silent when current.
#   2. Card resume (not done) renders the 'receipts:' block for semantic and live.
#   3. Card resume (done) warns when receipt is not current, already-done when current.
# Run: bash tests/test_flow_resume_receipt.sh
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
unset FLOW_HARNESS_DISABLE
export FLOW_LOG_DISABLE=1
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected='$1' got='$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

setup_repo() {
  SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
  export HOME="$SB/home"
  mkdir -p "$SB/home" "$SB/flow" "$SB/cards" "$SB/bin"
  for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
    printf '# %s\n## Gate\n- [x] ok\n\nbody for %s\n' "$s" "$s" > "$SB/flow/$s.md"
  done
  printf '# C-001\nstatus: todo\ndeps: none\nimplements: none\nrisk: standard\nrisk-reason: standard feature\nrisk-ack: none\n## Scope\none\n## Allowed files\nbin/\n## Verify\n- [x] true\n## Done-evidence\ncli runs\n## Evidence\n$ curl https://x/healthz -> 200 PASS\n' > "$SB/cards/C-001.md"
  cat > "$SB/bin/semantic_owner.sh" <<'EOS'
#!/usr/bin/env bash
set -u
fp=""; while [ $# -gt 0 ]; do case "$1" in --subject-fingerprint) shift; fp="${1:-}";; esac; shift 2>/dev/null || true; done
printf 'schema: flow-semantic-result/v1\nsubject_fingerprint: %s\nverdict: pass\ncritical_count: 0\nhigh_count: 0\nevidence_ref: none\n' "$fp"
EOS
  chmod +x "$SB/bin/semantic_owner.sh"
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
  chmod +x "$SB/bin/live_probe.sh" "$SB/bin/live_oracle.sh"
  cat > "$SB/bin/owner_stage_05.txt" <<EOF
schema: flow-attestation-owner/v1
kind: semantic_gate
subject_id: 05-contract
target_id: none
command: repo:bin/semantic_owner.sh
revision_oracle: none
EOF
  cat > "$SB/bin/owner_card_semantic.txt" <<EOF
schema: flow-attestation-owner/v1
kind: semantic_gate
subject_id: C-001
target_id: none
command: repo:bin/semantic_owner.sh
revision_oracle: none
EOF
  cat > "$SB/bin/owner_card_live.txt" <<EOF
schema: flow-attestation-owner/v1
kind: live_verify
subject_id: C-001
target_id: local-cli
command: repo:bin/live_probe.sh
revision_oracle: repo:bin/live_oracle.sh
EOF
  git -C "$SB" init -q
  git -C "$SB" config user.email "t@example.com"
  git -C "$SB" config user.name "T"
  git -C "$SB" add -A && git -C "$SB" commit -qm init
}

echo "A) stage resume: warns when stage semantic receipt is missing"
setup_repo
out="$(bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume exits 0"
has "$out" "WARNING: stage 05-contract semantic receipt is missing" "missing stage receipt triggers warning"
rm -rf "$SB"

echo "B) stage resume: silent when stage semantic receipt is current"
setup_repo
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage_05.txt >/dev/null
out="$(bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume exits 0"
no "$out" "WARNING: stage 05-contract semantic receipt" "current stage receipt emits no warning"
rm -rf "$SB"

echo "C) stage resume: warns when stage semantic receipt is stale"
setup_repo
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage_05.txt >/dev/null
echo "extra line" >> "$SB/flow/05-contract.md"
git -C "$SB" add -A && git -C "$SB" commit -qm "edit stage"
out="$(bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume exits 0"
has "$out" "WARNING: stage 05-contract semantic receipt is stale" "stale stage receipt triggers warning"
rm -rf "$SB"

echo "D) stage resume: warns when stage semantic receipt is red"
setup_repo
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage_05.txt >/dev/null
rp="$SB/.flow/attestations/semantic_gate/stage-05-contract.receipt"
awk '{sub(/verdict: pass/, "verdict: fail"); print}' "$rp" > "$rp.tmp" && mv "$rp.tmp" "$rp"
out="$(bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume exits 0"
has "$out" "WARNING: stage 05-contract semantic receipt is red" "red stage receipt triggers warning"
rm -rf "$SB"

echo "E) card resume (not done): displays 'receipts:' block with semantic and live status"
setup_repo
out="$(bash "$RUN" resume --card C-001 2>&1)"; rc=$?
ck 0 "$rc" "resume --card C-001 exits 0"
has "$out" "receipts:" "receipts block header rendered"
has "$out" "semantic: missing" "semantic receipt shown as missing"
has "$out" "live:     missing" "live receipt shown as missing"
rm -rf "$SB"

echo "F) card resume (not done): reflects minted semantic and live receipts"
setup_repo
base="$(git -C "$SB" rev-parse HEAD)"
mkdir -p "$SB/src"; printf 'v1\n' > "$SB/src/app.py"
git -C "$SB" add -A && git -C "$SB" commit -qm "app v1"
bash "$RUN" attest semantic --card C-001 --base "$base" --revision HEAD --owner bin/owner_card_semantic.txt >/dev/null
bash "$RUN" attest live-verify C-001 --revision HEAD --owner bin/owner_card_live.txt >/dev/null
out="$(bash "$RUN" resume --card C-001 2>&1)"; rc=$?
ck 0 "$rc" "resume --card C-001 exits 0"
has "$out" "receipts:" "receipts block header rendered"
has "$out" "semantic: current" "semantic receipt shown as current"
has "$out" "live:     current" "live receipt shown as current"
rm -rf "$SB"

echo "G) card resume (done): warns when receipt is missing instead of already-done"
setup_repo
sed -i 's/^status: todo/status: done/' "$SB/cards/C-001.md" 2>/dev/null || sed -i '' 's/^status: todo/status: done/' "$SB/cards/C-001.md"
out="$(bash "$RUN" resume --card C-001 2>&1)"; rc=$?
ck 0 "$rc" "resume --card C-001 exits 0"
has "$out" "WARNING: card C-001 receipt is missing" "done card with missing receipt warns"
no "$out" "card C-001 is already done" "does not report already done when receipt missing"
rm -rf "$SB"

echo "H) card resume (done): warns when receipt is stale"
setup_repo
base="$(git -C "$SB" rev-parse HEAD)"
mkdir -p "$SB/src"; printf 'v1\n' > "$SB/src/app.py"
git -C "$SB" add -A && git -C "$SB" commit -qm "app v1"
bash "$RUN" attest semantic --card C-001 --base "$base" --revision HEAD --owner bin/owner_card_semantic.txt >/dev/null
sed -i 's/^status: todo/status: done/' "$SB/cards/C-001.md" 2>/dev/null || sed -i '' 's/^status: todo/status: done/' "$SB/cards/C-001.md"
# Mutate repository after minting to make receipt stale
echo "edit" >> "$SB/src/app.py"
git -C "$SB" add -A && git -C "$SB" commit -qm "stale commit"
out="$(bash "$RUN" resume --card C-001 2>&1)"; rc=$?
ck 0 "$rc" "resume --card C-001 exits 0"
has "$out" "WARNING: card C-001 receipt is stale" "done card with stale receipt warns"
no "$out" "card C-001 is already done" "does not report already done when receipt stale"
rm -rf "$SB"

echo "I) card resume (done): warns when receipt is red"
setup_repo
base="$(git -C "$SB" rev-parse HEAD)"
mkdir -p "$SB/src"; printf 'v1\n' > "$SB/src/app.py"
git -C "$SB" add -A && git -C "$SB" commit -qm "app v1"
bash "$RUN" attest semantic --card C-001 --base "$base" --revision HEAD --owner bin/owner_card_semantic.txt >/dev/null
sed -i 's/^status: todo/status: done/' "$SB/cards/C-001.md" 2>/dev/null || sed -i '' 's/^status: todo/status: done/' "$SB/cards/C-001.md"
rp="$SB/.flow/attestations/semantic_gate/card-C-001.receipt"
awk '{sub(/verdict: pass/, "verdict: fail"); print}' "$rp" > "$rp.tmp" && mv "$rp.tmp" "$rp"
out="$(bash "$RUN" resume --card C-001 2>&1)"; rc=$?
ck 0 "$rc" "resume --card C-001 exits 0"
has "$out" "WARNING: card C-001 receipt is red" "done card with red receipt warns"
no "$out" "card C-001 is already done" "does not report already done when receipt red"
rm -rf "$SB"

echo "J) card resume (done): reports already-done when receipt is current"
setup_repo
base="$(git -C "$SB" rev-parse HEAD)"
mkdir -p "$SB/src"; printf 'v1\n' > "$SB/src/app.py"
git -C "$SB" add -A && git -C "$SB" commit -qm "app v1"
bash "$RUN" attest semantic --card C-001 --base "$base" --revision HEAD --owner bin/owner_card_semantic.txt >/dev/null
sed -i 's/^status: todo/status: done/' "$SB/cards/C-001.md" 2>/dev/null || sed -i '' 's/^status: todo/status: done/' "$SB/cards/C-001.md"
out="$(bash "$RUN" resume --card C-001 2>&1)"; rc=$?
ck 0 "$rc" "resume --card C-001 exits 0"
has "$out" "card C-001 is already done - see 'flow recall'" "reports already done when receipt current"
no "$out" "WARNING:" "no warning when receipt is current"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
