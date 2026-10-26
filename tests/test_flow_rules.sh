#!/usr/bin/env bash
# tests/test_flow_rules.sh - Verification for multi-harness workspace rule scaffolding (flow rules).
# Run: bash tests/test_flow_rules.sh (Git Bash on Windows or any POSIX bash). Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
PY="${FLOW_PYTHON:-python3}"

pass=0
fail=0

ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

SCRATCH="$(mktemp -d)"
cleanup() { rm -rf "$SCRATCH" 2>/dev/null; }
trap cleanup EXIT

echo "A) rules list outputs all 9 supported targets"
out_list="$(bash "$RUN" rules list 2>&1)"; rc_list=$?
ck 0 "$rc_list" "rules list exits 0"
has "$out_list" "cursor" "cursor listed"
has "$out_list" "windsurf" "windsurf listed"
has "$out_list" "roo" "roo listed"
has "$out_list" "cline" "cline listed"
has "$out_list" "aider" "aider listed"
has "$out_list" "openhands" "openhands listed"
has "$out_list" "copilot" "copilot listed"
has "$out_list" 'agent-skills -> .agents/skills/flow/SKILL.md' "Agent Skills destination listed"
has "$out_list" 'agents-md    -> AGENTS.md' "agents-md destination listed"

echo "B) rules cursor emits valid frontmatter and directives"
out_cur="$(bash "$RUN" rules cursor 2>&1)"; rc_cur=$?
ck 0 "$rc_cur" "rules cursor exits 0"
has "$out_cur" "description: Flow buildflow discipline layer" "frontmatter description present"
has "$out_cur" "alwaysApply: false" "alwaysApply flag is false"
has "$out_cur" "globs:" "globs directive present"
has "$out_cur" "globs: flow/\*\*,cards/\*\*" "targeted globs present"
has "$out_cur" "Respect Allowed Files" "core directive present"
CUR_DIR="$SCRATCH/cur_test"
mkdir -p "$CUR_DIR"
(
  cd "$CUR_DIR"
  FLOW_PROJECT_ROOT="$CUR_DIR" bash "$RUN" rules cursor --write >/dev/null 2>&1
)
has "$(cat "$CUR_DIR/.cursor/rules/flow.mdc")" "alwaysApply: false" "generated .cursor/rules/flow.mdc contains alwaysApply: false"
has "$(cat "$CUR_DIR/.cursor/rules/flow.mdc")" "globs:" "generated .cursor/rules/flow.mdc contains globs:"

echo "C) rules roo emits valid JSON custom modes"
out_roo="$(bash "$RUN" rules roo 2>&1)"; rc_roo=$?
ck 0 "$rc_roo" "rules roo exits 0"
ROO_DIR="$SCRATCH/roo_test"
mkdir -p "$ROO_DIR"
(
  cd "$ROO_DIR"
  FLOW_PROJECT_ROOT="$ROO_DIR" bash "$RUN" rules roo --write >/dev/null 2>&1
  "$PY" -c "import json, sys; d=json.load(open('.roomodes')); assert isinstance(d.get('customModes'), list); m=d['customModes'][0]; assert m['slug']=='flow'"
)
ck 0 "$?" "rules roo generates valid .roomodes JSON/customModes structure"

echo "D) rules aider emits valid YAML with test-cmd"
out_aider="$(bash "$RUN" rules aider 2>&1)"; rc_aider=$?
ck 0 "$rc_aider" "rules aider exits 0"
has "$out_aider" 'test-cmd: "bash -c ' "test-cmd present with bash wrapper"
has "$out_aider" "auto-test: true" "auto-test present"
no "$out_aider" "check-doc-budgets\.sh" ".aider.conf.yml does not contain check-doc-budgets.sh"

AIDER_TEST_DIR="$SCRATCH/aider_test"
mkdir -p "$AIDER_TEST_DIR/cards" "$AIDER_TEST_DIR/skills/flow/runner"
ln -s "$RUN" "$AIDER_TEST_DIR/skills/flow/runner/flow.sh"
(
  cd "$AIDER_TEST_DIR"
  FLOW_PROJECT_ROOT="$AIDER_TEST_DIR" bash "$RUN" rules aider --write >/dev/null 2>&1
)
no "$(cat "$AIDER_TEST_DIR/.aider.conf.yml")" "check-doc-budgets\.sh" "materialized .aider.conf.yml does not contain check-doc-budgets.sh"

