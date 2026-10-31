#!/usr/bin/env bash
set -euo pipefail
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
check_directory="$(mktemp -d)"
trap 'rm -rf "$check_directory"' EXIT
cd "$repository_root"
fvm dart run pigeon --input pigeons/device_accelerometer/device_accelerometer.dart --base_path "$check_directory"
fvm dart format --page-width 120 --trailing-commas preserve "$check_directory/lib/src/gen/device_accelerometer/device_accelerometer.g.dart" >/dev/null
# Normalize whitespace emitted by the pinned Pigeon native generators.
python3 - "$check_directory/lib/src/gen/device_accelerometer/android/DeviceAccelerometer.g.kt" "$check_directory/lib/src/gen/device_accelerometer/apple/DeviceAccelerometer.g.swift" <<'PYTHON'
from pathlib import Path
import sys
for name in sys.argv[1:]:
    path = Path(name)
    path.write_text('\n'.join(line.rstrip() for line in path.read_text().splitlines()).rstrip() + '\n')
PYTHON
for generated_file in \
  lib/src/gen/device_accelerometer/device_accelerometer.g.dart \
  lib/src/gen/device_accelerometer/android/DeviceAccelerometer.g.kt \
  lib/src/gen/device_accelerometer/apple/DeviceAccelerometer.g.swift; do
  if ! diff -u "$generated_file" "$check_directory/$generated_file"; then
    echo 'Run make generate-device-accelerometer-pigeon.' >&2
    exit 1
  fi
done
