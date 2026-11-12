#!/usr/bin/env bash
# Permanent boundary regression suite for the host-context adapter
# (skills/flow/adapter-hooks/, ADR-0001 Addendum 2026-10-13).
# Covers the risks that warrant permanence: snapshot persistence contract, strict
# payload parsing, ownership/mode/symlink refusals, output bounds, timeout process-group
# kill (with orphan-scenario evidence), nearest-root discovery (24 physical ancestors,
# strict ancestor signatures, local-root precedence), and no-side-effect guarantees
# (no telemetry, no .flow creation, inherited FLOW_PROJECT_ROOT shielded).
# Run: bash tests/test_flow_host_hooks.sh   (exit 0 = pass)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HANDLER="$HERE/../skills/flow/adapter-hooks/flow-context-handler"
REAL_SKILL="$HERE/../skills/flow"
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got: $2 | want: $3)"; fi; }
te() { if echo "$2" | grep -q "$3"; then ok "$1"; else bad "$1 (missing '$3')"; fi; }
tne() { if echo "$2" | grep -q "$3"; then bad "$1 (leaked: $3)"; else ok "$1"; fi; }
IS_WINDOWS=0
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
esac
PY_BIN="$(command -v python3 || command -v python)"
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

TMP="$(mktemp -d "${TMPDIR:-/tmp}/flow-hooks-test.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
export FLOW_SKILL_DIR="$(to_json_path "$REAL_SKILL")"
mkproj() {
  d="$TMP/$1"; mkdir -p "$d/flow" "$d/.flow"; chmod 755 "$d/.flow"
  printf '# idea\n' > "$d/flow/00-idea.md"
  printf '%s' "$d"
}

# --- Persistence contract ------------------------------------------------------
P1="$(mkproj persist)"
out=$("$HANDLER" <<EOF
{"hook_event_name":"PreCompact","cwd":"$(to_json_path "$P1")"}
EOF
) ; rc=$?
check "precompact exit 0" "$rc" "0"
check "precompact stdout empty" "$out" ""
SNAP="$P1/.flow/context-handoff/snapshot.json"
if [ "$IS_WINDOWS" -eq 1 ]; then
  [ ! -f "$SNAP" ] && ok "Windows: snapshot refused due to missing O_NOFOLLOW (fresh-only security boundary)" || bad "Windows: snapshot written without O_NOFOLLOW"
else
  [ -f "$SNAP" ] && ok "snapshot persisted in private dir" || bad "snapshot missing"
  mode_of() { python3 -c 'import os,stat,sys;print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode))[2:])' "$(to_native_path "$1")" 2>/dev/null; }
  check "snapshot mode 0600" "$(mode_of "$SNAP")" "600"
  check "private dir mode 0700" "$(mode_of "$P1/.flow/context-handoff")" "700"
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get('magic') == 'flow-compact-handoff/v1'
assert d.get('status_body', '').strip()
" "$(to_native_path "$SNAP")" && ok "snapshot strict JSON + magic + body" || bad "snapshot JSON invalid"
fi

# --- SessionStart fresh authority ----------------------------------------------
out=$("$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$P1")"}
EOF
) ; rc=$?
check "sessionstart exit 0" "$rc" "0"
te "fresh source labeled" "$out" '\[source: fresh'
if [ "$IS_WINDOWS" -eq 1 ]; then
  tne "Windows: snapshot citation absent (fresh-only)" "$out" "pre-compact snapshot: valid"
else
  te "snapshot cited as reference only" "$out" 'pre-compact snapshot: valid'
fi
tne "no stale mislabel on fresh path" "$out" 'STALE SOURCE'
tne "missing source does not claim compaction" "$out" 'post-compaction'
for source in startup resume clear fork compact unknown; do
  out=$("$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$P1")","source":"$source"}
EOF
  ); check "source $source exit 0" "$?" "0"
  if [ "$source" = compact ]; then
    te "compact source retains authority" "$out" 'post-compaction authoritative'
  else
    tne "$source does not claim compaction" "$out" 'post-compaction'
    te "$source fresh handoff" "$out" '\[source: fresh'
  fi
