import 'dart:io';

final class DeviceDisplayModelTestProcess {
  const DeviceDisplayModelTestProcess._();

  static Future<ProcessResult> run(
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
  }) => Process.run(
    'fvm',
    arguments,
    environment: environment,
    workingDirectory: workingDirectory,
    runInShell: Platform.isWindows,
  );
}
