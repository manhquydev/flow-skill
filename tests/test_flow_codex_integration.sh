#!/usr/bin/env bash
# Regression guard for the Codex cross-vendor second-engine doc-contract.
# The detection/cost-gate/gate-parity invariants live in the reference docs (the semantic layer),
# so this suite asserts those invariants are present and cannot be silently weakened by a later
# edit. It is a DOC-CONTRACT test, not a runtime test — there is no runner code for this feature.
# Run: bash tests/test_flow_codex_integration.sh   (exit 0 = all pass, 1 = any fail)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REF="$HERE/../skills/flow/references"
SKILL="$HERE/../skills/flow/SKILL.md"
pass=0; fail=0
has()  { if grep -qi "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing /$2/ in $(basename "$1"))"; fail=$((fail+1)); fi; }
file() { if [ -f "$1" ]; then echo "  ok   [$2]"; pass=$((pass+1)); else echo "  FAIL [$2] (no file $1)"; fail=$((fail+1)); fi; }

echo "==== Codex integration doc-contract ===="

# The seam doc exists and is the single source of truth.
file "$REF/codex-integration.md" "codex-integration.md exists (the seam)"

# Invariant 1: detection has two states — installed != usable (the live-review HIGH finding fix).
has "$REF/codex-integration.md" "INSTALLED"        "seam: INSTALLED state documented"
has "$REF/codex-integration.md" "USABLE"           "seam: USABLE state documented"
has "$REF/codex-integration.md" "liveness"         "seam: non-billable liveness/auth probe required"
has "$REF/agent-detection.md"   "INSTALLED"        "detection: INSTALLED state mirrored in agent-detection"
has "$REF/agent-detection.md"   "USABLE"           "detection: USABLE state mirrored in agent-detection"
has "$REF/agent-detection.md"   "codex-integration" "detection: points to the seam for the rule"

# Invariant 2: degrade-and-never-break (portability promise).
has "$REF/codex-integration.md" "degrade"          "seam: degrade rule present"
has "$REF/agent-detection.md"   "degrade"          "detection: degrade rule present"

# Invariant 3: cost gate = exactly the 3 allowed triggers; no rogue auto-trigger.
has "$REF/codex-integration.md"   "two-strikes"        "seam cost gate: two-strikes trigger"
has "$REF/codex-integration.md"   "security-class"     "seam cost gate: security-class trigger"
has "$REF/codex-integration.md"   "opt-in"             "seam cost gate: operator opt-in trigger"
has "$REF/adversarial-review.md"  "two-strikes"        "review lens: aligned to two-strikes trigger"
has "$REF/adversarial-review.md"  "opt-in"             "review lens: zero-findings is opt-in, not auto"

# Invariant 4: gate parity — Codex informs, never auto-passes/fails.
has "$REF/adversarial-review.md"  "INFORMS"            "review lens: Codex INFORMS triage"
has "$REF/adversarial-review.md"  "never"              "review lens: gate parity (never auto decide)"
has "$REF/codex-integration.md"   "Gate parity"        "seam: gate-parity section present"

# Invariant 5: surfaced at the skill level + points to the seam.
has "$SKILL" "codex-integration"  "SKILL.md points to codex-integration.md"
has "$REF/agent-stage-mapping.md" "default stays ck"   "stage map: Codex-primary is opt-in, default ck:"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
