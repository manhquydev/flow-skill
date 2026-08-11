#!/usr/bin/env bash
# Phase 1: static contract invariants for attestations.md + wiring.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
REF="$ROOT/skills/flow/references/attestations.md"
SKILL="$ROOT/skills/flow/SKILL.md"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected='$1' got='$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] missing /$2/"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -qE "$2"; then echo "  FAIL [$3] unexpected /$2/"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

echo "A) contract file exists and owns closed vocabularies"
[ -f "$REF" ]; ck 0 $? "attestations.md exists"
body="$(cat "$REF")"
has "$body" 'risk: standard\|security-class\|unknown' "risk vocab"
has "$body" 'flow-attestation/v1' "receipt schema"
has "$body" 'semantic_gate\|live_verify' "two kinds"
has "$body" 'pass\|fail\|override' "verdict vocab"
has "$body" 'authenticate|authentication|not.*identity' "non-auth claim"
has "$body" 'Bash \+ Git|Bash \+ Git floor|without Python' "bash floor"
no "$body" 'cryptographic actor identity required' "no false crypto claim"

echo "B) required receipt keys present"
for k in schema kind subject_type subject_id subject_fingerprint verdict actor engine evidence_ref timestamp override_ref owner_ref owner_fingerprint; do
  has "$body" "$k:" "key $k mentioned"
done

echo "C) forbidden ambiguities"
has "$body" 'Duplicate.*invalid|duplicates' "dup keys rejected"
has "$body" 'status.*Evidence.*excluded|excluded from card semantic' "status/Evidence excluded"
has "$body" 'committed.*owner|owner manifest' "owner manifest required"
has "$body" 'revision_oracle' "live oracle"
has "$body" 'attempt' "attempt marker"

echo "D) SKILL / refs link to contract (no full schema dump required)"
has "$(cat "$SKILL")" 'attestations\.md|Attested|attestation' "SKILL mentions attestations"
# graph plan supersession
has "$(head -30 "$ROOT/plans/260726-1718-harness-graph-executor-langgraph-port/plan.md")" '260811-1542-attested-execution|superseded' "old graph plan blocked"

echo "E) library + template exist"
[ -f "$ROOT/skills/flow/runner/attestations.sh" ]; ck 0 $? "attestations.sh exists"
has "$(cat "$ROOT/skills/flow/_templates/card.md")" 'risk: unknown' "template risk default"
has "$(cat "$ROOT/skills/flow/_templates/card.md")" 'risk-ack: none' "template risk-ack"

echo "F) flow.sh sources library and dispatches attest"
has "$(grep -n 'attestations.sh\|cmd_attest\|attest)' "$ROOT/skills/flow/runner/flow.sh" | head -20)" 'attestations\.sh' "sourced"
has "$(grep 'attest)' "$ROOT/skills/flow/runner/flow.sh")" 'cmd_attest' "dispatch"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