done

# Discovery uses real temporary homes and runners, never a fake os.name. On POSIX,
# select ntpath.expanduser explicitly to simulate USERPROFILE resolution only;
# native Windows process/launcher coverage remains a CI responsibility.
DISC_HOME="$TMP/discovery-home"
for target in .claude/skills/flow .codex/skills/flow .agents/skills/flow .omp/agent/skills/flow .cursor/skills/flow .gemini/antigravity-cli/skills/flow .gemini/config/skills/flow; do
  mkdir -p "$DISC_HOME/$target/runner"
  printf '#!/bin/sh\nprintf "discovered-home-marker\\n"\n' > "$DISC_HOME/$target/runner/flow.sh"
  chmod +x "$DISC_HOME/$target/runner/flow.sh"
  out=$(HOME="$(to_json_path "$DISC_HOME")" FLOW_SKILL_DIR= "$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$P1")"}
EOF
  ); check "discover $target exit 0" "$?" "0"
  te "discover $target handoff" "$out" 'discovered-home-marker'
  if [ "$target" = .claude/skills/flow ]; then
    out=$(
      unset HOME FLOW_SKILL_DIR
      export USERPROFILE="$(to_json_path "$DISC_HOME")"
      "$PY_BIN" -c 'import ntpath, os, runpy, sys; os.path.expanduser = ntpath.expanduser; runpy.run_path(sys.argv[1], run_name="__main__")' "$(to_native_path "$REAL_SKILL/adapter-hooks/context_handler.py")" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$P1")"}
EOF
    ); check "HOME unset USERPROFILE simulation exit 0" "$?" "0"
    te "HOME unset expanded home handoff" "$out" 'discovered-home-marker'
    out=$(HOME="$(to_json_path "$DISC_HOME")" "$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$P1")"}
EOF
    ); check "explicit skill directory exit 0" "$?" "0"
    te "explicit skill directory fresh handoff" "$out" '\[source: fresh'
    tne "explicit skill directory wins over home" "$out" 'discovered-home-marker'
  fi
  rm -rf "$DISC_HOME/$target"
done
# --- Bounded nearest-root discovery --------------------------------------------
# Keep every scanned ancestor inside our fixture even if TMPDIR is in a Flow repo.
ROOT_BASE="$TMP/roots"
i=0
while [ "$i" -lt 24 ]; do ROOT_BASE="$ROOT_BASE/d"; i=$((i+1)); done
mkdir -p "$ROOT_BASE" "$TMP/root-skill/runner"
ROOT_LOG="$TMP/root-record.json"
ROOT_RUNNER="$TMP/root-skill/runner/flow.sh"
cat > "$ROOT_RUNNER" <<'SH'
#!/usr/bin/env bash
"$FLOW_TEST_PY" -c 'import json, os; json.dump({"root": os.environ["FLOW_PROJECT_ROOT"], "cwd": os.getcwd(), "log_disable": os.environ.get("FLOW_LOG_DISABLE")}, open(os.environ["FLOW_TEST_ROOT_LOG"], "w"))'
printf 'root-context:%s\n' "$FLOW_PROJECT_ROOT"
SH
root_handoff() {
  rm -f "$ROOT_LOG"
  out=$(FLOW_TEST_PY="$PY_BIN" FLOW_TEST_ROOT_LOG="$(to_json_path "$ROOT_LOG")" \
    FLOW_SKILL_DIR="$(to_json_path "$TMP/root-skill")" "$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$1")","source":"startup"}
EOF
  ); rc=$?
  check "$2 exit 0" "$rc" "0"
}
root_selected() {
  "$PY_BIN" -c '
import json, os, sys
d = json.load(open(sys.argv[1]))
physical = lambda p: os.path.normcase(os.path.realpath(p))
assert physical(d["root"]) == physical(sys.argv[2]), d
assert physical(d["cwd"]) == physical(sys.argv[2]), d
assert d["log_disable"] == "1", d
' "$(to_native_path "$ROOT_LOG")" "$(to_native_path "$1")" \
    && ok "$2 runner root/cwd pinned, telemetry disabled" || bad "$2 runner root/cwd mismatch"
  te "$2 context emitted" "$out" 'root-context:'
  te "$2 fresh source labeled" "$out" '\[source: fresh'
}
root_refused() {
  check "$1 stdout empty" "$out" ""
  [ ! -e "$ROOT_LOG" ] && ok "$1 runner not invoked" || bad "$1 runner invoked"
}

