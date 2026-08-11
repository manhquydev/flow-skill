# attestations.sh — risk, receipts, fingerprints, auto policy (sourced by flow.sh)
# Namespace: _att_* helpers + cmd_attest. No side effects on source.
# Bash 3.2 + Git Bash portable. No jq/Python required for gate path.

# ---------- constants ----------
# Globals touched across helpers (set -u safe defaults)
_ATT_LAST_FP=""
_ATT_SUBJ_BASE=""; _ATT_SUBJ_REV=""; _ATT_SUBJ_TREE=""
_ATT_R_subject_fingerprint=""; _ATT_R_verdict=""
_ATT_FIELD_ERR=""
_ATT_SCHEMA="flow-attestation/v1"
_ATT_OWNER_SCHEMA="flow-attestation-owner/v1"
_ATT_SEM_RESULT_SCHEMA="flow-semantic-result/v1"
_ATT_AUTO_SCHEMA="flow-auto/v1"
_ATT_STAGES="00-idea 01-research 02-scope 03-prd 04-adr 05-contract"
# Defaults only; _att_run_supervised re-reads FLOW_ATTEST_* at call time.

# ---------- small utils ----------
_att_trim() { printf '%s' "${1:-}" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
_att_lc() { printf '%s' "${1:-}" | tr 'A-Z' 'a-z'; }
_att_now_rfc3339() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z"; }
_att_now_s() { date +%s 2>/dev/null || echo 0; }

_att_sanitize_label() { # $1 raw -> sanitized actor/engine or empty
  local s; s="$(printf '%s' "${1:-}" | tr -d '\r\n' | cut -c1-128)"
  case "$s" in
    [A-Za-z0-9][A-Za-z0-9._@/-]*) printf '%s' "$s" ;;
    *) printf '' ;;
  esac
}

_att_is_stage() {
  case " $_ATT_STAGES " in *" $1 "*) return 0 ;; esac
  return 1
}

_att_norm_card_id() { # $1 -> C-NNN or empty
  local arg="$1" num
  num="${arg#C-}"; num="${num#c-}"
  case "$num" in (*[!0-9]*) echo ""; return 1 ;; esac
  num=$((10#$num))
  printf 'C-%03d' "$num"
}

_att_valid_subject_id() {
  local id="$1"
  _att_is_stage "$id" && return 0
  case "$id" in C-[0-9][0-9][0-9]) return 0 ;; esac
  return 1
}

_att_valid_repo_ref() { # repo:relpath — no abs, no ..
  local r="$1" p
  case "$r" in
    none) return 0 ;;
    repo:*)
      p="${r#repo:}"
      case "$p" in
        ""|/*|*..*|*"//"*|*\\*) return 1 ;;
      esac
      # reject empty segments
      case "/$p/" in *"//"*|*"/./*"|*"/../"*) return 1 ;; esac
      [ "${#p}" -le 240 ] || return 1
      return 0
      ;;
    *) return 1 ;;
  esac
}

_att_valid_target_id() {
  case "$1" in
    none) return 0 ;;
    [a-z0-9][a-z0-9._-]*) [ "${#1}" -le 64 ] && return 0 ;;
  esac
  return 1
}

_att_valid_actor() {
  case "$1" in [A-Za-z0-9][A-Za-z0-9._@/-]*) [ "${#1}" -le 128 ] && return 0 ;; esac
  return 1
}

# ---------- git / state root ----------
_att_git_ok() { command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; }

_att_object_format() {
  local f
  f="$(git -C "$ROOT" rev-parse --show-object-format=storage 2>/dev/null || echo sha1)"
  case "$f" in sha1|sha256) printf '%s' "$f" ;; *) printf 'sha1' ;; esac
}

_att_oid_re() {
  case "$(_att_object_format)" in
    sha256) printf '^[0-9a-f]{64}$' ;;
    *)      printf '^[0-9a-f]{40}$' ;;
  esac
}

_att_full_commit() { # $1 rev -> full oid or empty
  git -C "$ROOT" rev-parse --verify "${1}^{commit}" 2>/dev/null | tr -d '\r\n'
}

_att_is_ancestor() { # $1 possible-ancestor $2 descendant
  git -C "$ROOT" merge-base --is-ancestor "$1" "$2" 2>/dev/null
}

_att_strip_git_env() {
  unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_INDEX_FILE 2>/dev/null || true
}

# Main state root: linked worktree -> main equiv; submodule/separate-git-dir stay local.
_att_main_state_root() {
  local root="$ROOT" git_dir common_dir worktree_top main_top rr wtop rel
  if ! _att_git_ok; then printf '%s' "$root"; return 0; fi
  _att_strip_git_env
  # Prefer path-format=absolute (git ≥2.31); fall back.
  local out
  out="$(git -C "$root" rev-parse --path-format=absolute --git-dir --git-common-dir --show-toplevel 2>/dev/null)" || out=""
  if [ -n "$out" ]; then
    git_dir="$(printf '%s\n' "$out" | sed -n '1p')"
    common_dir="$(printf '%s\n' "$out" | sed -n '2p')"
    worktree_top="$(printf '%s\n' "$out" | sed -n '3p')"
  else
    git_dir="$(git -C "$root" rev-parse --absolute-git-dir 2>/dev/null || true)"
    common_dir="$(git -C "$root" rev-parse --git-common-dir 2>/dev/null || true)"
    worktree_top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
    case "$common_dir" in /*) : ;; "") : ;; *) common_dir="$(cd "$root" && cd "$common_dir" 2>/dev/null && pwd)" ;; esac
  fi
  if [ -z "$git_dir" ] || [ -z "$common_dir" ] || [ -z "$worktree_top" ]; then
    printf '%s' "$root"; return 0
  fi
  # realpath-ish: prefer readlink -f / realpath; else leave
  _rp() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }
  git_dir="$(_rp "$git_dir")"
  common_dir="$(_rp "$common_dir")"
  worktree_top="$(_rp "$worktree_top")"
  rr="$(_rp "$root")"
  if [ "$git_dir" = "$common_dir" ]; then
    # main, submodule, or separate-git-dir — do not translate
    printf '%s' "$rr"; return 0
  fi
  main_top="$(git -C "$root" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10); exit}')"
  main_top="$(printf '%s' "$main_top" | tr -d '\r')"
  if [ -z "$main_top" ] || [ ! -e "$main_top/.git" ]; then
    printf '%s' "$rr"; return 0
  fi
  main_top="$(_rp "$main_top")"
  wtop="$worktree_top"
  case "$rr" in
    "$wtop"|"$wtop"/*)
      rel="${rr#"$wtop"}"
      rel="${rel#/}"
      if [ -z "$rel" ]; then printf '%s' "$main_top"; else printf '%s/%s' "$main_top" "$rel"; fi
      return 0
      ;;
  esac
  printf '%s' "$rr"
}

_att_dir() {
  local base; base="$(_att_main_state_root)"
  printf '%s/.flow/attestations' "$base"
}

_att_auto_state_path() {
  printf '%s/.flow/auto-state' "$(_att_main_state_root)"
}

_att_receipt_path() { # $1 kind $2 subject_type $3 subject_id
  local kind="$1" st="$2" sid="$3" name
  case "$st" in
    stage) name="stage-${sid}.receipt" ;;
    card)  name="card-${sid}.receipt" ;;
    *) return 1 ;;
  esac
  printf '%s/%s/%s' "$(_att_dir)" "$kind" "$name"
}

_att_attempt_path() { # card id
  printf '%s/live_verify/card-%s.attempt' "$(_att_dir)" "$1"
}

# ---------- locks ----------
_att_lock_dir() {
  printf '%s/.flow/locks' "$(_att_main_state_root)"
}

_att_lock_acquire() { # $1 name  (mkdir atomic)
  local d name="$1" i=0 opid
  d="$(_att_lock_dir)"
  mkdir -p "$d" 2>/dev/null || true
  while ! mkdir "$d/$name.lock.d" 2>/dev/null; do
    i=$((i + 1))
    opid="$(cat "$d/$name.lock.d/pid" 2>/dev/null || true)"
    if [ -n "$opid" ] && ! kill -0 "$opid" 2>/dev/null; then
      rm -rf "$d/$name.lock.d" 2>/dev/null || true
      continue
    fi
    [ "$i" -gt 100 ] && { echo "FAIL: could not acquire attestation lock '$name'" >&2; return 1; }
    sleep 0.05 2>/dev/null || sleep 1
  done
  printf '%s\n' "$$" > "$d/$name.lock.d/pid" 2>/dev/null || true
  return 0
}

_att_lock_release() {
  local d name="$1"
  d="$(_att_lock_dir)"
  rm -rf "$d/$name.lock.d" 2>/dev/null || true
}

_att_auto_lock_acquire() { _att_lock_acquire "auto-policy"; }
_att_auto_lock_release() { _att_lock_release "auto-policy"; }

_att_subject_lock_name() { # kind subject_id
  printf 'subj-%s-%s' "$2" "$1"
}

# ---------- cleanliness ----------
# Allowed dirt: .flow/**, flow/.lock{,.d/**}, cards/C-*.md with projection==HEAD.
_att_git_clean_for_attest() {
  local porcelain
  porcelain="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all 2>/dev/null || echo FAIL)"
  [ "$porcelain" = "FAIL" ] && return 1
  [ -z "$porcelain" ] && return 0
  local line path
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    path="${line#?? }"
    case "$path" in
      *" -> "*) path="${path##* -> }" ;;
    esac
    path="${path#\"}"; path="${path%\"}"
    case "$path" in
      .flow|.flow/*) continue ;;
      flow/.lock|flow/.lock.d|flow/.lock.d/*) continue ;;
      cards/C-*.md)
        _att_card_projection_matches_head "$path" || return 1
        continue
        ;;
      *) return 1 ;;
    esac
  done <<EOF
$porcelain
EOF
  return 0
}
_att_card_projection_matches_head() {
  local rel="$1" tmp now old
  [ -f "$ROOT/$rel" ] || return 1
  git -C "$ROOT" cat-file -e "HEAD:${rel}" 2>/dev/null || return 1
  tmp="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/.att-proj.$$")"
  if ! git -C "$ROOT" show "HEAD:${rel}" >"$tmp" 2>/dev/null; then
    rm -f "$tmp"; return 1
  fi
  now="$(_att_card_contract_projection "$ROOT/$rel")"
  old="$(_att_card_contract_projection "$tmp")"
  rm -f "$tmp"
  [ "$now" = "$old" ]
}
_att_require_clean_for_consume() {
  _att_git_ok || return 0
  _att_git_clean_for_attest
}

# ---------- card field parsing ----------
_att_field_count() { # $1 file $2 field
  grep -cE "^${2}:" "$1" 2>/dev/null | tr -d '\r' || echo 0
}

_att_field_once() { # $1 file $2 field -> value or empty; sets _ATT_FIELD_ERR on dupe
  _ATT_FIELD_ERR=""
  local c v
  c="$(_att_field_count "$1" "$2")"
  case "$c" in
    0) printf ''; return 0 ;;
    1)
      v="$(grep -m1 -E "^${2}:" "$1" 2>/dev/null | sed "s/^${2}:[[:space:]]*//" | tr -d '\r')"
      printf '%s' "$v"; return 0
      ;;
    *) _ATT_FIELD_ERR="duplicate"; printf ''; return 1 ;;
  esac
}

