#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
platform="${1:?Usage: generate_country_bindings.sh apple|android|windows [--check]}"
mode="${2:-}"
case "$platform" in
  apple|android|windows) ;;
  *) echo "Unknown binding platform: $platform" >&2; exit 1 ;;
esac
if [[ -n "$mode" && "$mode" != '--check' ]]; then
  echo "Unknown option: $mode" >&2
  exit 1
fi
binding_directory="$(mktemp -d)"
trap 'rm -rf "$binding_directory"' EXIT
cd "$repository_root/tool/country_bindings"
fvm flutter pub get --enforce-lockfile
if [[ "$platform" == android ]]; then
  (
    cd "$repository_root/example"
    fvm flutter pub get --enforce-lockfile
    fvm flutter build apk --config-only --no-pub
    cd android
    ./gradlew :oh_my_flutter:compileReleaseKotlin --console=plain
  )
fi
output_name="country_names_${platform}.g.dart"
fvm dart run "bin/generate_${platform}.dart" "$binding_directory/$output_name"
if [[ ! -s "$binding_directory/$output_name" ]]; then
  echo "The generator did not produce $output_name." >&2
  exit 1
fi
fvm dart format --page-width 120 --trailing-commas preserve "$binding_directory/$output_name" >/dev/null
checked_in_file="$repository_root/lib/src/gen/$output_name"
if [[ "$mode" == '--check' ]]; then
  if ! cmp -s "$checked_in_file" "$binding_directory/$output_name"; then
    echo "Generated Country bindings are stale: $output_name" >&2
    diff -u "$checked_in_file" "$binding_directory/$output_name" || true
    exit 1
  fi
else
  cp "$binding_directory/$output_name" "$checked_in_file"
fi
