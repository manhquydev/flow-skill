#!/usr/bin/env bash
# tests/test_flow_widelai_packaging.sh - T1: Agent Skills packaging + .widelai/ support.
# Covers (addendum §5 step 8):
#   1. SKILL.md frontmatter validity (name, compatibility, receipts attestation-only)
#   2. Frontmatter name equals the skill directory name
#   3. Rules-file generation (sync.mjs): exists, header, homed rules, no
#      "Both must agree", no flow-cost/v1, word budget, byte-identical re-run
#   4. Node CLI installer idempotency for --target widelai (fake HOME, two runs,
#      pointer line exactly once, user-edited rules conflict refused)
#   5. install.sh widelai (explicit target, autodetect on ~/.widelai/skills,
#      bare ~/.widelai does NOT install)
#   6. bash 3.2 run: bash -n + install.sh -h; npm pack lists the rules file
# Run: bash tests/test_flow_widelai_packaging.sh
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
pass=0
fail=0
ck() {
  if [ "$1" = "$2" ]; then
    echo "  ok   [$3]"
    pass=$((pass + 1))
  else
    echo "  FAIL [$3] expected='$1' got='$2'"
    fail=$((fail + 1))
  fi
}

SCRATCH="$(cd "$(mktemp -d)" && pwd -P)"
cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

SKILL="$ROOT/skills/flow/SKILL.md"
RULES_SRC="$ROOT/npm-wrapper/.widelai/rules/flowskill.md"

echo "=== 1. SKILL.md frontmatter validity ==="
fm="$(sed -n '2,/^---$/p' "$SKILL" | head -n -1)"
has_key() {
  printf '%s\n' "$fm" | grep -q "^$1:" && echo yes || echo no
}
ck yes "$(has_key name)" "frontmatter has name"
ck yes "$(has_key description)" "frontmatter has description"
ck yes "$(has_key license)" "frontmatter has license"
ck yes "$(has_key compatibility)" "frontmatter has compatibility"
ck yes "$(has_key metadata)" "frontmatter has metadata"
grep -q '^name: flow$' "$SKILL" && ck yes yes "name is flow" || ck yes no "name is flow"
grep -q '^compatibility: bash 3.2+, no runtime dependencies$' "$SKILL" && ck yes yes "compatibility line exact" || ck yes no "compatibility line exact"
grep -q '^  receipts: \[flow-attestation/v1\]$' "$SKILL" && ck yes yes "receipts lists flow-attestation/v1 only" || ck yes no "receipts lists flow-attestation/v1 only"
grep -q 'flow-cost' "$SKILL" && ck no yes "no flow-cost/v1 in SKILL.md" || ck no no "no flow-cost/v1 in SKILL.md"
grep -q '^  version: "1.0.0"$' "$SKILL" && ck yes yes "version stays unified 1.0.0" || ck yes no "version stays unified 1.0.0"
printf '%s\n' "$fm" | grep -q "$(printf '\t')" && ck no yes "frontmatter has no tabs" || ck no no "frontmatter has no tabs"

echo "=== 2. Frontmatter name equals the skill directory name ==="
fname="$(printf '%s\n' "$fm" | sed -n 's/^name: //p' | head -1)"
dname="$(basename "$ROOT/skills/flow")"
ck "$dname" "$fname" "frontmatter name ($fname) equals directory ($dname)"