card_risk() {
  local v
  v="$(_att_field_once "$1" risk)" || { printf 'invalid'; return 1; }
  [ -z "$v" ] && { printf 'unknown'; return 0; }
  printf '%s' "$v"
}

card_risk_reason() {
  _att_field_once "$1" risk-reason || true
}

card_risk_ack() {
  local v
  v="$(_att_field_once "$1" risk-ack)" || { printf 'invalid'; return 1; }
  [ -z "$v" ] && { printf 'none'; return 0; }
  printf '%s' "$v"
}

_att_reason_placeholder() {
  case "$(_att_lc "$1")" in
    ""|"[fill]"*|*"[fill]"*|"tbd"|"todo"|"n/a"|"none"|"-"|"—"|"x") return 0 ;;
  esac
  [ "${#1}" -lt 1 ] && return 0
  [ "${#1}" -gt 256 ] && return 0
  case "$1" in *$'\n'*|*$'\r'*) return 0 ;; esac
  return 1
}

# mode: manual|auto  -> prints normalized risk or "invalid:..." ; exit 0 ok, 1 structural
_card_risk_validate() {
  local file="$1" mode="${2:-manual}" risk reason ack
  if [ ! -f "$file" ]; then echo "invalid:missing-file"; return 1; fi
  risk="$(card_risk "$file")" || { echo "invalid:duplicate-risk"; return 1; }
  reason="$(card_risk_reason "$file" 2>/dev/null || true)"
  if [ "${_ATT_FIELD_ERR:-}" = "duplicate" ]; then echo "invalid:duplicate-risk-reason"; return 1; fi
  # re-count reason for duplicates
  if [ "$(_att_field_count "$file" risk-reason)" -gt 1 ]; then echo "invalid:duplicate-risk-reason"; return 1; fi
  ack="$(card_risk_ack "$file")" || { echo "invalid:duplicate-risk-ack"; return 1; }
  if [ "$(_att_field_count "$file" risk-ack)" -gt 1 ]; then echo "invalid:duplicate-risk-ack"; return 1; fi

  case "$risk" in
    standard|security-class|unknown) : ;;
    invalid) echo "invalid:duplicate-risk"; return 1 ;;
    *) echo "invalid:risk-value"; return 1 ;;
  esac
  case "$ack" in
    none|git:[0-9a-f]*) : ;;
    invalid) echo "invalid:duplicate-risk-ack"; return 1 ;;
    *)
      if [ -n "$(_att_field_once "$file" risk-ack 2>/dev/null)" ]; then
        case "$ack" in git:*) echo "invalid:risk-ack-shape"; return 1 ;; *) echo "invalid:risk-ack-shape"; return 1 ;; esac
      fi
      ;;
  esac

  if [ "$risk" = "unknown" ]; then
    [ "$ack" = "none" ] || { echo "invalid:unknown-with-ack"; return 1; }
    echo "unknown"; return 0
  fi
  if _att_reason_placeholder "$reason"; then echo "invalid:risk-reason"; return 1; fi
  if [ "$risk" = "standard" ]; then
    [ "$ack" = "none" ] || { echo "invalid:standard-with-ack"; return 1; }
    echo "standard"; return 0
  fi
  # security-class
  if [ "$mode" = "manual" ]; then
    echo "security-class"; return 0
  fi
  # auto: full ack
  if [ "$ack" = "none" ] || [ -z "$ack" ]; then echo "halt:ack-missing"; return 1; fi
  case "$ack" in git:*) : ;; *) echo "halt:ack-shape"; return 1 ;; esac
  local oid; oid="${ack#git:}"
  if ! printf '%s' "$oid" | grep -Eq "$(_att_oid_re)"; then echo "halt:ack-oid"; return 1; fi
  if ! _att_git_ok; then echo "halt:no-git"; return 1; fi
  if ! git -C "$ROOT" cat-file -e "${oid}^{commit}" 2>/dev/null; then echo "halt:ack-missing-commit"; return 1; fi
  local head; head="$(_att_full_commit HEAD)"
  if ! _att_is_ancestor "$oid" "$head"; then echo "halt:ack-not-ancestor"; return 1; fi
  local id; id="$(basename "$file" .md)"
  local prefix debt_blob line_no line author_mail exec_mail
  prefix="$(git -C "$ROOT" rev-parse --show-prefix 2>/dev/null || true)"
  debt_blob="$(git -C "$ROOT" show "${oid}:${prefix}DEBT.md" 2>/dev/null)" || { echo "halt:ack-no-debt"; return 1; }
  # exact open grammar
  line="$(printf '%s\n' "$debt_blob" | grep -nE "^- \[ \] DEBT: security-class ${id} --" || true)"
  if [ -z "$line" ]; then echo "halt:ack-debt-line"; return 1; fi
  if [ "$(printf '%s\n' "$line" | wc -l | tr -d ' ')" -ne 1 ]; then echo "halt:ack-debt-multi"; return 1; fi
  line_no="${line%%:*}"
  author_mail="$(git -C "$ROOT" blame --line-porcelain "$oid" -L "${line_no},${line_no}" -- "${prefix}DEBT.md" 2>/dev/null \
    | awk '/^author-mail /{print $2; exit}' | tr -d '<>' | tr 'A-Z' 'a-z' | tr -d '\r')"
  exec_mail="$(git -C "$ROOT" var GIT_AUTHOR_IDENT 2>/dev/null | sed -nE 's/.*<([^>]+)>.*/\1/p' | tr 'A-Z' 'a-z' | tr -d '\r')"
  if [ -z "$author_mail" ] || [ -z "$exec_mail" ]; then echo "halt:ack-identity-ambiguous"; return 1; fi
  if [ "$author_mail" = "$exec_mail" ]; then echo "halt:ack-same-identity"; return 1; fi
  echo "security-class"; return 0
}

_att_all_card_files() {
  ls -1 "$CARDS_DIR"/C-*.md 2>/dev/null | sort
}

_att_risk_fingerprint() {
  local f id risk reason ack body=""
  body=""
  for f in $(_att_all_card_files); do
    [ -f "$f" ] || continue
    id="$(basename "$f" .md)"
    risk="$(card_risk "$f" 2>/dev/null || echo invalid)"
    reason="$(_att_field_once "$f" risk-reason 2>/dev/null || true)"
    ack="$(card_risk_ack "$f" 2>/dev/null || echo invalid)"
    body="${body}${id}|${risk}|${reason}|${ack}"$'\n'
  done
  local fmt oid
  fmt="$(_att_object_format)"
  oid="$(printf '%s' "$body" | git -C "$ROOT" hash-object --stdin 2>/dev/null | tr -d '\r\n')"
  [ -n "$oid" ] || oid="0"
  printf 'git-%s:%s' "$fmt" "$oid"
}

# ---------- owner manifest ----------
_att_parse_kv_file() { # $1 path — sets _ATT_KV_<key> via eval-safe names only for known keys
  # shellcheck disable=SC2034
  _ATT_KV_schema=""; _ATT_KV_kind=""; _ATT_KV_subject_id=""; _ATT_KV_target_id=""
  _ATT_KV_command=""; _ATT_KV_revision_oracle=""
  local line k v seen=""
  [ -f "$1" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(printf '%s' "$line" | tr -d '\r')"
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    case "$line" in
      *": "*) k="${line%%: *}"; v="${line#*: }" ;;
      *:*) k="${line%%:*}"; v="${line#*:}"; v="${v# }" ;;
      *) return 1 ;;
    esac
    case "$k" in
      schema|kind|subject_id|target_id|command|revision_oracle) : ;;
      *) return 1 ;;
    esac
    case " $seen " in *" $k "*) return 1 ;; esac
    seen="$seen $k"
    case "$k" in
      schema) _ATT_KV_schema="$v" ;;
      kind) _ATT_KV_kind="$v" ;;
      subject_id) _ATT_KV_subject_id="$v" ;;
      target_id) _ATT_KV_target_id="$v" ;;
      command) _ATT_KV_command="$v" ;;
      revision_oracle) _ATT_KV_revision_oracle="$v" ;;
    esac
  done < "$1"
  [ "$_ATT_KV_schema" = "$_ATT_OWNER_SCHEMA" ] || return 1
  return 0
}