# Only the stage artifact qualifies: no .flow run-state can mask discovery errors.
MONO="$ROOT_BASE/monorepo"
mkdir -p "$MONO/flow" "$MONO/packages/web"
printf '# parent idea\n' > "$MONO/flow/00-idea.md"
root_handoff "$MONO/packages/web" "monorepo child"
root_selected "$MONO" "monorepo parent"
te "monorepo startup label preserved" "$out" 'session startup authoritative'
check "adoption leaves child empty" "$(find "$MONO/packages/web" -mindepth 1 -print)" ""

NESTED="$MONO/packages/web"
mkdir -p "$NESTED/flow" "$NESTED/src"
printf '# nested inspect\n' > "$NESTED/flow/00-inspect.md"
parent_before=$(find "$MONO/flow" -type f -exec cksum {} \;)
root_handoff "$NESTED" "nested local project"
root_selected "$NESTED" "nested local project wins"
tne "nested project never emits parent root" "$out" "root-context:$(to_json_path "$MONO")$"
root_handoff "$NESTED/src" "nearest ancestor project"
root_selected "$NESTED" "nearest nested ancestor wins"
check "parent state unchanged" "$(find "$MONO/flow" -type f -exec cksum {} \;)" "$parent_before"

for signature in inspect state card; do
  SIG="$ROOT_BASE/$signature"; mkdir -p "$SIG/child"
  case "$signature" in
    inspect) mkdir -p "$SIG/flow"; printf '# inspect\n' > "$SIG/flow/00-inspect.md" ;;
    state) mkdir -p "$SIG/.flow" ;;
    card) mkdir -p "$SIG/cards"; printf '# card\n' > "$SIG/cards/C-001.md" ;;
  esac
  root_handoff "$SIG/child" "$signature ancestor signature"
  root_selected "$SIG" "$signature ancestor signature"
done

# Existing hook-local markers stay local, including bare dirs and MODE. Those
# same bare dirs/MODE do not qualify for ancestor adoption (runner boundary).
for marker in flow cards MODE; do
  LOCAL="$MONO/local-$marker"; mkdir -p "$LOCAL"
  if [ "$marker" = MODE ]; then printf 'build\n' > "$LOCAL/MODE"; else mkdir -p "$LOCAL/$marker"; fi
  root_handoff "$LOCAL" "local $marker marker"
  root_selected "$LOCAL" "local $marker precedence unchanged"
  BARE="$ROOT_BASE/bare-$marker"; mkdir -p "$BARE/child"
  if [ "$marker" = MODE ]; then printf 'build\n' > "$BARE/MODE"; else mkdir -p "$BARE/$marker"; fi
  before=$(find "$BARE" | sort)
  root_handoff "$BARE/child" "bare ancestor $marker"
  root_refused "bare ancestor $marker"
  check "bare ancestor $marker no auto-init" "$(find "$BARE" | sort)" "$before"
done
FALSE_CARDS="$ROOT_BASE/false-cards"
mkdir -p "$FALSE_CARDS/cards/C-directory.md" "$FALSE_CARDS/child"
printf '# not a card\n' > "$FALSE_CARDS/cards/notes.md"
root_handoff "$FALSE_CARDS/child" "non-card ancestor"
root_refused "non-card ancestor"

