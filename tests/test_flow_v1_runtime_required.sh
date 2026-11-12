#!/usr/bin/env bash
# Missing coverage: every primary product verb refuses with complete install guidance.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
. "$HERE/fixture_path_lib.sh"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qF "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] missing '$2'"; fail=$((fail+1)); fi; }
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
mkdir "$SB/bin" "$SB/project"
for tool in bash dirname tr uname hostname date git head tail sed grep awk mkdir cat wc sort cut rm sleep timeout env mktemp; do
  loc="$(type -P "$tool" 2>/dev/null || true)"
  [ -z "$loc" ] || fixture_forward_tool "$SB/bin" "$tool" "$loc"
done
for verb in next card check gate; do
  out="$(PATH="$SB/bin" FLOW_PROJECT_ROOT="$SB/project" bash "$RUN" "$verb" 2>&1)"; rc=$?
  ck 1 "$rc" "$verb refuses without Python"
  for text in 'Python >=3.7' 'apt install python3' 'brew install python' 'python.org' 'docs/migration-v1.md' 'flow doctor'; do
    has "$out" "$text" "$verb actionable refusal: $text"
  done
  ck no "$([ -e "$SB/project/.flow" ] && echo yes || echo no)" "$verb creates no durable state or telemetry"
  ck no "$([ -e "$SB/project/flow" ] && echo yes || echo no)" "$verb creates no locks or stage files"
done
# Keep diagnostics useful without pretending that a failed prerequisite is healthy.
out="$(PATH="$SB/bin" FLOW_PROJECT_ROOT="$SB/project" bash "$RUN" doctor --check python 2>&1)"; rc=$?
ck 1 "$rc" 'doctor runs and reports failing Python prerequisite'
has "$out" 'product operations REFUSED' 'doctor reaches the runtime check'
for verb in help -h --help; do
  PATH="$SB/bin" FLOW_PROJECT_ROOT="$SB/project" bash "$RUN" "$verb" >/dev/null 2>&1
  ck 0 "$?" "$verb survives missing Python"
done
out="$(FLOW_PROJECT_ROOT="$SB/project" FLOW_HARNESS_DISABLE=disabled bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" 'any nonempty disable value refuses'
has "$out" 'docs/migration-v1.md' 'disable refusal names migration guide'
has "$out" 'flow doctor' 'disable refusal advises diagnostics'
ck no "$([ -e "$SB/project/.flow" ] && echo yes || echo no)" 'disable refusal emits no database or events'
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