# Python on Windows cannot open Git Bash /tmp/... paths (FileNotFoundError). When cygpath
# exists (Windows Git Bash), translate to a native Windows path for the python -c open().
AIDER_CONF_FOR_PY="$AIDER_TEST_DIR/.aider.conf.yml"
if command -v cygpath >/dev/null 2>&1; then
  AIDER_CONF_FOR_PY="$(cygpath -w "$AIDER_CONF_FOR_PY")"
fi

test_cmd="$("$PY" -c '
import json
with open(r"'"$AIDER_CONF_FOR_PY"'") as f:
    line = next(line for line in f if line.startswith("test-cmd: "))
print(json.loads(line[len("test-cmd: "):]))
')"

MARKER="$SCRATCH/flow_aider_injected_$$"
rm -f "$MARKER"
printf 'C-001; touch %s\n' "$MARKER" > "$AIDER_TEST_DIR/cards/.inflight"

cmd_out="$(
  cd "$AIDER_TEST_DIR"
  FLOW_PROJECT_ROOT="$AIDER_TEST_DIR" eval "$test_cmd" 2>&1
)"
[ ! -f "$MARKER" ]; ck 0 "$?" "hostile injection did NOT execute (marker file not created)"
has "$cmd_out" "required harness missing" "hostile inflight content safely refused (v1: runtime required, injection not executed)"

echo "E) rules cursor --write creates .cursor/rules/flow.mdc on disk"
(
  cd "$SCRATCH"
  FLOW_PROJECT_ROOT="$SCRATCH" bash "$RUN" rules cursor --write >/dev/null 2>&1
)
ck 0 "$?" "rules cursor --write exits 0"
[ -f "$SCRATCH/.cursor/rules/flow.mdc" ]; ck 0 "$?" "file materialized at .cursor/rules/flow.mdc"
has "$(cat "$SCRATCH/.cursor/rules/flow.mdc")" "Flow Discipline Rules for Cursor" "materialized file contains expected directives"

echo "E2) rules --write strictly refuses to overwrite existing files"
# Test 1: pre-existing .aider.conf.yml
printf '%s\n' "PRE_EXISTING_USER_CONFIG_SENTINEL" > "$SCRATCH/.aider.conf.yml"
out_ow="$(
  cd "$SCRATCH"
  FLOW_PROJECT_ROOT="$SCRATCH" bash "$RUN" rules aider --write 2>&1
)"
rc_ow=$?
ck 1 "$rc_ow" "rules aider --write on existing file exits 1"
has "$out_ow" "already exists" "refusal message reports destination already exists"
has "$(cat "$SCRATCH/.aider.conf.yml")" "PRE_EXISTING_USER_CONFIG_SENTINEL" "existing .aider.conf.yml content preserved"

# Test 2: pre-existing .cursor/rules/flow.mdc
printf '%s\n' "PRE_EXISTING_CURSOR_RULE_SENTINEL" > "$SCRATCH/.cursor/rules/flow.mdc"
out_ow_cur="$(
  cd "$SCRATCH"
  FLOW_PROJECT_ROOT="$SCRATCH" bash "$RUN" rules cursor --write 2>&1
)"
rc_ow_cur=$?
ck 1 "$rc_ow_cur" "rules cursor --write on existing file exits 1"
has "$out_ow_cur" "refusing to overwrite" "refusal message states refusing to overwrite"
has "$(cat "$SCRATCH/.cursor/rules/flow.mdc")" "PRE_EXISTING_CURSOR_RULE_SENTINEL" "existing .cursor/rules/flow.mdc content preserved"

# Test 3: dangling symlink refusal (must not follow dangling symlink to write target)
PROJ_SYM="$SCRATCH/proj_sym"
mkdir -p "$PROJ_SYM/.cursor/rules"
ln -s "$SCRATCH/absent_target.txt" "$PROJ_SYM/.cursor/rules/flow.mdc" 2>/dev/null || true
if [ -L "$PROJ_SYM/.cursor/rules/flow.mdc" ]; then
  out_sym="$(
    cd "$PROJ_SYM"
    FLOW_PROJECT_ROOT="$PROJ_SYM" bash "$RUN" rules cursor --write 2>&1
  )"
  rc_sym=$?
  ck 1 "$rc_sym" "rules cursor --write on dangling symlink exits 1"
  case "$out_sym" in
    *"already exists"*|*"refusing to overwrite"*) ck 0 0 "error message mentions already exists or refusing to overwrite" ;;
    *) ck 0 1 "error message mentions already exists or refusing to overwrite" ;;
  esac
  [ -L "$PROJ_SYM/.cursor/rules/flow.mdc" ]; ck 0 "$?" "dangling symlink is preserved"
  [ ! -f "$SCRATCH/absent_target.txt" ]; ck 0 "$?" "dangling target was NOT created"