BOUND="$ROOT_BASE/bounded"; mkdir -p "$BOUND/flow"
printf '# bounded idea\n' > "$BOUND/flow/00-idea.md"
DEEP="$BOUND"; i=0
while [ "$i" -lt 24 ]; do DEEP="$DEEP/d"; i=$((i+1)); done
mkdir -p "$DEEP/d"
root_handoff "$DEEP" "24th ancestor"
root_selected "$BOUND" "24th ancestor included"
before=$(find "$BOUND" | sort)
root_handoff "$DEEP/d" "no signature within 24 ancestors"
root_refused "25th ancestor excluded"
check "bounded miss no auto-init" "$(find "$BOUND" | sort)" "$before"

# FLOW_PROJECT_ROOT is intentionally NOT a hook override: after cwd validation,
# the hook replaces the inherited value with its selected physical project root.
EXT_ROOT="$ROOT_BASE/explicit-other"; mkdir -p "$EXT_ROOT/flow"
printf '# external idea\n' > "$EXT_ROOT/flow/00-idea.md"
before=$(find "$EXT_ROOT" -type f -exec cksum {} \;)
export FLOW_PROJECT_ROOT="$(to_json_path "$EXT_ROOT")"
root_handoff "$NESTED/src" "inherited root with adopted project"
root_selected "$NESTED" "inherited root cannot redirect adoption"
root_handoff "$DEEP/d" "inherited root with no project in bound"
root_refused "inherited root cannot bypass cwd validation"
unset FLOW_PROJECT_ROOT
check "explicit external root untouched" "$(find "$EXT_ROOT" -type f -exec cksum {} \;)" "$before"

if [ "$IS_WINDOWS" -eq 0 ]; then
  # The alias lives inside a project but points to a physical non-project subtree.
  # Walking lexical parents would incorrectly adopt MONO and cross this boundary.
  PHYSICAL="$ROOT_BASE/physical"; mkdir -p "$PHYSICAL/child"
  ln -s "$PHYSICAL/child" "$MONO/alias"
  root_handoff "$MONO/alias" "symlink lexical ancestor"
  root_refused "symlink alias cannot adopt lexical parent"
  ln -s "$NESTED/src" "$ROOT_BASE/valid-alias"
  root_handoff "$ROOT_BASE/valid-alias" "symlink physical ancestor"
  root_selected "$NESTED" "symlink uses nearest physical project"
fi


# --- Strict payload parsing ----------------------------------------------------
printf 'not-json{{{' | "$HANDLER" >/dev/null 2>&1; check "malformed JSON fail-open" "$?" "0"
printf '{"hook_event_name":"SessionStart","hook_event_name":"PreCompact","cwd":"%s"}' "$(to_json_path "$P1")" \
  | "$HANDLER" >/dev/null 2>&1; check "duplicate keys rejected fail-open" "$?" "0"
out=$("$HANDLER" <<EOF
{"hook_event_name":"PostToolUse","cwd":"$(to_json_path "$P1")"}
EOF
) ; check "unsupported event exit 0" "$?" "0"; check "unsupported event stdout empty" "$out" ""

# --- Ownership / symlink / mode refusals ---------------------------------------
P2="$(mkproj symlinkflow)"
if [ "$IS_WINDOWS" -eq 1 ] && command -v cmd >/dev/null 2>&1; then
  mv "$P2/.flow" "$TMP/rf2"
  cmd //c mklink //J "$(cygpath -w "$P2/.flow")" "$(cygpath -w "$TMP/rf2")" >/dev/null 2>&1
else
  mv "$P2/.flow" "$TMP/rf2"; ln -s "$TMP/rf2" "$P2/.flow"
fi
out=$("$HANDLER" <<EOF
{"hook_event_name":"PreCompact","cwd":"$(to_json_path "$P2")"}
EOF
) ; check "symlinked .flow exit 0" "$?" "0"; check "symlinked .flow stdout empty" "$out" ""
python3 -c "
import os, sys
p = sys.argv[1]
is_junc = getattr(os.path, 'isjunction', lambda _: False)
assert os.path.islink(p) or is_junc(p)
" "$(to_native_path "$P2/.flow")" && ok "symlink not replaced" || bad ".flow symlink tampered"
P3="$(mkproj laxdir)"; mkdir -p "$P3/.flow/context-handoff"; chmod 755 "$P3/.flow/context-handoff"
out=$("$HANDLER" <<EOF
{"hook_event_name":"PreCompact","cwd":"$(to_json_path "$P3")"}
EOF
) ; check "non-0700 private dir refused, exit 0" "$?" "0"
if [ "$IS_WINDOWS" -eq 1 ]; then
  [ ! -f "$P3/.flow/context-handoff/snapshot.json" ] && ok "Windows: no snapshot into lax dir (snapshot skipped)" || bad "Windows: snapshot written into lax dir"
