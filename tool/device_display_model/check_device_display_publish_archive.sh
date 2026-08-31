#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
package_root="${script_directory:h:h}"

cd "$package_root"
fvm dart run tool/device_display_model/device_display_model.dart \
  check-publish-archive \
  --package-root "$package_root"
