#!/usr/bin/env bash
# Phase 4: receipt substrate — parser, mint, stale, live.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
export FLOW_HARNESS_DISABLE=1
export FLOW_LOG_DISABLE=1
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }

setup_repo() {
  SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
  mkdir -p "$SB/flow" "$SB/cards" "$SB/bin"
  for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
    printf '# %s\n## Gate\n- [x] ok\n\ncontract body for %s\n' "$s" "$s" > "$SB/flow/$s.md"
  done
  printf '# C-001\nstatus: todo\ndeps: none\nimplements: none\nrisk: standard\nrisk-reason: ordinary feature work\nrisk-ack: none\n## Scope\none\n## Allowed files\nbin/\n## Verify\n- [ ] true\n## Done-evidence\ncli runs\n## Evidence\n(empty until done)\n' > "$SB/cards/C-001.md"
  # semantic producer
  cat > "$SB/bin/semantic_owner.sh" <<'EOS'
#!/usr/bin/env bash
set -u
fp=""; while [ $# -gt 0 ]; do case "$1" in --subject-fingerprint) shift; fp="${1:-}";; esac; shift 2>/dev/null || true; done
printf 'schema: flow-semantic-result/v1\nsubject_fingerprint: %s\nverdict: pass\ncritical_count: 0\nhigh_count: 0\nevidence_ref: none\n' "$fp"
EOS
  chmod +x "$SB/bin/semantic_owner.sh"
  # live probe + oracle
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
  cat > "$SB/bin/owner_semantic_stage.txt" <<EOF
schema: flow-attestation-owner/v1
kind: semantic_gate
subject_id: 05-contract
target_id: none
command: repo:bin/semantic_owner.sh
revision_oracle: none
EOF
  cat > "$SB/bin/owner_semantic_card.txt" <<EOF
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
target_id: local-cli
command: repo:bin/live_probe.sh
revision_oracle: repo:bin/live_oracle.sh
EOF
  git -C "$SB" init -q
  git -C "$SB" config user.email "t@example.com"
  git -C "$SB" config user.name "T"
  git -C "$SB" add -A && git -C "$SB" commit -qm init
}

echo "A) semantic stage mint + status current"
setup_repo
out="$(bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_semantic_stage.txt 2>&1)"; ck 0 $? "stage mint"
has "$out" 'verdict=pass' "stage pass"
out="$(bash "$RUN" attest status 05-contract 2>&1)"
has "$out" 'current|semantic_gate' "status shows"
rm -rf "$SB"

echo "B) duplicate key receipt invalid"
setup_repo
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_semantic_stage.txt >/dev/null
rp="$SB/.flow/attestations/semantic_gate/stage-05-contract.receipt"
# inject duplicate verdict
printf '%s\nverdict: pass\n' "$(cat "$rp")" > "$rp"
out="$(bash "$RUN" attest status 05-contract 2>&1)"
has "$out" 'invalid|missing|stale|red' "dup treated non-current"
rm -rf "$SB"

echo "C) stage edit makes receipt stale"
setup_repo
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_semantic_stage.txt >/dev/null
echo "mutated" >> "$SB/flow/05-contract.md"
git -C "$SB" add -A && git -C "$SB" commit -qm mutate
out="$(bash "$RUN" attest status 05-contract 2>&1)"
has "$out" 'stale|invalid|missing|red' "stale after edit"
rm -rf "$SB"

echo "D) card semantic + live mint"
setup_repo
base="$(git -C "$SB" rev-parse HEAD)"
# non-empty base..rev: commit a real code change after base
mkdir -p "$SB/src"; printf 'v1\n' > "$SB/src/app.py"
git -C "$SB" add -A && git -C "$SB" commit -qm code1
bash "$RUN" attest semantic --card C-001 --base "$base" --revision HEAD --owner bin/owner_semantic_card.txt >/dev/null; ck 0 $? "card semantic"
bash "$RUN" attest live-verify C-001 --revision HEAD --owner bin/owner_live.txt >/dev/null; ck 0 $? "live mint"
rm -rf "$SB"

echo "E) live non-zero fails"
setup_repo
printf '#!/usr/bin/env bash\nexit 3\n' > "$SB/bin/live_probe.sh"
chmod +x "$SB/bin/live_probe.sh"
git -C "$SB" add -A && git -C "$SB" commit -qm failprobe
bash "$RUN" attest live-verify C-001 --revision HEAD --owner bin/owner_live.txt >/dev/null 2>&1; ck 1 $? "live non-zero"
rm -rf "$SB"

echo "F) invalid usage exit 2 leaves no crash"
setup_repo
bash "$RUN" attest semantic >/dev/null 2>&1; ck 2 $? "usage 2"
rm -rf "$SB"

echo "G) reviewed non-card path change makes card semantic stale"
setup_repo
base="$(git -C "$SB" rev-parse HEAD)"
mkdir -p "$SB/src"
printf 'print("v1")\n' > "$SB/src/app.py"
git -C "$SB" add -A && git -C "$SB" commit -qm addapp
bash "$RUN" attest semantic --card C-001 --base "$base" --revision HEAD --owner bin/owner_semantic_card.txt >/dev/null; ck 0 $? "mint with non-empty range"
printf 'print("v2")\n' > "$SB/src/app.py"
git -C "$SB" add -A && git -C "$SB" commit -qm changeapp
out="$(bash "$RUN" attest status C-001 2>&1)"
has "$out" 'stale|invalid|missing|red' "path edit stale"
rm -rf "$SB"

echo "G2) reject empty base==rev card semantic"
setup_repo
base="$(git -C "$SB" rev-parse HEAD)"
bash "$RUN" attest semantic --card C-001 --base "$base" --revision HEAD --owner bin/owner_semantic_card.txt >/dev/null 2>&1
ck 2 $? "empty range exit 2"
rm -rf "$SB"

echo "H) Verify section change makes live receipt stale"
setup_repo
bash "$RUN" attest live-verify C-001 --revision HEAD --owner bin/owner_live.txt >/dev/null
# mutate Verify
sed -i 's/- \[ \] true/- [ ] true and more/' "$SB/cards/C-001.md" 2>/dev/null \
  || sed -i '' 's/- \[ \] true/- [ ] true and more/' "$SB/cards/C-001.md"
git -C "$SB" add -A && git -C "$SB" commit -qm verifyedit
out="$(bash "$RUN" attest status C-001 2>&1)"
has "$out" 'live_verify.*stale|live_verify card C-001: stale' "live verify edit stale"
# softer: any non-current for live
if printf '%s' "$out" | grep -qE 'live_verify card C-001: (stale|invalid|missing|red)'; then
  echo "  ok   [live non-current after Verify edit]"; pass=$((pass+1))
else
  echo "  FAIL [live still current after Verify edit: $out]"; fail=$((fail+1))
fi
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
