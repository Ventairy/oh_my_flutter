#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example_directory="$repository_root/example"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="$sdk_root/platform-tools/adb"
emulator="$sdk_root/emulator/emulator"
avdmanager="$sdk_root/cmdline-tools/latest/bin/avdmanager"
application_id='dev.ventairy.oh_my_flutter_example'
emulator_id='emulator-5580'
emulator_port='5580'
longitude='-46.844076'
latitude='-23.556391'

matrix=(
  '24;default;arm64-v8a;pixel_2'
  '27;default;arm64-v8a;pixel_2'
  '28;default;arm64-v8a;pixel_2'
  '30;default;arm64-v8a;pixel_2'
  '31;default;arm64-v8a;pixel_4'
  '33;default;arm64-v8a;pixel_4'
  '34;default;arm64-v8a;pixel_7'
  '35;google_apis_playstore_tablet;arm64-v8a;medium_tablet'
  '36;default;arm64-v8a;pixel_8'
  '37.0;google_apis_playstore_ps16k;arm64-v8a;pixel_9'
)

for executable in "$adb" "$emulator" "$avdmanager"; do
  if ! test -x "$executable"; then
    echo "Required Android SDK executable not found: $executable" >&2
    exit 1
  fi
done

emulator_pid=''
cleanup_emulator() {
  if test -n "$emulator_pid"; then
    "$adb" -s "$emulator_id" emu kill >/dev/null 2>&1 || true
    wait "$emulator_pid" >/dev/null 2>&1 || true
    emulator_pid=''
  fi
}
trap cleanup_emulator EXIT

wait_for_boot() {
  local attempts=0
  until test "$(
    "$adb" -s "$emulator_id" shell getprop sys.boot_completed 2>/dev/null |
      tr -d '\r'
  )" = '1'; do
    attempts=$((attempts + 1))
    if test "$attempts" -ge 90; then
      echo "Android emulator $emulator_id did not boot within three minutes." >&2
      exit 1
    fi
    sleep 2
  done
}

ensure_avd() {
  local api="$1"
  local tag="$2"
  local abi="$3"
  local device="$4"
  local avd_name="omf_location_api${api//./_}_${tag}"
  local package="system-images;android-$api;$tag;$abi"

  if ! "$emulator" -list-avds | grep -Fxq "$avd_name"; then
    if ! test -d "$sdk_root/system-images/android-$api/$tag/$abi"; then
      echo "Install the Android image before running this audit: $package" >&2
      exit 1
    fi
    printf 'no\n' | "$avdmanager" create avd \
      --force \
      --name "$avd_name" \
      --package "$package" \
      --device "$device" >&2
  fi

  printf '%s\n' "$avd_name"
}

run_flutter_scenario() {
  local scenario="$1"
  fvm flutter test \
    integration_test/device_location_android_test.dart \
    --device-id "$emulator_id" \
    --no-pub \
    --dart-define="DEVICE_LOCATION_SCENARIO=$scenario"
}

run_permission_prompt_scenario() {
  local output_file="${TMPDIR:-/tmp}/oh_my_flutter_permission_${api//./_}.log"
  run_flutter_scenario permissionRequest >"$output_file" 2>&1 &
  local test_pid="$!"
  local bounds=''
  local attempts=0

  until test -n "$bounds"; do
    if ! kill -0 "$test_pid" 2>/dev/null; then
      break
    fi
    attempts=$((attempts + 1))
    if test "$attempts" -ge 60; then
      break
    fi
    "$adb" -s "$emulator_id" shell uiautomator dump /sdcard/window.xml \
      >/dev/null 2>&1 || true
    bounds="$(
      "$adb" -s "$emulator_id" exec-out cat /sdcard/window.xml 2>/dev/null |
        tr '>' '\n' |
        grep -E 'resource-id="[^"]*permission_allow(_foreground_only)?_button"' |
        sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/' |
        head -n 1 || true
    )"
    test -n "$bounds" || sleep 1
  done

  if test -z "$bounds"; then
    cat "$output_file"
    kill "$test_pid" >/dev/null 2>&1 || true
    wait "$test_pid" >/dev/null 2>&1 || true
    echo "The Android $api permission dialog did not expose an allow button." >&2
    exit 1
  fi

  read -r left top right bottom <<<"$bounds"
  "$adb" -s "$emulator_id" shell input tap \
    "$(((left + right) / 2))" "$(((top + bottom) / 2))"
  if ! wait "$test_pid"; then
    cat "$output_file"
    exit 1
  fi
  cat "$output_file"
}

cd "$example_directory"
fvm flutter pub get --enforce-lockfile
fvm flutter build apk --debug --target=lib/main.dart
apk='build/app/outputs/flutter-apk/app-debug.apk'

for entry in "${matrix[@]}"; do
  IFS=';' read -r api tag abi device <<<"$entry"
  avd_name="$(ensure_avd "$api" "$tag" "$abi" "$device")"
  echo "Testing DeviceLocation on Android $api ($tag, $device)."

  "$emulator" "@$avd_name" \
    -port "$emulator_port" \
    -no-window \
    -no-audio \
    -no-boot-anim \
    -no-snapshot \
    -wipe-data \
    -gpu swiftshader_indirect \
    >"${TMPDIR:-/tmp}/oh_my_flutter_${avd_name}.log" 2>&1 &
  emulator_pid="$!"
  wait_for_boot

  "$adb" -s "$emulator_id" install -r "$apk"
  "$adb" -s "$emulator_id" shell settings put secure location_mode 3
  "$adb" -s "$emulator_id" shell pm grant \
    "$application_id" android.permission.ACCESS_COARSE_LOCATION
  "$adb" -s "$emulator_id" shell pm grant \
    "$application_id" android.permission.ACCESS_FINE_LOCATION
  "$adb" -s "$emulator_id" emu geo fix "$longitude" "$latitude"
  run_flutter_scenario granted

  "$adb" -s "$emulator_id" install -r "$apk"
  "$adb" -s "$emulator_id" shell pm revoke \
    "$application_id" android.permission.ACCESS_FINE_LOCATION
  "$adb" -s "$emulator_id" shell pm revoke \
    "$application_id" android.permission.ACCESS_COARSE_LOCATION
  run_permission_prompt_scenario

  if [[ "$api" == '24' || "$api" == '31' || "$api" == '36' ]]; then
    "$adb" -s "$emulator_id" install -r "$apk"
    "$adb" -s "$emulator_id" shell pm revoke \
      "$application_id" android.permission.ACCESS_FINE_LOCATION
    "$adb" -s "$emulator_id" shell pm revoke \
      "$application_id" android.permission.ACCESS_COARSE_LOCATION
    run_flutter_scenario denied
  fi

  if [[ "$api" == '31' || "$api" == '36' ]]; then
    "$adb" -s "$emulator_id" install -r "$apk"
    "$adb" -s "$emulator_id" shell pm grant \
      "$application_id" android.permission.ACCESS_COARSE_LOCATION
    "$adb" -s "$emulator_id" shell cmd location set-location-enabled false \
      --user 0
    run_flutter_scenario servicesDisabled
  fi

  cleanup_emulator
done
