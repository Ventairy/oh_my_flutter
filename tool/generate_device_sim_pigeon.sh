#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

fvm dart run pigeon \
  --input pigeons/device_sim/device_sim.dart
fvm dart format \
  --page-width 120 \
  --trailing-commas preserve \
  lib/src/gen/device_sim/device_sim.g.dart
