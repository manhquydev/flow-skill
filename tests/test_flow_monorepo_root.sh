#!/usr/bin/env bash
# Regression suite for the monorepo dual-root guard (Fix B): running flow from a subdir of an
# existing flow project must ADOPT the ancestor root, not silently mint a second .flow root.
# Run: bash tests/test_flow_monorepo_root.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

git_path_to_posix() {
  case "$1" in
    [A-Za-z]:[\\/]*)
      command -v cygpath >/dev/null 2>&1 || return 1
      cygpath -u "$1" 2>/dev/null
      ;;
    *) printf '%s\n' "$1" | tr '\\' '/' ;;
  esac
}

# Parent flow project with a flow/ planning dir; a frontend/ subdir with no flow state of its own.
newsb() { SB="$(mktemp -d)"; mkdir -p "$SB/flow" "$SB/frontend/src"; printf '# 00\n## Gate\n- [x] ok\n\nx.\n' > "$SB/flow/00-idea.md"; }

echo "A) from a subdir with no flow/ -> ADOPT the ancestor root + stderr note"
newsb
out="$( cd "$SB/frontend" && unset FLOW_PROJECT_ROOT; bash "$RUN" status 2>&1 )"
has "$out" "note: using flow root" "prints adoption note to stderr"
has "$out" "project: $SB" "status resolves to the ANCESTOR project, not the subdir"
no  "$out" "project: $SB/frontend" "does NOT mint a child root at the subdir"
# and no second .flow was created under frontend/
ck 1 "$([ -d "$SB/frontend/.flow" ] && echo 0 || echo 1)" "no second .flow root created under frontend/"
# stdout-only capture: the adoption marker is visible to host parsers on STDOUT too (C2)
sout="$( cd "$SB/frontend" && unset FLOW_PROJECT_ROOT; bash "$RUN" status 2>/dev/null )"
has "$sout" "adopting flow root $SB from an ancestor" "adoption marker also on stdout for host parsers"

echo "A2) /flow next from the adopted subdir -> PASS names the ROOT-qualified path"
SB="$(mktemp -d)"; mkdir -p "$SB/.flow" "$SB/frontend/src"   # SB was used as a root (.flow run-state); frontend adopts it
sout2="$( cd "$SB/frontend" && unset FLOW_PROJECT_ROOT; bash "$RUN" status 2>/dev/null )"
has "$sout2" "adopting flow root $SB from an ancestor" "status adopts the ancestor before first next"
nout="$( cd "$SB/frontend" && unset FLOW_PROJECT_ROOT; bash "$RUN" next 2>&1 )"
has "$nout" "unlocked stage 00" "stage-00 unlock literal preserved (parity contract)"
has "$nout" "PASS: unlocked stage 00 -> $SB/flow/00-idea.md" "PASS names the ROOT-qualified artifact path"
ck 0 "$([ -f "$SB/flow/00-idea.md" ] && echo 0 || echo 1)" "the qualified path actually exists at the ancestor"
rm -rf "$SB"

echo "B) subdir WITH its own flow/ (deliberate sub-project) -> NOT adopted"
newsb; mkdir -p "$SB/frontend/flow"
out="$( cd "$SB/frontend" && unset FLOW_PROJECT_ROOT; bash "$RUN" status 2>&1 )"
no  "$out" "note: using flow root" "deliberate sub-project is left alone (no adoption)"
has "$out" "project: $SB/frontend" "sub-project keeps its own root"
rm -rf "$SB"

echo "C) explicit FLOW_PROJECT_ROOT always wins (no adoption walk)"
newsb
out="$( cd "$SB/frontend" && FLOW_PROJECT_ROOT="$SB/frontend" bash "$RUN" status 2>&1 )"
no  "$out" "note: using flow root" "override suppresses the adoption walk"
has "$out" "project: $SB/frontend" "override root respected"
rm -rf "$SB"

echo "D) a standalone dir NOT under any flow project -> stays itself + new-root note (no false adoption)"
SB="$(mktemp -d)"; mkdir -p "$SB/plain"
out="$( cd "$SB/plain" && unset FLOW_PROJECT_ROOT; bash "$RUN" status 2>&1 )"
no  "$out" "note: using flow root" "no adoption when no ancestor is a flow project"
has "$out" "note: no Flow project found here or in ancestors" "announces that a NEW flow root starts at this CWD"
has "$out" "starting a new Flow project at $SB/plain" "announced destination is exactly this CWD"
has "$out" "project: $SB/plain" "standalone dir still resolves to itself"
rm -rf "$SB"

