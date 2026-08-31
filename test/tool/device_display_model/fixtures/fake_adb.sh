#!/usr/bin/env bash

set -euo pipefail

arguments="$*"
if [[ "$arguments" == "devices" ]]; then
  printf 'List of devices attached\n'
  printf 'anonymous-local\tdevice\n'
elif [[ "$arguments" == *'ro.build.version.sdk'* ]]; then
  printf '%s\n' "${OMF_FAKE_ANDROID_API_LEVEL:-31}"
elif [[ "$arguments" == *'ro.kernel.qemu'* ]]; then
  if [[ ${OMF_FAKE_ANDROID_QEMU_PROBE_HANG:-0} == 1 ]]; then
    trap '' TERM
    sleep 60 &
    printf '%s\n' "$!" > "${OMF_FAKE_ANDROID_HANG_CHILD_PID_PATH:?}"
    wait
  fi
  if [[ ${OMF_FAKE_ANDROID_QEMU_PROBE_FAILURE:-0} == 1 ]]; then
    exit 1
  fi
  printf '%s\n' "${OMF_FAKE_ANDROID_IS_EMULATOR:-0}"
elif [[ "$arguments" == *'am start'* ]]; then
  printf '%s\n' "${@: -1}" > "${OMF_FAKE_ANDROID_STATE_PATH:?}"
  printf 'Status: ok\n'
elif [[ "$arguments" == *'run-as dev.ventairy.oh_my_flutter.device_display_model_collector cat files/device_display_record.json'* ]]; then
  nonce=$(<"${OMF_FAKE_ANDROID_STATE_PATH:?}")
  if (( ${OMF_FAKE_ANDROID_API_LEVEL:-31} >= 31 )); then
    printf '%s\n' "{\"protocolVersion\":1,\"protocolSourceHash\":\"${OMF_FAKE_ANDROID_SOURCE_HASH:?}\",\"sourceKind\":\"android_api31_window_insets\",\"nonce\":\"$nonce\",\"rotation\":${OMF_FAKE_ANDROID_ROTATION:-0},\"hasFoldOrHinge\":${OMF_FAKE_ANDROID_HAS_FOLD_OR_HINGE:-false},\"physicalWidth\":1080,\"physicalHeight\":2400,\"viewPhysicalWidth\":1080,\"viewPhysicalHeight\":2400,\"devicePixelRatio\":3.0,\"viewPaddingLeftPhysical\":0,\"viewPaddingTopPhysical\":88,\"viewPaddingRightPhysical\":0,\"viewPaddingBottomPhysical\":144,\"systemGestureInsetLeftPhysical\":0,\"systemGestureInsetTopPhysical\":0,\"systemGestureInsetRightPhysical\":0,\"systemGestureInsetBottomPhysical\":144,\"displayCutoutWidthPhysical\":56,\"displayCutoutHeightPhysical\":88,\"displayCutoutCount\":1,\"topLeftRadiusPhysical\":${OMF_FAKE_ANDROID_TOP_LEFT_RADIUS:-0},\"topRightRadiusPhysical\":${OMF_FAKE_ANDROID_TOP_RIGHT_RADIUS:-0},\"bottomRightRadiusPhysical\":${OMF_FAKE_ANDROID_BOTTOM_RIGHT_RADIUS:-0},\"bottomLeftRadiusPhysical\":${OMF_FAKE_ANDROID_BOTTOM_LEFT_RADIUS:-0}}"
  elif [[ -n ${OMF_FAKE_ANDROID_LEGACY_TOP_RADIUS:-} && -n ${OMF_FAKE_ANDROID_LEGACY_BOTTOM_RADIUS:-} ]]; then
    printf '%s\n' "{\"protocolVersion\":1,\"protocolSourceHash\":\"${OMF_FAKE_ANDROID_SOURCE_HASH:?}\",\"sourceKind\":\"android_legacy_default_display_resource\",\"nonce\":\"$nonce\",\"rotation\":${OMF_FAKE_ANDROID_ROTATION:-0},\"hasFoldOrHinge\":${OMF_FAKE_ANDROID_HAS_FOLD_OR_HINGE:-false},\"physicalWidth\":1080,\"physicalHeight\":2400,\"devicePixelRatio\":3.0,\"topRadiusPhysical\":${OMF_FAKE_ANDROID_LEGACY_TOP_RADIUS},\"bottomRadiusPhysical\":${OMF_FAKE_ANDROID_LEGACY_BOTTOM_RADIUS}}"
  else
    exit 1
  fi
elif [[ "$arguments" == *' install '* || "$arguments" == *' uninstall '* || "$arguments" == *'am force-stop'* ]]; then
  printf 'Success\n'
elif [[ "$arguments" == *'ro.product.manufacturer'* ]]; then
  printf 'fixture-oem\n'
elif [[ "$arguments" == *'ro.product.model'* ]]; then
  printf 'fixture-family-31\n'
elif [[ "$arguments" == *'ro.product.device'* ]]; then
  printf 'fixture-generation-31\n'
fi
