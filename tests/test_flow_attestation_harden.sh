#!/usr/bin/env bash
# Harden package 1-6: blob-exec, live tip, cleanliness, empty-range, supervisor.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
export FLOW_HARNESS_DISABLE=1 FLOW_LOG_DISABLE=1
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }

setup() {
  SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
  mkdir -p "$SB/flow" "$SB/cards" "$SB/bin" "$SB/src"
  for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
    printf '# %s\n## Gate\n- [x] ok\n\nbody %s\n' "$s" "$s" > "$SB/flow/$s.md"
  done
  printf '# C-001\nstatus: todo\ndeps: none\nimplements: none\nrisk: standard\nrisk-reason: ordinary feature work\nrisk-ack: none\n## Scope\none\n## Allowed files\nsrc/\n## Verify\n- [x] ok\n## Done-evidence\ncli\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$SB/cards/C-001.md"
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
  cat > "$SB/bin/owner_stage.txt" <<'EOF'
schema: flow-attestation-owner/v1
kind: semantic_gate
subject_id: 05-contract
target_id: none
command: repo:bin/semantic_owner.sh
revision_oracle: none
EOF
  cat > "$SB/bin/owner_card.txt" <<'EOF'
schema: flow-attestation-owner/v1
kind: semantic_gate
subject_id: C-001
target_id: none
command: repo:bin/semantic_owner.sh
revision_oracle: none
EOF
  cat > "$SB/bin/owner_live.txt" <<'EOF'
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

echo "H1) dirty producer content cannot mint pass (blob equality)"
setup
printf '#!/usr/bin/env bash\nexit 1\n' > "$SB/bin/live_probe.sh"
chmod +x "$SB/bin/live_probe.sh"
git -C "$SB" add -A && git -C "$SB" commit -qm failprobe
printf '#!/usr/bin/env bash\nexit 0\n' > "$SB/bin/live_probe.sh"
bash "$RUN" attest live-verify C-001 --revision HEAD --owner bin/owner_live.txt >/dev/null 2>&1
ck 1 $? "dirty live producer rejected"
rm -rf "$SB"

echo "H2) live becomes stale when HEAD advances"
setup
bash "$RUN" attest live-verify C-001 --revision HEAD --owner bin/owner_live.txt >/dev/null
printf 'x\n' > "$SB/src/x.py"
git -C "$SB" add -A && git -C "$SB" commit -qm advance
out="$(bash "$RUN" attest status C-001 2>&1)"
has "$out" 'live_verify card C-001: stale' "live stale after tip advance"
rm -rf "$SB"

echo "H3) dirty non-excluded file blocks stage mint"
setup
echo dirty > "$SB/untracked.txt"
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null 2>&1
ck 1 $? "dirty blocks stage mint"
rm -rf "$SB"

echo "H3b) flow/.lock dirt does not block mint"
setup
mkdir -p "$SB/flow"; : > "$SB/flow/.lock"
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null
ck 0 $? "lock excluded from cleanliness"
rm -rf "$SB"

echo "H4) empty base==rev rejected"
setup
b="$(git -C "$SB" rev-parse HEAD)"
bash "$RUN" attest semantic --card C-001 --base "$b" --revision HEAD --owner bin/owner_card.txt >/dev/null 2>&1
ck 2 $? "empty range exit 2"
rm -rf "$SB"

echo "H5) force-unsupported supervisor refuses live"
setup
out="$(FLOW_ATTEST_SUPERVISOR=force-unsupported bash "$RUN" attest live-verify C-001 --revision HEAD --owner bin/owner_live.txt 2>&1)"
ck 1 $? "live refuses unsupported supervisor"
has "$out" 'supervisor|unsupported' "names supervisor"
rm -rf "$SB"

echo "H1b) happy path still works with non-empty range"
setup
base="$(git -C "$SB" rev-parse HEAD)"
printf 'v1\n' > "$SB/src/app.py"
git -C "$SB" add -A && git -C "$SB" commit -qm code
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_stage.txt >/dev/null; ck 0 $? "stage"
bash "$RUN" attest semantic --card C-001 --base "$base" --revision HEAD --owner bin/owner_card.txt >/dev/null; ck 0 $? "card"
bash "$RUN" attest live-verify C-001 --revision HEAD --owner bin/owner_live.txt >/dev/null; ck 0 $? "live"
bash "$RUN" auto >/dev/null; ck 0 $? "auto"
bash "$RUN" check C-001 >/dev/null; ck 0 $? "check under auto"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
