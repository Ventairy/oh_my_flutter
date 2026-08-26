import 'dart:io';

import 'skeleton_benchmark_validation_command.dart';

/// Validates a captured Flutter log instead of trusting `flutter run`'s exit
/// status.
Future<void> main(List<String> arguments) async {
  exitCode = await const SkeletonBenchmarkValidationCommand().run(arguments);
}
