#!/usr/bin/env bash
# tests/test_flow_widelai_packaging.sh - T1: Agent Skills packaging + .widelai/ support.
# Covers (addendum §5 step 8):
#   1. SKILL.md frontmatter validity (name, compatibility, receipts attestation-only)
#   2. Frontmatter name equals the skill directory name
#   3. Rules-file generation (sync.mjs): exists, header, homed rules, no
#      "Both must agree", no flow-cost/v1, word budget, byte-identical re-run
#   3b. Rules generation on a CRLF checkout (Windows): sync succeeds, verdict
#      line present, generated file byte-identical to the LF one, no CR bytes
#   4. Node CLI installer idempotency for --target widelai (fake HOME, two runs,
#      pointer line exactly once, user-edited rules conflict refused)
#   4b. Node CLI: CRLF AGENTS.md (no duplicate pointer), symlinked/directory
#      destinations refused, two concurrent extras updates serialize
#   5. install.sh widelai (explicit target, autodetect on ~/.widelai/skills,
#      bare ~/.widelai does NOT install)
#   5b. install.sh: CRLF AGENTS.md (no duplicate pointer), symlinked/directory
#      destinations refused
#   6. bash 3.2 run: bash -n + install.sh -h; npm pack --json lists the exact
#      rules-file entry (not the prepack log line)
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

# Windows path forms for Node: Node's homedir() on Windows reads USERPROFILE
# (libuv: USERPROFILE first, HOMEDRIVE+HOMEPATH only as fallback), ignoring
# HOME — so a fake HOME alone never redirects the Node installer there. And
# a Git Bash (MSYS) path such as /c/Users/... must reach Node in Windows
# form: path.join('/c/...') yields a drive-relative \c\... (D:\c\... on the
# runner) instead of C:\.... to_native_path (cygpath -w) is for env vars and
# argv; to_json_path (cygpath -m, forward slashes) is for paths embedded in
# generated .mjs source, where backslashes would be JS escape sequences.
# Both fall back to the input unchanged where cygpath is absent
# (Linux/macOS), mirroring tests/test_flow_host_hooks.sh.
to_native_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s' "$1"
  fi
}
to_json_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s' "$1"
  fi
}
# MSYS2 Git Bash deep-copies `ln -s` targets by default
# (winsymlinks:deepcopy), so a "symlink" fixture would be a regular file
# and the installer would rightly accept it. Prefer a native symlink; if
# the runner cannot make one, the caller skips the refusal checks (the
# refusal logic itself is covered on Linux/macOS).
make_symlink() {
  ln -s "$1" "$2" 2>/dev/null
  if [ -L "$2" ]; then return 0; fi
  rm -f "$2"
  MSYS=winsymlinks:nativestrict ln -s "$1" "$2" 2>/dev/null
  [ -L "$2" ]
}

SCRATCH="$(cd "$(mktemp -d)" && pwd -P)"
cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

SKILL="$ROOT/skills/flow/SKILL.md"
RULES_SRC="$ROOT/npm-wrapper/.widelai/rules/flowskill.md"

