import 'package:pigeon/pigeon.dart';

Future<void> main(List<String> arguments) async {
  final basePath = arguments.isEmpty ? null : arguments.single;
  final exitCode = await Pigeon.runWithOptions(
    PigeonOptions(
      input: 'pigeons/native_selectable_text/native_selectable_text.dart',
      swiftOut: 'macos/oh_my_flutter/Sources/oh_my_flutter/NativeSelectableText.g.swift',
      swiftOptions: const SwiftOptions(),
      dartPackageName: 'oh_my_flutter',
      basePath: basePath,
    ),
    mergeDefinitionFileOptions: false,
  );
  if (exitCode != 0) {
    throw StateError('Pigeon exited with status $exitCode.');
  }
}
