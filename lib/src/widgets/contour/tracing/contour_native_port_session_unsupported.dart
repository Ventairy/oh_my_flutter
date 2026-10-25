import 'dart:typed_data';

import 'contour_native_port_result.dart';

/// Keeps NativePort tracing unavailable without loading native bindings.
final class ContourNativePortSession {
  new _();

  /// Reports whether this platform supports NativePort tracing.
  static bool get isSupported => false;

  /// Reports that this platform is not an Android native tracing host.
  static bool get isAndroid => false;

  /// Returns no session on unsupported platforms.
  static ContourNativePortSession? create() => null;

  /// Returns no native owner on an unsupported platform.
  int get ownerId => 0;

  /// Returns no pending tickets on an unsupported platform.
  List<int> get pendingTickets => const [];

  /// Returns no native diagnostics without initializing bindings.
  Map<String, int> get stats => const {};

  /// Rejects tracing on an unsupported platform.
  Future<ContourNativePortResult?> trace(
    Uint8List rgba, {
    required int width,
    required int height,
    required double pixelRatio,
    required int totalQuota,
    int? ticket,
  }) => throw UnsupportedError(
    'NativePort contour tracing is unavailable on this platform.',
  );

  /// Has no native admission to release on an unsupported platform.
  void ack(int ticket) {}

  /// Has no native ownership to close on an unsupported platform.
  Future<void> close() => Future<void>.value();
}
