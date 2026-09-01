import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/device_display_model/device_display_model.dart';
import 'device_display_model_test_process.dart';

void main() {
  group('device display model collector', () {
    test('when an iOS public record is supplied, it should import numeric evidence only', () async {
      final temporaryDirectory = Directory.systemTemp.createTempSync(
        'omf-display-collector-test-',
      );
      addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
      final output = File('${temporaryDirectory.path}/corpus.json');

      final result = await DeviceDisplayModelTestProcess.run([
        'dart',
        'run',
        'tool/device_display_model/device_display_model.dart',
        'collect',
        '--ios-record',
        'test/tool/device_display_model/fixtures/ios_record.json',
        '--output',
        output.path,
      ]);
      final corpus = jsonDecode(output.readAsStringSync()) as Map<String, Object?>;
      final records = corpus['records']! as List<Object?>;
      final iosRecords = records
          .map((value) => value! as Map<String, Object?>)
          .where((record) => record['platform'] == 'ios')
          .toList();

      expect(
        <Object?>[
          result.exitCode,
          iosRecords.length,
          iosRecords.single['viewPhysicalWidth'],
          iosRecords.single['viewPhysicalHeight'],
          iosRecords.single.keys.any(
            (key) => RegExp(
              'manufacturer|model|deviceName|identifier',
              caseSensitive: false,
            ).hasMatch(key),
          ),
        ],
        <Object?>[0, 1, null, null, false],
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'when equivalent iOS observations have different provenance hashes, '
      'it should retain one mask-grouped record',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-collector-deduplication-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final fixture = jsonDecode(
          File(
            'test/tool/device_display_model/fixtures/ios_record.json',
          ).readAsStringSync(),
        ) as Map<String, Object?>;
        final input = File('${temporaryDirectory.path}/observations.json')
          ..writeAsStringSync(
            jsonEncode(<Object?>[
              <String, Object?>{
                ...fixture,
                'sourceObservationHash': 'sha256:old-run-hash',
              },
              <String, Object?>{
                ...fixture,
                'maskCollisionGroupHash': DeviceDisplayModelEncoding.groupFingerprint('mask-group'),
                'sourceObservationHash': 'sha256:new-run-hash',
              },
            ]),
          );
        final output = File('${temporaryDirectory.path}/corpus.json');

        final result = await DeviceDisplayModelTestProcess.run([
          'dart',
          'run',
          'tool/device_display_model/device_display_model.dart',
          'collect',
          '--ios-record',
          input.path,
          '--output',
          output.path,
        ]);
        final records = (jsonDecode(output.readAsStringSync()) as Map<String, Object?>)['records']! as List<Object?>;
        final iosRecords = records
            .map((value) => value! as Map<String, Object?>)
            .where((record) => record['platform'] == 'ios')
            .toList();

        expect(
          <Object?>[
            result.exitCode,
            iosRecords.length,
            iosRecords.single['maskCollisionGroupHash'],
            iosRecords.single['sourceObservationHash'],
          ],
          <Object?>[
            0,
            1,
            DeviceDisplayModelEncoding.groupFingerprint('mask-group'),
            matches(RegExp(r'^fnv1a64:[0-9a-f]{16}$')),
          ],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when imported iOS geometry or provenance is malformed, it should reject the observation',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-ios-import-validation-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final fixture = jsonDecode(
          File(
            'test/tool/device_display_model/fixtures/ios_record.json',
          ).readAsStringSync(),
        ) as Map<String, Object?>;
        final input = File('${temporaryDirectory.path}/observations.json')
          ..writeAsStringSync(
            jsonEncode(<Object?>[
              fixture,
              <String, Object?>{...fixture, 'topRadiusPhysical': 10000},
              <String, Object?>{
                ...fixture,
                'viewPhysicalWidth': 2000,
                'viewPhysicalHeight': 2500,
              },
              <String, Object?>{
                ...fixture,
                'viewPaddingLeftPhysical': -1,
              },
              <String, Object?>{
                ...fixture,
                'familyGroupHash': 'sha256:not-a-digest',
              },
              <String, Object?>{...fixture, 'chronologyRank': 1.5},
            ]),
          );
        final output = File('${temporaryDirectory.path}/corpus.json');

        final result = await DeviceDisplayModelTestProcess.run(<String>[
          'dart',
          'run',
          'tool/device_display_model/device_display_model.dart',
          'collect',
          '--ios-record',
          input.path,
          '--output',
          output.path,
        ]);
        final iosRecords =
            ((jsonDecode(output.readAsStringSync()) as Map<String, Object?>)['records']! as List<Object?>)
                .map((value) => value! as Map<String, Object?>)
                .where(
                  (record) => record['sourceKind'] == 'ios26_public_uikit_concentric_corner',
                )
                .toList();

        expect(
          <Object?>[result.exitCode, iosRecords.length],
          <Object?>[0, 1],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when API 31 reports zero corners, it should retain square truth without fabricating Flutter metrics',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-android-collector-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final sdk = Directory('${temporaryDirectory.path}/sdk')..createSync();
        final platformTools = Directory('${sdk.path}/platform-tools')..createSync(recursive: true);
        final commandLineTools = Directory('${sdk.path}/cmdline-tools/latest/bin')..createSync(recursive: true);
        final skin = Directory('${sdk.path}/skins/Fixture-Skin')..createSync(recursive: true);
        final avd = Directory('${temporaryDirectory.path}/fixture.avd')..createSync();
        final collectorApk = File('${temporaryDirectory.path}/collector.apk')
          ..writeAsStringSync(
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          );
        final collectorState = File('${temporaryDirectory.path}/collector-state');
        final adb = File(
          'test/tool/device_display_model/fixtures/fake_adb.sh',
        ).copySync('${platformTools.path}/adb');
        final avdManager = File(
          'test/tool/device_display_model/fixtures/fake_avdmanager.sh',
        ).copySync('${commandLineTools.path}/avdmanager');
        final apkAnalyzer = File(
          'test/tool/device_display_model/fixtures/fake_apkanalyzer.sh',
        ).copySync('${commandLineTools.path}/apkanalyzer');
        await Process.run('chmod', [
          '+x',
          adb.path,
          avdManager.path,
          apkAnalyzer.path,
        ]);
        File('${skin.path}/layout').writeAsStringSync('''
display {
  width 1080
  height 2400
  corner_radius 120
}
''');
        File('${avd.path}/config.ini').writeAsStringSync('''
hw.device.name=Fixture-Skin
hw.lcd.density=480
hw.lcd.width=1080
hw.lcd.height=2400
image.sysdir.1=system-images;android-35;default;arm64-v8a
''');
        final firstOutput = File('${temporaryDirectory.path}/api31.json');
        final environment = <String, String>{
          ...Platform.environment,
          'ANDROID_HOME': sdk.path,
          'ANDROID_SDK_ROOT': sdk.path,
          'OMF_FAKE_AVD_PATH': avd.path,
          'OMF_FAKE_ANDROID_API_LEVEL': '31',
          'OMF_FAKE_ANDROID_STATE_PATH': collectorState.path,
          'OMF_DEVICE_DISPLAY_ALLOW_TEST_COLLECTOR': '1',
          'OMF_DEVICE_DISPLAY_ANDROID_COLLECTOR_TEST_APK': collectorApk.path,
          'OMF_DEVICE_DISPLAY_ANDROID_COLLECTOR_TEST_SOURCE_HASH':
              'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'OMF_FAKE_ANDROID_SOURCE_HASH': 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        };
        final api31Result = await DeviceDisplayModelTestProcess.run(
          <String>[
            'dart',
            'run',
            'tool/device_display_model/device_display_model.dart',
            'collect',
            '--output',
            firstOutput.path,
          ],
          environment: environment,
        );
        final api31Records =
            (jsonDecode(firstOutput.readAsStringSync()) as Map<String, Object?>)['records']! as List<Object?>;
        final connected = api31Records
            .map((value) => value! as Map<String, Object?>)
            .singleWhere(
              (record) => record['sourceKind'] == 'android_api31_window_insets',
            );
        final joinedSkin = api31Records
            .map((value) => value! as Map<String, Object?>)
            .singleWhere(
              (record) => record['sourceKind'] == 'android_sdk_skin_avd_join',
            );
        final secondOutput = File('${temporaryDirectory.path}/api30.json');
        final api30Result = await DeviceDisplayModelTestProcess.run(
          <String>[
            'dart',
            'run',
            'tool/device_display_model/device_display_model.dart',
            'collect',
            '--output',
            secondOutput.path,
          ],
          environment: <String, String>{
            ...environment,
            'OMF_FAKE_ANDROID_API_LEVEL': '30',
          },
        );
        final api30Records =
            (jsonDecode(secondOutput.readAsStringSync()) as Map<String, Object?>)['records']! as List<Object?>;
        final emulatorOutput = File(
          '${temporaryDirectory.path}/emulator.json',
        );
        final emulatorResult = await DeviceDisplayModelTestProcess.run(
          <String>[
            'dart',
            'run',
            'tool/device_display_model/device_display_model.dart',
            'collect',
            '--output',
            emulatorOutput.path,
          ],
          environment: <String, String>{
            ...environment,
            'OMF_FAKE_ANDROID_IS_EMULATOR': '1',
          },
        );
        final emulatorCorpus = jsonDecode(emulatorOutput.readAsStringSync()) as Map<String, Object?>;
        final emulatorInventory =
            (emulatorCorpus['inventory']! as Map<String, Object?>)['android']! as Map<String, Object?>;
        final emulatorRecords = emulatorCorpus['records']! as List<Object?>;
        final failedProbeOutput = File(
          '${temporaryDirectory.path}/failed-probe.json',
        );
        final failedProbeResult = await DeviceDisplayModelTestProcess.run(
          <String>[
            'dart',
            'run',
            'tool/device_display_model/device_display_model.dart',
            'collect',
            '--output',
            failedProbeOutput.path,
          ],
          environment: <String, String>{
            ...environment,
            'OMF_FAKE_ANDROID_QEMU_PROBE_FAILURE': '1',
          },
        );
        final failedProbeCorpus = jsonDecode(failedProbeOutput.readAsStringSync()) as Map<String, Object?>;
        final failedProbeInventory =
            (failedProbeCorpus['inventory']! as Map<String, Object?>)['android']! as Map<String, Object?>;
        final failedProbeRecords = failedProbeCorpus['records']! as List<Object?>;
        final foldedOutput = File(
          '${temporaryDirectory.path}/folded.json',
        );
        final foldedResult = await DeviceDisplayModelTestProcess.run(
          <String>[
            'dart',
            'run',
            'tool/device_display_model/device_display_model.dart',
            'collect',
            '--output',
            foldedOutput.path,
          ],
          environment: <String, String>{
            ...environment,
            'OMF_FAKE_ANDROID_HAS_FOLD_OR_HINGE': 'true',
          },
        );
        final foldedRecords =
            (jsonDecode(foldedOutput.readAsStringSync()) as Map<String, Object?>)['records']! as List<Object?>;
        File('${avd.path}/config.ini').writeAsStringSync('''
hw.device.name=Fixture-Skin
hw.lcd.density=480
hw.lcd.width=1200
hw.lcd.height=2400
image.sysdir.1=system-images;android-35;default;arm64-v8a
''');
        final mismatchedAvdOutput = File(
          '${temporaryDirectory.path}/mismatched-avd.json',
        );
        final mismatchedAvdResult = await DeviceDisplayModelTestProcess.run(
          <String>[
            'dart',
            'run',
            'tool/device_display_model/device_display_model.dart',
            'collect',
            '--output',
            mismatchedAvdOutput.path,
          ],
          environment: <String, String>{
            ...environment,
            'OMF_FAKE_ANDROID_IS_EMULATOR': '1',
          },
        );
        final mismatchedAvdRecords =
            (jsonDecode(mismatchedAvdOutput.readAsStringSync()) as Map<String, Object?>)['records']! as List<Object?>;

        expect(
          <Object?>[
            api31Result.exitCode,
            connected['cornerClassification'],
            connected['labelAuthority'],
            connected['sourceApiLevel'],
            connected['viewPhysicalWidth'],
            connected['viewPaddingTopPhysical'],
            connected['systemGestureInsetBottomPhysical'],
            connected['displayCutoutWidthPhysical'],
            connected['displayCutoutHeightPhysical'],
            connected['displayCutoutCount'],
            joinedSkin['devicePixelRatio'],
            joinedSkin['sourceApiLevel'],
            joinedSkin['oemGroupHash'],
            joinedSkin['generationGroupHash'],
            joinedSkin['chronologyRank'],
            connected['oemGroupHash'] is String,
            connected['generationGroupHash'],
            connected['chronologyRank'],
            api30Result.exitCode,
            api30Records
                .map((value) => value! as Map<String, Object?>)
                .any(
                  (record) => record['sourceKind'] == 'android_api31_window_insets',
                ),
            emulatorResult.exitCode,
            emulatorInventory['connectedEmulatorDeviceCount'],
            emulatorInventory['connectedCollectorAttemptCount'],
            emulatorRecords
                .map((value) => value! as Map<String, Object?>)
                .any(
                  (record) => record['sourceKind'] == 'android_api31_window_insets',
                ),
            failedProbeResult.exitCode,
            failedProbeInventory['connectedEligibleDeviceCount'],
            failedProbeInventory['connectedCollectorAttemptCount'],
            failedProbeRecords
                .map((value) => value! as Map<String, Object?>)
                .any(
                  (record) => record['sourceKind'] == 'android_api31_window_insets',
                ),
            foldedResult.exitCode,
            foldedRecords
                .map((value) => value! as Map<String, Object?>)
                .any(
                  (record) => record['sourceKind'] == 'android_api31_window_insets',
                ),
            mismatchedAvdResult.exitCode,
            mismatchedAvdRecords
                .map((value) => value! as Map<String, Object?>)
                .any(
                  (record) => record['sourceKind'] == 'android_sdk_skin_avd_join',
                ),
          ],
          <Object?>[
            0,
            'square',
            'android_api31_window_insets',
            31,
            1080,
            88,
            144,
            56,
            88,
            1,
            3.0,
            35,
            null,
            null,
            null,
            true,
            null,
            null,
            0,
            false,
            0,
            1,
            0,
            false,
            0,
            0,
            0,
            false,
            0,
            false,
            0,
            false,
          ],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when the expected hash exists outside a stale BuildConfig field, it should reject the Android collector',
      () async {
        const expectedHash = 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const staleHash = 'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-android-apk-provenance-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final sdk = Directory('${temporaryDirectory.path}/sdk')..createSync();
        final platformTools = Directory(
          '${sdk.path}/platform-tools',
        )..createSync(recursive: true);
        final adb = File(
          'test/tool/device_display_model/fixtures/fake_adb.sh',
        ).copySync('${platformTools.path}/adb');
        final apkAnalyzer = File(
          'test/tool/device_display_model/fixtures/fake_apkanalyzer.sh',
        ).absolute;
        await Process.run('chmod', <String>['+x', adb.path, apkAnalyzer.path]);
        final collectorApk = File('${temporaryDirectory.path}/collector.apk')
          ..writeAsStringSync('$staleHash\nunrelated=$expectedHash\n');
        final output = File('${temporaryDirectory.path}/corpus.json');

        final result = await DeviceDisplayModelTestProcess.run(
          <String>[
            'dart',
            'run',
            'tool/device_display_model/device_display_model.dart',
            'collect',
            '--output',
            output.path,
          ],
          environment: <String, String>{
            ...Platform.environment,
            'ANDROID_HOME': sdk.path,
            'ANDROID_SDK_ROOT': sdk.path,
            'OMF_FAKE_ANDROID_API_LEVEL': '31',
            'OMF_FAKE_ANDROID_STATE_PATH': '${temporaryDirectory.path}/collector-state',
            'OMF_DEVICE_DISPLAY_ALLOW_TEST_COLLECTOR': '1',
            'OMF_DEVICE_DISPLAY_ANDROID_COLLECTOR_TEST_APK': collectorApk.path,
            'OMF_DEVICE_DISPLAY_ANDROID_COLLECTOR_TEST_SOURCE_HASH': expectedHash,
            'OMF_DEVICE_DISPLAY_APKANALYZER': apkAnalyzer.path,
            'OMF_FAKE_ANDROID_SOURCE_HASH': expectedHash,
          },
        );
        final corpus = jsonDecode(output.readAsStringSync()) as Map<String, Object?>;
        final inventory = (corpus['inventory']! as Map<String, Object?>)['android']! as Map<String, Object?>;
        final records = corpus['records']! as List<Object?>;

        expect(
          <Object?>[
            result.exitCode,
            inventory['connectedEligibleDeviceCount'],
            inventory['connectedCollectorAttemptCount'],
            inventory['connectedCollectorFailureCount'],
            inventory['collectorSourceHash'],
            records.any(
              (value) => (value! as Map<String, Object?>)['sourceKind'] == 'android_api31_window_insets',
            ),
          ],
          <Object?>[0, 1, 0, 1, null, false],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when a pre-31 default display has positive framework radii, it should retain only legacy label evidence',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-android-legacy-collector-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final sdk = Directory('${temporaryDirectory.path}/sdk')..createSync();
        final platformTools = Directory(
          '${sdk.path}/platform-tools',
        )..createSync(recursive: true);
        final commandLineTools = Directory(
          '${sdk.path}/cmdline-tools/latest/bin',
        )..createSync(recursive: true);
        final adb = File(
          'test/tool/device_display_model/fixtures/fake_adb.sh',
        ).copySync('${platformTools.path}/adb');
        final apkAnalyzer = File(
          'test/tool/device_display_model/fixtures/fake_apkanalyzer.sh',
        ).copySync('${commandLineTools.path}/apkanalyzer');
        await Process.run('chmod', <String>[
          '+x',
          adb.path,
          apkAnalyzer.path,
        ]);
        final collectorApk = File('${temporaryDirectory.path}/collector.apk')
          ..writeAsStringSync(
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          );
        final output = File('${temporaryDirectory.path}/corpus.json');

        final result = await DeviceDisplayModelTestProcess.run(
          <String>[
            'dart',
            'run',
            'tool/device_display_model/device_display_model.dart',
            'collect',
            '--output',
            output.path,
          ],
          environment: <String, String>{
            ...Platform.environment,
            'ANDROID_HOME': sdk.path,
            'ANDROID_SDK_ROOT': sdk.path,
            'OMF_FAKE_ANDROID_API_LEVEL': '30',
            'OMF_FAKE_ANDROID_STATE_PATH': '${temporaryDirectory.path}/collector-state',
            'OMF_DEVICE_DISPLAY_ALLOW_TEST_COLLECTOR': '1',
            'OMF_DEVICE_DISPLAY_ANDROID_COLLECTOR_TEST_APK': collectorApk.path,
            'OMF_DEVICE_DISPLAY_ANDROID_COLLECTOR_TEST_SOURCE_HASH':
                'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'OMF_FAKE_ANDROID_SOURCE_HASH': 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'OMF_FAKE_ANDROID_LEGACY_TOP_RADIUS': '96',
            'OMF_FAKE_ANDROID_LEGACY_BOTTOM_RADIUS': '72',
          },
        );
        final records = (jsonDecode(output.readAsStringSync()) as Map<String, Object?>)['records']! as List<Object?>;
        final connected = records
            .map((value) => value! as Map<String, Object?>)
            .singleWhere(
              (record) => record['sourceKind'] == 'android_legacy_default_display_resource',
            );

        expect(
          <Object?>[
            result.exitCode,
            connected['topRadiusPhysical'],
            connected['bottomRadiusPhysical'],
            connected['cornerClassification'],
            connected['viewPhysicalWidth'],
            connected['viewPaddingTopPhysical'],
            connected['systemGestureInsetBottomPhysical'],
            connected['displayCutoutCount'],
          ],
          <Object?>[0, 96, 72, 'rounded', null, null, null, null],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when simulator command descendants ignore termination, it should stop and clean the process tree',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-simulator-process-tree-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final childPidFile = File('${temporaryDirectory.path}/child.pid');
        addTearDown(() async {
          if (childPidFile.existsSync()) {
            await Process.run('kill', <String>[
              '-KILL',
              childPidFile.readAsStringSync().trim(),
            ]);
          }
        });
        final timeoutHelper = File(
          'tool/device_display_model/run_with_timeout.zsh',
        ).absolute;
        final hangingCommand = File(
          'test/tool/device_display_model/fixtures/fake_adb.sh',
        ).absolute;
        final stopwatch = Stopwatch()..start();

        final result = await Process.run(
          'zsh',
          <String>[
            '-c',
            r'source "$1"; shift; run_with_timeout 1 "$@"',
            'omf-simulator-timeout-test',
            timeoutHelper.path,
            hangingCommand.path,
            '-s',
            'fixture',
            'shell',
            'getprop',
            'ro.kernel.qemu',
          ],
          environment: <String, String>{
            ...Platform.environment,
            'OMF_FAKE_ANDROID_QEMU_PROBE_HANG': '1',
            'OMF_FAKE_ANDROID_HANG_CHILD_PID_PATH': childPidFile.path,
          },
        );
        stopwatch.stop();
        final childIsAlive =
            childPidFile.existsSync() &&
            (await Process.run('kill', <String>[
                  '-0',
                  childPidFile.readAsStringSync().trim(),
                ])).exitCode ==
                0;

        expect(
          <Object?>[
            result.exitCode != 0,
            childPidFile.existsSync(),
            childIsAlive,
            stopwatch.elapsed < const Duration(seconds: 5),
          ],
          <Object?>[true, true, false, true],
        );
      },
      skip: Platform.isMacOS ? false : 'The iOS simulator collector requires macOS.',
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'when a collector command ignores termination and keeps pipes open, it should stop within the bounded grace period',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-bounded-process-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final sdk = Directory('${temporaryDirectory.path}/sdk')..createSync();
        final platformTools = Directory(
          '${sdk.path}/platform-tools',
        )..createSync(recursive: true);
        final commandLineTools = Directory(
          '${sdk.path}/cmdline-tools/latest/bin',
        )..createSync(recursive: true);
        final adb = File(
          'test/tool/device_display_model/fixtures/fake_adb.sh',
        ).copySync('${platformTools.path}/adb');
        final apkAnalyzer = File(
          'test/tool/device_display_model/fixtures/fake_apkanalyzer.sh',
        ).copySync('${commandLineTools.path}/apkanalyzer');
        await Process.run('chmod', <String>[
          '+x',
          adb.path,
          apkAnalyzer.path,
        ]);
        final childPidFile = File('${temporaryDirectory.path}/child.pid');
        final output = File('${temporaryDirectory.path}/corpus.json');
        addTearDown(() async {
          if (childPidFile.existsSync()) {
            await Process.run('kill', <String>[
              '-KILL',
              childPidFile.readAsStringSync().trim(),
            ]);
          }
        });
        final stopwatch = Stopwatch()..start();

        final result = await DeviceDisplayModelTestProcess.run(
          <String>[
            'dart',
            'run',
            'tool/device_display_model/device_display_model.dart',
            'collect',
            '--output',
            output.path,
          ],
          environment: <String, String>{
            ...Platform.environment,
            'ANDROID_HOME': sdk.path,
            'ANDROID_SDK_ROOT': sdk.path,
            'OMF_DEVICE_DISPLAY_ALLOW_TEST_COLLECTOR': '1',
            'OMF_DEVICE_DISPLAY_XCRUN': File(
              'test/tool/device_display_model/fixtures/fake_xcrun.sh',
            ).absolute.path,
            'OMF_DEVICE_DISPLAY_PROCESS_TIMEOUT_MS': '500',
            'OMF_FAKE_ANDROID_QEMU_PROBE_HANG': '1',
            'OMF_FAKE_ANDROID_HANG_CHILD_PID_PATH': childPidFile.path,
          },
        );
        stopwatch.stop();
        final childIsAlive =
            childPidFile.existsSync() &&
            (await Process.run('kill', <String>[
                  '-0',
                  childPidFile.readAsStringSync().trim(),
                ])).exitCode ==
                0;
        final inventory =
            ((jsonDecode(output.readAsStringSync()) as Map<String, Object?>)['inventory']!
                    as Map<String, Object?>)['android']!
                as Map<String, Object?>;

        expect(
          <Object?>[
            result.exitCode,
            inventory['connectedEligibleDeviceCount'],
            inventory['connectedCollectorAttemptCount'],
            childPidFile.existsSync(),
            childIsAlive,
            stopwatch.elapsed < const Duration(seconds: 5),
          ],
          <Object?>[0, 0, 0, true, false, true],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when the collector reports four portrait corners, it should preserve natural head asymmetry',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-android-corner-pair-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final sdk = Directory('${temporaryDirectory.path}/sdk')..createSync();
        final platformTools = Directory(
          '${sdk.path}/platform-tools',
        )..createSync(recursive: true);
        final commandLineTools = Directory(
          '${sdk.path}/cmdline-tools/latest/bin',
        )..createSync(recursive: true);
        final adb = File(
          'test/tool/device_display_model/fixtures/fake_adb.sh',
        ).copySync('${platformTools.path}/adb');
        final apkAnalyzer = File(
          'test/tool/device_display_model/fixtures/fake_apkanalyzer.sh',
        ).copySync('${commandLineTools.path}/apkanalyzer');
        await Process.run('chmod', <String>[
          '+x',
          adb.path,
          apkAnalyzer.path,
        ]);
        final collectorApk = File('${temporaryDirectory.path}/collector.apk')
          ..writeAsStringSync(
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          );
        final output = File('${temporaryDirectory.path}/corpus.json');

        final result = await DeviceDisplayModelTestProcess.run(
          <String>[
            'dart',
            'run',
            'tool/device_display_model/device_display_model.dart',
            'collect',
            '--output',
            output.path,
          ],
          environment: <String, String>{
            ...Platform.environment,
            'ANDROID_HOME': sdk.path,
            'ANDROID_SDK_ROOT': sdk.path,
            'OMF_FAKE_ANDROID_API_LEVEL': '31',
            'OMF_FAKE_ANDROID_STATE_PATH': '${temporaryDirectory.path}/collector-state',
            'OMF_DEVICE_DISPLAY_ALLOW_TEST_COLLECTOR': '1',
            'OMF_DEVICE_DISPLAY_ANDROID_COLLECTOR_TEST_APK': collectorApk.path,
            'OMF_DEVICE_DISPLAY_ANDROID_COLLECTOR_TEST_SOURCE_HASH':
                'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'OMF_FAKE_ANDROID_SOURCE_HASH': 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'OMF_FAKE_ANDROID_TOP_LEFT_RADIUS': '40',
            'OMF_FAKE_ANDROID_TOP_RIGHT_RADIUS': '60',
            'OMF_FAKE_ANDROID_BOTTOM_RIGHT_RADIUS': '20',
            'OMF_FAKE_ANDROID_BOTTOM_LEFT_RADIUS': '30',
          },
        );
        final records = (jsonDecode(output.readAsStringSync()) as Map<String, Object?>)['records']! as List<Object?>;
        final connected = records
            .map((value) => value! as Map<String, Object?>)
            .singleWhere(
              (record) => record['sourceKind'] == 'android_api31_window_insets',
            );

        expect(
          <Object?>[
            result.exitCode,
            connected['topRadiusPhysical'],
            connected['bottomRadiusPhysical'],
            connected['cornerClassification'],
          ],
          <Object?>[0, 50, 25, 'rounded'],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when portrait rotation cannot be verified, it should reject the connected label',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-android-rotation-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final sdk = Directory('${temporaryDirectory.path}/sdk')..createSync();
        final platformTools = Directory(
          '${sdk.path}/platform-tools',
        )..createSync(recursive: true);
        final adb = File(
          'test/tool/device_display_model/fixtures/fake_adb.sh',
        ).copySync('${platformTools.path}/adb');
        await Process.run('chmod', <String>['+x', adb.path]);
        final collectorApk = File('${temporaryDirectory.path}/collector.apk')
          ..writeAsStringSync(
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          );
        final output = File('${temporaryDirectory.path}/corpus.json');

        final result = await DeviceDisplayModelTestProcess.run(
          <String>[
            'dart',
            'run',
            'tool/device_display_model/device_display_model.dart',
            'collect',
            '--output',
            output.path,
          ],
          environment: <String, String>{
            ...Platform.environment,
            'ANDROID_HOME': sdk.path,
            'ANDROID_SDK_ROOT': sdk.path,
            'OMF_FAKE_ANDROID_API_LEVEL': '31',
            'OMF_FAKE_ANDROID_STATE_PATH': '${temporaryDirectory.path}/collector-state',
            'OMF_DEVICE_DISPLAY_ALLOW_TEST_COLLECTOR': '1',
            'OMF_DEVICE_DISPLAY_ANDROID_COLLECTOR_TEST_APK': collectorApk.path,
            'OMF_DEVICE_DISPLAY_ANDROID_COLLECTOR_TEST_SOURCE_HASH':
                'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'OMF_FAKE_ANDROID_SOURCE_HASH': 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'OMF_FAKE_ANDROID_ROTATION': '1',
          },
        );
        final records = (jsonDecode(output.readAsStringSync()) as Map<String, Object?>)['records']! as List<Object?>;

        expect(
          <Object?>[
            result.exitCode,
            records
                .map((value) => value! as Map<String, Object?>)
                .any(
                  (record) => record['sourceKind'] == 'android_api31_window_insets',
                ),
          ],
          <Object?>[0, false],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when a signed iOS collector is supplied, it should validate eligibility provenance payload and cleanup',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-ios-device-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final sdk = Directory('${temporaryDirectory.path}/sdk')..createSync();
        final binaries = Directory('${temporaryDirectory.path}/bin')..createSync();
        final devicectl = File(
          'test/tool/device_display_model/fixtures/fake_devicectl.sh',
        ).copySync('${binaries.path}/devicectl');
        final codesign = File(
          'test/tool/device_display_model/fixtures/fake_codesign.sh',
        ).copySync('${binaries.path}/codesign');
        final security = File(
          'test/tool/device_display_model/fixtures/fake_security.sh',
        ).copySync('${binaries.path}/security');
        final plutil = File(
          'test/tool/device_display_model/fixtures/fake_plutil.sh',
        ).copySync('${binaries.path}/plutil');
        final xcrun = File(
          'test/tool/device_display_model/fixtures/fake_xcrun.sh',
        ).copySync('${binaries.path}/xcrun');
        await Process.run('chmod', <String>[
          '+x',
          devicectl.path,
          codesign.path,
          security.path,
          plutil.path,
          xcrun.path,
        ]);
        final sourceHeader = File(
          'tool/device_display_model/ios_device_collector/collector_source_hash.h',
        ).readAsStringSync();
        final sourceHash = RegExp(
          'sha256:[0-9a-f]{64}',
        ).firstMatch(sourceHeader)!.group(0)!;
        final app = Directory('${temporaryDirectory.path}/Collector.app')..createSync();
        File('${app.path}/Info.plist').writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.ventairy.oh-my-flutter.device-display-collector</string>
<key>CFBundleExecutable</key><string>DeviceDisplayCollector</string>
<key>MinimumOSVersion</key><string>26.0</string>
</dict></plist>
''');
        File('${app.path}/DeviceDisplayCollector').writeAsStringSync(
          'public collector $sourceHash',
        );
        File('${app.path}/embedded.mobileprovision').writeAsStringSync(
          'fixture profile',
        );
        final state = File('${temporaryDirectory.path}/state');
        final outputLog = File('${temporaryDirectory.path}/outputs');
        final lifecycleLog = File('${temporaryDirectory.path}/lifecycle');
        final commonEnvironment = <String, String>{
          ...Platform.environment,
          'PATH': '${binaries.path}:${Platform.environment['PATH']}',
          'ANDROID_HOME': sdk.path,
          'ANDROID_SDK_ROOT': sdk.path,
          'OMF_DEVICE_DISPLAY_ALLOW_TEST_COLLECTOR': '1',
          'OMF_DEVICE_DISPLAY_DEVICETL': devicectl.path,
          'OMF_DEVICE_DISPLAY_XCRUN': xcrun.path,
          'OMF_FAKE_IOS_SOURCE_HASH': sourceHash,
          'OMF_FAKE_IOS_STATE_PATH': state.path,
          'OMF_FAKE_IOS_OUTPUT_LOG': outputLog.path,
          'OMF_FAKE_IOS_LIFECYCLE_LOG': lifecycleLog.path,
        };

        Future<({ProcessResult result, Map<String, Object?> corpus})> collect(
          String name, {
          Map<String, String> environment = const <String, String>{},
        }) async {
          final output = File('${temporaryDirectory.path}/$name.json');
          final result = await DeviceDisplayModelTestProcess.run(
            <String>[
              'dart',
              'run',
              'tool/device_display_model/device_display_model.dart',
              'collect',
              '--ios-device-app',
              app.path,
              '--output',
              output.path,
            ],
            environment: <String, String>{
              ...commonEnvironment,
              ...environment,
            },
          );
          return (
            result: result,
            corpus: jsonDecode(output.readAsStringSync()) as Map<String, Object?>,
          );
        }

        final success = await collect('success');
        final stale = await collect(
          'stale',
          environment: const <String, String>{
            'OMF_FAKE_IOS_STALE_NONCE': '1',
          },
        );
        final invalidGeometry = await collect(
          'geometry',
          environment: const <String, String>{
            'OMF_FAKE_IOS_PHYSICAL_WIDTH': '2000',
          },
        );
        final invalidProfile = await collect(
          'profile',
          environment: const <String, String>{
            'OMF_FAKE_IOS_PROFILE_BUNDLE': 'invalid.bundle',
          },
        );
        final invalidSchema = await collect(
          'schema',
          environment: const <String, String>{
            'OMF_FAKE_IOS_JSON_VERSION': '2',
          },
        );
        final shutdown = await collect(
          'shutdown',
          environment: const <String, String>{
            'OMF_FAKE_IOS_BOOT_STATE': 'shutdown',
          },
        );

        Map<String, Object?> apple(
          ({ProcessResult result, Map<String, Object?> corpus}) value,
        ) => (value.corpus['inventory']! as Map<String, Object?>)['apple']! as Map<String, Object?>;
        final successApple = apple(success);
        final successRecord = (success.corpus['records']! as List<Object?>)
            .map((value) => value! as Map<String, Object?>)
            .singleWhere(
              (record) => record['sourceKind'] == 'ios26_connected_public_uikit_concentric_corner',
            );
        final temporaryOutputsWereRemoved = outputLog.readAsLinesSync().every(
          (path) => !File(path).parent.existsSync(),
        );

        expect(
          <Object?>[
            success.result.exitCode,
            successApple['connectedDeviceCount'],
            successApple['connectedEligibleDeviceCount'],
            successApple['connectedCollectorAttemptCount'],
            successApple['connectedLabelCount'],
            successApple['connectedCollectorFailureCount'],
            successApple['connectedCollectorSourceHash'],
            successRecord['familyGroupHash'],
            successRecord['oemGroupHash'],
            successRecord['generationGroupHash'],
            successRecord['chronologyRank'],
            jsonEncode(successRecord).contains('private-fixture-id'),
            apple(stale)['connectedCollectorFailureCount'],
            apple(invalidGeometry)['connectedCollectorFailureCount'],
            apple(invalidProfile)['connectedCollectorAttemptCount'],
            apple(invalidProfile)['connectedCollectorFailureCount'],
            apple(invalidSchema)['connectedDeviceCount'],
            apple(shutdown)['connectedEligibleDeviceCount'],
            lifecycleLog.readAsLinesSync().length,
            temporaryOutputsWereRemoved,
          ],
          <Object?>[
            0,
            1,
            1,
            1,
            1,
            0,
            sourceHash,
            DeviceDisplayModelEncoding.groupFingerprint(
              'family-product:iPhone18,1',
            ),
            DeviceDisplayModelEncoding.groupFingerprint('oem:apple'),
            DeviceDisplayModelEncoding.groupFingerprint(
              'generation-min-runtime:1703936',
            ),
            1703936,
            false,
            1,
            1,
            0,
            1,
            0,
            0,
            3,
            true,
          ],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }, skip: Platform.isWindows ? 'Collector process fixtures require Unix platform tools.' : false);
}
