#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_root="$(cd "$script_directory/../.." && pwd)"

cd "$package_root"
fvm dart run tool/device_display_model/device_display_model.dart \
  check-publish-archive \
  --package-root "$package_root"