else
  echo "  ok   [platform cannot create symlinks: dangling symlink test skipped]"
  pass=$((pass+4))
fi

echo "F) unknown harness exits 2 with usage"
out_unk="$(bash "$RUN" rules unknown_harness 2>&1)"; rc_unk=$?
ck 2 "$rc_unk" "unknown harness exits 2"
has "$out_unk" "unknown harness: unknown_harness" "error message reports unknown harness"
has "$out_unk" "agents-md" "unknown harness usage includes agents-md"

echo "G) invalid extra arguments exits 2"
out_bad="$(bash "$RUN" rules cursor --badflag 2>&1)"; rc_bad=$?
ck 2 "$rc_bad" "invalid extra option exits 2"
has "$out_bad" "usage: flow rules" "usage string printed on bad option"
has "$out_bad" "agents-md" "invalid option usage includes agents-md"

echo "H) Agent Skills preview, standard fields, and safe creation"
AGENT_DIR="$SCRATCH/agent_test"
mkdir -p "$AGENT_DIR"
out_agent="$(FLOW_PROJECT_ROOT="$AGENT_DIR" bash "$RUN" rules agent-skills)"; rc_agent=$?
ck 0 "$rc_agent" "Agent Skills preview exits 0"
[ ! -e "$AGENT_DIR/.agents" ]; ck 0 "$?" "preview creates no discovery directory"
[ -z "$(find "$AGENT_DIR" -mindepth 1 -print)" ]; ck 0 "$?" "preview leaves project empty"
FLOW_PROJECT_ROOT="$AGENT_DIR" bash "$RUN" rules agent-skills --write >/dev/null 2>&1
ck 1 "$?" "empty project refuses broken pointer"
[ -z "$(find "$AGENT_DIR" -mindepth 1 -print)" ]; ck 0 "$?" "missing bundle refusal creates no files"
mkdir -p "$AGENT_DIR/skills/flow/runner"
printf '%s\n' '# Canonical Flow fixture' > "$AGENT_DIR/skills/flow/SKILL.md"
FLOW_PROJECT_ROOT="$AGENT_DIR" bash "$RUN" rules agent-skills --write >/dev/null 2>&1
ck 1 "$?" "missing canonical runner refuses pointer"
[ ! -e "$AGENT_DIR/.agents" ]; ck 0 "$?" "missing runner refusal creates no discovery directory"
printf '%s\n' '#!/usr/bin/env bash' 'printf "canonical-runner-ok\\n"' > "$AGENT_DIR/skills/flow/runner/flow.sh"
printf '%s\n' "$out_agent" | "$PY" -c '
import sys
text = sys.stdin.read()
lines = text.splitlines()
assert lines[0] == "---" and lines[3] == "---"
assert lines[1] == "name: flow"
assert lines[2].startswith("description: ")
assert 0 < len(lines[2][len("description: "):]) <= 1024
assert len(text) < 2000
try:
    import yaml
except ImportError:
    pass
else:
    fields = yaml.safe_load("\n".join(lines[1:3]))
    assert fields["name"] == "flow" and isinstance(fields["description"], str)
