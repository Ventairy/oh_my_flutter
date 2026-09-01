import 'dart:io';

import 'interactive_swipe_dismiss_benchmark_validation_command.dart';

/// Validates a captured Flutter log instead of trusting `flutter run`'s exit
/// status.
Future<void> main(List<String> arguments) async {
  const command = InteractiveSwipeDismissBenchmarkValidationCommand();
  exitCode = await command.run(arguments);
}