echo "=== 3. Rules-file generation (sync.mjs) ==="
out="$(node "$ROOT/npm-wrapper/scripts/sync.mjs" 2>&1)" || { echo "FAIL: sync.mjs failed: $out"; fail=$((fail + 1)); }
[ -f "$RULES_SRC" ] && ck yes yes "generated rules file exists" || ck yes no "generated rules file exists"
grep -q 'GENERATED — do not edit by hand' "$RULES_SRC" && ck yes yes "rules header present" || ck yes no "rules header present"
grep -q 'Branch per card' "$RULES_SRC" && ck yes yes "rules file has branch/worktree rule" || ck yes no "rules file has branch/worktree rule"
grep -q 'bash 3.2-safe' "$RULES_SRC" && ck yes yes "rules file has bash 3.2-safe rule" || ck yes no "rules file has bash 3.2-safe rule"
grep -q 'zero new runtime dependencies' "$RULES_SRC" && ck yes yes "rules file has zero-new-deps rule" || ck yes no "rules file has zero-new-deps rule"
grep -q 'flow-attestation/v1' "$RULES_SRC" && ck yes yes "rules file points at flow-attestation/v1" || ck yes no "rules file points at flow-attestation/v1"
grep -q 'verify-chain' "$RULES_SRC" && ck yes yes "rules file points at verify-chain" || ck yes no "rules file points at verify-chain"
grep -q 'warning-only' "$RULES_SRC" && ck yes yes "rules file states warning-only next" || ck yes no "rules file states warning-only next"
grep -q 'Both must agree' "$RULES_SRC" && ck no yes "rules file never copies Both must agree" || ck no no "rules file never copies Both must agree"
grep -q 'flow-cost' "$RULES_SRC" && ck no yes "rules file never lists flow-cost/v1" || ck no no "rules file never lists flow-cost/v1"
grep -q 'BLOCKED' "$RULES_SRC" && ck no yes "rules file states no BLOCKED verdict" || ck no no "rules file states no BLOCKED verdict"
words="$(wc -w < "$RULES_SRC" | tr -d ' ')"
[ "$words" -le 400 ] && ck yes yes "rules file under 400 words ($words)" || ck yes no "rules file under 400 words ($words)"
cp "$RULES_SRC" "$SCRATCH/rules-first.md"
out="$(node "$ROOT/npm-wrapper/scripts/sync.mjs" 2>&1)" || { echo "FAIL: sync.mjs re-run failed: $out"; fail=$((fail + 1)); }
cmp -s "$RULES_SRC" "$SCRATCH/rules-first.md" && ck yes yes "regeneration is byte-identical" || ck yes no "regeneration is byte-identical"

echo "=== 4. Node CLI installer idempotency (--target widelai) ==="
CLI_HOME="$SCRATCH/fake_home_cli"
mkdir -p "$CLI_HOME"
out="$(HOME="$CLI_HOME" node "$ROOT/npm-wrapper/bin/cli.mjs" --yes -t widelai 2>&1)"; rc=$?
ck 0 "$rc" "CLI --target widelai exits 0 (got $rc: $out)"
[ -f "$CLI_HOME/.widelai/skills/flow/SKILL.md" ] && ck yes yes "CLI installs skill to ~/.widelai/skills/flow" || ck yes no "CLI installs skill to ~/.widelai/skills/flow"
[ -f "$CLI_HOME/.widelai/skills/flow/manifest-hashes.json" ] && ck yes yes "CLI install carries the skill receipt" || ck yes no "CLI install carries the skill receipt"
[ -f "$CLI_HOME/.widelai/rules/flowskill.md" ] && ck yes yes "CLI places the rules file" || ck yes no "CLI places the rules file"
[ -f "$CLI_HOME/.widelai/AGENTS.md" ] && ck yes yes "CLI creates ~/.widelai/AGENTS.md" || ck yes no "CLI creates ~/.widelai/AGENTS.md"
ptr="$(grep -c -Fx 'FlowSkill rules: see .widelai/rules/flowskill.md' "$CLI_HOME/.widelai/AGENTS.md" 2>/dev/null || true)"
ck 1 "$ptr" "pointer line appears exactly once"
printf '%s\n' "$out" | grep -q 'WidelCode' && ck yes yes "Done line mentions WidelCode" || ck yes no "Done line mentions WidelCode"
cp "$CLI_HOME/.widelai/rules/flowskill.md" "$SCRATCH/cli-rules-before.md"
cp "$CLI_HOME/.widelai/AGENTS.md" "$SCRATCH/cli-agents-before.md"
cp "$CLI_HOME/.widelai/skills/flow/SKILL.md" "$SCRATCH/cli-skill-before.md"
out="$(HOME="$CLI_HOME" node "$ROOT/npm-wrapper/bin/cli.mjs" --yes -t widelai 2>&1)"; rc=$?
ck 0 "$rc" "CLI re-install exits 0"
cmp -s "$CLI_HOME/.widelai/rules/flowskill.md" "$SCRATCH/cli-rules-before.md" && ck yes yes "rules file unchanged on re-install" || ck yes no "rules file unchanged on re-install"
cmp -s "$CLI_HOME/.widelai/AGENTS.md" "$SCRATCH/cli-agents-before.md" && ck yes yes "AGENTS.md unchanged on re-install" || ck yes no "AGENTS.md unchanged on re-install"
cmp -s "$CLI_HOME/.widelai/skills/flow/SKILL.md" "$SCRATCH/cli-skill-before.md" && ck yes yes "skill unchanged on re-install" || ck yes no "skill unchanged on re-install"
printf '\nuser edit\n' >> "$CLI_HOME/.widelai/rules/flowskill.md"
out="$(HOME="$CLI_HOME" node "$ROOT/npm-wrapper/bin/cli.mjs" --yes -t widelai 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ck yes yes "user-edited rules file refuses install (rc=$rc)" || ck yes no "user-edited rules file refuses install (rc=$rc)"
printf '%s\n' "$out" | grep -q 'refusing to overwrite' && ck yes yes "refusal names the overwrite guard" || ck yes no "refusal names the overwrite guard"
grep -q 'user edit' "$CLI_HOME/.widelai/rules/flowskill.md" && ck yes yes "user-edited rules file left untouched" || ck yes no "user-edited rules file left untouched"

