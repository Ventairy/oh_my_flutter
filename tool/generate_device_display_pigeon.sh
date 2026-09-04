#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

fvm dart run pigeon \
  --input pigeons/device_display/device_display.dart
fvm dart format \
  --page-width 120 \
  --trailing-commas preserve \
  lib/src/device/device_display/pigeon/device_display.g.dart
