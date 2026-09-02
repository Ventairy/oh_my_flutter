#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repository_root"

fvm dart run tool/device_display_model/device_display_model.dart train \
  --corpus tool/device_display_model/corpus.json \
  --output tool/device_display_model/model_manifest.json
fvm dart run tool/device_display_model/device_display_model.dart generate \
  --manifest tool/device_display_model/model_manifest.json \
  --output lib/src/device/device_display/estimator/device_display_estimator_model.g.dart
fvm dart run tool/device_display_model/device_display_model.dart validate \
  --corpus tool/device_display_model/corpus.json \
  --manifest tool/device_display_model/model_manifest.json \
  --output tool/device_display_model/validation_report.md