else
  [ -f "$P3/.flow/context-handoff/snapshot.json" ] && bad "snapshot written into lax dir" || ok "no snapshot into non-0700 dir"
fi
P4="$(mkproj crossproj)"; mkdir -p "$P4/.flow/context-handoff"; chmod 700 "$P4/.flow/context-handoff"
P4_SNAP="$P4/.flow/context-handoff/snapshot.json"
python3 -c "
import json, sys
json.dump({'magic':'flow-compact-handoff/v1','captured':'t','project':'/somewhere/else','source':'s','status_body':'CROSSPROJ-BODY'}, open(sys.argv[1],'w'))
import os; os.chmod(sys.argv[1], 0o600)
" "$(to_native_path "$P4_SNAP")"
[ -f "$P4_SNAP" ] && ok "cross-project snapshot fixture created" || bad "cross-project snapshot fixture missing"
mkdir -p "$TMP/fakefail/runner"; printf '#!/bin/sh\nexit 1\n' > "$TMP/fakefail/runner/flow.sh"; chmod +x "$TMP/fakefail/runner/flow.sh"
out=$(FLOW_SKILL_DIR="$(to_json_path "$TMP/fakefail")" "$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$P4")"}
EOF
) ; rc=$?
check "cross-project refused: exit 0" "$rc" "0"
tne "cross-project body never rehydrated" "$out" "CROSSPROJ-BODY"
tne "cross-project never presented as state" "$out" "STALE SOURCE"
[ -z "$out" ] && ok "cross-project refusal keeps stdout empty" || bad "cross-project refusal leaked stdout"

# --- Bounds ---------------------------------------------------------------------
out=$(FLOW_HOOK_MAX_BYTES=1024 "$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$P1")"}
EOF
) ; rc=$?; blen=$(printf '%s' "$out" | wc -c)
check "min-cap accepted, exit 0" "$rc" "0"
[ "$blen" -le 1024 ] && ok "output within 1024-byte cap ($blen)" || bad "output exceeded cap ($blen)"
SECRET_COMPACT="SENTINEL_SECRET_COMPACT_99999"
"$HANDLER" <<EOF >/dev/null 2>&1
{"hook_event_name":"PreCompact","cwd":"$(to_json_path "$P1")","secret_note":"$SECRET_COMPACT"}
EOF
if [ "$IS_WINDOWS" -eq 1 ]; then
  [ ! -f "$P1/.flow/context-handoff/snapshot.json" ] && ok "Windows: secret token never persisted (snapshots refused)" || bad "Windows: snapshot persisted unexpectedly"
elif [ -f "$P1/.flow/context-handoff/snapshot.json" ]; then
  tne "secret token never leaked into snapshot" "$(cat "$P1/.flow/context-handoff/snapshot.json")" "$SECRET_COMPACT"
else
  bad "snapshot not written during secret leakage test"
fi

