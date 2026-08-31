#!/bin/zsh

set -euo pipefail

signing_identity=""
provisioning_profile=""
output_app=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --signing-identity)
      signing_identity="${2:-}"
      shift 2
      ;;
    --provisioning-profile)
      provisioning_profile="${2:-}"
      shift 2
      ;;
    --output)
      output_app="${2:-}"
      shift 2
      ;;
    *)
      print -u2 "Unknown option: $1"
      exit 64
      ;;
  esac
done
if [[ -z "$signing_identity" ||
      "$provisioning_profile" != /* ||
      "$output_app" != /* ||
      "$output_app" != *.app ]]; then
  print -u2 \
    "usage: $0 --signing-identity IDENTITY --provisioning-profile /absolute/profile.mobileprovision --output /absolute/Collector.app"
  exit 64
fi
if [[ ! -f "$provisioning_profile" || -e "$output_app" ]]; then
  print -u2 "The profile must exist and the output app must not already exist."
  exit 1
fi

script_directory="${0:A:h}"
source_directory="$script_directory/ios_device_collector"
"$script_directory/generate_ios_device_collector_provenance.sh" --check >/dev/null
temporary_directory="$(mktemp -d)"
output_created=false
build_succeeded=false
cleanup() {
  if ! $build_succeeded && $output_created; then
    rm -rf -- "$output_app"
  fi
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

security cms -D -i "$provisioning_profile" > "$temporary_directory/profile.plist"
bundle_identifier="$(
  plutil -extract CFBundleIdentifier raw -o - "$source_directory/Info.plist"
)"
application_identifier="$(
  plutil -extract Entitlements.application-identifier raw -o - \
    "$temporary_directory/profile.plist"
)"
if [[ "$application_identifier" != *".$bundle_identifier" ]]; then
  print -u2 "The provisioning profile App ID does not match the collector bundle ID."
  exit 1
fi
plutil -extract Entitlements xml1 -o "$temporary_directory/entitlements.plist" \
  "$temporary_directory/profile.plist"

mkdir -p "$output_app"
output_created=true
cp "$source_directory/Info.plist" "$output_app/Info.plist"
cp "$provisioning_profile" "$output_app/embedded.mobileprovision"
ios_sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos clang \
  -fobjc-arc \
  -fmodules \
  -isysroot "$ios_sdk" \
  -miphoneos-version-min=26.0 \
  -target arm64-apple-ios26.0 \
  -framework UIKit \
  -I "$source_directory" \
  "$source_directory/main.m" \
  "$source_directory/public_corner_radius_collector_app_delegate.m" \
  -o "$output_app/DeviceDisplayCollector"
codesign \
  --force \
  --sign "$signing_identity" \
  --entitlements "$temporary_directory/entitlements.plist" \
  --timestamp=none \
  "$output_app"
codesign --verify --deep --strict "$output_app"
build_succeeded=true
print -r -- "$output_app"
