#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-}"
if [[ -n "$mode" && "$mode" != '--check' ]]; then
  echo "Usage: generate_device_location_bindings.sh [--check]" >&2
  exit 1
fi
binding_directory="$(mktemp -d)"
trap 'rm -rf "$binding_directory"' EXIT
cd "$repository_root/tool/device_location_bindings"
fvm dart pub get --enforce-lockfile
output_name='apple_device_location_native_bindings.g.dart'
fvm dart run bin/generate.dart "$binding_directory/$output_name"
fvm dart format --page-width 120 --trailing-commas preserve "$binding_directory/$output_name" >/dev/null
checked_in_file="$repository_root/lib/src/device/device_location/apple_device_location/$output_name"
if [[ "$mode" == '--check' ]]; then
  if ! cmp -s "$checked_in_file" "$binding_directory/$output_name"; then
    echo "Generated device-location bindings are stale: $output_name" >&2
    diff -u "$checked_in_file" "$binding_directory/$output_name" || true
    exit 1
  fi
else
  cp "$binding_directory/$output_name" "$checked_in_file"
fi
