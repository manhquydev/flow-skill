#!/usr/bin/env bash
# Regression guard for the Antigravity (Gemini-3) cross-vendor third-engine doc-contract + install wiring.
# The detection/cost-gate/gate-parity invariants live in the reference docs (semantic layer); this
# suite asserts each invariant is present AND bound to its actual clause, so a later edit that
# deletes/inverts one fails rather than surviving on an unrelated keyword. Install wiring is checked
# against the real install scripts. DOC-CONTRACT + WIRING test (no live `agy`, no auth needed).
# Run: bash tests/test_flow_antigravity_integration.sh   (exit 0 = all pass, 1 = any fail)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
REF="$ROOT/skills/flow/references"
SKILL="$ROOT/skills/flow/SKILL.md"
SEAM="$REF/antigravity-integration.md"
pass=0; fail=0
hasE() { if grep -qiE "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing /$2/ in $(basename "$1"))"; fail=$((fail+1)); fi; }
has()  { if grep -qi  "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing '$2' in $(basename "$1"))"; fail=$((fail+1)); fi; }
lacks(){ if grep -qiE "$2" "$1" 2>/dev/null; then echo "  FAIL [$3] (anti-pattern /$2/ present in $(basename "$1"))"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
file() { if [ -f "$1" ]; then echo "  ok   [$2]"; pass=$((pass+1)); else echo "  FAIL [$2] (no file $1)"; fail=$((fail+1)); fi; }

echo "==== Antigravity integration doc-contract + install wiring ===="

file "$SEAM" "antigravity-integration.md exists (the seam)"

# Invariant 1: two-state detection — installed is NOT sufficient, and the exit code MUST NOT be trusted.
has  "$SEAM" "installed"        "seam: INSTALLED state named"
hasE "$SEAM" "exit code lies|never.{0,30}exit code|exit code is ignored|exit code.{0,20}lie" "seam: exit code is explicitly not trusted"
hasE "$SEAM" "non-empty.{0,40}(output|response|token)|only non-empty" "seam: USABLE proven only by non-empty output"
hasE "$SEAM" "exit 0.{0,40}empty stdout|empty stdout.{0,40}unauthenticated" "seam: the measured exit0+empty-stdout fact is recorded"

# the liveness probe shape is the single most operationally critical clause (it distinguishes USABLE
# from NOT USABLE) — bind the sentinel token + timeout flag so a probe-shape regression fails here.
has  "$SEAM" "FLOWPONG"      "seam: liveness probe sentinel token specified"
has  "$SEAM" "print-timeout" "seam: liveness probe timeout flag specified"

# Invariant 2: headless unreliable -> interactive is the supported default; empty != pass (loud degrade).
hasE "$SEAM" "interactive.{0,40}(default|supported)|supported.{0,30}interactive" "seam: interactive is the supported default"
hasE "$SEAM" "empty.{0,40}(never|not).{0,20}(pass|approv)|review-unavailable" "seam: empty result is review-unavailable, NEVER a pass"

# Invariant 3: degrade-and-never-break (portability promise).
hasE "$SEAM" "degrade.*(announce|never|silent)|never.{0,20}(an error|a gate change)" "seam: degrade-never-break rule"
has  "$REF/agent-detection.md" "antigravity tier unavailable" "detection: degrade announce string mirrored"

# Invariant 4: cost/data gate — billable + diff/specs leave the machine to Google; closed 3-trigger set.
has  "$SEAM" "billable"        "seam: calls are billable"
hasE "$SEAM" "google|gemini api" "seam: data leaves machine to Google/Gemini"
has  "$SEAM" "two-strikes"     "seam cost gate: two-strikes trigger"
has  "$SEAM" "security-class"  "seam cost gate: security-class trigger"
has  "$SEAM" "opt-in"          "seam cost gate: operator opt-in trigger"
hasE "$SEAM" "never call antigravity on every stage|not .* every stage" "seam cost gate: closed-set (no fire-every-stage)"

# Invariant 5: gate parity — INFORMS, never auto-passes AND never auto-fails.
hasE "$SEAM" "never auto-pass|informs triage|never.{0,30}auto-(pass|fail)" "seam: gate parity (informs, never auto-decides)"

# Invariant 6: detection mirrored in the ladder, and points at the seam.
has  "$REF/agent-detection.md" "antigravity-integration.md" "detection: links to the seam doc"
hasE "$REF/agent-detection.md" "installed.{0,20}usable|never route on exit code" "detection: installed!=usable + exit-code rule mirrored"

# Invariant 7: install homes are the verified Antigravity paths (CLI + IDE), in both install scripts.
has  "$ROOT/install.sh"  ".gemini/antigravity-cli/skills/flow" "install.sh: agy CLI global home"
has  "$ROOT/install.sh"  ".gemini/config/skills/flow"          "install.sh: Antigravity IDE global home"
has  "$ROOT/install.sh"  "antigravity"                          "install.sh: antigravity target exists"
has  "$ROOT/install.ps1" ".gemini/antigravity-cli/skills/flow" "install.ps1: agy CLI global home"
has  "$ROOT/install.ps1" ".gemini/config/skills/flow"          "install.ps1: Antigravity IDE global home"
has  "$ROOT/install.ps1" "antigravity"                          "install.ps1: antigravity target exists (not just path strings)"

# Invariant 8: SKILL.md documents the tier + the discovery command.
has  "$SKILL" "antigravity-integration.md" "SKILL.md links the seam in the reference list"
has  "$SKILL" "agy inspect" "SKILL.md tells operator to confirm load via agy inspect"
hasE "$SKILL" "third engine|Gemini-3" "SKILL.md names the Gemini-3 third engine"

# Invariant 9 (v0.23 A0): the post-install Done line tells Antigravity users to restart/reload —
# the reported symptom was "installed, typed /flow, saw nothing" because a freshly-installed
# skill isn't discovered until the agent reloads, and the old static message never mentioned
# Antigravity at all. Both install scripts must build this hint dynamically (only for targets
# actually installed), not as a single hardcoded Claude+Codex-only string.
hasE "$ROOT/install.sh"  "antigravity.{0,80}(restart|reload)|(restart|reload).{0,80}antigravity" "install.sh: Antigravity restart/reload hint present"
lacks "$ROOT/install.sh" "^echo \"Done\. Claude Code: type /flow \. Codex CLI" "install.sh: old hardcoded Claude+Codex-only Done line is gone"
hasE "$ROOT/install.ps1" "antigravity.{0,80}(restart|reload)|(restart|reload).{0,80}antigravity" "install.ps1: Antigravity restart/reload hint present"
lacks "$ROOT/install.ps1" 'Write-Host "Done\. Claude Code: type /flow \. Codex CLI' "install.ps1: old hardcoded Claude+Codex-only Done line is gone"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