echo "=== 1. SKILL.md frontmatter validity ==="
# Portable: `head -n -1` is a GNU extension BSD head rejects (macOS CI).
fm="$(sed -n '2,/^---$/p' "$SKILL" | sed '$d')"
has_key() {
  printf '%s\n' "$fm" | grep -q "^$1:" && echo yes || echo no
}
ck yes "$(has_key name)" "frontmatter has name"
ck yes "$(has_key description)" "frontmatter has description"
ck yes "$(has_key license)" "frontmatter has license"
ck yes "$(has_key compatibility)" "frontmatter has compatibility"
ck yes "$(has_key metadata)" "frontmatter has metadata"
grep -q '^name: flow$' "$SKILL" && ck yes yes "name is flow" || ck yes no "name is flow"
grep -q '^compatibility: bash 3.2+, Python 3.7+ (stdlib sqlite3) for product commands$' "$SKILL" && ck yes yes "compatibility line exact" || ck yes no "compatibility line exact"
grep -q '^  receipts: flow-attestation/v1$' "$SKILL" && ck yes yes "receipts lists flow-attestation/v1 only" || ck yes no "receipts lists flow-attestation/v1 only"
grep -q 'flow-cost' "$SKILL" && ck no yes "no flow-cost/v1 in SKILL.md" || ck no no "no flow-cost/v1 in SKILL.md"
# shellcheck disable=SC2016
pkg_ver="$(sed -n 's/^  "version": "\([^"]*\)",$/\1/p' "$ROOT/npm-wrapper/package.json" | head -1)"
grep -q "^  version: \"$pkg_ver\"\$" "$SKILL" && ck yes yes "version matches npm-wrapper ($pkg_ver)" || ck yes no "version matches npm-wrapper ($pkg_ver)"
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

echo "=== 3b. Rules generation on a CRLF checkout (Windows) ==="
CRLF_REPO="$SCRATCH/crlf-repo"
mkdir -p "$CRLF_REPO"
cp -R "$ROOT/." "$CRLF_REPO/"
rm -rf "$CRLF_REPO/plans" "$CRLF_REPO/.git"
for f in AGENTS.md CONTRIBUTING.md skills/flow/law/CLAUDE.md skills/flow/references/attestations.md skills/flow/runner/flow.sh; do
  awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$CRLF_REPO/$f" > "$CRLF_REPO/$f.crlf" && mv "$CRLF_REPO/$f.crlf" "$CRLF_REPO/$f"
done
out="$(node "$CRLF_REPO/npm-wrapper/scripts/sync.mjs" 2>&1)"; rc=$?
ck 0 "$rc" "sync.mjs succeeds on a CRLF tree (got $rc: $out)"
CRLF_RULES="$CRLF_REPO/npm-wrapper/.widelai/rules/flowskill.md"
[ -f "$CRLF_RULES" ] && ck yes yes "CRLF tree still generates the rules file" || ck yes no "CRLF tree still generates the rules file"
grep -q 'verdict `pass|fail|override` only' "$CRLF_RULES" && ck yes yes "CRLF tree rules file has the verdict line" || ck yes no "CRLF tree rules file has the verdict line"
cmp -s "$CRLF_RULES" "$RULES_SRC" && ck yes yes "CRLF rules file is byte-identical to the LF one" || ck yes no "CRLF rules file is byte-identical to the LF one"
grep -q $'\r' "$CRLF_RULES" && ck no yes "generated rules file has no CR bytes" || ck no no "generated rules file has no CR bytes"

echo "=== 4. Node CLI installer idempotency (--target widelai) ==="
CLI_HOME="$SCRATCH/fake_home_cli"
mkdir -p "$CLI_HOME"
out="$(HOME="$CLI_HOME" USERPROFILE="$(to_native_path "$CLI_HOME")" node "$ROOT/npm-wrapper/bin/cli.mjs" --yes -t widelai 2>&1)"; rc=$?
ck 0 "$rc" "CLI --target widelai exits 0 (got $rc: $out)"
# Fail fast on a wrong home instead of cascading: the CLI must name the fake
# home (Windows form) in its output, not the operator's real home.
printf '%s\n' "$out" | grep -Fq "$(to_native_path "$CLI_HOME")" && ck yes yes "CLI output names the fake home" || ck yes no "CLI output names the fake home"
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
out="$(HOME="$CLI_HOME" USERPROFILE="$(to_native_path "$CLI_HOME")" node "$ROOT/npm-wrapper/bin/cli.mjs" --yes -t widelai 2>&1)"; rc=$?
ck 0 "$rc" "CLI re-install exits 0"
cmp -s "$CLI_HOME/.widelai/rules/flowskill.md" "$SCRATCH/cli-rules-before.md" && ck yes yes "rules file unchanged on re-install" || ck yes no "rules file unchanged on re-install"
cmp -s "$CLI_HOME/.widelai/AGENTS.md" "$SCRATCH/cli-agents-before.md" && ck yes yes "AGENTS.md unchanged on re-install" || ck yes no "AGENTS.md unchanged on re-install"
cmp -s "$CLI_HOME/.widelai/skills/flow/SKILL.md" "$SCRATCH/cli-skill-before.md" && ck yes yes "skill unchanged on re-install" || ck yes no "skill unchanged on re-install"
printf '\nuser edit\n' >> "$CLI_HOME/.widelai/rules/flowskill.md"
out="$(HOME="$CLI_HOME" USERPROFILE="$(to_native_path "$CLI_HOME")" node "$ROOT/npm-wrapper/bin/cli.mjs" --yes -t widelai 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ck yes yes "user-edited rules file refuses install (rc=$rc)" || ck yes no "user-edited rules file refuses install (rc=$rc)"
printf '%s\n' "$out" | grep -q 'refusing to overwrite' && ck yes yes "refusal names the overwrite guard" || ck yes no "refusal names the overwrite guard"
grep -q 'user edit' "$CLI_HOME/.widelai/rules/flowskill.md" && ck yes yes "user-edited rules file left untouched" || ck yes no "user-edited rules file left untouched"

echo "=== 4b. Node CLI: CRLF pointer, symlink/directory refusal, concurrent extras ==="
# CRLF AGENTS.md: reinstall must recognize the pointer, not duplicate it.
# (Restore the rules file first: §4 left it user-edited to test the refusal.)
cp "$SCRATCH/cli-rules-before.md" "$CLI_HOME/.widelai/rules/flowskill.md"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$CLI_HOME/.widelai/AGENTS.md" > "$SCRATCH/agents-crlf.md" && mv "$SCRATCH/agents-crlf.md" "$CLI_HOME/.widelai/AGENTS.md"
out="$(HOME="$CLI_HOME" USERPROFILE="$(to_native_path "$CLI_HOME")" node "$ROOT/npm-wrapper/bin/cli.mjs" --yes -t widelai 2>&1)"; rc=$?
ck 0 "$rc" "CLI re-install over CRLF AGENTS.md exits 0 (got $rc)"
ptr="$(tr -d '\r' < "$CLI_HOME/.widelai/AGENTS.md" | grep -c -Fx 'FlowSkill rules: see .widelai/rules/flowskill.md')"
ck 1 "$ptr" "CRLF pointer still appears exactly once"

# Symlinked destinations are refused, never followed.
CLI_HOME_SYM="$SCRATCH/fake_home_sym"
mkdir -p "$CLI_HOME_SYM/.widelai/rules"
printf 'do not touch\n' > "$SCRATCH/sym-target.txt"
if make_symlink "$SCRATCH/sym-target.txt" "$CLI_HOME_SYM/.widelai/rules/flowskill.md"; then
out="$(HOME="$CLI_HOME_SYM" USERPROFILE="$(to_native_path "$CLI_HOME_SYM")" node "$ROOT/npm-wrapper/bin/cli.mjs" --yes -t widelai 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ck yes yes "CLI refuses a symlinked rules destination (rc=$rc)" || ck yes no "CLI refuses a symlinked rules destination (rc=$rc)"
if grep -q 'do not touch' "$SCRATCH/sym-target.txt" && ! grep -q 'FlowSkill rules' "$SCRATCH/sym-target.txt"; then ck yes yes "CLI symlink target left untouched"; else ck yes no "CLI symlink target left untouched"; fi
else
echo "  skip [CLI refuses a symlinked rules destination — no native symlink on this runner]"
fi

CLI_HOME_SYM2="$SCRATCH/fake_home_sym2"
mkdir -p "$CLI_HOME_SYM2/.widelai/rules"
cp "$RULES_SRC" "$CLI_HOME_SYM2/.widelai/rules/flowskill.md"
if make_symlink "$SCRATCH/sym-target.txt" "$CLI_HOME_SYM2/.widelai/AGENTS.md"; then
out="$(HOME="$CLI_HOME_SYM2" USERPROFILE="$(to_native_path "$CLI_HOME_SYM2")" node "$ROOT/npm-wrapper/bin/cli.mjs" --yes -t widelai 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ck yes yes "CLI refuses a symlinked AGENTS.md (rc=$rc)" || ck yes no "CLI refuses a symlinked AGENTS.md (rc=$rc)"
else
echo "  skip [CLI refuses a symlinked AGENTS.md — no native symlink on this runner]"
fi

# A directory at the rules destination is refused (not a nested copy).
CLI_HOME_DIR="$SCRATCH/fake_home_dir"
mkdir -p "$CLI_HOME_DIR/.widelai/rules/flowskill.md"
out="$(HOME="$CLI_HOME_DIR" USERPROFILE="$(to_native_path "$CLI_HOME_DIR")" node "$ROOT/npm-wrapper/bin/cli.mjs" --yes -t widelai 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ck yes yes "CLI refuses a directory at the rules destination (rc=$rc)" || ck yes no "CLI refuses a directory at the rules destination (rc=$rc)"

# Two concurrent extras updates serialize: exactly one pointer, no lost data.
# The generated .mjs embeds $ROOT as a path: on Windows a bare drive path
# (D:/...) is NOT a valid ESM import specifier — Node parses it as a URL
# with scheme 'd:' and throws ERR_UNSUPPORTED_ESM_URL_SCHEME. Import through
# pathToFileURL so the specifier is a proper file:// URL on every platform.
ROOT_JS="$(to_json_path "$ROOT")"
cat > "$SCRATCH/run-extras.mjs" <<EOF
import { pathToFileURL } from 'node:url';
const { installWidelaiExtras } = await import(pathToFileURL('$ROOT_JS/npm-wrapper/src/installer.mjs').href);
installWidelaiExtras({ pkgRoot: '$ROOT_JS/npm-wrapper', home: process.argv[2] });
EOF
CLI_HOME_CONC="$SCRATCH/fake_home_conc"
mkdir -p "$CLI_HOME_CONC"
node "$SCRATCH/run-extras.mjs" "$(to_native_path "$CLI_HOME_CONC")" & pid1=$!
node "$SCRATCH/run-extras.mjs" "$(to_native_path "$CLI_HOME_CONC")" & pid2=$!
wait $pid1; rc1=$?
wait $pid2; rc2=$?
ck 0 "$rc1" "concurrent extras run 1 exits 0 (got $rc1)"
ck 0 "$rc2" "concurrent extras run 2 exits 0 (got $rc2)"
ptr="$(grep -c -Fx 'FlowSkill rules: see .widelai/rules/flowskill.md' "$CLI_HOME_CONC/.widelai/AGENTS.md" 2>/dev/null || true)"
ck 1 "$ptr" "concurrent extras append the pointer exactly once"
cmp -s "$CLI_HOME_CONC/.widelai/rules/flowskill.md" "$RULES_SRC" && ck yes yes "concurrent extras rules file is byte-identical" || ck yes no "concurrent extras rules file is byte-identical"

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

SH_HOME4="$SCRATCH/fake_home_sh4"
mkdir -p "$SH_HOME4/.widelai"
printf 'regular file, not a container\n' > "$SH_HOME4/.widelai/skills"
out="$(HOME="$SH_HOME4" bash "$TEST_REPO/install.sh" global all 2>&1)"; rc=$?
ck 0 "$rc" "install.sh global all exits 0 with regular-file marker"
[ -d "$SH_HOME4/.widelai/skills/flow" ] && ck no yes "regular-file ~/.widelai/skills does NOT install widelai" || ck no no "regular-file ~/.widelai/skills does NOT install widelai"
[ -f "$SH_HOME4/.widelai/skills" ] && ck yes yes "regular-file ~/.widelai/skills marker left untouched" || ck yes no "regular-file ~/.widelai/skills marker left untouched"

echo "=== 5b. install.sh: CRLF pointer, symlink/directory refusal ==="
# CRLF AGENTS.md: reinstall must recognize the pointer, not duplicate it.
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$SH_HOME/.widelai/AGENTS.md" > "$SCRATCH/sh-agents-crlf.md" && mv "$SCRATCH/sh-agents-crlf.md" "$SH_HOME/.widelai/AGENTS.md"
out="$(HOME="$SH_HOME" bash "$TEST_REPO/install.sh" global widelai 2>&1)"; rc=$?
ck 0 "$rc" "install.sh re-install over CRLF AGENTS.md exits 0 (got $rc)"
ptr="$(tr -d '\r' < "$SH_HOME/.widelai/AGENTS.md" | grep -c -Fx 'FlowSkill rules: see .widelai/rules/flowskill.md')"
ck 1 "$ptr" "install.sh CRLF pointer still appears exactly once"

# Symlinked destinations are refused, never followed.
SH_HOME_SYM="$SCRATCH/fake_home_sh_sym"
mkdir -p "$SH_HOME_SYM/.widelai/rules"
if make_symlink "$SCRATCH/sym-target.txt" "$SH_HOME_SYM/.widelai/rules/flowskill.md"; then
out="$(HOME="$SH_HOME_SYM" bash "$TEST_REPO/install.sh" global widelai 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ck yes yes "install.sh refuses a symlinked rules destination (rc=$rc)" || ck yes no "install.sh refuses a symlinked rules destination (rc=$rc)"
if grep -q 'do not touch' "$SCRATCH/sym-target.txt" && ! grep -q 'FlowSkill rules' "$SCRATCH/sym-target.txt"; then ck yes yes "install.sh symlink target left untouched"; else ck yes no "install.sh symlink target left untouched"; fi
else
echo "  skip [install.sh refuses a symlinked rules destination — no native symlink on this runner]"
fi

SH_HOME_SYM2="$SCRATCH/fake_home_sh_sym2"
mkdir -p "$SH_HOME_SYM2/.widelai/rules"
cp "$RULES_SRC" "$SH_HOME_SYM2/.widelai/rules/flowskill.md"
if make_symlink "$SCRATCH/sym-target.txt" "$SH_HOME_SYM2/.widelai/AGENTS.md"; then
out="$(HOME="$SH_HOME_SYM2" bash "$TEST_REPO/install.sh" global widelai 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ck yes yes "install.sh refuses a symlinked AGENTS.md (rc=$rc)" || ck yes no "install.sh refuses a symlinked AGENTS.md (rc=$rc)"
else
echo "  skip [install.sh refuses a symlinked AGENTS.md — no native symlink on this runner]"
fi

# A directory at the rules destination is refused (not a nested copy).
SH_HOME_DIR="$SCRATCH/fake_home_sh_dir"
mkdir -p "$SH_HOME_DIR/.widelai/rules/flowskill.md"
out="$(HOME="$SH_HOME_DIR" bash "$TEST_REPO/install.sh" global widelai 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ck yes yes "install.sh refuses a directory at the rules destination (rc=$rc)" || ck yes no "install.sh refuses a directory at the rules destination (rc=$rc)"

echo "=== 6. bash 3.2 run + tarball ==="
bash -n "$ROOT/install.sh" 2>/dev/null; rc=$?
ck 0 "$rc" "bash -n install.sh passes"
bash "$ROOT/install.sh" -h >/dev/null 2>&1; rc=$?
ck 0 "$rc" "install.sh -h exits 0"
# Parse the --json listing and assert the exact files entry: grepping the
# plain listing can match the prepack sync log instead of the shipped file.
pack_json="$(cd "$ROOT/npm-wrapper" && npm pack --dry-run --ignore-scripts --json 2>/dev/null)"
printf '%s' "$pack_json" | node -e "let s='';process.stdin.on('data',d=>{s+=d}).on('end',()=>{try{const j=JSON.parse(s);const files=((j[0]||{}).files||[]).map(f=>f.path);process.exit(files.includes('.widelai/rules/flowskill.md')?0:1)}catch(e){process.exit(2)}})"; rc=$?
ck 0 "$rc" "npm pack --json lists the exact .widelai/rules/flowskill.md entry (got $rc)"

echo "=== Summary ==="
echo "Pass: $pass, Fail: $fail"
[ "$fail" -eq 0 ] || exit 1