SECRET_SESSION="SENTINEL_SECRET_SESSION_88888"
err_out="$TMP/secret.err"
out=$(FLOW_HOOK_MAX_BYTES=200 "$HANDLER" 2>"$err_out" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$P1")","secret_note":"$SECRET_SESSION"}
EOF
) ; rc=$?
check "below-floor cap falls back to default (exit 0)" "$rc" "0"
te "below-floor cap rejected with note" "$(cat "$err_out")" "out of range"
tne "secret token never echoed in stdout" "$out" "$SECRET_SESSION"
tne "secret token never echoed in stderr" "$(cat "$err_out")" "$SECRET_SESSION"
# --- Timeout: process-group kill with orphan-scenario evidence -------------------
PH="$(mkproj hang)"; mkdir -p "$PH/.flow/context-handoff"; chmod 700 "$PH/.flow/context-handoff"
python3 -c "
import json, sys
json.dump({'magic':'flow-compact-handoff/v1','captured':'t','project':sys.argv[2],'source':'s','status_body':'FALLBACK-MARKER'}, open(sys.argv[1],'w'))
import os; os.chmod(sys.argv[1], 0o600)
" "$(to_native_path "$PH/.flow/context-handoff/snapshot.json")" "$PH"
mkdir -p "$TMP/hanghome/runner"
PIDFILE="$TMP/hanghome/child.pids"
STARTFILE="$TMP/hanghome/child.started"
PY_BIN="$(command -v python3 || command -v python)"
N_PIDFILE="$(to_json_path "$PIDFILE")"
N_STARTFILE="$(to_json_path "$STARTFILE")"
printf '#!/bin/sh\n"%s" -c '\''import sys, os, time; open(sys.argv[1], "w").write(str(os.getpid())); open(sys.argv[2], "w").write("STARTED"); time.sleep(30)'\'' "%s" "%s" &\nwait\n' \
  "$PY_BIN" "$N_PIDFILE" "$N_STARTFILE" > "$TMP/hanghome/runner/flow.sh"
chmod +x "$TMP/hanghome/runner/flow.sh"
out=$(FLOW_SKILL_DIR="$(to_json_path "$TMP/hanghome")" FLOW_HOOK_TIMEOUT=3 "$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$PH")"}
EOF
) ; rc=$?
check "timeout exit 0 (fail-open)" "$rc" "0"
if [ "$IS_WINDOWS" -eq 1 ]; then
  tne "Windows: stale fallback absent (fresh-only)" "$out" "STALE SOURCE"
  check "Windows: output empty on timeout" "$out" ""
else
  te "stale fallback after timeout" "$out" "STALE SOURCE"
fi
sleep 1
check "orphan scenario: child actually started" "$([ -f "$STARTFILE" ] && echo 1 || echo 0)" "1"
survivors=0
if [ "$IS_WINDOWS" -eq 1 ]; then
  if [ -s "$PIDFILE" ]; then
    python3 -c '
import sys, ctypes
from ctypes import wintypes
cpid = int(open(sys.argv[1]).read().strip())
SYNCHRONIZE = 0x00100000
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
STILL_ACTIVE = 259
ERROR_INVALID_PARAMETER = 87

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
k32.OpenProcess.restype = wintypes.HANDLE
k32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
k32.WaitForSingleObject.restype = wintypes.DWORD
k32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
k32.GetExitCodeProcess.restype = wintypes.BOOL
k32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
k32.CloseHandle.restype = wintypes.BOOL
k32.CloseHandle.argtypes = [wintypes.HANDLE]

h = k32.OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, False, cpid)
if not h:
    err = ctypes.get_last_error()
    if err == ERROR_INVALID_PARAMETER:
        sys.exit(0)
    print("OpenProcess failed for PID %d: OS error %d" % (cpid, err), file=sys.stderr)
    sys.exit(1)
try:
    wait_res = k32.WaitForSingleObject(h, 0)
    if wait_res != 0:
        print("WaitForSingleObject returned non-signaled state: %d" % wait_res, file=sys.stderr)
        sys.exit(1)
    exit_code = wintypes.DWORD()
    if not k32.GetExitCodeProcess(h, ctypes.byref(exit_code)):
        err = ctypes.get_last_error()
        print("GetExitCodeProcess failed: OS error %d" % err, file=sys.stderr)
        sys.exit(1)
    if exit_code.value == STILL_ACTIVE:
        print("Process %d is STILL_ACTIVE" % cpid, file=sys.stderr)
        sys.exit(1)
    sys.exit(0)
finally:
    k32.CloseHandle(h)
' "$(to_native_path "$PIDFILE")" && ok "orphan scenario: all recorded child pids reaped by group kill (owned-pid evidence)" || bad "orphan scenario: child pid survived on Windows"
  else
    bad "orphan scenario: pidfile empty - owned-pid evidence not collected"
  fi
