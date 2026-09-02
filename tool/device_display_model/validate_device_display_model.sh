#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repository_root"

fvm dart run tool/device_display_model/device_display_model.dart check \
  --corpus tool/device_display_model/corpus.json \
  --manifest tool/device_display_model/model_manifest.json \
  --artifact lib/src/device/device_display/estimator/device_display_estimator_model.g.dart \
  --report tool/device_display_model/validation_report.md