'
ck 0 "$?" "standard frontmatter and short pointer shape"
has "$out_agent" 'Codex/Gemini' "scoped consumers named"
has "$out_agent" 'skills/flow/SKILL.md' "canonical source referenced"
has "$out_agent" 'source of truth' "canonical authority preserved"
has "$out_agent" 'bash <skill-dir>/runner/flow.sh <command>' "host runner instruction present"
has "$out_agent" 'From the project root' "runner working directory explicit"
has "$out_agent" '.claude/skills' "Claude path kept separate"
FLOW_PROJECT_ROOT="$AGENT_DIR" bash "$RUN" rules agent-skills --write
ck 0 "$?" "Agent Skills write exits 0"
AGENT_DEST="$AGENT_DIR/.agents/skills/flow/SKILL.md"
[ -f "$AGENT_DEST" ]; ck 0 "$?" "exact discovery destination created"
printf '%s\n' "$out_agent" | cmp - "$AGENT_DEST"
ck 0 "$?" "written bytes match preview"
[ -f "$AGENT_DIR/.agents/skills/flow/../../../skills/flow/SKILL.md" ]; ck 0 "$?" "relative canonical skill link resolves"
runner_result="$(cd "$AGENT_DIR" && bash skills/flow/runner/flow.sh status)"
ck 'canonical-runner-ok' "$runner_result" "project-root runner instruction reaches canonical runner"
printf '%s\n' 'USER_SKILL_SENTINEL' > "$AGENT_DEST"
FLOW_PROJECT_ROOT="$AGENT_DIR" bash "$RUN" rules agent-skills --write >/dev/null 2>&1
ck 1 "$?" "existing Agent Skills file refused"
ck 'USER_SKILL_SENTINEL' "$(cat "$AGENT_DEST")" "existing skill preserved exactly"
AGENT_SYM="$SCRATCH/agent_sym"
mkdir -p "$AGENT_SYM/.agents/skills/flow"
mkdir -p "$AGENT_SYM/skills/flow/runner"
cp "$AGENT_DIR/skills/flow/SKILL.md" "$AGENT_SYM/skills/flow/SKILL.md"
cp "$AGENT_DIR/skills/flow/runner/flow.sh" "$AGENT_SYM/skills/flow/runner/flow.sh"
ln -s "$SCRATCH/absent_agent_skill" "$AGENT_SYM/.agents/skills/flow/SKILL.md" 2>/dev/null || true
if [ -L "$AGENT_SYM/.agents/skills/flow/SKILL.md" ]; then
  FLOW_PROJECT_ROOT="$AGENT_SYM" bash "$RUN" rules agent-skills --write >/dev/null 2>&1
  ck 1 "$?" "dangling Agent Skills symlink refused"
  [ -L "$AGENT_SYM/.agents/skills/flow/SKILL.md" ]; ck 0 "$?" "symlink preserved"
  ck "$SCRATCH/absent_agent_skill" "$(readlink "$AGENT_SYM/.agents/skills/flow/SKILL.md")" "symlink destination unchanged"
  [ ! -e "$SCRATCH/absent_agent_skill" ]; ck 0 "$?" "symlink target not created"
else
  echo "  SKIP [platform cannot create symlinks]"
fi
FLOW_PROJECT_ROOT="$AGENT_DIR" bash "$RUN" rules agent-skills --write unexpected >/dev/null 2>&1
ck 2 "$?" "extra trailing argument exits 2"

