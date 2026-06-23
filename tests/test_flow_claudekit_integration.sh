#!/usr/bin/env bash
# Regression guard for the claudekit skill-layer doc-contract.
# The whitelist + binding invariants (INFORMS-not-PASS, Claude-side detection + silent degrade,
# opt-in-with-prompt, the 5 deep-wired skills, twins/competing-orchestrators cut) live in the
# reference docs (the semantic layer). This suite asserts those invariants are present AND bound
# to their actual clause — a later edit that deletes/inverts one must FAIL, not survive on an
# unrelated keyword. DOC-CONTRACT test (no runner code for this feature).
# Run: bash tests/test_flow_claudekit_integration.sh   (exit 0 = all pass, 1 = any fail)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REF="$HERE/../skills/flow/references"
SKILL="$HERE/../skills/flow/SKILL.md"
CAT="$REF/claudekit-skills.md"
pass=0; fail=0
hasE() { if grep -qiE "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing /$2/ in $(basename "$1"))"; fail=$((fail+1)); fi; }
has()  { if grep -qi "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing '$2' in $(basename "$1"))"; fail=$((fail+1)); fi; }
lacks(){ if grep -qiE "$2" "$1" 2>/dev/null; then echo "  FAIL [$3] (anti-pattern /$2/ present in $(basename "$1"))"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
file() { if [ -f "$1" ]; then echo "  ok   [$2]"; pass=$((pass+1)); else echo "  FAIL [$2] (no file $1)"; fail=$((fail+1)); fi; }

echo "==== claudekit skill-layer doc-contract ===="

file "$CAT" "claudekit-skills.md exists (the skill-layer seam)"

# Invariant 1: gate parity — a skill INFORMS, the gate JUDGES; never auto-pass/auto-fail (clause-bound).
has  "$CAT" "INFORMS"  "seam: a skill INFORMS a stage"
hasE "$CAT" "never auto-pass" "seam: never auto-pass a gate (gate parity)"

# Invariant 2: detection is Claude-side and degrades silently; the runner never detects skills.
hasE "$CAT" "detection is .{0,20}claude-side|claude-side, and degrades" "seam: detection is Claude-side"
hasE "$CAT" "flow\\.sh .{0,20}cannot|bash .{0,20}no view" "seam: flow.sh cannot detect skills (runner has no registry view)"
hasE "$CAT" "never lowers a gate" "seam: missing skill never lowers a gate (portability)"

# Invariant 3: cost gate = opt-in-with-prompt, off the hot path (no fire-every-stage).
has  "$CAT" "opt-in-with-prompt" "seam cost gate: opt-in-with-prompt"
hasE "$CAT" "off the hot path|never wire a skill into .?cmd_next" "seam cost gate: off the hot path"

# Invariant 4: the 5 deep-wired skills are named and bound to their gate.
hasE "$CAT" "ck-predict.{0,40}ADR"     "deep-wire: ck-predict @ ADR"
hasE "$CAT" "ck-scenario.{0,60}Contract" "deep-wire: ck-scenario @ Contract"
has  "$CAT" "review-pr"   "deep-wire: review-pr present"
has  "$CAT" "ck-security" "deep-wire: ck-security present"
hasE "$CAT" "retro.{0,40}Retro" "deep-wire: retro @ Retro"

# Invariant 5: security wiring does NOT auto-pass the Tier-C operator HALT.
hasE "$CAT" "HALT is never auto-passed|never auto-passed by a clean scan" "ck-security: Tier-C HALT never auto-passed"

# Invariant 6: graph tool is a SINGLE pick — ck-graphify chosen, gkg explicitly not wired.
has  "$CAT" "ck-graphify" "graph: ck-graphify is the chosen tool"
hasE "$CAT" "gkg is NOT wired|do not surface both" "graph: gkg not wired (single pick, no dup)"

# Invariant 7: twins + competing orchestrators + worktree dup are explicitly CUT (not surfaced).
hasE "$CAT" "skill/agent twins" "cut: skill/agent twins not surfaced"
hasE "$CAT" "competing orchestrators" "cut: cook/vibe/ship/bootstrap not run inside a stage"
hasE "$CAT" "worktree.{0,40}(duplicate|already ships)" "cut: worktree dup of flow.sh workspace"
has  "$CAT" "marketing" "cut: marketing skills excluded"

# Invariant 8: surfaced from the files the skill already reads (reachability — the top rot risk).
has  "$SKILL"                    "claudekit-skills" "SKILL.md points to claudekit-skills.md"
has  "$REF/agent-stage-mapping.md" "claudekit-skills.md" "stage map points to claudekit-skills.md"
hasE "$REF/agent-stage-mapping.md" "ck-predict.{0,80}ADR" "stage map names ck-predict@ADR"
hasE "$REF/agent-stage-mapping.md" "ck-scenario.{0,80}Contract" "stage map names ck-scenario@Contract"

# Invariant 9: the two deep wirings reached the gate ritual itself (gate-rules.md), bound + INFORM-only.
hasE "$REF/gate-rules.md" "ck-predict" "gate-rules ADR carries ck-predict"
hasE "$REF/gate-rules.md" "ck-scenario" "gate-rules Contract carries ck-scenario"
hasE "$REF/gate-rules.md" "INFORMS this challenge|INFORMS the gate" "gate-rules: skill INFORMS, not passes"

# ---- Round-2: review-pr / ck-security / retro wired into their gate rituals ----
RETRO="$HERE/../skills/flow/law/RETRO.md"
AREV="$REF/adversarial-review.md"

# review-pr: wired into the Review gate as a PR-context lens, opt-in, INFORM-only, distinct from code-reviewer.
hasE "$AREV" "review-pr" "R2 review-pr: present in the Review gate"
hasE "$AREV" "opt-in-with-prompt" "R2 review-pr/ck-security: opt-in-with-prompt at Review"
hasE "$AREV" "the wired .code-reviewer. agent" "R2 review-pr: distinct from code-reviewer (not a twin)"
hasE "$AREV" "INFORMS, never decides|never auto-passes a card" "R2 review-pr: gate parity (INFORM-only)"

# ck-security: explicit opt-in offer that never auto-passes the Tier-C HALT.
hasE "$AREV" "Offer .ck-security. on a security-class card" "R2 ck-security: explicit opt-in offer at Review"
hasE "$AREV" "never auto-passes the Tier-C HALT|never auto-release" "R2 ck-security: never auto-passes Tier-C HALT"

# retro: offered at the Retro gate, operator still authors the line (teach-mode rule holds).
hasE "$RETRO" "retro. SKILL|the .retro. SKILL" "R2 retro: offered at the Retro gate"
hasE "$RETRO" "operator still writes the line|never authors it" "R2 retro: operator still authors (teach-mode)"

# Q1 lazy telemetry: ON, only at the wired gates, via existing harness verb, no new runner verb.
hasE "$CAT" "Lazy capture .ON" "R2 telemetry: lazy capture ON"
hasE "$CAT" "only at the 5 wired gates|Only at the 5 wired gates" "R2 telemetry: scoped to the 5 wired gates"
hasE "$CAT" "harness intervention add" "R2 telemetry: reuses existing harness verb"
# Q2 (no `suggest` verb) + no-new-runner-verb: guard the RUNNER itself, not just the prose.
RUNNER="$HERE/../skills/flow/runner/flow.sh"
lacks "$RUNNER" "cmd_suggest|^[[:space:]]*suggest\\)" "R2/Q2: runner has NO suggest verb (docs-only, decision Q2=no)"

# stage map names the 3 newly-wired skills.
hasE "$REF/agent-stage-mapping.md" "review-pr" "R2 stage map: names review-pr"
hasE "$REF/agent-stage-mapping.md" "ck-security" "R2 stage map: names ck-security"
hasE "$REF/agent-stage-mapping.md" "retro. at Retro|retro at Retro" "R2 stage map: names retro@Retro"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
