#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node --test "$ROOT/tests/test_verify_attestation_with_gh.mjs"