_att_owner_fingerprint() { # $1 owner path relative, $2 revision
  local rel="$1" rev="$2" cmd_path oracle_path mode blob o_mode o_blob body fmt oid owner_blob owner_mode
  cmd_path="${_ATT_KV_command#repo:}"
  owner_blob="$(git -C "$ROOT" rev-parse "${rev}:${rel}" 2>/dev/null | tr -d '\r\n')" || return 1
  owner_mode="$(git -C "$ROOT" ls-tree "$rev" -- "$rel" 2>/dev/null | awk '{print $1}' | head -1)"
  blob="$(git -C "$ROOT" rev-parse "${rev}:${cmd_path}" 2>/dev/null | tr -d '\r\n')" || return 1
  mode="$(git -C "$ROOT" ls-tree "$rev" -- "$cmd_path" 2>/dev/null | awk '{print $1}' | head -1)"
  body="owner=${rel}:${owner_mode}:${owner_blob}"$'\n'"cmd=${cmd_path}:${mode}:${blob}"$'\n'
  if [ "${_ATT_KV_revision_oracle}" != "none" ] && [ -n "${_ATT_KV_revision_oracle}" ]; then
    oracle_path="${_ATT_KV_revision_oracle#repo:}"
    o_blob="$(git -C "$ROOT" rev-parse "${rev}:${oracle_path}" 2>/dev/null | tr -d '\r\n')" || return 1
    o_mode="$(git -C "$ROOT" ls-tree "$rev" -- "$oracle_path" 2>/dev/null | awk '{print $1}' | head -1)"
    body="${body}oracle=${oracle_path}:${o_mode}:${o_blob}"$'\n'
  fi
  body="${body}target=${_ATT_KV_target_id}"$'\n'"kind=${_ATT_KV_kind}"$'\n'
  fmt="$(_att_object_format)"
  oid="$(printf '%s' "$body" | git -C "$ROOT" hash-object --stdin 2>/dev/null | tr -d '\r\n')"
  printf 'git-%s:%s' "$fmt" "$oid"
}

# ---------- committed-blob execution ----------
_att_path_mode_at_rev() { git -C "$ROOT" ls-tree "$1" -- "$2" 2>/dev/null | awk '{print $1}' | head -1; }
_att_blob_at_rev() { git -C "$ROOT" rev-parse "${1}:${2}" 2>/dev/null | tr -d '\r\n'; }
_att_blob_on_disk() {
  local f="$ROOT/$1"
  [ -f "$f" ] || return 1
  [ ! -L "$f" ] || return 1
  git -C "$ROOT" hash-object -- "$f" 2>/dev/null | tr -d '\r\n'
}
_att_assert_committed_regular() {
  local rev="$1" rel="$2" mode blob disk
  mode="$(_att_path_mode_at_rev "$rev" "$rel")"
  case "$mode" in 100644|100755) : ;; *) return 1 ;; esac
  blob="$(_att_blob_at_rev "$rev" "$rel")" || return 1
  [ -n "$blob" ] || return 1
  disk="$(_att_blob_on_disk "$rel")" || return 1
  [ "$disk" = "$blob" ] || return 1
  _ATT_BLOB_OID="$blob"
  return 0
}
_att_materialize_blob_exec() {
  local rev="$1" rel="$2" mode blob tmp
  mode="$(_att_path_mode_at_rev "$rev" "$rel")"
  case "$mode" in 100644|100755) : ;; *) return 1 ;; esac
  blob="$(_att_blob_at_rev "$rev" "$rel")" || return 1
  tmp="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/.att-exec.$$.$RANDOM")"
  if ! git -C "$ROOT" cat-file blob "$blob" >"$tmp" 2>/dev/null; then
    rm -f "$tmp"; return 1
  fi
  chmod 700 "$tmp" 2>/dev/null || chmod +x "$tmp" 2>/dev/null || true
  printf '%s' "$tmp"
  return 0
}
_att_load_owner_at_rev() {
  local rev="$1" rel="$2" cmd_rel
  _att_assert_committed_regular "$rev" "$rel" || return 1
  _att_parse_kv_file "$ROOT/$rel" || return 1
  case "${_ATT_KV_command:-}" in repo:*) : ;; *) return 1 ;; esac
  cmd_rel="${_ATT_KV_command#repo:}"
  _att_assert_committed_regular "$rev" "$cmd_rel" || return 1
  if [ "${_ATT_KV_revision_oracle:-none}" != "none" ] && [ -n "${_ATT_KV_revision_oracle:-}" ]; then
    case "$_ATT_KV_revision_oracle" in repo:*) : ;; *) return 1 ;; esac
    _att_assert_committed_regular "$rev" "${_ATT_KV_revision_oracle#repo:}" || return 1
  fi
  return 0
}

# ---------- projections / fingerprints ----------
_att_card_contract_projection() { # $1 card file
  local f="$1"
  # Extract contract fields; exclude status/Evidence
  {
    grep -E '^(deps|implements|risk|risk-reason|risk-ack):' "$f" 2>/dev/null || true
    awk '
      /^## Scope/{p=1; print; next}
      /^## Allowed files/{p=1; print; next}
      /^## Verify/{p=1; print; next}
      /^## Done-evidence/{p=1; print; next}
      /^## Evidence/{p=0; next}
      /^## /{ if($0 !~ /^## (Scope|Allowed files|Verify|Done-evidence)/) p=0 }
      p{print}
    ' "$f" 2>/dev/null || true
  } | tr -d '\r'
}

_att_stage_fingerprint() { # $1 stage $2 revision -> fp (also sets _ATT_LAST_FP)
  local stage="$1" rev="$2" path blob fmt
  path="flow/${stage}.md"
  blob="$(git -C "$ROOT" rev-parse "${rev}:${path}" 2>/dev/null | tr -d '\r\n')" || return 1
  fmt="$(_att_object_format)"
  _ATT_LAST_FP="$(printf 'git-%s:%s' "$fmt" "$blob")"
  printf '%s' "$_ATT_LAST_FP"
}

_att_card_semantic_fingerprint() { # $1 card file $2 base $3 head -> prints fp; sets _ATT_SUBJ_*
  local file="$1" base="$2" head="$3" id proj tree body fmt oid path_manifest
  id="$(basename "$file" .md)"
  base="$(_att_full_commit "$base")" || return 1
  head="$(_att_full_commit "$head")" || return 1
  tree="$(git -C "$ROOT" rev-parse "${head}^{tree}" 2>/dev/null | tr -d '\r\n')" || return 1
  proj="$(_att_card_contract_projection "$file")"
  # changed paths base..head excluding card path
  path_manifest="$(git -C "$ROOT" diff-tree -r --no-commit-id --name-status "$base" "$head" 2>/dev/null \
    | awk -v card="cards/${id}.md" '$2 != card && $3 != card {print}' \
    | while read -r st p rest; do
        case "$st" in
          R*|C*) p="$rest" ;;
        esac
        [ -z "$p" ] && continue
        mode_oid="$(git -C "$ROOT" ls-tree "$head" -- "$p" 2>/dev/null | awk '{print $1" "$3}')"
        printf '%s %s\n' "$p" "$mode_oid"
      done | sort)"
  body="base=${base}"$'\n'"head=${head}"$'\n'"tree=${tree}"$'\n'"proj<<"$'\n'"${proj}"$'\n'">>"$'\n'"paths<<"$'\n'"${path_manifest}"$'\n'">>"$'\n'
  fmt="$(_att_object_format)"
  oid="$(printf '%s' "$body" | git -C "$ROOT" hash-object --stdin 2>/dev/null | tr -d '\r\n')"
  _ATT_SUBJ_BASE="$base"
  _ATT_SUBJ_REV="$head"
  _ATT_SUBJ_TREE="$tree"
  _ATT_LAST_FP="$(printf 'git-%s:%s' "$fmt" "$oid")"
  printf '%s' "$_ATT_LAST_FP"
}

