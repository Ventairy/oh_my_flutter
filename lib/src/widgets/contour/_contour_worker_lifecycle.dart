part of 'contour.dart';

class _ContourWorkerLifecycle {
  final responses = ReceivePort();
  final exits = ReceivePort();
  final ready = Completer<SendPort>();
  final exited = Completer<void>.sync();
  final pendingIds = <int>{};
  Isolate? isolate;
  SendPort? port;
  bool stopping = false;
}