echo "I) AGENTS.md preview, standard fields, and safe creation"
AGENTS_DIR="$SCRATCH/agents_md_test"
mkdir -p "$AGENTS_DIR"
mkdir -p "$AGENTS_DIR/skills/flow/runner"
ln -s "$RUN" "$AGENTS_DIR/skills/flow/runner/flow.sh"
agents_before="$(find "$AGENTS_DIR" -mindepth 1 -print)"
out_agents_md="$(FLOW_PROJECT_ROOT="$AGENTS_DIR" bash "$RUN" rules agents-md)"; rc_agents_md=$?
ck 0 "$rc_agents_md" "AGENTS.md preview exits 0"
[ ! -e "$AGENTS_DIR/AGENTS.md" ]; ck 0 "$?" "preview creates no AGENTS.md file"
ck "$agents_before" "$(find "$AGENTS_DIR" -mindepth 1 -print)" "preview leaves project unchanged"
no "$out_agents_md" "^---" "no frontmatter in AGENTS.md template"
has "$out_agents_md" "Flow gated build discipline" "flow discipline marker present"
has "$out_agents_md" "Idea→Research→Scope→PRD→ADR→Contract→Cards→Build→Review→Verify→Retro" "stage flow progression present"
has "$out_agents_md" "Kill at any gate is a valid, honored outcome" "kill gate marker present"
has "$out_agents_md" "## Allowed files" "Allowed files marker present"
has "$out_agents_md" "## Verify" "Verify marker present"
has "$out_agents_md" "## Evidence" "Evidence marker present"
has "$out_agents_md" "bash skills/flow/runner/flow.sh <command>" "bash runner command present"
has "$out_agents_md" "Git Bash or WSL" "Windows Bash invocation documented"
has "$out_agents_md" "status" "status command listed"
has "$out_agents_md" "next" "next command listed"
has "$out_agents_md" "check C-NNN" "check command listed"
byte_len=$(printf '%s\n' "$out_agents_md" | wc -c)
[ "$byte_len" -le 2048 ]; ck 0 "$?" "AGENTS.md size ($byte_len bytes) is <= 2048 bytes"
FLOW_PROJECT_ROOT="$AGENTS_DIR" bash "$RUN" rules agents-md --write
ck 0 "$?" "AGENTS.md write exits 0"
AGENTS_DEST="$AGENTS_DIR/AGENTS.md"
[ -f "$AGENTS_DEST" ]; ck 0 "$?" "exact AGENTS.md destination created"
printf '%s\n' "$out_agents_md" | cmp - "$AGENTS_DEST"
ck 0 "$?" "written bytes match preview"
printf '%s\n' 'USER_AGENTS_MD_SENTINEL' > "$AGENTS_DEST"
out_refuse="$(FLOW_PROJECT_ROOT="$AGENTS_DIR" bash "$RUN" rules agents-md --write 2>&1)"
ck 1 "$?" "existing AGENTS.md file refused with exit 1"
has "$out_refuse" "destination already exists: AGENTS.md" "refusal reports destination already exists"
ck 'USER_AGENTS_MD_SENTINEL' "$(cat "$AGENTS_DEST")" "existing sentinel preserved exactly"
AGENTS_SYM="$SCRATCH/agents_sym"
mkdir -p "$AGENTS_SYM"
ln -s "$SCRATCH/absent_agents_md_target" "$AGENTS_SYM/AGENTS.md" 2>/dev/null || true
if [ -L "$AGENTS_SYM/AGENTS.md" ]; then
  out_sym="$(FLOW_PROJECT_ROOT="$AGENTS_SYM" bash "$RUN" rules agents-md --write 2>&1)"
  ck 1 "$?" "dangling AGENTS.md symlink refused with exit 1"
  [ -L "$AGENTS_SYM/AGENTS.md" ]; ck 0 "$?" "symlink preserved"
  ck "$SCRATCH/absent_agents_md_target" "$(readlink "$AGENTS_SYM/AGENTS.md")" "symlink destination unchanged"
  [ ! -e "$SCRATCH/absent_agents_md_target" ]; ck 0 "$?" "symlink target not created"
else
  echo "  SKIP [platform cannot create symlinks]"
fi
FLOW_PROJECT_ROOT="$AGENTS_DIR" bash "$RUN" rules agents-md --write unexpected >/dev/null 2>&1
ck 2 "$?" "extra trailing argument exits 2"

echo "J) installed runner scaffolds a command that resolves in the user project"
INSTALL_DIR="$SCRATCH/home/.agents/skills/flow"
INSTALL_PROJECT="$SCRATCH/installed_project"
mkdir -p "$INSTALL_DIR" "$INSTALL_PROJECT"
cp -R "$HERE/../skills/flow/." "$INSTALL_DIR/"
FLOW_PROJECT_ROOT="$INSTALL_PROJECT" bash "$INSTALL_DIR/runner/flow.sh" rules cursor --write >/dev/null 2>&1
ck 0 "$?" "installed runner scaffolds Cursor rules"
(
  cd "$INSTALL_PROJECT"
  "$PY" -c '
import pathlib, re, shlex, shutil, subprocess
text = pathlib.Path(".cursor/rules/flow.mdc").read_text()
commands = re.findall(r"`(bash [^`]+)`", text)
assert commands, "no runner invocation found"
for command in commands:
    runner = shlex.split(command)[1]
    native = subprocess.check_output(["cygpath", "-w", runner], text=True).strip() if shutil.which("cygpath") else runner
    assert pathlib.Path(native).is_file(), "scaffolded runner does not resolve: " + runner
'
)
ck 0 "$?" "installed template runner paths exist from project root"

echo "K) all harness commands resolve in source, global, and project-local installs"
SOURCE_PROJECT="$SCRATCH/source_project"
SPECIAL_INSTALL="$SCRATCH/home/Flow space 'quote' \"double\" \$dollar [x]+(y)&/skills/flow"
if command -v cygpath >/dev/null 2>&1; then
  # Windows filenames cannot contain quotes; retain spaces and regex metacharacters.
  SPECIAL_INSTALL="$SCRATCH/home/Flow space [x]+(y)&/skills/flow"
