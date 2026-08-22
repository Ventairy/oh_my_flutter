import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:oh_my_flutter/src/device/device_location/device_location_c_library.dart';

void main(List<String> arguments) async {
  await link(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    if (input.config.code.targetOS != OS.iOS) return;

    final recordedUses = input.recordedUses;
    if (recordedUses == null) {
      throw UnsupportedError(
        'DeviceLocation requires Flutter 3.47 or newer, Dart 3.13 or newer, '
        'and Flutter record-use support to remain enabled so unused iOS '
        'location code can be removed from application builds.',
      );
    }
    if (!DeviceLocationCLibrary.isReachable(recordedUses)) return;

    await DeviceLocationCLibrary.library.link(
      input: input,
      output: output,
      linkerOptions: LinkerOptions.treeshake(symbolsToKeep: null),
    );
  });
}
