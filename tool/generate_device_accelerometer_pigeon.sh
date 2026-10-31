#!/usr/bin/env bash
set -euo pipefail
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"
fvm dart run pigeon --input pigeons/device_accelerometer/device_accelerometer.dart
fvm dart format --page-width 120 --trailing-commas preserve lib/src/gen/device_accelerometer/device_accelerometer.g.dart

# Normalize whitespace emitted by the pinned Pigeon native generators.
python3 - "./lib/src/gen/device_accelerometer/android/DeviceAccelerometer.g.kt" "./lib/src/gen/device_accelerometer/apple/DeviceAccelerometer.g.swift" <<'PYTHON'
from pathlib import Path
import sys
for name in sys.argv[1:]:
    path = Path(name)
    path.write_text('\n'.join(line.rstrip() for line in path.read_text().splitlines()).rstrip() + '\n')
PYTHON