echo "F) a dir with only .flow/ run-state (no flow/, no cards/) -> existing root, NO new-project note"
SB="$(mktemp -d)"; mkdir -p "$SB/plain/.flow"
out="$( cd "$SB/plain" && unset FLOW_PROJECT_ROOT; bash "$RUN" status 2>&1 )"
no  "$out" "note: no Flow project found here" ".flow run-state means this root is not new"
has "$out" "project: $SB/plain" ".flow-only dir still resolves to itself"
rm -rf "$SB"

echo "G) git repo: run-state ignores land in .git/info/exclude, never committed"
SB="$(mktemp -d)"
 ( cd "$SB" \
  && export GIT_AUTHOR_NAME=ci GIT_AUTHOR_EMAIL=ci@localhost GIT_COMMITTER_NAME=ci GIT_COMMITTER_EMAIL=ci@localhost \
  && git init -q && git commit -qm base --allow-empty )
EX_REL="$(git_path_to_posix "$(git -C "$SB" rev-parse --git-path info/exclude)")"
case "$EX_REL" in /*) EX_PATH="$EX_REL" ;; *) EX_PATH="$SB/$EX_REL" ;; esac
printf '# existing local excludes without final newline' > "$EX_PATH"
( cd "$SB" && unset FLOW_PROJECT_ROOT && bash "$RUN" next >/dev/null 2>&1 )
EX="$(git_path_to_posix "$(git -C "$SB" rev-parse --git-path info/exclude)")"
case "$EX" in /*) ;; *) EX="$SB/$EX" ;; esac
[ "$(grep -cxF '/.flow/' "$EX")" -eq 1 ] && grep -qxF '/flow/.lock*' "$EX" && grep -qxF '/cards/.inflight' "$EX" || { echo "  FAIL [info/exclude missing or concatenated patterns]"; fail=$((fail+1)); }
git -C "$SB" config user.name ci
git -C "$SB" config user.email ci@localhost
if git -C "$SB" -c user.name=ci -c user.email=ci@localhost add -A && git -C "$SB" -c user.name=ci -c user.email=ci@localhost commit -qm "novice: git add -A"; then
  echo "  ok   [novice add and commit succeeded]"
else
  echo "  FAIL [novice add and commit succeeded]"
  fail=$((fail+1))
fi
COMMITTED_TREE="$(git -C "$SB" ls-tree -r --name-only HEAD 2>/dev/null || true)"
ck 0 "$(printf '%s\n' "$COMMITTED_TREE" | grep -cE '^\.flow/|^flow/\.lock|^\.gitignore$' || true)" "committed tree has no .flow/, no flow/.lock*, no minted .gitignore"
ck 1 "$(printf '%s\n' "$COMMITTED_TREE" | grep -cx 'flow/00-idea.md' || true)" "planned stage-00 artifact remains in committed tree"
ck 0 "$([ -f "$SB/.flow/cycle_id" ] && echo 0 || echo 1)" "run-state still written to disk (telemetry policy remains intact)"
( cd "$SB" && test ! -f .gitignore ) && echo "  ok   [no .gitignore created in git repos]" || { echo "  FAIL [.gitignore should not be created]"; fail=$((fail+1)); }

echo "G2) newline-bearing Flow root cannot inject or append git ignore patterns"
for newline_kind in lf crlf trailing-lf; do
  SB="$(mktemp -d)"
  ( cd "$SB" && git init -q && git config user.name ci && git config user.email ci@localhost && git commit -qm base --allow-empty )
  EX_REL="$(git_path_to_posix "$(git -C "$SB" rev-parse --git-path info/exclude)")"
  case "$EX_REL" in /*) EX_PATH="$EX_REL" ;; *) EX_PATH="$SB/$EX_REL" ;; esac
  printf '# sentinel\n' > "$EX_PATH"
  printf '# tracked ignore sentinel\n' > "$SB/.gitignore"
  git -C "$SB" add .gitignore && git -C "$SB" commit -qm 'tracked ignore sentinel' || { echo 'FAIL: cannot commit ignore sentinel'; exit 1; }
  ignore_before="$(git -C "$SB" hash-object "$SB/.gitignore")"
  TEST_HOME="$SB/home"; mkdir -p "$TEST_HOME"
  case "$newline_kind" in
    lf) BAD_ROOT="$SB/frontend
*.md
suffix" ;;
    crlf) BAD_ROOT="$(printf '%s/frontend\r\n*.md\r\nsuffix' "$SB")" ;;
    trailing-lf) BAD_ROOT="$SB/frontend
" ;;
  esac
  physical_root_available=1
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) physical_root_available=0 ;;
    *)
      if ! mkdir -p "$BAD_ROOT/flow" 2>/dev/null; then
        echo 'FAIL: cannot create newline-root fixture'; exit 1
      fi
      ;;
  esac
  cp "$HERE/../skills/flow/runner/flow.sh" "$SB/flow.sh"
  printf '# unrelated markdown\n' > "$SB/unrelated.md"
  before_ex="$(git -C "$SB" hash-object "$EX_PATH")"
  ec=0
  out="$( cd "$SB" && HOME="$TEST_HOME" FLOW_PROJECT_ROOT="$BAD_ROOT" bash "$SB/flow.sh" next 2>&1 )" || ec=$?
  ck 1 "$ec" "$newline_kind: unsafe root exits nonzero before library loading"
  after_ex="$(git -C "$SB" hash-object "$EX_PATH")"
  has "$out" 'root path contains CR/LF' "$newline_kind: names unsafe root refusal"
  ck "$before_ex" "$after_ex" "$newline_kind: exclude remains byte-identical"
  out="$( cd "$SB" && FLOW_PROJECT_ROOT="$BAD_ROOT" bash "$RUN" mode work 2>&1 )"
  ck 1 "$([ -f "$BAD_ROOT/MODE" ] && echo 0 || echo 1)" "$newline_kind: mode refuses before writing state"
  out="$( cd "$SB" && FLOW_PROJECT_ROOT="$BAD_ROOT" bash "$RUN" project-type library 2>&1 )"
  ck 1 "$([ -f "$BAD_ROOT/PROJECT_TYPE" ] && echo 0 || echo 1)" "$newline_kind: project type refuses before writing state"
  if [ "$physical_root_available" = 1 ]; then
  ec=0
  out="$( cd "$BAD_ROOT" && unset FLOW_PROJECT_ROOT && HOME="$TEST_HOME" bash "$RUN" next 2>&1 )" || ec=$?
  ck 1 "$ec" "$newline_kind: raw CWD is rejected before terminal LF stripping"
  has "$out" 'root path contains CR/LF' "$newline_kind: CWD refusal is loud"
  for command in status assess; do
    ec=0
    out="$( cd "$BAD_ROOT" && HOME="$TEST_HOME" FLOW_PROJECT_ROOT=. bash "$RUN" "$command" 2>&1 )" || ec=$?
    ck 1 "$ec" "$newline_kind: $command rejects unsafe physical root behind relative alias"
    has "$out" 'root path contains CR/LF' "$newline_kind: $command physical alias refusal is loud"
  done
  else
    echo "  skip [$newline_kind: filesystem rejects CR/LF directory names; explicit-root and direct-writer checks still run]"
  fi
  ck 1 "$([ -e "$BAD_ROOT/flow/00-idea.md" ] || [ -e "$BAD_ROOT/flow/.lock" ] || [ -e "$BAD_ROOT/flow/.lock.d" ] || [ -e "$BAD_ROOT/flow/.lock.claim" ]; echo $?)" "$newline_kind: no plan or lock writes"
  ck 1 "$([ -e "$BAD_ROOT/.flow" ]; echo $?)" "$newline_kind: no telemetry, workspace or eval directory"
  ck 1 "$([ -e "$TEST_HOME/.claude/flow/usage.jsonl" ]; echo $?)" "$newline_kind: no global telemetry"
  ck "$ignore_before" "$(git -C "$SB" hash-object "$SB/.gitignore")" "$newline_kind: tracked ignore bytes unchanged"
  ck "$before_ex" "$(git -C "$SB" hash-object "$EX_PATH")" "$newline_kind: exclude unchanged after all rejected commands"
  # Source real helpers with a valid root, then exercise each writer against an unsafe root.
  for helper in _claim_lock _write_lock lock_acquire _ws_record_append _ensure_cycle _eval_emit_batch_marker _eval_emit_result _eval_routing_emit_batch_marker _eval_routing_emit_result _eval_converge_emit_batch_marker _eval_converge_emit_result _log_event; do
    ec=0
    out="$(HOME="$TEST_HOME" FLOW_PROJECT_ROOT="$SB" FLOW_LIB_ONLY=1 bash -c '
      . "$1"
      ROOT="$2"; FLOW_DIR="$ROOT/flow"; LOG_DIR="$ROOT/.flow"
      LOCK_FILE="$FLOW_DIR/.lock"; LOCK_DIR="$FLOW_DIR/.lock.d"; LOCK_CLAIM="$FLOW_DIR/.lock.claim"
      CYCLE_FILE="$LOG_DIR/cycle_id"; EVENTS_FILE="$LOG_DIR/events.jsonl"
      "$3"
    ' _ "$RUN" "$BAD_ROOT" "$helper" 2>&1)" || ec=$?
    ck 1 "$ec" "$newline_kind: direct $helper refuses unsafe root"
    has "$out" 'root path contains CR/LF' "$newline_kind: direct $helper refusal is loud"
  done
  ck 1 "$([ -e "$BAD_ROOT/.flow" ] || [ -e "$BAD_ROOT/flow/.lock" ] || [ -e "$BAD_ROOT/flow/.lock.d" ] || [ -e "$BAD_ROOT/flow/.lock.claim" ]; echo $?)" "$newline_kind: direct helpers leave no state"
  ( cd "$SB" && git -c core.excludesFile=/dev/null check-ignore -q unrelated.md ); ck 1 "$?" "$newline_kind: unrelated markdown remains visible"
  ck 0 "$(git -C "$SB" ls-files --others --exclude-standard | grep -cE '(^|/)\.flow/|(^|/)\.lock' || true)" "$newline_kind: no Flow run-state files were created"
  rm -rf "$SB"
done

echo "E) DECOY: ancestor has a bare flow/ dir but NO stage artifact -> must NOT adopt (real-signature guard)"
SB="$(mktemp -d)"; mkdir -p "$SB/flow" "$SB/deep/sub"   # flow/ exists but is EMPTY (no 00-idea.md, no .flow/, no cards)
out="$( cd "$SB/deep/sub" && unset FLOW_PROJECT_ROOT; bash "$RUN" status 2>&1 )"
no  "$out" "note: using flow root" "a bare flow/ folder (e.g. ~/flow) is NOT a flow project — no adoption"
rm -rf "$SB"


echo "H) adopted Flow root inside a larger repo scopes ignore rules to its prefix"
SB="$(mktemp -d)"
git -C "$SB" init -q
git -C "$SB" config user.name ci
git -C "$SB" config user.email ci@localhost
mkdir -p "$SB/frontend/flow" "$SB/frontend/cards" "$SB/frontend/src"
printf '# Stage 00\n## Goal\n- [x] goal recorded\n\nDone.\n' > "$SB/frontend/flow/00-idea.md"
git -C "$SB" add frontend/flow/00-idea.md
git -C "$SB" commit -qm base
(cd "$SB/frontend" && unset FLOW_PROJECT_ROOT && bash "$RUN" next >/dev/null 2>&1)
EX="$(git_path_to_posix "$(git -C "$SB/frontend" rev-parse --git-path info/exclude)")"
case "$EX" in /*) ;; *) EX="$SB/frontend/$EX" ;; esac
for pat in '/frontend/.flow/' '/frontend/flow/.lock*' '/frontend/cards/.inflight' '/frontend/MODE' '/frontend/PROJECT_TYPE'; do
  grep -qxF "$pat" "$EX" || { echo "  FAIL [nested exclude missing $pat]"; fail=$((fail+1)); }
done
mkdir -p "$SB/frontend/.flow" "$SB/frontend/flow" "$SB/frontend/cards" "$SB/.flow" "$SB/flow"
touch "$SB/frontend/.flow/events.jsonl" "$SB/frontend/flow/.lock" "$SB/frontend/cards/.inflight" "$SB/frontend/MODE" "$SB/frontend/PROJECT_TYPE" "$SB/.flow/keep" "$SB/flow/.lock"
for path in frontend/.flow/events.jsonl frontend/flow/.lock frontend/cards/.inflight frontend/MODE frontend/PROJECT_TYPE; do
  git -C "$SB" check-ignore -q "$path" || { echo "  FAIL [nested run-state not ignored: $path]"; fail=$((fail+1)); }
done
for path in .flow/keep flow/.lock; do
  git -C "$SB" check-ignore -q "$path" && { echo "  FAIL [unrelated repo path ignored: $path]"; fail=$((fail+1)); } || echo "  ok   [unrelated repo path remains trackable: $path]"
done
rm -rf "$SB"

echo "I) linked worktree without .gitignore writes absolute main-git-dir exclude"
SB="$(mktemp -d)"
git -C "$SB" init -q
git -C "$SB" config user.name ci
git -C "$SB" config user.email ci@localhost
printf '# base\n' > "$SB/base.txt"
git -C "$SB" add base.txt
git -C "$SB" commit -qm base
git -C "$SB" worktree add --detach "$SB-linked" HEAD >/dev/null
test -f "$SB-linked/.git" && test ! -d "$SB-linked/.git" && test ! -e "$SB-linked/.gitignore"
(cd "$SB-linked" && unset FLOW_PROJECT_ROOT && FLOW_DEBUG_IGNORE_RUN_STATE=1 bash "$RUN" next >/dev/null 2>"$SB/linked-ignore-debug.log")
EX="$(git_path_to_posix "$(git -C "$SB-linked" rev-parse --git-path info/exclude)")"
case "$EX" in /*) ;; *) EX="$SB-linked/$EX" ;; esac
for pat in '/.flow/' '/flow/.lock*' '/cards/.inflight' '/MODE' '/PROJECT_TYPE'; do
  grep -qxF "$pat" "$EX" || { echo "  FAIL [linked exclude missing $pat]"; cat "$SB/linked-ignore-debug.log"; fail=$((fail+1)); }
done
test ! -e "$SB-linked/.git/info/exclude" && echo "  ok   [no relative-path stray .git tree under worktree]" || { echo "  FAIL [relative-path stray .git tree]"; fail=$((fail+1)); }
git -C "$SB-linked" worktree remove --force "$SB-linked"
rm -rf "$SB"

echo "J) explicit Flow root from a nested CWD writes the repository exclude"
SB="$(mktemp -d)"
git -C "$SB" init -q
git -C "$SB" config user.name ci
git -C "$SB" config user.email ci@localhost
mkdir -p "$SB/flow" "$SB/frontend/subdir"
printf '# Stage 00\n## Goal\n- [x] goal recorded\n\nDone.\n' > "$SB/flow/00-idea.md"
git -C "$SB" add flow/00-idea.md && git -C "$SB" commit -qm base
(cd "$SB/frontend/subdir" && FLOW_PROJECT_ROOT="$SB" bash "$RUN" mode work >/dev/null 2>&1)
EX="$(git_path_to_posix "$(git -C "$SB" rev-parse --git-path info/exclude)")"
case "$EX" in /*) ;; *) EX="$SB/$EX" ;; esac
grep -qxF '/.flow/' "$EX" && grep -qxF '/flow/.lock*' "$EX" || { echo "  FAIL [explicit ROOT excludes missing from main git dir]"; fail=$((fail+1)); }
test ! -e "$SB/frontend/subdir/.git/info/exclude" && echo "  ok   [nested CWD did not create a stray exclude file]" || { echo "  FAIL [exclude path was resolved against nested CWD]"; fail=$((fail+1)); }
rm -rf "$SB"

echo "K) relative FLOW_PROJECT_ROOT resolves git exclude from selected root, not CWD"
SB="$(mktemp -d)"; mkdir -p "$SB/repo/flow" "$SB/repo/frontend"
git -C "$SB/repo" init -q
git -C "$SB/repo" config user.name ci
git -C "$SB/repo" config user.email ci@localhost
printf '# Stage 00\n## Goal\n- [x] goal recorded\n\nDone.\n' > "$SB/repo/flow/00-idea.md"
git -C "$SB/repo" add flow/00-idea.md && git -C "$SB/repo" commit -qm base
(cd "$SB/repo/frontend" && FLOW_PROJECT_ROOT=.. FLOW_DEBUG_IGNORE_RUN_STATE=1 bash "$RUN" mode work >/dev/null 2>"$SB/relative-root-debug.log")
EX="$(git_path_to_posix "$(git -C "$SB/repo" rev-parse --git-path info/exclude)")"
case "$EX" in /*) ;; *) EX="$SB/repo/$EX" ;; esac
grep -qxF '/.flow/' "$EX" || { echo "  FAIL [relative ROOT patterns missing from selected repository exclude]"; cat "$SB/relative-root-debug.log"; fail=$((fail+1)); }
test ! -e "$SB/.git/info/exclude" && echo "  ok   [relative ROOT did not write above repository]" || { echo "  FAIL [relative ROOT wrote to joined-path escape]"; fail=$((fail+1)); }
test ! -e "$SB/repo/frontend/.git/info/exclude" && echo "  ok   [relative ROOT did not write into CWD]" || { echo "  FAIL [relative ROOT was resolved against CWD]"; fail=$((fail+1)); }
rm -rf "$SB"

echo "J) nested Flow root with ignore metacharacters is matched literally"
SB="$(mktemp -d)"
git -C "$SB" init -q
git -C "$SB" config user.name ci
git -C "$SB" config user.email ci@localhost
mkdir -p "$SB/frontend[1]/flow" "$SB/frontend1/.flow"
printf '# Stage 00\n## Goal\n- [x] goal recorded\n\nDone.\n' > "$SB/frontend[1]/flow/00-idea.md"
git -C "$SB" add 'frontend[1]/flow/00-idea.md'
git -C "$SB" commit -qm base
(cd "$SB/frontend[1]" && unset FLOW_PROJECT_ROOT && FLOW_DEBUG_IGNORE_RUN_STATE=1 bash "$RUN" mode work >/dev/null 2>"$SB/ignore-debug.log")
EX="$(git_path_to_posix "$(git -C "$SB" rev-parse --git-path info/exclude)")"
case "$EX" in /*) ;; *) EX="$SB/$EX" ;; esac
if ! grep -qxF '/frontend\[1\]/.flow/' "$EX"; then
  echo "  FAIL [literal metachar prefix not escaped]"
  cat "$SB/ignore-debug.log"
  fail=$((fail+1))
fi
mkdir -p "$SB/frontend[1]/.flow" "$SB/frontend1/.flow"
touch "$SB/frontend[1]/.flow/events.jsonl" "$SB/frontend1/.flow/keep"
(cd "$SB/frontend[1]" && git check-ignore -q -- .flow/events.jsonl) || { echo "  FAIL [literal root state not ignored]"; cat "$SB/ignore-debug.log"; fail=$((fail+1)); }
(cd "$SB/frontend1" && git check-ignore -q -- .flow/keep) && { echo "  FAIL [metachar lookalike unexpectedly ignored]"; fail=$((fail+1)); } || echo "  ok   [metachar lookalike remains trackable]"
rm -rf "$SB"

echo "L) CDPATH output does not contaminate a valid relative root"
SB="$(mktemp -d)"; mkdir -p "$SB/repo" "$SB/caller"
git -C "$SB/repo" init -q
ec=0
out="$(cd "$SB/caller" && CDPATH="$SB" HOME="$SB/home" FLOW_PROJECT_ROOT=repo bash "$RUN" status 2>&1)" || ec=$?
ck 0 "$ec" "relative-root status works with exported CDPATH"
no "$out" 'root path contains CR/LF' "CDPATH chatter is not mistaken for a newline root"
# Exercise the exclude helper too: CDPATH may resolve a relative path not in CWD.
ec=0
out="$(cd "$SB/caller" && CDPATH="$SB" HOME="$SB/home" FLOW_PROJECT_ROOT=repo FLOW_LIB_ONLY=1 bash -c '. "$1"; _ignore_run_state' _ "$RUN" 2>&1)" || ec=$?
ck 0 "$ec" "direct exclude helper accepts valid relative root with CDPATH"
rm -rf "$SB"
echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
