#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example_directory="$repository_root/example"
application_directory="$example_directory/build/ios/iphoneos/Runner.app"
framework_directory="$application_directory/Frameworks/oh_my_flutter_device_location.framework"
framework_binary="$framework_directory/oh_my_flutter_device_location"
privacy_manifest_name='PrivacyInfo.xcprivacy'
privacy_manifest="$application_directory/oh_my_flutter_oh_my_flutter.bundle/$privacy_manifest_name"
native_symbols=(
  '_omf_device_location_is_service_enabled'
  '_omf_device_location_check_permission'
  '_omf_device_location_request_permission'
  '_omf_device_location_request_coordinates'
  '_omf_device_location_request_address'
  '_omf_device_location_allocate'
  '_omf_device_location_free'
  '_omf_device_location_open_settings'
)

iphoneos_sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun clang \
  -fobjc-arc \
  -Wall \
  -Wextra \
  -Wpedantic \
  -Werror \
  -fsyntax-only \
  -isysroot "$iphoneos_sdk" \
  -miphoneos-version-min=15.0 \
  "$repository_root/src/device_location/apple_device_location.m"

cd "$example_directory"

if [[ "${GITHUB_ACTIONS:-}" != true ]]; then
  fvm flutter clean
fi
fvm flutter pub get --enforce-lockfile
fvm flutter build ios --release --no-codesign --target=lib/main.dart --no-pub

test -f "$framework_binary"
xcrun vtool -show-build "$framework_binary" | grep -Eq 'minos 15(\.0+)?$'
otool -L "$framework_binary" | grep -Fq '/System/Library/Frameworks/CoreLocation.framework/'
otool -L "$framework_binary" | grep -Fq '/System/Library/Frameworks/MapKit.framework/'
otool -L "$framework_binary" | grep -Fq '/System/Library/Frameworks/Contacts.framework/'
if otool -L "$framework_binary" | grep -Fq 'LocationEssentials.framework'; then
  echo 'The DeviceLocation framework links a private LocationEssentials framework.' >&2
  exit 1
fi
nm -m "$framework_binary" |
  grep -F 'weak external _OBJC_CLASS_$_MKReverseGeocodingRequest' >/dev/null
for symbol in "${native_symbols[@]}"; do
  nm -gU "$framework_binary" | grep -Fq "$symbol"
done

test -f "$privacy_manifest"
plutil -lint "$privacy_manifest"

fvm flutter clean
fvm flutter pub get --enforce-lockfile
fvm flutter build ios \
  --release \
  --no-codesign \
  --no-pub \
  --target=../tool/fixtures/device_location_unused.dart

if test -e "$framework_directory"; then
  echo 'The DeviceLocation framework was bundled when the API was unreachable.' >&2
  exit 1
fi
test -f "$privacy_manifest"
plutil -lint "$privacy_manifest"
