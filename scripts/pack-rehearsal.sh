#!/usr/bin/env bash
# pack-rehearsal.sh — credentialless pack → tarball parity → install → e2e.
# Local and CI share this file. From repo root (or anywhere):
#   bash scripts/pack-rehearsal.sh
# Requires Node >=22.14 (same floor as npm-wrapper engines). Ubuntu is the CI lane.
# There is no $INSTALLED variable. Zero-arg e2e invoke is a job bug.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAP="$ROOT/npm-wrapper"
WORKDIR=""
PREFIX=""
DEST=""
PACKED=""

cleanup() {
  [ -n "$WORKDIR" ] && rm -rf "$WORKDIR"
  [ -n "$PREFIX" ] && rm -rf "$PREFIX"
  [ -n "$DEST" ] && rm -rf "$DEST"
  [ -n "$PACKED" ] && rm -f "$PACKED"
}
trap cleanup EXIT

if [ -n "${GITHUB_ACTIONS:-}" ] && [ -n "${NPM_TOKEN:-}" ]; then
  echo "FAIL: NPM_TOKEN is set; pack-rehearsal is credentialless" >&2
  exit 1
fi

node -e 'const [M,m]=process.versions.node.split(".").map(Number);if(M<22||(M===22&&m<14)){console.error("FAIL: need Node >=22.14, got "+process.versions.node);process.exit(1)}'

WORKDIR="$(mktemp -d)"
PREFIX="$(mktemp -d)"
DEST="$(mktemp -d)"
export HOME="$WORKDIR/home"
mkdir -p "$HOME"

echo "=== pack-rehearsal ==="
echo "ROOT=$ROOT"
echo "DEST=$DEST"

# Pack from npm-wrapper so prepack runs sync.mjs; tarball lands there.
cd "$WRAP"
# Redirect stdout only — notices stay on stderr. Avoid `npm pack | tail` so a
# failed pack cannot hide behind tail's exit 0 (set -e without pipefail).
npm pack > "$WORKDIR/pack.out"
PACKED_NAME="$(tail -1 "$WORKDIR/pack.out")"
PACKED="$WRAP/$PACKED_NAME"
case "$PACKED_NAME" in
  manhquy-flow-skill-*.tgz) ;;
  *) echo "FAIL: npm pack did not print manhquy-flow-skill-*.tgz (got: $PACKED_NAME)" >&2; exit 1 ;;
esac
[ -f "$PACKED" ] || { echo "FAIL: tarball missing: $PACKED" >&2; exit 1; }
echo "packed $PACKED_NAME"

mkdir -p "$WORKDIR/extract"
tar -xzf "$PACKED" -C "$WORKDIR/extract"
EXTRACTED="$WORKDIR/extract/package/skills/flow"
[ -d "$EXTRACTED" ] || { echo "FAIL: tarball missing package/skills/flow" >&2; exit 1; }

# Shared JS predicate — argv branch before copy. Not an unfiltered diff -r.
node "$WRAP/scripts/sync.mjs" --compare "$EXTRACTED" "$ROOT/skills/flow"

# Local tarball only. --ignore-scripts: do not re-run prepack on the installed copy.
npm i --no-audit --no-fund --ignore-scripts --prefix "$PREFIX" "$PACKED"
BIN="$PREFIX/node_modules/.bin/flow-skill"
[ -f "$BIN" ] || { echo "FAIL: installer bin missing at $BIN" >&2; exit 1; }

# Dry-run JSONL, then the real project-scope install (writes $DEST/.claude/skills/flow only).
"$BIN" --yes --project --dir "$DEST" --dry-run --json
"$BIN" --yes --project --dir "$DEST"

# Pin one path, azure-shaped. No $INSTALLED. Do not use repo install.sh.
RUN="$DEST/.claude/skills/flow/runner/flow.sh"
[ -f "$RUN" ] || { echo "FAIL: installed runner not found at $RUN" >&2; exit 1; }

DEST_ABS="$(cd "$DEST" && pwd)"
RUN_DIR="$(cd "$(dirname "$RUN")" && pwd)"
case "$RUN_DIR" in
  "$DEST_ABS"/*) ;;
  *) echo "FAIL: driven runner $RUN_DIR is not under DEST $DEST_ABS" >&2; exit 1 ;;
esac
CHECKOUT_DIR="$(cd "$ROOT/skills/flow/runner" && pwd)"
if [ "$RUN_DIR" = "$CHECKOUT_DIR" ]; then
  echo "FAIL: driven runner is the checkout $CHECKOUT_DIR" >&2
  exit 1
fi

# Zero-arg invoke is a job bug — always pass the installed runner as $1.
bash "$ROOT/tests/e2e-installed-drive.sh" "$RUN"

echo "pack-rehearsal OK (runner=$RUN)"
