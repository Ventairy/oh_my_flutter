import 'dart:io';

import 'morph_benchmark_validation_command.dart';

/// Validates a captured Flutter log instead of trusting `flutter run`'s exit
/// status.
Future<void> main(List<String> arguments) async {
  exitCode = await const MorphBenchmarkValidationCommand().run(arguments);
}