# ---------- receipt parse / write ----------
_att_receipt_parse() { # $1 path — sets _ATT_R_* ; return 0 valid schema structure
  local f="$1" line k v seen="" n=0 size
  _ATT_R_schema=""; _ATT_R_kind=""; _ATT_R_subject_type=""; _ATT_R_subject_id=""
  _ATT_R_subject_fingerprint=""; _ATT_R_verdict=""; _ATT_R_actor=""; _ATT_R_engine=""
  _ATT_R_evidence_ref=""; _ATT_R_timestamp=""; _ATT_R_override_ref=""
  _ATT_R_owner_ref=""; _ATT_R_owner_fingerprint=""
  _ATT_R_subject_revision=""; _ATT_R_subject_base=""; _ATT_R_subject_tree=""
  _ATT_R_command_fingerprint=""; _ATT_R_result_code=""; _ATT_R_result_fingerprint=""
  _ATT_R_duration_ms=""; _ATT_R_target_id=""
  _ATT_R_revision_oracle_ref=""; _ATT_R_revision_oracle_fingerprint=""
  [ -f "$f" ] || return 1
  size="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
  [ "${size:-0}" -le 16384 ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(printf '%s' "$line" | tr -d '\r')"
    [ -z "$line" ] && continue
    n=$((n + 1))
    [ "$n" -gt 64 ] && return 1
    case "$line" in
      *": "*) k="${line%%: *}"; v="${line#*: }" ;;
      *) return 1 ;;
    esac
    case "$k" in
      schema|kind|subject_type|subject_id|subject_fingerprint|verdict|actor|engine|evidence_ref|timestamp|override_ref|owner_ref|owner_fingerprint|subject_revision|subject_base|subject_tree|command_fingerprint|result_code|result_fingerprint|duration_ms|target_id|revision_oracle_ref|revision_oracle_fingerprint) : ;;
      *) return 1 ;;
    esac
    case " $seen " in *" $k "*) return 1 ;; esac
    seen="$seen $k"
    case "$v" in *$'\n'*|*$'\t'*) return 1 ;; esac
    [ "${#v}" -le 512 ] || return 1
    case "$k" in
      schema) _ATT_R_schema="$v" ;;
      kind) _ATT_R_kind="$v" ;;
      subject_type) _ATT_R_subject_type="$v" ;;
      subject_id) _ATT_R_subject_id="$v" ;;
      subject_fingerprint) _ATT_R_subject_fingerprint="$v" ;;
      verdict) _ATT_R_verdict="$v" ;;
      actor) _ATT_R_actor="$v" ;;
      engine) _ATT_R_engine="$v" ;;
      evidence_ref) _ATT_R_evidence_ref="$v" ;;
      timestamp) _ATT_R_timestamp="$v" ;;
      override_ref) _ATT_R_override_ref="$v" ;;
      owner_ref) _ATT_R_owner_ref="$v" ;;
      owner_fingerprint) _ATT_R_owner_fingerprint="$v" ;;
      subject_revision) _ATT_R_subject_revision="$v" ;;
      subject_base) _ATT_R_subject_base="$v" ;;
      subject_tree) _ATT_R_subject_tree="$v" ;;
      command_fingerprint) _ATT_R_command_fingerprint="$v" ;;
      result_code) _ATT_R_result_code="$v" ;;
      result_fingerprint) _ATT_R_result_fingerprint="$v" ;;
      duration_ms) _ATT_R_duration_ms="$v" ;;
      target_id) _ATT_R_target_id="$v" ;;
      revision_oracle_ref) _ATT_R_revision_oracle_ref="$v" ;;
      revision_oracle_fingerprint) _ATT_R_revision_oracle_fingerprint="$v" ;;
    esac
  done < "$f"
  [ "$_ATT_R_schema" = "$_ATT_SCHEMA" ] || return 1
  case "$_ATT_R_kind" in semantic_gate|live_verify) : ;; *) return 1 ;; esac
  case "$_ATT_R_subject_type" in stage|card) : ;; *) return 1 ;; esac
  _att_valid_subject_id "$_ATT_R_subject_id" || return 1
  case "$_ATT_R_verdict" in pass|fail|override) : ;; *) return 1 ;; esac
  [ "$_ATT_R_kind" = "live_verify" ] && [ "$_ATT_R_verdict" = "override" ] && return 1
  _att_valid_actor "$_ATT_R_actor" || return 1
  _att_valid_actor "$_ATT_R_engine" || return 1
  _att_valid_repo_ref "$_ATT_R_evidence_ref" || return 1
  _att_valid_repo_ref "$_ATT_R_owner_ref" || return 1
  [ -n "$_ATT_R_subject_fingerprint" ] && [ -n "$_ATT_R_owner_fingerprint" ] && [ -n "$_ATT_R_timestamp" ] || return 1
  return 0
}

_att_atomic_write() { # $1 dest $2 content
  local dest="$1" dir tmp
  dir="$(dirname "$dest")"
  mkdir -p "$dir" 2>/dev/null || return 1
  tmp="$dir/.tmp.$$.$(_att_now_s)"
  printf '%s' "$2" > "$tmp" || { rm -f "$tmp"; return 1; }
  chmod 600 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$dest" || { rm -f "$tmp"; return 1; }
  return 0
}

_att_write_receipt() { # builds from _ATT_W_* vars
  local body dest kind st sid
  kind="$_ATT_W_kind"; st="$_ATT_W_subject_type"; sid="$_ATT_W_subject_id"
  dest="$(_att_receipt_path "$kind" "$st" "$sid")" || return 1
  body="schema: ${_ATT_SCHEMA}
kind: ${kind}
subject_type: ${st}
subject_id: ${sid}
subject_fingerprint: ${_ATT_W_subject_fingerprint}
verdict: ${_ATT_W_verdict}
actor: ${_ATT_W_actor}
engine: ${_ATT_W_engine}
evidence_ref: ${_ATT_W_evidence_ref}
timestamp: ${_ATT_W_timestamp}
override_ref: ${_ATT_W_override_ref}
owner_ref: ${_ATT_W_owner_ref}
owner_fingerprint: ${_ATT_W_owner_fingerprint}
"
  if [ "$kind" = "semantic_gate" ] && [ "$st" = "stage" ]; then
    body="${body}subject_revision: ${_ATT_W_subject_revision}
"
  fi
  if [ "$kind" = "semantic_gate" ] && [ "$st" = "card" ]; then
    body="${body}subject_base: ${_ATT_W_subject_base}
subject_revision: ${_ATT_W_subject_revision}
subject_tree: ${_ATT_W_subject_tree}
"
  fi
  if [ "$kind" = "live_verify" ]; then
    body="${body}subject_revision: ${_ATT_W_subject_revision}
command_fingerprint: ${_ATT_W_command_fingerprint}
result_code: ${_ATT_W_result_code}
result_fingerprint: ${_ATT_W_result_fingerprint}
duration_ms: ${_ATT_W_duration_ms}
target_id: ${_ATT_W_target_id}
revision_oracle_ref: ${_ATT_W_revision_oracle_ref}
revision_oracle_fingerprint: ${_ATT_W_revision_oracle_fingerprint}
"
  fi
  _att_atomic_write "$dest" "$body"
}

# ---------- process supervisor ----------
_att_supervisor_capable() {
  if [ "${FLOW_ATTEST_SUPERVISOR:-}" = "force-unsupported" ]; then return 1; fi
  if [ "${FLOW_ATTEST_SUPERVISOR:-}" = "force-ok" ]; then return 0; fi
  command -v setsid >/dev/null 2>&1 || return 1
  if [ "${_ATT_SUP_CAP_CACHED:-}" = "1" ]; then
    [ "${_ATT_SUP_CAP_OK:-0}" = "1" ]; return $?
  fi
  _ATT_SUP_CAP_CACHED=1; _ATT_SUP_CAP_OK=0
  local outf pid pgid
  outf="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/.att-cap.$$")"
  : > "$outf"
  ( cd "${ROOT:-/tmp}" || exit 127; exec setsid sleep 30 ) >"$outf" 2>&1 &
  pid=$!
  sleep 0.15 2>/dev/null || true
  pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  [ -n "$pgid" ] || pgid="$pid"
  kill -TERM -"$pgid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  sleep 0.25 2>/dev/null || true
  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL -"$pgid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
    sleep 0.1 2>/dev/null || true
  fi
  wait "$pid" 2>/dev/null || true
  rm -f "$outf" 2>/dev/null || true
  kill -0 "$pid" 2>/dev/null && return 1
  _ATT_SUP_CAP_OK=1
  return 0
}
_att_run_supervised() {
  local timeout_s="${FLOW_ATTEST_TIMEOUT_S:-30}" cap="${FLOW_ATTEST_OUT_CAP:-65536}"
  local comb="${FLOW_ATTEST_COMBINED_CAP:-98304}" grace_s="${FLOW_ATTEST_GRACE_S:-2}"
  local outf errf start end rc=0 pid="" pgid="" i
  _ATT_RUN_RC="spawn-error"; _ATT_RUN_CODE=127; _ATT_RUN_OUT=""; _ATT_RUN_MS=0
  if ! _att_supervisor_capable; then _ATT_RUN_RC="spawn-error"; return 1; fi
  case "$timeout_s" in ''|*[!0-9]*|0) timeout_s=30 ;; esac
  case "$cap" in ''|*[!0-9]*|0) cap=65536 ;; esac
  case "$comb" in ''|*[!0-9]*|0) comb=98304 ;; esac
  case "$grace_s" in ''|*[!0-9]*) grace_s=2 ;; esac
  outf="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/.att-out.$$")"
  errf="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/.att-err.$$")"
  : > "$outf"; : > "$errf"
  start="$(_att_now_s)"
  ( cd "$ROOT" || exit 127; exec setsid "$@" ) >"$outf" 2>"$errf" &
  pid=$!
  i=0
  while [ "$i" -lt 20 ]; do
    if kill -0 "$pid" 2>/dev/null; then
      pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
      [ -n "$pgid" ] && break
    fi
    i=$((i+1)); sleep 0.05 2>/dev/null || true
  done
  [ -n "$pgid" ] || pgid="$pid"
  ( sleep "$timeout_s" 2>/dev/null
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM -"$pgid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
      sleep "$grace_s" 2>/dev/null
      kill -KILL -"$pgid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
      echo timeout > "${outf}.to"
    fi ) &
  local wd=$!
  ( while kill -0 "$pid" 2>/dev/null; do
      local os es
      os="$(wc -c < "$outf" 2>/dev/null | tr -d ' ')"
      es="$(wc -c < "$errf" 2>/dev/null | tr -d ' ')"
      if [ "${os:-0}" -gt "$cap" ] || [ "${es:-0}" -gt "$cap" ] || [ $(( ${os:-0} + ${es:-0} )) -gt "$comb" ]; then
        kill -TERM -"$pgid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
        sleep 1
        kill -KILL -"$pgid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
        echo cap > "${outf}.cap"; break
      fi
      sleep 0.1 2>/dev/null || sleep 1
    done ) &
  local capw=$!
  wait "$pid" 2>/dev/null; rc=$?
  kill "$wd" 2>/dev/null; wait "$wd" 2>/dev/null
  kill "$capw" 2>/dev/null; wait "$capw" 2>/dev/null
  kill -KILL -"$pgid" 2>/dev/null || true
  end="$(_att_now_s)"
  _ATT_RUN_MS=$(( (end - start) * 1000 )); [ "$_ATT_RUN_MS" -lt 0 ] && _ATT_RUN_MS=0
  if [ -f "${outf}.cap" ]; then _ATT_RUN_RC="output-cap"; _ATT_RUN_CODE=1; rm -f "${outf}.cap"
  elif [ -f "${outf}.to" ]; then _ATT_RUN_RC="timeout"; _ATT_RUN_CODE=124; rm -f "${outf}.to"
  elif [ "$rc" -eq 137 ] || [ "$rc" -eq 143 ]; then
    if [ $((end - start)) -ge "$timeout_s" ]; then _ATT_RUN_RC="timeout"; _ATT_RUN_CODE=124
    else _ATT_RUN_RC="signal"; _ATT_RUN_CODE="$rc"; fi
  elif [ "$rc" -eq 127 ]; then _ATT_RUN_RC="spawn-error"; _ATT_RUN_CODE=127
  else _ATT_RUN_RC="exit"; _ATT_RUN_CODE="$rc"; fi
  _ATT_RUN_OUT="$(head -c "$cap" "$outf" 2>/dev/null | tr -d '\000')"
  rm -f "$outf" "$errf" 2>/dev/null || true
  return 0
}

