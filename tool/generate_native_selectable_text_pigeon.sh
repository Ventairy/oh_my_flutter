#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

fvm dart run pigeon \
  --input pigeons/native_selectable_text/native_selectable_text.dart
fvm dart run tool/generate_native_selectable_text_macos_pigeon.dart
fvm dart run \
  tool/patch_native_selectable_text_linux_pigeon.dart \
  linux/native_selectable_text.g.cc
fvm dart format \
  --page-width 120 \
  --trailing-commas preserve \
  lib/src/widgets/native_selectable_text/pigeon/native_selectable_text.g.dart
