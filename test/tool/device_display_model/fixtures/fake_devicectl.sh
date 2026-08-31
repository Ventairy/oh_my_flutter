#!/bin/zsh

set -euo pipefail

arguments="$*"
output_file=""
destination=""
environment_json=""
for ((index = 1; index <= $#; index += 1)); do
  value="${@[index]}"
  case "$value" in
    --json-output)
      output_file="${@[$((index + 1))]}"
      ;;
    --destination)
      destination="${@[$((index + 1))]}"
      ;;
    --environment-variables)
      environment_json="${@[$((index + 1))]}"
      ;;
  esac
done
[[ -n "$output_file" ]]
print -r -- "$output_file" >> "${OMF_FAKE_IOS_OUTPUT_LOG:?}"

outcome="${OMF_FAKE_IOS_OUTCOME:-success}"
json_version="${OMF_FAKE_IOS_JSON_VERSION:-3}"
if [[ "$arguments" == *'list devices'* ]]; then
  print -r -- "{\"info\":{\"outcome\":\"$outcome\",\"jsonVersion\":$json_version},\"result\":{\"devices\":[{\"identifier\":\"private-fixture-id\",\"visibilityClass\":\"default\",\"hardwareProperties\":{\"platform\":\"iOS\",\"reality\":\"physical\",\"productType\":\"iPhone18,1\",\"udid\":\"FIXTURE-UDID\"},\"deviceProperties\":{\"osVersionNumber\":\"26.0\",\"developerModeStatus\":\"enabled\",\"ddiServicesAvailable\":true,\"bootState\":\"${OMF_FAKE_IOS_BOOT_STATE:-booted}\"},\"connectionProperties\":{\"pairingState\":\"paired\",\"transportType\":\"${OMF_FAKE_IOS_TRANSPORT:-wired}\",\"tunnelState\":\"connected\"}}]}}" > "$output_file"
elif [[ "$arguments" == *'device process launch'* ]]; then
  nonce="$(print -rn -- "$environment_json" | jq -r '.OMF_DEVICE_DISPLAY_COLLECTOR_NONCE')"
  print -rn -- "$nonce" > "${OMF_FAKE_IOS_STATE_PATH:?}"
  print -r -- '{"info":{"outcome":"success","jsonVersion":3},"result":{}}' > "$output_file"
elif [[ "$arguments" == *'device copy from'* ]]; then
  mkdir -p "$destination"
  nonce="$(<"${OMF_FAKE_IOS_STATE_PATH:?}")"
  if [[ ${OMF_FAKE_IOS_STALE_NONCE:-0} == 1 ]]; then
    nonce="stale"
  fi
  print -r -- "{\"protocolVersion\":1,\"protocolSourceHash\":\"${OMF_FAKE_IOS_SOURCE_HASH:?}\",\"platform\":\"ios\",\"sourceKind\":\"ios26_connected_public_uikit_concentric_corner\",\"nonce\":\"$nonce\",\"physicalWidth\":${OMF_FAKE_IOS_PHYSICAL_WIDTH:-1206},\"physicalHeight\":2622,\"viewPhysicalWidth\":${OMF_FAKE_IOS_PHYSICAL_WIDTH:-1206},\"viewPhysicalHeight\":2622,\"devicePixelRatio\":3,\"viewPaddingLeftPhysical\":0,\"viewPaddingTopPhysical\":180,\"viewPaddingRightPhysical\":0,\"viewPaddingBottomPhysical\":102,\"topLeftRadiusPhysical\":165,\"topRightRadiusPhysical\":165,\"bottomRightRadiusPhysical\":165,\"bottomLeftRadiusPhysical\":165}" > "$destination/record.json"
  print -r -- '{"info":{"outcome":"success","jsonVersion":3},"result":{}}' > "$output_file"
elif [[ "$arguments" == *'device uninstall app'* ]]; then
  print -r -- uninstall >> "${OMF_FAKE_IOS_LIFECYCLE_LOG:?}"
  print -r -- '{"info":{"outcome":"success","jsonVersion":3},"result":{}}' > "$output_file"
else
  print -r -- '{"info":{"outcome":"success","jsonVersion":3},"result":{}}' > "$output_file"
fi
