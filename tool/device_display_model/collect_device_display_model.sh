#!/bin/zsh

set -euo pipefail

repository_root="${0:A:h:h:h}"
cd "$repository_root"

collector_arguments=()
if [[ ${1:-} == "--include-legacy-ios" ]]; then
  collector_arguments+=(--include-legacy)
  shift
fi
if [[ $# -ne 0 ]]; then
  print -u2 "usage: $0 [--include-legacy-ios]"
  exit 64
fi

tool/device_display_model/collect_ios_simulator.sh \
  "${collector_arguments[@]}" \
  tool/device_display_model/evidence/ios26_simulator_records.json
device_arguments=()
if [[ -n ${DEVICE_DISPLAY_IOS_COLLECTOR_APP:-} ]]; then
  device_arguments+=(
    --ios-device-app
    "$DEVICE_DISPLAY_IOS_COLLECTOR_APP"
  )
fi
fvm dart run tool/device_display_model/device_display_model.dart collect \
  --ios-record tool/device_display_model/evidence/ios26_simulator_records.json \
  "${device_arguments[@]}" \
  --output tool/device_display_model/corpus.json