fi
LOCAL_PROJECT="$SCRATCH/local_project"
# Windows Python cannot read MSYS paths; hand the verification a native bash path.
HOST_BASH="$(command -v bash)"
if command -v cygpath >/dev/null 2>&1; then HOST_BASH="$(cygpath -w "$HOST_BASH")"; fi
mkdir -p "$SOURCE_PROJECT/skills" "$SPECIAL_INSTALL" "$LOCAL_PROJECT/.claude/skills/flow"
cp -R "$HERE/../skills/flow" "$SOURCE_PROJECT/skills/flow"
cp -R "$HERE/../skills/flow/." "$SPECIAL_INSTALL/"
cp -R "$HERE/../skills/flow/." "$LOCAL_PROJECT/.claude/skills/flow/"
for layout in source global local; do
  case "$layout" in
    source) project="$SOURCE_PROJECT"; installed_run="$SOURCE_PROJECT/skills/flow/runner/flow.sh" ;;
    global) project="$SCRATCH/global_project"; installed_run="$SPECIAL_INSTALL/runner/flow.sh" ;;
    local) project="$LOCAL_PROJECT"; installed_run="$LOCAL_PROJECT/.claude/skills/flow/runner/flow.sh" ;;
  esac
  mkdir -p "$project"
  for target in agents-md cursor windsurf roo cline aider openhands copilot; do
    scaffold_out=$(FLOW_LOG_DISABLE=1 FLOW_PROJECT_ROOT="$project" bash "$installed_run" rules "$target" --write 2>&1)
    scaffold_rc=$?
    if [ "$scaffold_rc" -ne 0 ]; then
      printf 'scaffold %s %s failed:\n%s\n' "$layout" "$target" "$scaffold_out" >&2
      RUNNER_DIR="$(dirname "$installed_run")"
      py="$(command -v python3)"
      hp="$RUNNER_DIR/../harness/flow_harness.py"
      # (a) The REAL helper, verbatim body, stderr intact — reveals which branch runs.
      bash -c '
        src="$1"; py="$2"; hp="$3"
        eval "$(awk "/^_with_timeout\\(\\)/{f=1} f{print} f&&/^}$/{exit}" "$src")"
        _with_timeout 20 "$py" "$hp" --help
        printf "real_helper_rc=%s\n" "$?" >&2
      ' diagnose "$RUNNER_DIR/flow.sh" "$py" "$hp" 2>&1 | tail -14 >&2
      # (b) GNU timeout alone, stderr intact.
      if command -v timeout >/dev/null 2>&1; then
        timeout 20 "$py" "$hp" --help; printf "gnu_timeout_rc=%s\n" "$?" >&2
      else
        printf "timeout_absent=1\n" >&2
      fi
      # (c) What native python actually receives on the specials path.
      "$py" -c 'import os, sys; p = sys.argv[1]; print("argv_repr=", repr(p)); print("isfile=", os.path.isfile(p))' "$hp" 2>&1 | tail -3 >&2
      # (d) Plain-path control: whole harness dir (sibling modules preserved).
      plaindir="$SCRATCH/plain_probe_harness"
      rm -rf "$plaindir"; cp -R "$RUNNER_DIR/../harness" "$plaindir" 2>/dev/null
      "$py" "$plaindir/flow_harness.py" --help >/tmp/probe2.out 2>&1; printf "probe_plain_rc=%s\n" "$?" >&2
      sed -n '1,8p' /tmp/probe2.out >&2
      break
    fi
    ck 0 "$scaffold_rc" "$layout $target scaffolding succeeds"
  done
  if command -v sh >/dev/null 2>&1; then
    sh -c '! grep -F '\''"bash '\'' "$@"' sh \
      "$project/AGENTS.md" "$project/.cursor/rules/flow.mdc" \
      "$project/.windsurf/rules/flow.md" "$project/.clinerules" \
      "$project/.openhands/microagents/flow.md" "$project/.github/copilot-instructions.md"
    ck 0 "$?" "$layout Markdown commands have no literal quote wrapping"
  fi
  (
    cd "$project"
    FLOW_LOG_DISABLE=1 FLOW_PROJECT_ROOT="$project" "$PY" - "$layout" "$installed_run" "$HOST_BASH" <<'PY'
import json, os, pathlib, re, shlex, shutil, subprocess, sys
layout, installed_run, suite_bash = sys.argv[1:]
def to_native_form(p):
    # Product emits the same Windows-native absolute form (cygpath -m) on MSYS hosts.
    if os.name == "nt" and shutil.which("cygpath"):
        return subprocess.check_output(["cygpath", "-m", p], text=True).strip()
    return p
expected_runner = "skills/flow/runner/flow.sh" if layout == "source" else to_native_form(installed_run)
bash_bin = sys.argv[3]
def pick_bash():
    # On Windows, bare "bash" on PATH can be WSL bash.exe; use the suite's own bash.
    if os.name == "nt" and os.path.isfile(bash_bin):
        return bash_bin
    return "bash"
if layout == "global":
    assert "&" in expected_runner, "fixture must exercise literal ampersand replacement"
def runner_exists(runner):
    native = subprocess.check_output(["cygpath", "-w", runner], text=True).strip() if shutil.which("cygpath") else runner
    return pathlib.Path(native).is_file()
files = ["AGENTS.md", ".cursor/rules/flow.mdc", ".windsurf/rules/flow.md",
         ".clinerules", ".openhands/microagents/flow.md", ".github/copilot-instructions.md"]
commands = []
for name in files:
    text = pathlib.Path(name).read_text()
    assert "@FLOW_" not in text, name
    found = re.findall(r"`(bash [^`]+)`", text)
    assert found, name
    for command in found:
        runner = shlex.split(command)[1]
        assert runner_exists(runner), (name, runner)
        assert runner == expected_runner, (name, runner, expected_runner)
        if layout == "source":
            assert runner == "skills/flow/runner/flow.sh", (name, runner)
        else:
            assert re.match(r"^([A-Za-z]:)?/", runner), (name, runner)
        commands.append(command)
groups = json.loads(pathlib.Path(".roomodes").read_text())["customModes"][0]["groups"]
regex = next(group[1]["commandRegex"] for group in groups if isinstance(group, list) and group[0] == "command")
for command in commands:
    assert re.match(regex, command), (regex, command)
assert not re.match(regex, "bash other/runner/flow.sh status"), regex
line = next(line for line in pathlib.Path(".aider.conf.yml").read_text().splitlines() if line.startswith("test-cmd: "))
test_cmd = json.loads(line[len("test-cmd: "):])
assert test_cmd.startswith("bash ") and not test_cmd.startswith('"bash '), test_cmd
program = shlex.split(test_cmd)[2]
runner_commands = re.findall(r"(?:then|else) (bash .*?) (?:check|status)", program)
assert len(runner_commands) == 2, program
for runner in runner_commands:
    assert runner_exists(shlex.split(runner)[1]), runner
    assert shlex.split(runner)[1] == expected_runner, (runner, expected_runner)
pathlib.Path("cards").mkdir(exist_ok=True)
for inflight in ("", "C-001", "C-001; touch injected"):
    pathlib.Path("cards/.inflight").write_text(inflight)
    result = subprocess.run([pick_bash(), "-c", test_cmd], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    assert result.returncode in (0, 1), result.stdout
    assert "No such file or directory" not in result.stdout, result.stdout
    assert "required harness missing" not in result.stdout, result.stdout
    if inflight == "C-001":
        assert "C-001" in result.stdout, result.stdout
    assert not pathlib.Path("injected").exists(), result.stdout
print("resolved all six Markdown templates, Roo regex, and Aider status/check/injection paths")
PY
  )
  ck 0 "$?" "$layout templates reference resolvable runner commands"
done

# N) _harness_native conversion contract (PR93 root cause): MSYS/Git Bash skip automatic
# POSIX->Windows argument conversion for metacharacter-bearing paths, so every native
# harness invocation must use the converted path when a converter exists, and the exact
# POSIX path otherwise. Behavior-verified via a stub cygpath mapping to a REAL file.
echo "N) harness native-path conversion"
HARNESS_SRC="$SCRATCH/n_posix/harness.py"; HARNESS_CONV="$SCRATCH/n_mixed/harness.py"
mkdir -p "$SCRATCH/n_posix" "$SCRATCH/n_mixed" "$SCRATCH/n_bin"
printf 'x\n' > "$HARNESS_SRC"; printf 'x\n' > "$HARNESS_CONV"
cat > "$SCRATCH/n_bin/cygpath" <<STUB
#!/usr/bin/env bash
[ "\$1" = "-m" ] || exit 1
case "\$2" in
  *"$SCRATCH/n_posix/harness.py") printf '%s\n' "$HARNESS_CONV" ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$SCRATCH/n_bin/cygpath"
