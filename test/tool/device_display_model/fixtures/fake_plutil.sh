#!/usr/bin/env bash

set -euo pipefail

[[ "$*" == '-convert json -o - '* ]]
plist_path="${@: -1}"
grep -q '<key>CFBundleIdentifier</key><string>dev.ventairy.oh-my-flutter.device-display-collector</string>' "$plist_path"
grep -q '<key>CFBundleExecutable</key><string>DeviceDisplayCollector</string>' "$plist_path"
grep -q '<key>MinimumOSVersion</key><string>26.0</string>' "$plist_path"
printf '%s\n' '{"CFBundleIdentifier":"dev.ventairy.oh-my-flutter.device-display-collector","CFBundleExecutable":"DeviceDisplayCollector","MinimumOSVersion":"26.0"}'