_att_result_code_str() {
  case "$_ATT_RUN_RC" in
    exit) printf 'exit:%s' "$_ATT_RUN_CODE" ;;
    timeout) printf 'timeout' ;;
    output-cap) printf 'output-cap' ;;
    signal) printf 'signal:%s' "$_ATT_RUN_CODE" ;;
    *) printf 'spawn-error' ;;
  esac
}

_att_hash_text() {
  local fmt oid
  fmt="$(_att_object_format)"
  oid="$(printf '%s' "$1" | git -C "$ROOT" hash-object --stdin 2>/dev/null | tr -d '\r\n')"
  printf 'git-%s:%s' "$fmt" "${oid:-0}"
}

# ---------- receipt currentness ----------
_att_receipt_status() { # $1 path -> current|missing|stale|invalid|red|blocked-attempt
  local path="$1"
  if [ ! -f "$path" ]; then echo "missing"; return 1; fi
  if ! _att_receipt_parse "$path"; then echo "invalid"; return 1; fi
  if [ "$_ATT_R_verdict" = "fail" ]; then echo "red"; return 1; fi
  # attempt marker for live
  if [ "$_ATT_R_kind" = "live_verify" ]; then
    local ap; ap="$(_att_attempt_path "$_ATT_R_subject_id")"
    if [ -f "$ap" ]; then echo "blocked-attempt"; return 1; fi
  fi
  # recompute subject fingerprint loosely
  case "$_ATT_R_kind:$_ATT_R_subject_type" in
    semantic_gate:stage)
      local cur
      if ! cur="$(_att_stage_fingerprint "$_ATT_R_subject_id" "${_ATT_R_subject_revision:-HEAD}")"; then
        echo "stale"; return 1
      fi
      # compare to current HEAD blob too
      local headfp
      headfp="$(_att_stage_fingerprint "$_ATT_R_subject_id" HEAD 2>/dev/null || true)"
      if [ "$_ATT_R_subject_fingerprint" != "$cur" ] && [ "$_ATT_R_subject_fingerprint" != "$headfp" ]; then
        echo "stale"; return 1
      fi
      # if HEAD blob differs from recorded revision blob, stale unless same
      if [ -n "$headfp" ] && [ "$headfp" != "$_ATT_R_subject_fingerprint" ]; then
        echo "stale"; return 1
      fi
      if ! _att_require_clean_for_consume; then echo "stale"; return 1; fi
      ;;
    semantic_gate:card)
      local file; file="$(resolve_card_file "$_ATT_R_subject_id")"
      [ -f "$file" ] || { echo "stale"; return 1; }
      local head; head="$(_att_full_commit HEAD)"
      [ -n "$head" ] && [ -n "$_ATT_R_subject_revision" ] && [ -n "$_ATT_R_subject_base" ] || { echo "stale"; return 1; }
      # Same revision: recompute fingerprint against base..rev (must match receipt).
      if [ "$head" = "$_ATT_R_subject_revision" ]; then
        if ! _att_card_semantic_fingerprint "$file" "$_ATT_R_subject_base" "$_ATT_R_subject_revision" >/dev/null; then
          echo "stale"; return 1
        fi
        [ "$_ATT_R_subject_fingerprint" = "$_ATT_LAST_FP" ] || { echo "stale"; return 1; }
      else
        # Ancestry-preserving integration path: always revalidate projection + path survival.
        if ! _att_is_ancestor "$_ATT_R_subject_revision" "$head"; then
          echo "stale"; return 1
        fi
        local proj_now proj_old tmpc
        proj_now="$(_att_card_contract_projection "$file")"
        tmpc="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/.att-card.$$")"
        if ! git -C "$ROOT" show "${_ATT_R_subject_revision}:cards/${_ATT_R_subject_id}.md" >"$tmpc" 2>/dev/null; then
          rm -f "$tmpc"; echo "stale"; return 1
        fi
        proj_old="$(_att_card_contract_projection "$tmpc")"
        rm -f "$tmpc"
        [ "$proj_now" = "$proj_old" ] || { echo "stale"; return 1; }
        if ! _att_card_paths_survive "$_ATT_R_subject_base" "$_ATT_R_subject_revision" "$head" "$_ATT_R_subject_id"; then
          echo "stale"; return 1
        fi
      fi
      if ! _att_require_clean_for_consume; then echo "stale"; return 1; fi
      ;;
    live_verify:card)
      [ "$_ATT_R_verdict" = "pass" ] || { echo "red"; return 1; }
      local head file proj cur_fp ofp_now owner_rel
      head="$(_att_full_commit HEAD)"
      file="$(resolve_card_file "$_ATT_R_subject_id")"
      [ -f "$file" ] || { echo "stale"; return 1; }
      [ -n "$_ATT_R_subject_revision" ] || { echo "stale"; return 1; }
      [ "$_ATT_R_subject_revision" = "$head" ] || { echo "stale"; return 1; }
      case "${_ATT_R_owner_ref:-}" in repo:*) owner_rel="${_ATT_R_owner_ref#repo:}" ;; *) echo "stale"; return 1 ;; esac
      if ! _att_load_owner_at_rev "$head" "$owner_rel"; then echo "stale"; return 1; fi
      ofp_now="$(_att_owner_fingerprint "$owner_rel" "$head")" || { echo "stale"; return 1; }
      [ "$ofp_now" = "${_ATT_R_owner_fingerprint}" ] || { echo "stale"; return 1; }
      proj="$(awk '/^## Verify/{p=1} /^## Done-evidence/{p=1} /^## Evidence/{p=0} /^## /{if($0!~/^## (Verify|Done-evidence)/)p=0} p{print}' "$file" | tr -d '\r')"
      cur_fp="$(_att_hash_text "live|${head}|${_ATT_R_target_id}|${ofp_now}|${proj}")"
      [ "$cur_fp" = "$_ATT_R_subject_fingerprint" ] || { echo "stale"; return 1; }
      if ! _att_require_clean_for_consume; then echo "stale"; return 1; fi
      ;;
  esac
  case "$_ATT_R_verdict" in
    pass|override) echo "current"; return 0 ;;
    fail) echo "red"; return 1 ;;
  esac
  echo "invalid"; return 1
}

_att_card_paths_survive() { # base rev head cardid
  local base="$1" rev="$2" head="$3" id="$4" p mode_rev mode_head oid_rev oid_head
  # name-only: each line is the path (not name-status $2)
  while IFS= read -r p; do
    p="$(printf '%s' "$p" | tr -d '\r')"
    [ -z "$p" ] && continue
    case "$p" in "cards/${id}.md") continue ;; esac
    mode_rev="$(git -C "$ROOT" ls-tree "$rev" -- "$p" 2>/dev/null | awk '{print $1}')"
    oid_rev="$(git -C "$ROOT" ls-tree "$rev" -- "$p" 2>/dev/null | awk '{print $3}')"
    mode_head="$(git -C "$ROOT" ls-tree "$head" -- "$p" 2>/dev/null | awk '{print $1}')"
    oid_head="$(git -C "$ROOT" ls-tree "$head" -- "$p" 2>/dev/null | awk '{print $3}')"
    [ -n "$mode_rev" ] && [ -n "$oid_rev" ] || return 1
    [ "$mode_rev" = "$mode_head" ] && [ "$oid_rev" = "$oid_head" ] || return 1
  done <<EOF
$(git -C "$ROOT" diff-tree -r --name-only "$base" "$rev" 2>/dev/null)
EOF
  return 0
}

_att_accepted_semantic() { # subject_type subject_id — exit 0 if current pass|override
  local st="$1" sid="$2" path
  path="$(_att_receipt_path semantic_gate "$st" "$sid")"
  # Do not use command substitution: _att_receipt_status sets _ATT_R_* in this shell.
  if ! _att_receipt_status "$path" >/dev/null 2>&1; then return 1; fi
  case "${_ATT_R_verdict:-}" in pass|override) return 0 ;; *) return 1 ;; esac
}

_att_accepted_live() { # card id
  local path
  path="$(_att_receipt_path live_verify card "$1")"
  if [ -f "$(_att_attempt_path "$1")" ]; then return 1; fi
  if ! _att_receipt_status "$path" >/dev/null 2>&1; then return 1; fi
  [ "${_ATT_R_verdict:-}" = "pass" ]
}

# ---------- auto state ----------
_att_auto_state_read() { # sets _ATT_A_*; echoes INACTIVE|ACTIVE|STALE|INVALID
  local p; p="$(_att_auto_state_path)"
  _ATT_A_schema=""; _ATT_A_status=""; _ATT_A_activated_at=""; _ATT_A_activated_by=""
  _ATT_A_integration_branch=""; _ATT_A_risk_fingerprint=""; _ATT_A_contract_fingerprint=""
  if [ ! -f "$p" ]; then echo "INACTIVE"; return 0; fi
  if ! _att_parse_auto_file "$p"; then echo "INVALID"; return 0; fi
  # revalidate
  if ! _att_auto_current_ok; then echo "STALE"; return 0; fi
  echo "ACTIVE"; return 0
}

