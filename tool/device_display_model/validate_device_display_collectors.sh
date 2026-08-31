#!/bin/zsh

set -euo pipefail

repository_root="${0:A:h:h:h}"
cd "$repository_root"

if [[ "$(uname -s)" == Darwin ]]; then
  tool/device_display_model/generate_ios_device_collector_provenance.sh --check

  ios_sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
  xcrun --sdk iphoneos clang \
    -fobjc-arc \
    -fmodules \
    -fsyntax-only \
    -isysroot "$ios_sdk" \
    -miphoneos-version-min=26.0 \
    -target arm64-apple-ios26.0 \
    -framework UIKit \
    -I tool/device_display_model/ios_device_collector \
    tool/device_display_model/ios_device_collector/main.m \
    tool/device_display_model/ios_device_collector/public_corner_radius_collector_app_delegate.m
fi

fvm dart run tool/device_display_model/device_display_model.dart check-collectors
