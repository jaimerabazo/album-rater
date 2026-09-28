#!/usr/bin/env bash
# Tests unitarios de AlbumRaterCore con cobertura. Falla si la cobertura de líneas
# del módulo baja del mínimo (95% por defecto; se puede cambiar con MIN_COVERAGE).
set -euo pipefail

MIN_COVERAGE="${MIN_COVERAGE:-95}"
# Carpeta de compilación. En una carpeta sincronizada con iCloud (p. ej. el Escritorio),
# codesign rechaza los atributos que añade macOS: usa SWIFT_SCRATCH_PATH fuera de ella.
SCRATCH_PATH="${SWIFT_SCRATCH_PATH:-.build}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/Packages/AlbumRaterKit"

swift test --scratch-path "$SCRATCH_PATH" --enable-code-coverage --filter AlbumRaterCoreTests
python3 "$ROOT/scripts/coverage.py" "$(swift build --scratch-path "$SCRATCH_PATH" --show-bin-path)" \
    AlbumRaterCore "$MIN_COVERAGE"