extract_helper() {
  awk '/^_native_path\(\)/{f=1} f{print} f&&/^}$/{exit}' "$RUN"
  printf '%s\n' "$(_grep_harness_native)"
}
_grep_harness_native() { grep -E '^_harness_native\(\) \{ _native_path' "$RUN"; }
out_conv="$(PATH="$SCRATCH/n_bin:$PATH" HARNESS_PY="$HARNESS_SRC" bash -c "$(extract_helper); _harness_native")"
ck 0 "$?" "_harness_native uses converter output when cygpath present"
ck "$HARNESS_CONV" "$out_conv" "converted path equals cygpath mapping"
ck 0 "$([ -f "$out_conv" ]; echo $?)" "converted path is a real readable file"
out_fb="$(PATH="$SCRATCH/n_bin:$PATH" HARNESS_PY="$HARNESS_SRC" bash -c "$(extract_helper); cygpath() { return 1; }; _harness_native")"
ck "$HARNESS_SRC" "$out_fb" "identity when converter fails or is absent"

# O) cygpath conversion guard and degradation fallback regression (PR93 P2 finding):
# When cygpath is present on PATH but fails (exit 1 / empty output), rules scaffolding
# must not target /flow.sh; it must fall back to the fallback runner path and emit
# the degradation warning if pwd -W is also unsupported.
echo "O) installed runner cygpath failure fallback regression"
REG_INSTALL="$SCRATCH/reg_cygpath_install/skills/flow"
REG_PROJECT="$SCRATCH/reg_cygpath_project"
mkdir -p "$REG_INSTALL" "$REG_PROJECT"
cp -R "$HERE/../skills/flow/." "$REG_INSTALL/"

