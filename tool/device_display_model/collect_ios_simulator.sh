#!/bin/zsh

set -euo pipefail

include_legacy=false
canonicalize_only=false
runtime_identifier_override=""
while [[ ${1:-} == --* ]]; do
  case "$1" in
    --include-legacy)
      include_legacy=true
      shift
      ;;
    --canonicalize-only)
      canonicalize_only=true
      shift
      ;;
    --runtime)
      if [[ $# -lt 2 ]]; then
        print -u2 "--runtime requires a simulator runtime identifier."
        exit 64
      fi
      runtime_identifier_override="$2"
      shift 2
      ;;
    *)
      print -u2 "Unknown option: $1"
      exit 64
      ;;
  esac
done
if [[ $# -ne 1 ]]; then
  print -u2 \
    "usage: $0 [--canonicalize-only] [--include-legacy] [--runtime IDENTIFIER] OUTPUT_JSON"
  exit 64
fi

output_path="$1"
script_directory="${0:A:h}"
temporary_directory="$(mktemp -d)"
simulator_udid=""
simulator_udid_pattern='^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'
source "$script_directory/run_with_timeout.zsh"

stable_hash() {
  print -rn "$1" | shasum -a 256 | awk '{print "sha256:" substr($1, 1, 16)}'
}

cleanup_simulator() {
  if [[ -n "$simulator_udid" ]]; then
    run_with_timeout 20 xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
    run_with_timeout 20 xcrun simctl delete "$simulator_udid" >/dev/null 2>&1 || true
    if xcrun simctl list devices --json | jq -e --arg udid "$simulator_udid" \
        '.devices[][] | select(.udid == $udid)' >/dev/null; then
      sleep 1
      run_with_timeout 20 xcrun simctl delete "$simulator_udid" >/dev/null 2>&1 || true
    fi
    simulator_udid=""
  fi
}

cleanup() {
  cleanup_simulator
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

app_directory="$temporary_directory/CornerRadiusCollector.app"
records_directory="$temporary_directory/records"
mkdir -p "$app_directory" "$records_directory"
mkdir -p "${output_path:h}"
cp "$script_directory/ios_collector/Info.plist" "$app_directory/Info.plist"
typeset -A completed_family_hashes
typeset -A canonical_family_by_existing_hash
typeset -A generation_hash_by_family
typeset -A chronology_rank_by_family

while IFS=$'\t' read -r device_type_identifier device_type_bundle_path minimum_runtime_version; do
  legacy_family_hash="$(stable_hash "family:$device_type_identifier")"
  model_identifier="$(
    plutil -extract modelIdentifier raw -o - \
      "$device_type_bundle_path/Contents/Resources/profile.plist" \
      2>/dev/null || true
  )"
  if [[ -n "$model_identifier" ]]; then
    family_hash="$(stable_hash "family-product:$model_identifier")"
  else
    family_hash="$legacy_family_hash"
  fi
  canonical_family_by_existing_hash[$legacy_family_hash]="$family_hash"
  canonical_family_by_existing_hash[$family_hash]="$family_hash"
  if [[ "$minimum_runtime_version" == <-> ]]; then
    generation_hash_by_family[$family_hash]="$(
      stable_hash "generation-min-runtime:$minimum_runtime_version"
    )"
    chronology_rank_by_family[$family_hash]="$minimum_runtime_version"
  fi
done < <(
  xcrun simctl list devicetypes --json |
    jq -r '.devicetypes[] | select(.productFamily == "iPhone") | [.identifier, .bundlePath, (.minRuntimeVersion // "")] | @tsv'
)

write_aggregate() {
  local aggregate_records_directory
  local canonical_observation
  local observation_hash
  aggregate_records_directory="$(
    mktemp -d "$temporary_directory/aggregate-records.XXXXXX"
  )"
  jq -s '
    group_by({
      platform,
      sourceKind,
      physicalWidth,
      physicalHeight,
      devicePixelRatio,
      viewPhysicalWidth,
      viewPhysicalHeight,
      viewPaddingLeftPhysical,
      viewPaddingTopPhysical,
      viewPaddingRightPhysical,
      viewPaddingBottomPhysical,
      systemGestureInsetLeftPhysical,
      systemGestureInsetTopPhysical,
      systemGestureInsetRightPhysical,
      systemGestureInsetBottomPhysical,
      displayCutoutWidthPhysical,
      displayCutoutHeightPhysical,
      displayCutoutCount,
      topRadiusPhysical,
      bottomRadiusPhysical,
      familyGroupHash,
      generationGroupHash,
      oemGroupHash,
      chronologyRank
    } | tojson) |
    map(sort_by([
      .maskCollisionGroupHash == null,
      .viewPhysicalWidth == null,
      .viewPhysicalHeight == null,
      .viewPaddingLeftPhysical == null,
      .viewPaddingTopPhysical == null,
      .viewPaddingRightPhysical == null,
      .viewPaddingBottomPhysical == null
    ]) | first) |
    sort_by(
      .physicalWidth,
      .physicalHeight,
      .topRadiusPhysical,
      .bottomRadiusPhysical,
      .familyGroupHash,
      .generationGroupHash,
      .oemGroupHash,
      .sourceObservationHash
    )
  ' "$records_directory"/*.json > "$aggregate_records_directory/deduplicated.json"

  local aggregate_index=0
  while IFS= read -r record; do
    canonical_observation="$(
      print -r "$record" |
        jq -cS 'del(.maskCollisionGroupHash, .sourceObservationHash)'
    )"
    observation_hash="$(stable_hash "observation:$canonical_observation")"
    print -r "$record" |
      jq --arg observation "$observation_hash" \
        '.sourceObservationHash = $observation' \
        > "$aggregate_records_directory/$aggregate_index.json"
    aggregate_index=$((aggregate_index + 1))
  done < <(jq -c '.[]' "$aggregate_records_directory/deduplicated.json")

  jq -s '
    sort_by(
      .physicalWidth,
      .physicalHeight,
      .topRadiusPhysical,
      .bottomRadiusPhysical,
      .familyGroupHash,
      .generationGroupHash,
      .oemGroupHash,
      .sourceObservationHash
    )
  ' "$aggregate_records_directory"/<->.json > "$aggregate_records_directory/aggregate.json"
  mv "$aggregate_records_directory/aggregate.json" "$output_path"
}

