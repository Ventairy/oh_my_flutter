import 'dart:io';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('Expected the generated Linux Pigeon source path.');
    exitCode = 64;
    return;
  }

  final file = File(arguments.single);
  const generatedTask = '  GTask* task = g_task_new(self, cancellable, callback, user_data);\n';
  const cancellationSafeTask =
      '''
$generatedTask  // Preserve the lower channel's cancellation result for the generated finish helper.
  g_task_set_check_cancellable(task, FALSE);
''';
  const generatedForward = '  g_task_return_pointer(task, result, g_object_unref);\n';
  const ownershipSafeForward = '''
  // Retain the borrowed result until the deferred finish callback consumes it.
  g_task_return_pointer(task, g_object_ref(result), g_object_unref);
''';
  const generatedFinish = '  GAsyncResult* r = G_ASYNC_RESULT(g_task_propagate_pointer(task, nullptr));\n';
  const ownershipSafeFinish = '''
  // Release the retained nested result after the message-channel finish call.
  g_autoptr(GAsyncResult) r = G_ASYNC_RESULT(g_task_propagate_pointer(task, nullptr));
''';
  final source = file.readAsStringSync();
  final taskCount = RegExp(RegExp.escape(generatedTask)).allMatches(source).length;
  final forwardCount = RegExp(RegExp.escape(generatedForward)).allMatches(source).length;
  final finishCount = RegExp(RegExp.escape(generatedFinish)).allMatches(source).length;
  if (taskCount != 2 || forwardCount != 2 || finishCount != 2) {
    stderr.writeln(
      'Expected two generated Linux Flutter API task sequences; found '
      '$taskCount tasks, $forwardCount forwards, and $finishCount finishes.',
    );
    exitCode = 1;
    return;
  }

  file.writeAsStringSync(
    source
        .replaceAll(generatedTask, cancellationSafeTask)
        .replaceAll(generatedForward, ownershipSafeForward)
        .replaceAll(generatedFinish, ownershipSafeFinish),
  );
}