REG_BIN="$SCRATCH/reg_bin"
mkdir -p "$REG_BIN"
REAL_UNAME="$(command -v uname)"
cat > "$REG_BIN/uname" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "-s" ]; then
  echo "MINGW64_NT-10.0"
else
  exec "$REAL_UNAME" "\$@"
fi
EOF
chmod +x "$REG_BIN/uname"

# Variant 1: cygpath stub exits 1 (failure)
cat > "$REG_BIN/cygpath" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$REG_BIN/cygpath"

err_f1="$SCRATCH/reg_err_1.txt"
out_reg1="$(PATH="$REG_BIN:$PATH" FLOW_PROJECT_ROOT="$REG_PROJECT" bash "$REG_INSTALL/runner/flow.sh" rules cursor 2>"$err_f1")"
rc_reg1=$?
err_reg1="$(cat "$err_f1")"
ck 0 "$rc_reg1" "rules cursor succeeds when cygpath exits 1"
has "$out_reg1" "$REG_INSTALL/runner/flow.sh" "generated command targets fallback runner path when cygpath exits 1"
no "$out_reg1" "bash /flow.sh" "generated command does not target /flow.sh when cygpath exits 1"
has "$err_reg1" "WARN: cannot convert install path to Windows form" "degradation warning present when cygpath exits 1"

# Variant 2: cygpath stub exits 0 but returns empty output
cat > "$REG_BIN/cygpath" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *flow_harness.py) exit 1 ;;
  *) exit 0 ;;
esac
STUB
err_f2="$SCRATCH/reg_err_2.txt"
out_reg2="$(PATH="$REG_BIN:$PATH" FLOW_PROJECT_ROOT="$REG_PROJECT" bash "$REG_INSTALL/runner/flow.sh" rules cursor 2>"$err_f2")"
rc_reg2=$?
err_reg2="$(cat "$err_f2")"
ck 0 "$rc_reg2" "rules cursor succeeds when cygpath returns empty output"
has "$out_reg2" "$REG_INSTALL/runner/flow.sh" "generated command targets fallback runner path when cygpath returns empty"
no "$out_reg2" "bash /flow.sh" "generated command does not target /flow.sh when cygpath returns empty"
has "$err_reg2" "WARN: cannot convert install path to Windows form" "degradation warning present when cygpath returns empty"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?
