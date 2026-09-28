#!/usr/bin/env bash
# Tests de integración de AlbumRaterData contra el Supabase local. Requiere `supabase start`.
# La cobertura de esta capa se informa, pero no bloquea: la barrera del 95% es para Core.
set -euo pipefail

SCRATCH_PATH="${SWIFT_SCRATCH_PATH:-.build}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/local-supabase-env.sh"
cd "$ROOT/Packages/AlbumRaterKit"

swift test --scratch-path "$SCRATCH_PATH" --enable-code-coverage --filter AlbumRaterDataTests
python3 "$ROOT/scripts/coverage.py" "$(swift build --scratch-path "$SCRATCH_PATH" --show-bin-path)" AlbumRaterData