echo "=== 5. install.sh widelai ==="
TEST_REPO="$SCRATCH/test_repo"
mkdir -p "$TEST_REPO/skills/flow" "$TEST_REPO/npm-wrapper"
cp "$ROOT/install.sh" "$TEST_REPO/"
cp -R "$ROOT/skills/flow/." "$TEST_REPO/skills/flow/"
cp -R "$ROOT/npm-wrapper/.widelai" "$TEST_REPO/npm-wrapper/"
SH_HOME="$SCRATCH/fake_home_sh"
mkdir -p "$SH_HOME"
out="$(HOME="$SH_HOME" bash "$TEST_REPO/install.sh" global widelai 2>&1)"; rc=$?
ck 0 "$rc" "install.sh global widelai exits 0 (got $rc)"
[ -f "$SH_HOME/.widelai/skills/flow/SKILL.md" ] && ck yes yes "install.sh installs skill to ~/.widelai/skills/flow" || ck yes no "install.sh installs skill to ~/.widelai/skills/flow"
[ -f "$SH_HOME/.widelai/rules/flowskill.md" ] && ck yes yes "install.sh places the rules file" || ck yes no "install.sh places the rules file"
ptr="$(grep -c -Fx 'FlowSkill rules: see .widelai/rules/flowskill.md' "$SH_HOME/.widelai/AGENTS.md" 2>/dev/null || true)"
ck 1 "$ptr" "install.sh pointer line appears exactly once"
printf '%s\n' "$out" | grep -q 'WidelCode' && ck yes yes "install.sh Done line mentions WidelCode" || ck yes no "install.sh Done line mentions WidelCode"

SH_HOME2="$SCRATCH/fake_home_sh2"
mkdir -p "$SH_HOME2/.widelai/skills"
out="$(HOME="$SH_HOME2" bash "$TEST_REPO/install.sh" global all 2>&1)"; rc=$?
ck 0 "$rc" "install.sh global all exits 0 with marker present"
[ -f "$SH_HOME2/.widelai/skills/flow/SKILL.md" ] && ck yes yes "install.sh global all autodetects ~/.widelai/skills" || ck yes no "install.sh global all autodetects ~/.widelai/skills"

SH_HOME3="$SCRATCH/fake_home_sh3"
mkdir -p "$SH_HOME3/.widelai"
printf '{}' > "$SH_HOME3/.widelai/credentials.json"
out="$(HOME="$SH_HOME3" bash "$TEST_REPO/install.sh" global all 2>&1)"; rc=$?
ck 0 "$rc" "install.sh global all exits 0 with bare ~/.widelai"
[ -d "$SH_HOME3/.widelai/skills/flow" ] && ck no yes "bare ~/.widelai does NOT install widelai" || ck no no "bare ~/.widelai does NOT install widelai"

echo "=== 6. bash 3.2 run + tarball ==="
bash -n "$ROOT/install.sh" 2>/dev/null; rc=$?
ck 0 "$rc" "bash -n install.sh passes"
bash "$ROOT/install.sh" -h >/dev/null 2>&1; rc=$?
ck 0 "$rc" "install.sh -h exits 0"
pack_list="$(cd "$ROOT/npm-wrapper" && npm pack --dry-run 2>/dev/null)"
printf '%s\n' "$pack_list" | grep -q 'widelai/rules/flowskill.md' && ck yes yes "npm pack lists .widelai/rules/flowskill.md" || ck yes no "npm pack lists .widelai/rules/flowskill.md"

echo "=== Summary ==="
echo "Pass: $pass, Fail: $fail"
[ "$fail" -eq 0 ] || exit 1