record_index=0
if [[ -s "$output_path" ]]; then
  while IFS= read -r existing_record; do
    existing_family_hash="$(
      print -r "$existing_record" | jq -r '.familyGroupHash // empty'
    )"
    canonical_family_hash="${canonical_family_by_existing_hash[$existing_family_hash]:-$existing_family_hash}"
    existing_record="$(
      print -r "$existing_record" |
        jq --arg family "$canonical_family_hash" '.familyGroupHash = $family'
    )"
    existing_family_hash="$canonical_family_hash"
    existing_generation_hash="${generation_hash_by_family[$existing_family_hash]:-}"
    existing_chronology_rank="${chronology_rank_by_family[$existing_family_hash]:-}"
    existing_record="$(
      print -r "$existing_record" |
        jq \
          --arg generation "$existing_generation_hash" \
          --arg chronology "$existing_chronology_rank" \
          '.generationGroupHash = (if $generation == "" then null else $generation end) |
           .chronologyRank = (if $chronology == "" then null else ($chronology | tonumber) end)'
    )"
    print -r "$existing_record" > "$records_directory/$record_index.json"
    if ! $include_legacy; then
      completed_family_hash="$(
        print -r "$existing_record" |
          jq -r '
            select(
              .viewPhysicalWidth != null and
              .viewPhysicalHeight != null and
              .viewPaddingLeftPhysical != null and
              .viewPaddingTopPhysical != null and
              .viewPaddingRightPhysical != null and
              .viewPaddingBottomPhysical != null
            ) |
            .familyGroupHash // empty
          '
      )"
      if [[ -n "$completed_family_hash" ]]; then
        completed_family_hashes[$completed_family_hash]=1
      fi
    fi
    record_index=$((record_index + 1))
  done < <(jq -c '.[]' "$output_path")
  print -u2 "Resuming with $record_index previously collected records."
fi
if $canonicalize_only; then
  if [[ $record_index -eq 0 ]]; then
    print -u2 "No existing simulator record was available to canonicalize."
    exit 1
  fi
  write_aggregate
  print -u2 "Canonicalized $record_index anonymous numeric records."
  exit 0
fi

if [[ -n "$runtime_identifier_override" ]]; then
  runtime_identifiers="$runtime_identifier_override"
elif $include_legacy; then
  runtime_identifiers="$(
    xcrun simctl list runtimes --json |
      jq -r '.runtimes[] | select(.isAvailable == true and .platform == "iOS") | .identifier'
  )"
else
  runtime_identifiers="$(
    xcrun simctl list runtimes --json |
      jq -r '[.runtimes[] | select(.isAvailable == true and .platform == "iOS" and (.version | startswith("26.")))] | sort_by(.version) | last | .identifier // empty'
  )"
fi
if [[ -z "$runtime_identifiers" ]]; then
  print -u2 "No requested iOS simulator runtime was found."
  exit 1
fi

sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"
architecture="$(uname -m)"
xcrun --sdk iphonesimulator clang \
  -fobjc-arc \
  -fmodules \
  -isysroot "$sdk_path" \
  -mios-simulator-version-min=15.0 \
  -target "$architecture-apple-ios15.0-simulator" \
  -framework UIKit \
  "$script_directory/ios_collector/main.m" \
  "$script_directory/ios_collector/corner_radius_collector_app_delegate.m" \
  -o "$app_directory/CornerRadiusCollector"