_att_parse_auto_file() {
  local f="$1" line k v seen=""
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(printf '%s' "$line" | tr -d '\r')"
    [ -z "$line" ] && continue
    case "$line" in
      *": "*) k="${line%%: *}"; v="${line#*: }" ;;
      *) return 1 ;;
    esac
    case "$k" in
      schema|status|activated_at|activated_by|integration_branch|risk_fingerprint|contract_fingerprint) : ;;
      *) return 1 ;;
    esac
    case " $seen " in *" $k "*) return 1 ;; esac
    seen="$seen $k"
    case "$k" in
      schema) _ATT_A_schema="$v" ;;
      status) _ATT_A_status="$v" ;;
      activated_at) _ATT_A_activated_at="$v" ;;
      activated_by) _ATT_A_activated_by="$v" ;;
      integration_branch) _ATT_A_integration_branch="$v" ;;
      risk_fingerprint) _ATT_A_risk_fingerprint="$v" ;;
      contract_fingerprint) _ATT_A_contract_fingerprint="$v" ;;
    esac
  done < "$f"
  [ "$_ATT_A_schema" = "$_ATT_AUTO_SCHEMA" ] || return 1
  [ "$_ATT_A_status" = "active" ] || return 1
  return 0
}

_att_auto_current_ok() {
  _att_git_ok || return 1
  local br head rfp cfp f rv
  br="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\r')"
  [ "$br" = "$_ATT_A_integration_branch" ] || return 1
  [ "$br" != "HEAD" ] || return 1
  # risk set revalidation
  for f in $(_att_all_card_files); do
    rv="$(_card_risk_validate "$f" auto 2>/dev/null || echo bad)"
    case "$rv" in standard|security-class) : ;; *) return 1 ;; esac
  done
  rfp="$(_att_risk_fingerprint)"
  [ "$rfp" = "$_ATT_A_risk_fingerprint" ] || return 1
  # stage 05 receipt
  _att_accepted_semantic stage 05-contract || return 1
  cfp="$_ATT_R_subject_fingerprint"
  [ "$cfp" = "$_ATT_A_contract_fingerprint" ] || return 1
  return 0
}

_att_auto_write() {
  local path body
  path="$(_att_auto_state_path)"
  mkdir -p "$(dirname "$path")" 2>/dev/null || true
  body="schema: ${_ATT_AUTO_SCHEMA}
status: active
activated_at: ${_ATT_W_activated_at}
activated_by: ${_ATT_W_activated_by}
integration_branch: ${_ATT_W_integration_branch}
risk_fingerprint: ${_ATT_W_risk_fingerprint}
contract_fingerprint: ${_ATT_W_contract_fingerprint}
"
  _att_atomic_write "$path" "$body"
}

_att_auto_clear() {
  rm -f "$(_att_auto_state_path)" 2>/dev/null || true
}

_att_auto_is_enforcing() {
  # File existence is the policy latch; STALE/INVALID still hard-enforce (plan matrix).
  local p; p="$(_att_auto_state_path)"
  [ -f "$p" ]
}