elif [ -s "$PIDFILE" ]; then
  ok "orphan scenario: fake runner recorded its child pid(s) before the kill"
  while read -r pid; do
    [ -n "$pid" ] || continue
    if kill -0 "$pid" 2>/dev/null; then
      survivors=$((survivors + 1))
    fi
  done < "$PIDFILE"
  [ "$survivors" -eq 0 ] && ok "orphan scenario: all recorded child pids reaped by group kill (owned-pid evidence)" || bad "orphan scenario: $survivors owned child pid(s) survived"
else
  bad "orphan scenario: pidfile empty - owned-pid evidence not collected"
fi

# --- Root exits while descendant holds pipe (deadline + group kill) -------------
PH2="$(mkproj rootexit)"; mkdir -p "$PH2/.flow/context-handoff"; chmod 700 "$PH2/.flow/context-handoff"
python3 -c "
import json, sys
json.dump({'magic':'flow-compact-handoff/v1','captured':'t','project':sys.argv[2],'source':'s','status_body':'FALLBACK-ROOTEXIT'}, open(sys.argv[1],'w'))
" "$(to_native_path "$PH2/.flow/context-handoff/snapshot.json")" "$PH2"
mkdir -p "$TMP/rootexithome/runner"
PIDFILE2="$TMP/rootexithome/child.pids"
STARTFILE2="$TMP/rootexithome/child.started"
PY_BIN="$(command -v python3 || command -v python)"
N_PIDFILE2="$(to_json_path "$PIDFILE2")"
N_STARTFILE2="$(to_json_path "$STARTFILE2")"
printf '#!/bin/sh\n"%s" -c '\''import sys, os, time; open(sys.argv[1], "w").write(str(os.getpid())); open(sys.argv[2], "w").write("STARTED"); time.sleep(30)'\'' "%s" "%s" &\nexit 0\n' \
  "$PY_BIN" "$N_PIDFILE2" "$N_STARTFILE2" > "$TMP/rootexithome/runner/flow.sh"
chmod +x "$TMP/rootexithome/runner/flow.sh"
out=$(FLOW_SKILL_DIR="$(to_json_path "$TMP/rootexithome")" FLOW_HOOK_TIMEOUT=2 "$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$PH2")"}
EOF
) ; rc=$?
check "root-exit held-pipe exit 0" "$rc" "0"
sleep 1
check "root-exit held pipe: child actually started" "$([ -f "$STARTFILE2" ] && echo 1 || echo 0)" "1"
survivors2=0
if [ "$IS_WINDOWS" -eq 1 ]; then
  if [ -s "$PIDFILE2" ]; then
    python3 -c '
import sys, ctypes
from ctypes import wintypes
cpid = int(open(sys.argv[1]).read().strip())
SYNCHRONIZE = 0x00100000
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
STILL_ACTIVE = 259
ERROR_INVALID_PARAMETER = 87

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
k32.OpenProcess.restype = wintypes.HANDLE
k32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
k32.WaitForSingleObject.restype = wintypes.DWORD
k32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
k32.GetExitCodeProcess.restype = wintypes.BOOL
k32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
k32.CloseHandle.restype = wintypes.BOOL
k32.CloseHandle.argtypes = [wintypes.HANDLE]

h = k32.OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, False, cpid)
if not h:
    err = ctypes.get_last_error()
    if err == ERROR_INVALID_PARAMETER:
        sys.exit(0)
    print("OpenProcess failed for PID %d: OS error %d" % (cpid, err), file=sys.stderr)
    sys.exit(1)
try:
    wait_res = k32.WaitForSingleObject(h, 0)
    if wait_res != 0:
        print("WaitForSingleObject returned non-signaled state: %d" % wait_res, file=sys.stderr)
        sys.exit(1)
    exit_code = wintypes.DWORD()
    if not k32.GetExitCodeProcess(h, ctypes.byref(exit_code)):
        err = ctypes.get_last_error()
        print("GetExitCodeProcess failed: OS error %d" % err, file=sys.stderr)
        sys.exit(1)
    if exit_code.value == STILL_ACTIVE:
        print("Process %d is STILL_ACTIVE" % cpid, file=sys.stderr)
        sys.exit(1)
    sys.exit(0)
