#!/usr/bin/env python3
"""Cobertura de líneas de un módulo de AlbumRaterKit tras `swift test --enable-code-coverage`.

Uso: coverage.py <carpeta bin de swift build> <módulo> [mínimo]
Con mínimo, termina con error si la cobertura del módulo queda por debajo.
Lee todos los bundles de tests: según la versión de SwiftPM hay uno por target o uno común.
"""
import glob
import json
import subprocess
import sys

bin_path, module = sys.argv[1], sys.argv[2]
minimum = float(sys.argv[3]) if len(sys.argv) > 3 else None

binaries = sorted(glob.glob(f"{bin_path}/*.xctest/Contents/MacOS/*"))
if not binaries:
    sys.exit(f"No hay bundles de tests en {bin_path}")
objects = [binaries[0]] + [arg for binary in binaries[1:] for arg in ("-object", binary)]
report = json.loads(subprocess.run(
    ["xcrun", "llvm-cov", "export", "-summary-only", "-instr-profile", f"{bin_path}/codecov/default.profdata", *objects],
    check=True, capture_output=True, text=True,
).stdout)

files = [f for f in report["data"][0]["files"] if f"/Sources/{module}/" in f["filename"]]
if not files:
    sys.exit(f"No hay datos de cobertura para {module}")

covered = count = 0
print(f"\nCobertura de líneas de {module}" + ("" if minimum is not None else " (informativa)"))
for f in sorted(files, key=lambda f: f["filename"]):
    lines = f["summary"]["lines"]
    covered += lines["covered"]
    count += lines["count"]
    print(f'  {lines["percent"]:6.2f}%  {f["filename"].split("/Sources/")[1]}')

total = 100 * covered / count
print(f"  {total:6.2f}%  TOTAL ({covered}/{count} líneas)" + (f", mínimo {minimum:g}%" if minimum is not None else ""))
if minimum is not None and total < minimum:
    sys.exit(f"La cobertura ({total:.2f}%) está por debajo del mínimo ({minimum:g}%).")