_att_is_main_worktree() {
  _att_git_ok || return 1
  local git_dir common_dir
  git_dir="$(git -C "$ROOT" rev-parse --absolute-git-dir 2>/dev/null || true)"
  common_dir="$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null || true)"
  case "$common_dir" in /*) : ;; "") return 1 ;; *)
    common_dir="$(cd "$ROOT" && cd "$common_dir" 2>/dev/null && pwd)"
  ;; esac
  [ -n "$git_dir" ] && [ -n "$common_dir" ] || return 1
  # linked when git_dir != common_dir
  [ "$(cd "$(dirname "$git_dir")" 2>/dev/null && pwd -P)/$(basename "$git_dir")" = \
    "$(cd "$(dirname "$common_dir")" 2>/dev/null && pwd -P)/$(basename "$common_dir")" ] 2>/dev/null \
    || {
      # compare realpaths
      local a b
      a="$(cd "$git_dir" 2>/dev/null && pwd -P || echo "$git_dir")"
      b="$(cd "$common_dir" 2>/dev/null && pwd -P || echo "$common_dir")"
      [ "$a" = "$b" ]
    }
}

_att_main_worktree_path() {
  git -C "$ROOT" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10); exit}'
}

# ---------- mint commands ----------
_att_default_actor() {
  local a
  a="$(_att_sanitize_label "${FLOW_SESSION_ID:-flow}")"
  [ -n "$a" ] || a="flow"
  printf '%s' "$a"
}

_att_default_engine() {
  local e
  e="$(_att_sanitize_label "${FLOW_ENGINE_TIER:-builtin}")"
  [ -n "$e" ] || e="builtin"
  printf '%s' "$e"
}

_att_mint_semantic_stage() {
  local stage="$1" rev="$2" owner_rel="$3"
  local full owner_abs fp ofp out_doc verdict crit high eref
  _att_is_stage "$stage" || { echo "FAIL: invalid stage '$stage'"; return 2; }
  _att_git_ok || { echo "FAIL: attest requires a Git repository"; return 2; }
  full="$(_att_full_commit "$rev")" || { echo "FAIL: bad revision"; return 2; }
  _att_git_clean_for_attest || { echo "FAIL: dirty worktree (only .flow/, locks, status/Evidence allowed)"; return 1; }
  if ! _att_load_owner_at_rev "$full" "$owner_rel"; then
    echo "FAIL: owner/command must be committed regular files matching disk at revision (blob equality)"
    return 1
  fi
  [ "$_ATT_KV_kind" = "semantic_gate" ] || { echo "FAIL: owner kind must be semantic_gate"; return 2; }
  [ "$_ATT_KV_subject_id" = "$stage" ] || { echo "FAIL: owner subject_id mismatch"; return 2; }
  [ "$_ATT_KV_target_id" = "none" ] && [ "$_ATT_KV_revision_oracle" = "none" ] || { echo "FAIL: semantic owner must have target/oracle none"; return 2; }
  local cmd_rel="${_ATT_KV_command#repo:}"
  if ! _att_stage_fingerprint "$stage" "$full" >/dev/null; then echo "FAIL: stage fingerprint"; return 1; fi
  fp="$_ATT_LAST_FP"
  ofp="$(_att_owner_fingerprint "$owner_rel" "$full")" || { echo "FAIL: owner fingerprint"; return 1; }

  local lname execf; lname="$(_att_subject_lock_name semantic_gate "$stage")"
  _att_lock_acquire "$lname" || return 1
  execf="$(_att_materialize_blob_exec "$full" "$cmd_rel")" || {
    _att_lock_release "$lname"; echo "FAIL: could not materialize committed producer"; return 1
  }
  _att_run_supervised "$execf" --subject-id "$stage" --subject-revision "$full" --subject-fingerprint "$fp"
  rm -f "$execf" 2>/dev/null || true
  if [ "$_ATT_RUN_RC" != "exit" ] || [ "$_ATT_RUN_CODE" -ne 0 ]; then
    _ATT_W_kind=semantic_gate; _ATT_W_subject_type=stage; _ATT_W_subject_id="$stage"
    _ATT_W_subject_fingerprint="$fp"; _ATT_W_verdict=fail
    _ATT_W_actor="$(_att_default_actor)"; _ATT_W_engine="$(_att_default_engine)"
    _ATT_W_evidence_ref=none; _ATT_W_timestamp="$(_att_now_rfc3339)"; _ATT_W_override_ref=none
    _ATT_W_owner_ref="repo:${owner_rel}"; _ATT_W_owner_fingerprint="$ofp"
    _ATT_W_subject_revision="$full"
    _att_write_receipt || true
    _att_lock_release "$lname"
    echo "FAIL: semantic producer non-zero (${_ATT_RUN_RC}:${_ATT_RUN_CODE})"
    return 1
  fi
  # parse semantic result
  out_doc="$_ATT_RUN_OUT"
  verdict="$(printf '%s\n' "$out_doc" | awk -F': ' '/^verdict: /{print $2; exit}' | tr -d '\r')"
  local sfp
  sfp="$(printf '%s\n' "$out_doc" | awk -F': ' '/^subject_fingerprint: /{print $2; exit}' | tr -d '\r')"
  crit="$(printf '%s\n' "$out_doc" | awk -F': ' '/^critical_count: /{print $2; exit}' | tr -d '\r')"
  high="$(printf '%s\n' "$out_doc" | awk -F': ' '/^high_count: /{print $2; exit}' | tr -d '\r')"
  eref="$(printf '%s\n' "$out_doc" | awk -F': ' '/^evidence_ref: /{print $2; exit}' | tr -d '\r')"
  local sch
  sch="$(printf '%s\n' "$out_doc" | awk -F': ' '/^schema: /{print $2; exit}' | tr -d '\r')"
  if [ "$sch" != "$_ATT_SEM_RESULT_SCHEMA" ] || [ "$sfp" != "$fp" ]; then
    _att_lock_release "$lname"
    echo "FAIL: producer result schema/fingerprint mismatch"; return 1
  fi
  case "$verdict" in pass|fail) : ;; *) _att_lock_release "$lname"; echo "FAIL: bad producer verdict"; return 1 ;; esac
  if [ "$verdict" = "pass" ]; then
    [ "$crit" = "0" ] && [ "$high" = "0" ] || verdict=fail
  fi
  [ -n "$eref" ] || eref=none
  _att_valid_repo_ref "$eref" || eref=none
  _ATT_W_kind=semantic_gate; _ATT_W_subject_type=stage; _ATT_W_subject_id="$stage"
  _ATT_W_subject_fingerprint="$fp"; _ATT_W_verdict="$verdict"
  _ATT_W_actor="$(_att_default_actor)"; _ATT_W_engine="$(_att_default_engine)"
  _ATT_W_evidence_ref="$eref"; _ATT_W_timestamp="$(_att_now_rfc3339)"; _ATT_W_override_ref=none
  _ATT_W_owner_ref="repo:${owner_rel}"; _ATT_W_owner_fingerprint="$ofp"
  _ATT_W_subject_revision="$full"
  if ! _att_write_receipt; then _att_lock_release "$lname"; echo "FAIL: write receipt"; return 1; fi
  _att_lock_release "$lname"
  echo "PASS: semantic_gate stage $stage verdict=$verdict fp=$fp"
  [ "$verdict" = "pass" ] || [ "$verdict" = "override" ]
}

_att_mint_semantic_card() {
  local id="$1" base="$2" rev="$3" owner_rel="$4"
  local file full_base full_head fp ofp
  id="$(_att_norm_card_id "$id")" || { echo "FAIL: bad card id"; return 2; }
  file="$(resolve_card_file "$id")"
  [ -f "$file" ] || { echo "FAIL: card not found"; return 2; }
  _att_git_ok || { echo "FAIL: attest requires Git"; return 2; }
  _att_git_clean_for_attest || { echo "FAIL: dirty worktree"; return 1; }
  full_base="$(_att_full_commit "$base")" || { echo "FAIL: bad base"; return 2; }
  full_head="$(_att_full_commit "$rev")" || { echo "FAIL: bad revision"; return 2; }
  if [ "$full_base" = "$full_head" ]; then
    echo "FAIL: card semantic requires non-empty base..revision (base must differ from --revision)"
    return 2
  fi
  if ! _att_load_owner_at_rev "$full_head" "$owner_rel"; then
    echo "FAIL: owner/command must be committed regular files matching disk at revision"
    return 1
  fi
  [ "$_ATT_KV_kind" = "semantic_gate" ] || { echo "FAIL: owner kind"; return 2; }
  [ "$_ATT_KV_subject_id" = "$id" ] || { echo "FAIL: subject_id mismatch"; return 2; }
  local cmd_rel="${_ATT_KV_command#repo:}"
  if ! _att_card_semantic_fingerprint "$file" "$full_base" "$full_head" >/dev/null; then echo "FAIL: fingerprint"; return 1; fi
  fp="$_ATT_LAST_FP"
  ofp="$(_att_owner_fingerprint "$owner_rel" "$full_head")" || { echo "FAIL: owner fp"; return 1; }
  local lname execf; lname="$(_att_subject_lock_name semantic_gate "$id")"
  _att_lock_acquire "$lname" || return 1
  execf="$(_att_materialize_blob_exec "$full_head" "$cmd_rel")" || {
    _att_lock_release "$lname"; echo "FAIL: could not materialize committed producer"; return 1
  }
  _att_run_supervised "$execf" --subject-id "$id" --subject-revision "$full_head" --subject-fingerprint "$fp"
  rm -f "$execf" 2>/dev/null || true
  local verdict=fail eref=none
  if [ "$_ATT_RUN_RC" = "exit" ] && [ "$_ATT_RUN_CODE" -eq 0 ]; then
    local sch sfp crit high
    sch="$(printf '%s\n' "$_ATT_RUN_OUT" | awk -F': ' '/^schema: /{print $2; exit}' | tr -d '\r')"
    sfp="$(printf '%s\n' "$_ATT_RUN_OUT" | awk -F': ' '/^subject_fingerprint: /{print $2; exit}' | tr -d '\r')"
    verdict="$(printf '%s\n' "$_ATT_RUN_OUT" | awk -F': ' '/^verdict: /{print $2; exit}' | tr -d '\r')"
    crit="$(printf '%s\n' "$_ATT_RUN_OUT" | awk -F': ' '/^critical_count: /{print $2; exit}' | tr -d '\r')"
    high="$(printf '%s\n' "$_ATT_RUN_OUT" | awk -F': ' '/^high_count: /{print $2; exit}' | tr -d '\r')"
    eref="$(printf '%s\n' "$_ATT_RUN_OUT" | awk -F': ' '/^evidence_ref: /{print $2; exit}' | tr -d '\r')"
    [ "$sch" = "$_ATT_SEM_RESULT_SCHEMA" ] && [ "$sfp" = "$fp" ] || verdict=fail
    case "$verdict" in pass|fail) : ;; *) verdict=fail ;; esac
    [ "$verdict" = "pass" ] && { [ "$crit" = "0" ] && [ "$high" = "0" ] || verdict=fail; }
    [ -n "$eref" ] || eref=none
  fi
  _ATT_W_kind=semantic_gate; _ATT_W_subject_type=card; _ATT_W_subject_id="$id"
  _ATT_W_subject_fingerprint="$fp"; _ATT_W_verdict="$verdict"
  _ATT_W_actor="$(_att_default_actor)"; _ATT_W_engine="$(_att_default_engine)"
  _ATT_W_evidence_ref="$eref"; _ATT_W_timestamp="$(_att_now_rfc3339)"; _ATT_W_override_ref=none
  _ATT_W_owner_ref="repo:${owner_rel}"; _ATT_W_owner_fingerprint="$ofp"
  _ATT_W_subject_base="$_ATT_SUBJ_BASE"; _ATT_W_subject_revision="$_ATT_SUBJ_REV"; _ATT_W_subject_tree="$_ATT_SUBJ_TREE"
  _att_write_receipt || { _att_lock_release "$lname"; return 1; }
  _att_lock_release "$lname"
  echo "PASS: semantic_gate card $id verdict=$verdict"
  [ "$verdict" = "pass" ]
}

_att_mint_live() {
  local id="$1" rev="$2" owner_rel="$3"
  local file full cmd_rel oracle_rel target ofp cfp lname ap
  id="$(_att_norm_card_id "$id")" || { echo "FAIL: bad card"; return 2; }
  file="$(resolve_card_file "$id")"; [ -f "$file" ] || { echo "FAIL: card missing"; return 2; }
  _att_git_ok || { echo "FAIL: git required"; return 2; }
  if ! _att_supervisor_capable; then echo "FAIL: process supervisor unsupported on this platform"; return 1; fi
  _att_git_clean_for_attest || { echo "FAIL: dirty worktree (live mint requires clean subject)"; return 1; }
  full="$(_att_full_commit "$rev")" || { echo "FAIL: bad revision"; return 2; }
  if ! _att_load_owner_at_rev "$full" "$owner_rel"; then
    echo "FAIL: owner/command/oracle must be committed regular files matching disk at revision"
    return 1
  fi
  [ "$_ATT_KV_kind" = "live_verify" ] || { echo "FAIL: owner kind must be live_verify"; return 2; }
  [ "$_ATT_KV_subject_id" = "$id" ] || { echo "FAIL: subject mismatch"; return 2; }
  target="$_ATT_KV_target_id"
  _att_valid_target_id "$target" && [ "$target" != "none" ] || { echo "FAIL: live needs target_id"; return 2; }
  case "$_ATT_KV_revision_oracle" in repo:*) : ;; *) echo "FAIL: live needs revision_oracle"; return 2 ;; esac
  cmd_rel="${_ATT_KV_command#repo:}"; oracle_rel="${_ATT_KV_revision_oracle#repo:}"
  ofp="$(_att_owner_fingerprint "$owner_rel" "$full")" || { echo "FAIL: owner fp"; return 1; }
  local o_blob o_mode o_fp cmd_blob cmd_mode
  o_blob="$(_att_blob_at_rev "$full" "$oracle_rel")"
  o_mode="$(_att_path_mode_at_rev "$full" "$oracle_rel")"
  o_fp="$(_att_hash_text "oracle:${oracle_rel}:${o_mode}:${o_blob}")"
  cmd_blob="$(_att_blob_at_rev "$full" "$cmd_rel")"
  cmd_mode="$(_att_path_mode_at_rev "$full" "$cmd_rel")"
  cfp="$(_att_hash_text "argv:${cmd_rel}:${cmd_mode}:${cmd_blob}|${id}|${full}|${target}")"
  local proj fp
  proj="$(awk '/^## Verify/{p=1} /^## Done-evidence/{p=1} /^## Evidence/{p=0} /^## /{if($0!~/^## (Verify|Done-evidence)/)p=0} p{print}' "$file" | tr -d '\r')"
  fp="$(_att_hash_text "live|${full}|${target}|${ofp}|${proj}")"
  lname="$(_att_subject_lock_name live_verify "$id")"
  _att_lock_acquire "$lname" || return 1
  ap="$(_att_attempt_path "$id")"
  mkdir -p "$(dirname "$ap")" 2>/dev/null || true
  printf 'pid=%s\nstart=%s\nhost=%s\n' "$$" "$(_att_now_s)" "$(uname -n 2>/dev/null || echo host)" > "$ap"
  local oracle_exec cmd_exec oracle_oid verdict=fail rcode
  oracle_exec="$(_att_materialize_blob_exec "$full" "$oracle_rel")" || {
    rm -f "$ap"; _att_lock_release "$lname"; echo "FAIL: materialize oracle"; return 1
  }
  _att_run_supervised "$oracle_exec" --subject-id "$id" --subject-revision "$full" --target-id "$target"
  rm -f "$oracle_exec" 2>/dev/null || true
  rcode="$(_att_result_code_str)"
  if [ "$_ATT_RUN_RC" = "exit" ] && [ "$_ATT_RUN_CODE" -eq 0 ]; then
    oracle_oid="$(printf '%s' "$_ATT_RUN_OUT" | tr -d '\r\n[:space:]')"
    if [ "$oracle_oid" = "$full" ]; then
      cmd_exec="$(_att_materialize_blob_exec "$full" "$cmd_rel")" || true
      if [ -n "${cmd_exec:-}" ]; then
        _att_run_supervised "$cmd_exec" --subject-id "$id" --subject-revision "$full" --subject-fingerprint "$fp"
        rm -f "$cmd_exec" 2>/dev/null || true
        rcode="$(_att_result_code_str)"
        if [ "$_ATT_RUN_RC" = "exit" ] && [ "$_ATT_RUN_CODE" -eq 0 ]; then
          verdict=pass
        fi
      else
        rcode="spawn-error"
      fi
    else
      rcode="exit:1"
    fi
  fi
  local rfp
  rfp="$(_att_hash_text "result|${rcode}|${_ATT_RUN_MS}|${cfp}")"
  _ATT_W_kind=live_verify; _ATT_W_subject_type=card; _ATT_W_subject_id="$id"
  _ATT_W_subject_fingerprint="$fp"; _ATT_W_verdict="$verdict"
  _ATT_W_actor="$(_att_default_actor)"; _ATT_W_engine="$(_att_default_engine)"
  _ATT_W_evidence_ref=none; _ATT_W_timestamp="$(_att_now_rfc3339)"; _ATT_W_override_ref=none
  _ATT_W_owner_ref="repo:${owner_rel}"; _ATT_W_owner_fingerprint="$ofp"
  _ATT_W_subject_revision="$full"
  _ATT_W_command_fingerprint="$cfp"; _ATT_W_result_code="$rcode"
  _ATT_W_result_fingerprint="$rfp"; _ATT_W_duration_ms="$_ATT_RUN_MS"
  _ATT_W_target_id="$target"
  _ATT_W_revision_oracle_ref="repo:${oracle_rel}"
  _ATT_W_revision_oracle_fingerprint="$o_fp"
  _att_write_receipt || true
  rm -f "$ap" 2>/dev/null || true
  _att_lock_release "$lname"
  echo "PASS: live_verify $id verdict=$verdict result=$rcode"
  [ "$verdict" = "pass" ]
}

_att_recover_live() {
  local id="$1"
  id="$(_att_norm_card_id "$id")" || return 2
  local ap lname
  ap="$(_att_attempt_path "$id")"
  lname="$(_att_subject_lock_name live_verify "$id")"
  _att_lock_acquire "$lname" || return 1
  # write fail receipt if none/attempt
  _ATT_W_kind=live_verify; _ATT_W_subject_type=card; _ATT_W_subject_id="$id"
  _ATT_W_subject_fingerprint="git-sha1:0"; _ATT_W_verdict=fail
  _ATT_W_actor="$(_att_default_actor)"; _ATT_W_engine="$(_att_default_engine)"
  _ATT_W_evidence_ref=none; _ATT_W_timestamp="$(_att_now_rfc3339)"; _ATT_W_override_ref=none
  _ATT_W_owner_ref=none; _ATT_W_owner_fingerprint="git-sha1:0"
  _ATT_W_subject_revision="$(_att_full_commit HEAD 2>/dev/null || echo 0)"
  _ATT_W_command_fingerprint="git-sha1:0"; _ATT_W_result_code=spawn-error
  _ATT_W_result_fingerprint="git-sha1:0"; _ATT_W_duration_ms=0
  _ATT_W_target_id=none
  _ATT_W_revision_oracle_ref=none; _ATT_W_revision_oracle_fingerprint="git-sha1:0"
  _att_write_receipt || true
  rm -f "$ap" 2>/dev/null || true
  _att_lock_release "$lname"
  echo "PASS: recovered live attempt for $id as fail"
  return 0
}

# ---------- enforcement helpers ----------
_att_warn_or_block() { # $1 message  $2 force_block(0/1)
  if [ "$2" = "1" ]; then
    echo "BLOCK: $1"
    return 1
  fi
  echo "WARNING: $1 (auto inactive — manual path still usable)"
  return 0
}

# Check card receipts for auto. $1 card id $2 require_live(0/1) $3 enforce(0/1)
_att_enforce_card() {
  local id="$1" need_live="$2" enforce="$3" st
  if [ "$enforce" != "1" ]; then
    if ! _att_accepted_semantic card "$id"; then
      _att_warn_or_block "card $id semantic receipt missing/stale/red" 0
    fi
    if [ "$need_live" = "1" ] && ! _att_accepted_live "$id"; then
      _att_warn_or_block "card $id live_verify receipt missing/stale/red" 0
    fi
    return 0
  fi
  # enforcing
  st="$(_att_auto_state_read)"
  if [ "$st" = "STALE" ] || [ "$st" = "INVALID" ]; then
    echo "BLOCK: auto state is $st — run '/flow auto' to refresh or '/flow auto stop'"
    return 1
  fi
  if [ -f "$(_att_attempt_path "$id")" ]; then
    echo "BLOCK: live attempt in progress for $id — wait or '/flow attest recover $id --mark-failed'"
    return 1
  fi
  if ! _att_accepted_semantic card "$id"; then
    echo "BLOCK: card $id needs current semantic_gate receipt (pass/override)"
    return 1
  fi
  if [ "$need_live" = "1" ] && ! _att_accepted_live "$id"; then
    echo "BLOCK: card $id needs current live_verify pass receipt"
    return 1
  fi
  return 0
}

# ---------- cmd_attest ----------
cmd_attest() {
  local sub="${1:-}"; shift 2>/dev/null || true
  case "$sub" in
    semantic)
      local stage="" card="" base="" rev="" owner=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --stage) shift; stage="${1:-}" ;;
          --card) shift; card="${1:-}" ;;
          --base) shift; base="${1:-}" ;;
          --revision) shift; rev="${1:-}" ;;
          --owner) shift; owner="${1:-}" ;;
          *) echo "usage: flow attest semantic --stage S --revision R --owner PATH | --card C --base B --revision R --owner PATH"; return 2 ;;
        esac
        shift 2>/dev/null || true
      done
      [ -n "$owner" ] && [ -n "$rev" ] || { echo "usage: flow attest semantic ... --revision R --owner PATH"; return 2; }
      # strip repo: prefix if given
      case "$owner" in repo:*) owner="${owner#repo:}" ;; esac
      if [ -n "$stage" ] && [ -z "$card" ]; then
        _att_mint_semantic_stage "$stage" "$rev" "$owner"; return $?
      elif [ -n "$card" ] && [ -z "$stage" ]; then
        [ -n "$base" ] || { echo "FAIL: --base required for card semantic"; return 2; }
        _att_mint_semantic_card "$card" "$base" "$rev" "$owner"; return $?
      else
        echo "FAIL: specify exactly one of --stage or --card"; return 2
      fi
      ;;
    live-verify)
      local id="${1:-}"; shift 2>/dev/null || true
      local rev="" owner=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --revision) shift; rev="${1:-}" ;;
          --owner) shift; owner="${1:-}" ;;
          *) echo "usage: flow attest live-verify C-NNN --revision R --owner PATH"; return 2 ;;
        esac
        shift 2>/dev/null || true
      done
      [ -n "$id" ] && [ -n "$rev" ] && [ -n "$owner" ] || { echo "usage: flow attest live-verify C-NNN --revision R --owner PATH"; return 2; }
      case "$owner" in repo:*) owner="${owner#repo:}" ;; esac
      _att_mint_live "$id" "$rev" "$owner"; return $?
      ;;
    status)
      local target="${1:-}"
      local st
      st="$(_att_auto_state_read)"
      echo "auto: $st"
      if [ -n "${_ATT_A_activated_at:-}" ]; then
        echo "  activated_at: ${_ATT_A_activated_at}"
        echo "  branch: ${_ATT_A_integration_branch}"
      fi
      if [ -n "$target" ]; then
        local sid path kind
        if _att_is_stage "$target"; then
          path="$(_att_receipt_path semantic_gate stage "$target")"
          echo "semantic_gate stage $target: $(_att_receipt_status "$path" 2>/dev/null || echo missing)"
        else
          sid="$(_att_norm_card_id "$target" 2>/dev/null || echo "$target")"
          path="$(_att_receipt_path semantic_gate card "$sid")"
          echo "semantic_gate card $sid: $(_att_receipt_status "$path" 2>/dev/null || echo missing)"
          path="$(_att_receipt_path live_verify card "$sid")"
          echo "live_verify card $sid: $(_att_receipt_status "$path" 2>/dev/null || echo missing)"
        fi
      else
        echo "receipts dir: $(_att_dir)"
        ls -la "$(_att_dir)" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
      fi
      return 0
      ;;
    recover)
      local id="${1:-}"; shift 2>/dev/null || true
      [ "${1:-}" = "--mark-failed" ] || { echo "usage: flow attest recover C-NNN --mark-failed"; return 2; }
      _att_recover_live "$id"; return $?
      ;;
    *)
      echo "usage: flow attest semantic|live-verify|status|recover ..."
      return 2
      ;;
  esac
}

# Risk preflight for auto — print all blockers; return 0 if clear
_att_risk_preflight() {
  local f id rv any=0
  local n=0
  for f in $(_att_all_card_files); do
    n=$((n + 1))
    id="$(basename "$f" .md)"
    rv="$(_card_risk_validate "$f" auto 2>/dev/null || echo "invalid:parse")"
    case "$rv" in
      standard)
        echo "READY $id risk=standard: $(_att_field_once "$f" risk-reason | cut -c1-80)"
        ;;
      security-class)
        echo "READY $id risk=security-class: ack ok"
        ;;
      unknown)
        echo "BLOCK $id risk=unknown: classify risk + reason"
        any=1
        ;;
      halt:*)
        echo "HALT  $id risk=security-class: ${rv#halt:}"
        any=1
        ;;
      invalid:*)
        echo "BLOCK $id ${rv}"
        any=1
        ;;
      *)
        echo "BLOCK $id risk=$rv"
        any=1
        ;;
    esac
  done
  [ "$n" -gt 0 ] || { echo "FAIL: no cards"; return 1; }
  [ "$any" -eq 0 ]
}
