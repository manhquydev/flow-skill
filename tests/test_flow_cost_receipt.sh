#!/usr/bin/env bash
# flow-cost/v1 cost receipts — record, parse, status, warn-only, chain exclusion.
# Mirrors tests/test_flow_attestations.sh (same sandbox shape, git repo).
# Run: bash tests/test_flow_cost_receipt.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
EVAL="$HERE/../skills/flow/eval/fixtures"
export FLOW_LOG_DISABLE=1
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected='$1' got='$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -qE "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

# Portable in-place sed (GNU vs BSD/macOS).
sedi() { # $1 expr $2 file
  sed -i "$1" "$2" 2>/dev/null || sed -i '' "$1" "$2"
}

setup_repo() {
  SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
  mkdir -p "$SB/flow" "$SB/cards" "$SB/bin"
  for s in 00-idea 00-inspect 01-research 02-scope 03-prd 04-adr 05-contract; do
    printf '# %s\n## Gate\n- [x] ok\n\ncontract body for %s\n' "$s" "$s" > "$SB/flow/$s.md"
  done
  printf '# C-001\nstatus: todo\ndeps: none\nimplements: none\nrisk: standard\nrisk-reason: ordinary feature work\nrisk-ack: none\n## Scope\none\n## Allowed files\nbin/\n## Verify\n- [ ] true\n## Done-evidence\ncli runs\n## Evidence\n(empty until done)\n' > "$SB/cards/C-001.md"
  cat > "$SB/bin/semantic_owner.sh" <<'EOS'
#!/usr/bin/env bash
set -u
fp=""; while [ $# -gt 0 ]; do case "$1" in --subject-fingerprint) shift; fp="${1:-}";; esac; shift 2>/dev/null || true; done
printf 'schema: flow-semantic-result/v1\nsubject_fingerprint: %s\nverdict: pass\ncritical_count: 0\nhigh_count: 0\nevidence_ref: none\n' "$fp"
EOS
  chmod +x "$SB/bin/semantic_owner.sh"
  cat > "$SB/bin/owner_semantic_stage.txt" <<EOF
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
  COST="$SB/.flow/attestations/cost/stage-05-contract.receipt"
}

# Write the valid sample receipt (Sonnet 5.5, 12000 in + 3000 out = 10800 mcr).
# Fingerprint is the sandbox HEAD stage blob, so the sample is current here.
write_sample() {
  mkdir -p "$(dirname "$COST")"
  local fp
  fp="git-sha1:$(git -C "$SB" rev-parse HEAD:flow/05-contract.md)"
  cat > "$COST" <<EOF
schema: flow-cost/v1
run_id: run-20261112-000001
stage: 05-contract
subject_fingerprint: $fp
attestation_ref: none
model_id: claude-sonnet-5.5
input_tokens: 12000
output_tokens: 3000
token_count_source: reported
price_table_version: widelai-2026-11-12
input_price_mcr_per_1k: 400
output_price_mcr_per_1k: 2000
cost_mcredits: 10800
budget_cap_mcredits: 50000
budget_status: within
timestamp: 2026-11-12T00:00:00Z
EOF
}

cost_status() { # prints "cost stage 05-contract: <status>"
  bash "$RUN" attest cost status --stage 05-contract 2>/dev/null | grep '^cost stage'
}

echo "A) record happy path: sample numbers, exact receipt content"
setup_repo
out="$(bash "$RUN" attest cost record --stage 05-contract --model-id claude-sonnet-5.5 --input-tokens 12000 --output-tokens 3000 --budget-cap-mcredits 50000 --run-id run-20261112-000001 2>&1)"; rc=$?
ck 0 "$rc" "record exit 0"
has "$out" 'cost: 10800 mcr  budget: within' "record prints cost 10800 mcr within"
[ -f "$COST" ] && ck yes yes "cost receipt file exists" || ck yes no "cost receipt file exists"
perm="$(stat -c %a "$COST" 2>/dev/null || stat -f %Lp "$COST" 2>/dev/null)"
ck 600 "$perm" "cost receipt mode 600"
grep -qx 'schema: flow-cost/v1' "$COST" && ck yes yes "schema line" || ck yes no "schema line"
grep -qx 'run_id: run-20261112-000001' "$COST" && ck yes yes "run_id kept" || ck yes no "run_id kept"
grep -qx 'stage: 05-contract' "$COST" && ck yes yes "stage line" || ck yes no "stage line"
headfp="git-sha1:$(git -C "$SB" rev-parse HEAD:flow/05-contract.md)"
grep -qx "subject_fingerprint: $headfp" "$COST" && ck yes yes "fingerprint defaults to HEAD stage blob" || ck yes no "fingerprint defaults to HEAD stage blob"
grep -qx 'attestation_ref: none' "$COST" && ck yes yes "attestation_ref none without attestation" || ck yes no "attestation_ref none without attestation"
grep -qx 'model_id: claude-sonnet-5.5' "$COST" && ck yes yes "model_id line" || ck yes no "model_id line"
grep -qx 'input_tokens: 12000' "$COST" && ck yes yes "input tokens line" || ck yes no "input tokens line"
grep -qx 'output_tokens: 3000' "$COST" && ck yes yes "output tokens line" || ck yes no "output tokens line"
grep -qx 'token_count_source: reported' "$COST" && ck yes yes "token source default reported" || ck yes no "token source default reported"
grep -qx 'price_table_version: widelai-2026-11-12' "$COST" && ck yes yes "price table version" || ck yes no "price table version"
grep -qx 'input_price_mcr_per_1k: 400' "$COST" && ck yes yes "input price 400" || ck yes no "input price 400"
grep -qx 'output_price_mcr_per_1k: 2000' "$COST" && ck yes yes "output price 2000" || ck yes no "output price 2000"
grep -qx 'cost_mcredits: 10800' "$COST" && ck yes yes "cost 10800" || ck yes no "cost 10800"
grep -qx 'budget_cap_mcredits: 50000' "$COST" && ck yes yes "cap 50000" || ck yes no "cap 50000"
grep -qx 'budget_status: within' "$COST" && ck yes yes "status within" || ck yes no "status within"
grep -qE '^timestamp: 20[0-9][0-9]-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$COST" && ck yes yes "timestamp UTC shape" || ck yes no "timestamp UTC shape"
[ "$(wc -l < "$COST" | tr -d ' ')" = "16" ] && ck yes yes "receipt has exactly 16 lines" || ck yes no "receipt has exactly 16 lines"
rm -rf "$SB"

echo "B) status current after record; no warning when current"
setup_repo
bash "$RUN" attest cost record --stage 05-contract --model-id claude-sonnet-5.5 --input-tokens 12000 --output-tokens 3000 --budget-cap-mcredits 50000 >/dev/null 2>&1
ck "cost stage 05-contract: current" "$(cost_status)" "status current"
out="$(bash "$RUN" attest cost status --stage 05-contract 2>&1)"
no "$out" 'WARNING' "no warning when current"
rm -rf "$SB"

echo "C) missing warns on stderr, status missing, exit 0"
setup_repo
out="$(bash "$RUN" attest cost status --stage 05-contract 2>&1)"; rc=$?
ck 0 "$rc" "cost status exit 0 when missing"
has "$out" 'cost stage 05-contract: missing' "status missing"
has "$out" 'WARNING: cost receipt missing for stage 05-contract' "missing warning on stderr"
has "$out" 'attestation verdict unaffected' "missing warning states verdict unaffected"
rm -rf "$SB"

echo "D) parser rejects each mutation (status invalid)"
setup_repo
write_sample
ck "cost stage 05-contract: current" "$(cost_status)" "sample parses current before mutations"
# 1. blank line
write_sample; sedi '2a\
' "$COST"; ck "cost stage 05-contract: invalid" "$(cost_status)" "blank line rejected"
# 2. unknown key
write_sample; sedi 's/^model_id:/model_xyz:/' "$COST"; ck "cost stage 05-contract: invalid" "$(cost_status)" "unknown key rejected"
# 3. duplicate key
write_sample; printf 'model_id: claude-sonnet-5.5\n' >> "$COST"; ck "cost stage 05-contract: invalid" "$(cost_status)" "duplicate key rejected"
# 4. missing key
write_sample; sedi '/^timestamp:/d' "$COST"; ck "cost stage 05-contract: invalid" "$(cost_status)" "missing key rejected"
# 5. out-of-order keys (timestamp first)
write_sample; { sed -n '16p' "$COST"; sed -n '1,15p' "$COST"; } > "$COST.tmp" && mv "$COST.tmp" "$COST"; ck "cost stage 05-contract: invalid" "$(cost_status)" "out-of-order keys rejected"
# 6. wrong arithmetic
write_sample; sedi 's/^cost_mcredits: 10800/cost_mcredits: 10000/' "$COST"; ck "cost stage 05-contract: invalid" "$(cost_status)" "wrong cost arithmetic rejected"
out="$(bash "$RUN" attest cost status --stage 05-contract 2>&1)"; has "$out" 'cost_mcredits mismatch: want 10800' "arithmetic reason named in warning"
# 7. wrong budget status
write_sample; sedi 's/^budget_status: within/budget_status: exceeded/' "$COST"; ck "cost stage 05-contract: invalid" "$(cost_status)" "inconsistent budget_status rejected"
# 8. bad fingerprint
write_sample; sedi 's/^subject_fingerprint: .*/subject_fingerprint: git-sha1:xyz/' "$COST"; ck "cost stage 05-contract: invalid" "$(cost_status)" "bad fingerprint rejected"
# 9. bad stage
write_sample; sedi 's/^stage: 05-contract/stage: 06-foo/' "$COST"; ck "cost stage 05-contract: invalid" "$(cost_status)" "bad stage rejected"
# 10. missing ': ' separator
write_sample; sedi 's/^model_id: /model_id:/' "$COST"; ck "cost stage 05-contract: invalid" "$(cost_status)" "missing separator rejected"
# 11. attestation receipt is not a cost receipt
write_sample
cat > "$COST" <<'EOF'
schema: flow-attestation/v1
kind: semantic_gate
subject_type: stage
subject_id: 05-contract
subject_fingerprint: git-sha1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
verdict: pass
actor: test
engine: test
evidence_ref: none
timestamp: 2026-11-12T00:00:00Z
override_ref: none
owner_ref: repo:bin/owner_semantic_stage.txt
owner_fingerprint: git-sha1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
EOF
ck "cost stage 05-contract: invalid" "$(cost_status)" "flow-attestation/v1 rejected as cost receipt"
rm -rf "$SB"

echo "E) stale after stage edit"
setup_repo
bash "$RUN" attest cost record --stage 05-contract --model-id claude-sonnet-5.5 --input-tokens 12000 --output-tokens 3000 >/dev/null 2>&1
ck "cost stage 05-contract: current" "$(cost_status)" "current before edit"
printf '# 05-contract\n## Gate\n- [x] ok\n\nbody CHANGED\n' > "$SB/flow/05-contract.md"
git -C "$SB" add -A && git -C "$SB" commit -qm change
ck "cost stage 05-contract: stale" "$(cost_status)" "stale after stage edit"
out="$(bash "$RUN" attest cost status --stage 05-contract 2>&1)"; has "$out" 'is stale: subject_fingerprint differs from stage blob at HEAD' "stale reason named"
rm -rf "$SB"

echo "F) unknown model, zero usage, exceeded cap"
setup_repo
out="$(bash "$RUN" attest cost record --stage 04-adr --model-id claude-unknown-9.9 --input-tokens 100 --output-tokens 50 --budget-cap-mcredits 1000 2>&1)"; rc=$?
ck 0 "$rc" "unknown model still records (exit 0)"
has "$out" "not in price table" "unknown model warns at record"
has "$out" 'cost: unknown mcr  budget: unpriced' "unpriced summary"
grep -qx 'input_price_mcr_per_1k: unknown' "$SB/.flow/attestations/cost/stage-04-adr.receipt" && ck yes yes "unknown input price" || ck yes no "unknown input price"
grep -qx 'cost_mcredits: unknown' "$SB/.flow/attestations/cost/stage-04-adr.receipt" && ck yes yes "unknown cost (never 0)" || ck yes no "unknown cost (never 0)"
out="$(bash "$RUN" attest cost status --stage 04-adr 2>&1)"; has "$out" 'is unpriced.*cap of 1000 mcr is unverifiable' "cap-unverifiable warning"
bash "$RUN" attest cost record --stage 03-prd --model-id claude-sonnet-5.5 --input-tokens 0 --output-tokens 0 >/dev/null 2>&1
out="$(bash "$RUN" attest cost status --stage 03-prd 2>&1)"; has "$out" 'records no usage' "zero-usage warning"
grep -qx 'cost_mcredits: 0' "$SB/.flow/attestations/cost/stage-03-prd.receipt" && ck yes yes "zero usage costs 0 mcr" || ck yes no "zero usage costs 0 mcr"
bash "$RUN" attest cost record --stage 02-scope --model-id claude-sonnet-5.5 --input-tokens 12000 --output-tokens 3000 --budget-cap-mcredits 1000 >/dev/null 2>&1
ck "cost stage 02-scope: current" "$(bash "$RUN" attest cost status --stage 02-scope 2>/dev/null | grep '^cost stage')" "exceeded receipt still parses current"
out="$(bash "$RUN" attest cost status --stage 02-scope 2>&1)"; has "$out" 'exceeded its budget cap by 9800 mcr' "exceeded warning names overage 9800"
grep -qx 'cost_mcredits: 10800' "$SB/.flow/attestations/cost/stage-02-scope.receipt" && ck yes yes "over-cap records real totals" || ck yes no "over-cap records real totals"
rm -rf "$SB"

echo "G) attestation interop: fingerprint copy, attestation_ref, chain exclusion"
setup_repo
bash "$RUN" attest semantic --stage 05-contract --revision HEAD --owner bin/owner_semantic_stage.txt >/dev/null 2>&1
ck 0 $? "semantic mint exit 0"
out="$(bash "$RUN" attest status 05-contract 2>&1)"
has "$out" 'semantic_gate stage 05-contract: current' "semantic receipt current"
bash "$RUN" attest cost record --stage 05-contract --model-id claude-sonnet-5.5 --input-tokens 12000 --output-tokens 3000 --budget-cap-mcredits 50000 >/dev/null 2>&1
afp="$(grep '^subject_fingerprint:' "$SB/.flow/attestations/semantic_gate/stage-05-contract.receipt")"
cfp="$(grep '^subject_fingerprint:' "$COST")"
ck "$afp" "$cfp" "cost fingerprint copies attestation fingerprint"
grep -qx 'attestation_ref: .flow/attestations/semantic_gate/stage-05-contract.receipt' "$COST" && ck yes yes "attestation_ref points at attestation receipt" || ck yes no "attestation_ref points at attestation receipt"
out="$(bash "$RUN" attest verify-chain 2>&1)"; rc=$?
ck 0 "$rc" "verify-chain exit 0 with cost receipt present"
has "$out" 'chain: OK 1 entries' "chain OK, cost receipt skipped"
out="$(bash "$RUN" attest status 05-contract 2>&1)"
has "$out" 'semantic_gate stage 05-contract: current' "semantic still current after cost record"
has "$out" 'cost stage 05-contract: current' "cost current alongside attestation"
rm -rf "$SB"

echo "H) eval fixtures: sound parses, wrong-cost fails arithmetic"
sound="$EVAL/fc01_cost_sound/.flow/attestations/cost/stage-05-contract.receipt"
wrong="$EVAL/fc01_cost_wrong/.flow/attestations/cost/stage-05-contract.receipt"
setup_repo
# Fixtures carry a stand-in fingerprint; point it at this sandbox HEAD so the
# only defect under test is the arithmetic.
fp="git-sha1:$(git -C "$SB" rev-parse HEAD:flow/05-contract.md)"
mkdir -p "$(dirname "$COST")"
cp "$sound" "$COST"
sedi "s|^subject_fingerprint: .*|subject_fingerprint: $fp|" "$COST"
ck "cost stage 05-contract: current" "$(cost_status)" "fc01_cost_sound parses current"
cp "$wrong" "$COST"
sedi "s|^subject_fingerprint: .*|subject_fingerprint: $fp|" "$COST"
ck "cost stage 05-contract: invalid" "$(cost_status)" "fc01_cost_wrong rejected"
out="$(bash "$RUN" attest cost status --stage 05-contract 2>&1)"; has "$out" 'cost_mcredits mismatch: want 10800' "wrong-cost defect is the cost arithmetic"
diff "$EVAL/fc01_cost_sound/flow/05-contract.md" "$EVAL/fc01_cost_wrong/flow/05-contract.md" >/dev/null 2>&1 && ck yes yes "pair differs only in the cost receipt" || ck yes no "pair differs only in the cost receipt"
rm -rf "$SB"

echo "I) flow next warns on missing cost receipt (warn-only, does not block)"
setup_repo
out="$(bash "$RUN" next 2>&1 || true)"
has "$out" 'cost receipt missing for stage' "next warns about missing cost receipt"
rm -rf "$SB"

echo "J) usage errors exit 2"
setup_repo
bash "$RUN" attest cost record --stage 05-contract --model-id claude-sonnet-5.5 --input-tokens 12000 >/dev/null 2>&1; ck 2 $? "missing --output-tokens exits 2"
bash "$RUN" attest cost record --stage 06-foo --model-id claude-sonnet-5.5 --input-tokens 1 --output-tokens 1 >/dev/null 2>&1; ck 2 $? "unknown stage exits 2"
bash "$RUN" attest cost record --stage 05-contract --model-id claude-sonnet-5.5 --input-tokens 1.5 --output-tokens 1 >/dev/null 2>&1; ck 2 $? "non-integer tokens exit 2"
bash "$RUN" attest cost record --stage 05-contract --model-id claude-sonnet-5.5 --input-tokens 1 --output-tokens 1 --token-count-source guessed >/dev/null 2>&1; ck 2 $? "bad token_count_source exits 2"
bash "$RUN" attest cost status --stage 06-foo >/dev/null 2>&1; ck 2 $? "cost status unknown stage exits 2"
bash "$RUN" attest cost bogus >/dev/null 2>&1; ck 2 $? "unknown cost subcommand exits 2"
rm -rf "$SB"

echo "K) cost status without --stage lists all stages"
setup_repo
bash "$RUN" attest cost record --stage 05-contract --model-id claude-sonnet-5.5 --input-tokens 12000 --output-tokens 3000 >/dev/null 2>&1
out="$(bash "$RUN" attest cost status 2>/dev/null)"
has "$out" 'cost stage 05-contract: current' "all-stage listing shows current 05-contract"
has "$out" 'cost stage 00-idea: missing' "all-stage listing shows missing 00-idea"
has "$out" 'cost stage 00-inspect: missing' "all-stage listing shows missing 00-inspect"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
