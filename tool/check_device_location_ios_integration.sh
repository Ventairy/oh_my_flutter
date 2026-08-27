#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example_directory="$repository_root/example"
bundle_identifier='dev.ventairy.ohMyFlutterExample'
simulated_location='-23.556391,-46.844076'
permission_lifecycle_complete='OH_MY_FLUTTER_IOS_PERMISSION_LIFECYCLE_COMPLETE'

booted_device_line="$(xcrun simctl list devices available | grep 'iPhone.*(Booted)' | head -n 1 || true)"
booted_by_script=false
if test -n "$booted_device_line"; then
  device_line="$booted_device_line"
else
  device_line="$(xcrun simctl list devices available | grep 'iPhone.*(Shutdown)' | tail -n 1)"
  booted_by_script=true
fi

device_id="$(sed -E 's/.*\(([0-9A-F-]{36})\) \((Booted|Shutdown)\).*/\1/' <<<"$device_line")"
if ! [[ "$device_id" =~ ^[0-9A-F-]{36}$ ]]; then
  echo 'No available iPhone simulator was found.' >&2
  exit 1
fi

cleanup() {
  xcrun simctl location "$device_id" clear >/dev/null 2>&1 || true
  xcrun simctl privacy "$device_id" reset location "$bundle_identifier" >/dev/null 2>&1 || true
  if test "$booted_by_script" = true; then
    xcrun simctl shutdown "$device_id" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if test "$booted_by_script" = true; then
  xcrun simctl boot "$device_id"
fi
xcrun simctl bootstatus "$device_id" -b

cd "$example_directory"
fvm flutter clean
fvm flutter pub get --enforce-lockfile
fvm flutter build ios --simulator --target=lib/main.dart
application_path='build/ios/iphonesimulator/Runner.app'
purpose_string="$({
  plutil -extract NSLocationWhenInUseUsageDescription raw \
    "$application_path/Info.plist"
} 2>/dev/null)"
if ! grep -Eq '[^[:space:]]' <<<"$purpose_string"; then
  echo 'The example must declare a non-empty location purpose string.' >&2
  exit 1
fi
xcrun simctl install "$device_id" "$application_path"
xcrun simctl privacy "$device_id" grant location "$bundle_identifier"
xcrun simctl location "$device_id" set "$simulated_location"
fvm flutter test \
  integration_test/device_location_ios_test.dart \
  --device-id "$device_id" \
  --no-pub

xcrun simctl privacy "$device_id" reset location "$bundle_identifier"
# Opening Settings backgrounds Runner. Restore it once the test confirms the
# lifecycle result so Flutter can close the integration-test connection.
fvm flutter test \
  integration_test/device_location_ios_permission_lifecycle_test.dart \
  --device-id "$device_id" \
  --reporter expanded \
  --no-pub 2>&1 | while IFS= read -r output; do
  printf '%s\n' "$output"
  if [[ "$output" == *"$permission_lifecycle_complete"* ]]; then
    xcrun simctl launch "$device_id" "$bundle_identifier" >/dev/null
  fi
done
