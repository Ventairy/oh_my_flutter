#!/usr/bin/env bash
set -euo pipefail
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
simulator_id="${SIMULATOR_ID:-$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [device for devices in json.load(sys.stdin)["devices"].values() for device in devices if device.get("isAvailable") and device["name"].startswith("iPhone")]
devices.sort(key=lambda device: device["state"] != "Booted")
if not devices:
    sys.exit("No available iPhone simulator found")
print(devices[0]["udid"])
')}"
cd "$repository_root/example"
fvm flutter build ios --debug --simulator --no-pub --target=lib/main.dart
xcodebuild test -quiet \
  -workspace ios/Runner.xcworkspace \
  -scheme oh_my_flutterTests \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  CODE_SIGNING_ALLOWED=NO \
  FRAMEWORK_SEARCH_PATHS="$PWD/build/ios/Debug-iphonesimulator" \
  LD_RUNPATH_SEARCH_PATHS="$PWD/build/ios/Debug-iphonesimulator" \
  -only-testing:oh_my_flutterTests/IOSDeviceAccelerometerHandlerTests \
  -only-testing:oh_my_flutterTests/OhMyFlutterPluginTests
