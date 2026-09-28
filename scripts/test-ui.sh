#!/usr/bin/env bash
# Tests de UI del recorrido crítico en el simulador, contra el Supabase local. Requiere `supabase start`.
# Nunca usan tu proyecto real: la app solo acepta el backend de pruebas en Debug y hacia localhost.
# SIMULATOR elige el dispositivo (por defecto, iPhone 17 Pro).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/local-supabase-env.sh"
cd "$ROOT"

# xcodebuild pasa las variables TEST_RUNNER_* al proceso de los tests sin ese prefijo.
TEST_RUNNER_SUPABASE_TEST_URL="$SUPABASE_TEST_URL" \
TEST_RUNNER_SUPABASE_TEST_PUBLISHABLE_KEY="$SUPABASE_TEST_PUBLISHABLE_KEY" \
xcodebuild test \
    -project AlbumRater.xcodeproj \
    -scheme AlbumRater \
    -destination "platform=iOS Simulator,name=${SIMULATOR:-iPhone 17 Pro}" \
    ${DERIVED_DATA_PATH:+-derivedDataPath "$DERIVED_DATA_PATH"} \
    -resultBundlePath "${RESULT_BUNDLE_PATH:-$(mktemp -d)/UITests.xcresult}"
