#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pigeon_check_directory="$(mktemp -d)"
trap 'rm -rf "$pigeon_check_directory"' EXIT

cd "$repository_root"
fvm dart run pigeon \
  --input pigeons/native_selectable_text/native_selectable_text.dart \
  --base_path "$pigeon_check_directory"
fvm dart run \
  tool/generate_native_selectable_text_macos_pigeon.dart \
  "$pigeon_check_directory"
fvm dart run \
  tool/patch_native_selectable_text_linux_pigeon.dart \
  "$pigeon_check_directory/linux/native_selectable_text.g.cc"
fvm dart format \
  --page-width 120 \
  --trailing-commas preserve \
  "$pigeon_check_directory/lib/src/widgets/native_selectable_text/pigeon/native_selectable_text.g.dart" \
  >/dev/null

generated_files=(
  "lib/src/widgets/native_selectable_text/pigeon/native_selectable_text.g.dart"
  "android/src/main/kotlin/dev/ventairy/oh_my_flutter/NativeSelectableText.g.kt"
  "ios/oh_my_flutter/Sources/oh_my_flutter/NativeSelectableText.g.swift"
  "macos/oh_my_flutter/Sources/oh_my_flutter/NativeSelectableText.g.swift"
  "windows/native_selectable_text.g.h"
  "windows/native_selectable_text.g.cpp"
  "linux/native_selectable_text.g.h"
  "linux/native_selectable_text.g.cc"
)
is_current=true

for generated_file in "${generated_files[@]}"; do
  checked_in_file="$repository_root/$generated_file"
  regenerated_file="$pigeon_check_directory/$generated_file"
  if ! cmp -s "$checked_in_file" "$regenerated_file"; then
    echo "Generated Pigeon file is stale: $generated_file" >&2
    diff -u "$checked_in_file" "$regenerated_file" || true
    is_current=false
  fi
done

if [[ "$is_current" != true ]]; then
  echo 'Run ./tool/generate_native_selectable_text_pigeon.sh.' >&2
  exit 1
fi
