import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:oh_my_flutter/src/device/device_location/device_location_c_library.dart';

void main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    if (input.config.code.targetOS != OS.iOS) return;

    await DeviceLocationCLibrary.library.build(
      input: input,
      output: output,
    );
  });
}