codesign --force --sign - "$app_directory" >/dev/null
while IFS= read -r runtime_identifier; do
while IFS=$'\t' read -r device_type_identifier device_type_bundle_path minimum_runtime_version; do
  legacy_family_hash="$(stable_hash "family:$device_type_identifier")"
  family_hash="${canonical_family_by_existing_hash[$legacy_family_hash]:-$legacy_family_hash}"
  if ! $include_legacy && [[ -n ${completed_family_hashes[$family_hash]:-} ]]; then
    continue
  fi
  simulator_udid="$(
    run_with_timeout 30 xcrun simctl create \
      "OMF-Corner-Radius-Collector-$$-$record_index" \
      "$device_type_identifier" \
      "$runtime_identifier" 2>/dev/null || true
  )"
  if [[ ! "$simulator_udid" =~ $simulator_udid_pattern ]]; then
    simulator_udid=""
    continue
  fi

  print -u2 "Collecting simulator $((record_index + 1))..."
  if ! run_with_timeout 30 xcrun simctl boot "$simulator_udid"; then
    print -u2 "Skipping simulator: boot did not finish within 30 seconds."
    cleanup_simulator
    continue
  fi
  if ! run_with_timeout 120 xcrun simctl bootstatus "$simulator_udid" -b >/dev/null; then
    print -u2 "Skipping simulator: boot readiness did not finish within 120 seconds."
    cleanup_simulator
    continue
  fi
  if ! run_with_timeout 60 xcrun simctl install "$simulator_udid" "$app_directory"; then
    print -u2 "Skipping simulator: installation did not finish within 60 seconds."
    cleanup_simulator
    continue
  fi
  if ! run_with_timeout 15 xcrun simctl launch \
      --terminate-running-process \
      "$simulator_udid" \
      dev.ventairy.oh-my-flutter.corner-radius-collector >/dev/null; then
    print -u2 "Continuing after simulator launch exceeded 15 seconds."
  fi

  container_path="$(
    run_with_timeout 30 xcrun simctl get_app_container \
      "$simulator_udid" \
      dev.ventairy.oh-my-flutter.corner-radius-collector \
      data 2>/dev/null || true
  )"
  if [[ -z "$container_path" ]]; then
    print -u2 "Skipping simulator: app container was unavailable."
    cleanup_simulator
    continue
  fi
  record_path="$container_path/Documents/record.json"
  for attempt in {1..100}; do
    if [[ -s "$record_path" ]]; then
      generation_rank="${chronology_rank_by_family[$family_hash]:-}"
      generation_hash="${generation_hash_by_family[$family_hash]:-}"
      oem_hash="$(stable_hash "oem:apple")"
      mask_value="$(
        plutil -extract framebufferMask raw -o - \
          "$device_type_bundle_path/Contents/Resources/profile.plist" \
          2>/dev/null || true
      )"
      mask_hash=""
      if [[ -n "$mask_value" ]]; then
        mask_hash="$(stable_hash "framebuffer-mask:$mask_value")"
      fi
      observation_hash="$(
        record_digest="$(shasum -a 256 "$record_path" | awk '{print $1}')"
        stable_hash "observation:$runtime_identifier:$device_type_identifier:$record_digest"
      )"
      jq \
        --arg family "$family_hash" \
        --arg generation "$generation_hash" \
        --arg oem "$oem_hash" \
        --arg mask "$mask_hash" \
        --arg observation "$observation_hash" \
        --arg chronology "$generation_rank" \
        '. + {
          familyGroupHash: $family,
          generationGroupHash: (if $generation == "" then null else $generation end),
          oemGroupHash: $oem,
          maskCollisionGroupHash: (if $mask == "" then null else $mask end),
          chronologyRank: (if $chronology == "" then null else ($chronology | tonumber) end),
          sourceObservationHash: $observation
        }' \
        "$record_path" > "$records_directory/$record_index.json"
      record_index=$((record_index + 1))
      if ! $include_legacy; then
        completed_family_hashes[$family_hash]=1
      fi
      write_aggregate
      break
    fi
    sleep 0.1
  done
  cleanup_simulator
done < <(
  xcrun simctl list devicetypes --json |
    jq -r '.devicetypes[] | select(.productFamily == "iPhone") | [.identifier, .bundlePath, (.minRuntimeVersion // "")] | @tsv'
)
done <<< "$runtime_identifiers"

if [[ $record_index -eq 0 ]]; then
  print -u2 "No compatible iPhone simulator produced an exact record."
  exit 1
fi

write_aggregate
print -u2 "Collected $record_index anonymous numeric records."
