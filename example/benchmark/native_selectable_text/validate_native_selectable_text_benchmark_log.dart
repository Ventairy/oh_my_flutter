import 'dart:io';

import 'validation_command.dart';

/// Validates one captured NativeSelectableText benchmark log.
Future<void> main(List<String> arguments) async {
  exitCode = await const NativeSelectableTextBenchmarkValidationCommand().run(
    arguments,
  );
}
