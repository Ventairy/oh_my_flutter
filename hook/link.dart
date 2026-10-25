import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:oh_my_flutter/src/device/device_location/device_location_c_library.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_c_library.dart';

Future<void> main(List<String> arguments) async {
  await link(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final target = input.config.code.targetOS;
    if (target == OS.iOS) {
      final recordedUses = input.recordedUses;
      if (recordedUses == null) {
        throw UnsupportedError(
          'DeviceLocation requires Flutter record-use support '
          'to remain enabled so unused iOS '
          'location code can be removed from application builds.',
        );
      }
      if (DeviceLocationCLibrary.isReachable(recordedUses)) {
        await DeviceLocationCLibrary.library.link(
          input: input,
          output: output,
          linkerOptions: LinkerOptions.treeshake(symbolsToKeep: null),
        );
      }
    }
    if (ContourNativePortCLibrary.supports(target) && ContourNativePortCLibrary.isReachable(input.recordedUses)) {
      await ContourNativePortCLibrary.link(
        input: input,
        output: output,
        linkerOptions: LinkerOptions.treeshake(symbolsToKeep: null),
      );
    }
  });
}
