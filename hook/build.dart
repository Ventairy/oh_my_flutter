import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:oh_my_flutter/src/device/device_location/device_location_c_library.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_c_library.dart';

Future<void> main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final target = input.config.code.targetOS;
    if (target == OS.iOS) {
      await DeviceLocationCLibrary.library.build(input: input, output: output);
    }
    if (ContourNativePortCLibrary.supports(target)) {
      await ContourNativePortCLibrary.build(
        input: input,
        output: output,
      );
    }
  });
}
