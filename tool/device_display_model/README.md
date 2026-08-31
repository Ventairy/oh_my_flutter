# Device display model tooling

This excluded tooling collects anonymous numeric display observations, trains
the deterministic corner-radius estimator, regenerates the shipping constants,
and reproduces the validation report. It never maintains a device-radius
catalog and never uses framebuffer masks as labels.

## Collect local evidence

Run the complete opt-in collection from the repository root:

```sh
tool/device_display_model/collect_device_display_model.sh
```

The command resumes and auto-enumerates the selected local iOS 26 simulator
runtime, then inventories Android SDK skins, compatible AVD configurations,
connected physical Android devices, and connected physical iPhones. It builds
the excluded Android collector from the committed source manifest before any
eligible physical-device attempt. API 31+ observations use public
`WindowInsets.getRoundedCorner`; API 24-30 observations accept only positive,
unambiguous default-display framework resources. ADB emulators are excluded
from the connected-hardware path.

To inspect or resume only the simulator evidence:

```sh
tool/device_display_model/collect_ios_simulator.sh \
  tool/device_display_model/evidence/ios26_simulator_records.json
tool/device_display_model/collect_ios_simulator.sh --canonicalize-only \
  tool/device_display_model/evidence/ios26_simulator_records.json
```

Each ephemeral simulator operation is bounded. The collector checkpoints
canonical anonymous records after each success and shuts down and deletes its
ephemeral simulator on success, failure, or interruption.

## Optional connected iOS labels

`devicectl` cannot expose the radius. Hardware collection therefore requires a
separately built, public-iOS-26-only, caller-signed app. Building and signing is
explicit because automatic provisioning can mutate Apple account or device
state. Supply an existing matching development profile and signing identity;
the script never creates or downloads either:

```sh
tool/device_display_model/build_ios_device_display_collector.sh \
  --signing-identity "Apple Development: …" \
  --provisioning-profile /absolute/path/Collector.mobileprovision \
  --output /absolute/path/DeviceDisplayCollector.app

DEVICE_DISPLAY_IOS_COLLECTOR_APP=/absolute/path/DeviceDisplayCollector.app \
  tool/device_display_model/collect_device_display_model.sh
```

The default accepts only wired, booted, paired, trusted, developer-mode iPhones
running iOS 26 or later. Set
`OMF_DEVICE_DISPLAY_ALLOW_NETWORK_IOS_DEVICES=1` only when intentionally
collecting over a connected local-network tunnel. The app source manifest and
embedded hash, code signature, provisioning App ID and target device,
public-only token scan, nonce, phone geometry, and numeric payload are checked
before import. The supplied signed binary remains trusted local evidence; no
claim of reproducible Apple code signing is made. The app is uninstalled after
every install attempt.

Raw ADB/devicectl identifiers, serials, device names, provisioning identities,
and command output remain only in mode-0700 temporary state. The committed
corpus stores numeric observables and stable anonymous groups. It does not store
raw model, manufacturer, serial, UDID, host, team, or profile names.

## Regenerate and validate

```sh
tool/device_display_model/generate_device_display_model.sh
tool/device_display_model/validate_device_display_model.sh
tool/device_display_model/validate_device_display_collectors.sh
tool/device_display_model/check_device_display_publish_archive.sh
```

The portable model check reproduces corpus -> manifest -> Dart artifact ->
report byte-for-byte and validates both collector source manifests. The
collector validator additionally assembles and lints the Android helper. On
macOS it also checks the generated public-iOS source hash and compiles the iOS
source against the installed iPhoneOS SDK. Collection itself is deliberately
outside normal `check` commands because it boots simulators and can install
temporary apps on explicitly connected devices.

The committed [`validation_report.md`](validation_report.md) is authoritative
for the labels, inventory counts, split availability, measured errors, and
limitations of the current local corpus. Missing evidence is reported as
missing; no accuracy result is fabricated.