finally:
    k32.CloseHandle(h)
' "$(to_native_path "$PIDFILE2")" && ok "root-exit held pipe: descendant child killed by group on deadline" || bad "root-exit held pipe: descendant child survived on Windows"
  else
    bad "root-exit held pipe: pidfile empty on Windows"
  fi
else
  if [ -s "$PIDFILE2" ]; then
    while read -r pid; do
      [ -n "$pid" ] || continue
      if kill -0 "$pid" 2>/dev/null; then
        survivors2=$((survivors2 + 1))
      fi
    done < "$PIDFILE2"
  fi
  [ "$survivors2" -eq 0 ] && ok "root-exit held pipe: descendant child killed by group on deadline" || bad "root-exit held pipe: descendant child survived ($survivors2)"
fi

# --- Silent held-stdin producer (bounded deadline, fail-open) --------------------
t0=$(date +%s)
out=$("$PY_BIN" -c "import time; time.sleep(2.5)" | FLOW_HOOK_STDIN_DEADLINE=1 "$HANDLER")
rc=$?
t1=$(date +%s)
elapsed=$((t1 - t0))
check "silent held-stdin exit 0" "$rc" "0"
check "silent held-stdin stdout empty" "$out" ""
[ "$elapsed" -le 3 ] && ok "silent held-stdin bounded by deadline (${elapsed}s <= 3s)" || bad "silent held-stdin exceeded deadline (${elapsed}s)"

# --- No-side-effect guarantees ---------------------------------------------------
P5="$(mkproj noflow)"; rmdir "$P5/.flow"
before=$(find "$P5" | sort)
out=$("$HANDLER" <<EOF
{"hook_event_name":"PreCompact","cwd":"$(to_json_path "$P5")"}
EOF
) ; check "no-.flow project exit 0" "$?" "0"; check "no-.flow stdout empty" "$out" ""
after=$(find "$P5" | sort)
if [ "$before" = "$after" ]; then ok "no auto-init (filesystem unchanged)"; else printf '%s\n' "$after" > "$TMP/fs.after"; bad "filesystem changed (compare \$before vs \$TMP/fs.after)"; fi
out=$("$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$P5")"}
EOF
) ; check "sessionstart no-project exit 0" "$?" "0"
[ -f "$P5/.flow/events.jsonl" ] && bad "telemetry written on hook path" || ok "no telemetry (FLOW_LOG_DISABLE honored)"
EXT="$(mkproj ext)"; extb=$(find "$EXT" -type f | sort)
out=$(FLOW_PROJECT_ROOT="$(to_json_path "$EXT")" "$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$P1")"}
EOF
) ; check "inherited FLOW_PROJECT_ROOT ignored, exit 0" "$?" "0"
[ -n "$out" ] && ok "handoff produced for payload project" || bad "handoff empty under inherited root"
exta=$(find "$EXT" -type f | sort)
if [ "$extb" = "$exta" ]; then ok "external project untouched"; else printf '%s\n' "$exta" > "$TMP/ext.after"; bad "external project mutated (compare \$extb vs \$TMP/ext.after)"; fi

# --- Launcher fail-open without python -------------------------------------------
SHIM="$TMP/shim"; mkdir -p "$SHIM"
printf '#!/bin/sh\nexit 127\n' > "$SHIM/python3"; printf '#!/bin/sh\nexit 127\n' > "$SHIM/python"; chmod +x "$SHIM/python3" "$SHIM/python"
out=$(PATH="$SHIM:$PATH" "$HANDLER" <<EOF
{"hook_event_name":"SessionStart","cwd":"$(to_json_path "$P1")"}
EOF
) ; rc=$?
check "no-python launcher exit 0" "$rc" "0"; check "no-python stdout empty" "$out" ""

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
