#!/bin/zsh

set -euo pipefail

arguments="$*"
if [[ "$arguments" == "devices" ]]; then
  print 'List of devices attached'
  print 'anonymous-local\tdevice'
elif [[ "$arguments" == *'ro.build.version.sdk'* ]]; then
  print "${OMF_FAKE_ANDROID_API_LEVEL:-31}"
elif [[ "$arguments" == *'ro.kernel.qemu'* ]]; then
  if [[ ${OMF_FAKE_ANDROID_QEMU_PROBE_HANG:-0} == 1 ]]; then
    trap '' TERM
    sleep 60 &
    print "$!" > "${OMF_FAKE_ANDROID_HANG_CHILD_PID_PATH:?}"
    wait
  fi
  if [[ ${OMF_FAKE_ANDROID_QEMU_PROBE_FAILURE:-0} == 1 ]]; then
    exit 1
  fi
  print "${OMF_FAKE_ANDROID_IS_EMULATOR:-0}"
elif [[ "$arguments" == *'am start'* ]]; then
  print -r -- "${@: -1}" > "${OMF_FAKE_ANDROID_STATE_PATH:?}"
  print 'Status: ok'
elif [[ "$arguments" == *'run-as dev.ventairy.oh_my_flutter.device_display_model_collector cat files/device_display_record.json'* ]]; then
  nonce=$(<"${OMF_FAKE_ANDROID_STATE_PATH:?}")
  if (( ${OMF_FAKE_ANDROID_API_LEVEL:-31} >= 31 )); then
    print -r -- "{\"protocolVersion\":1,\"protocolSourceHash\":\"${OMF_FAKE_ANDROID_SOURCE_HASH:?}\",\"sourceKind\":\"android_api31_window_insets\",\"nonce\":\"$nonce\",\"rotation\":${OMF_FAKE_ANDROID_ROTATION:-0},\"hasFoldOrHinge\":${OMF_FAKE_ANDROID_HAS_FOLD_OR_HINGE:-false},\"physicalWidth\":1080,\"physicalHeight\":2400,\"viewPhysicalWidth\":1080,\"viewPhysicalHeight\":2400,\"devicePixelRatio\":3.0,\"viewPaddingLeftPhysical\":0,\"viewPaddingTopPhysical\":88,\"viewPaddingRightPhysical\":0,\"viewPaddingBottomPhysical\":144,\"systemGestureInsetLeftPhysical\":0,\"systemGestureInsetTopPhysical\":0,\"systemGestureInsetRightPhysical\":0,\"systemGestureInsetBottomPhysical\":144,\"displayCutoutWidthPhysical\":56,\"displayCutoutHeightPhysical\":88,\"displayCutoutCount\":1,\"topLeftRadiusPhysical\":${OMF_FAKE_ANDROID_TOP_LEFT_RADIUS:-0},\"topRightRadiusPhysical\":${OMF_FAKE_ANDROID_TOP_RIGHT_RADIUS:-0},\"bottomRightRadiusPhysical\":${OMF_FAKE_ANDROID_BOTTOM_RIGHT_RADIUS:-0},\"bottomLeftRadiusPhysical\":${OMF_FAKE_ANDROID_BOTTOM_LEFT_RADIUS:-0}}"
  elif [[ -n ${OMF_FAKE_ANDROID_LEGACY_TOP_RADIUS:-} && -n ${OMF_FAKE_ANDROID_LEGACY_BOTTOM_RADIUS:-} ]]; then
    print -r -- "{\"protocolVersion\":1,\"protocolSourceHash\":\"${OMF_FAKE_ANDROID_SOURCE_HASH:?}\",\"sourceKind\":\"android_legacy_default_display_resource\",\"nonce\":\"$nonce\",\"rotation\":${OMF_FAKE_ANDROID_ROTATION:-0},\"hasFoldOrHinge\":${OMF_FAKE_ANDROID_HAS_FOLD_OR_HINGE:-false},\"physicalWidth\":1080,\"physicalHeight\":2400,\"devicePixelRatio\":3.0,\"topRadiusPhysical\":${OMF_FAKE_ANDROID_LEGACY_TOP_RADIUS},\"bottomRadiusPhysical\":${OMF_FAKE_ANDROID_LEGACY_BOTTOM_RADIUS}}"
  else
    exit 1
  fi
elif [[ "$arguments" == *' install '* || "$arguments" == *' uninstall '* || "$arguments" == *'am force-stop'* ]]; then
  print 'Success'
elif [[ "$arguments" == *'ro.product.manufacturer'* ]]; then
  print 'fixture-oem'
elif [[ "$arguments" == *'ro.product.model'* ]]; then
  print 'fixture-family-31'
elif [[ "$arguments" == *'ro.product.device'* ]]; then
  print 'fixture-generation-31'
fi
