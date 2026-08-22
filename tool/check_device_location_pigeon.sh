#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pigeon_check_directory="$(mktemp -d)"
trap 'rm -rf "$pigeon_check_directory"' EXIT

cd "$repository_root"
fvm dart run pigeon \
  --input pigeons/device_location/device_location.dart \
  --base_path "$pigeon_check_directory"
fvm dart format \
  --page-width 120 \
  --trailing-commas preserve \
  "$pigeon_check_directory/lib/src/device/device_location/pigeon/android_device_location.g.dart" \
  >/dev/null

generated_files=(
  "lib/src/device/device_location/pigeon/android_device_location.g.dart"
  "android/src/main/kotlin/dev/ventairy/oh_my_flutter/AndroidDeviceLocation.g.kt"
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
  echo 'Run ./tool/generate_device_location_pigeon.sh.' >&2
  exit 1
fi
