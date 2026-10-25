import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../tracing/contour_native_port_bindings.dart';
import '../tracing/contour_native_port_session.dart';
import 'contour_composite_output.dart';

/// Retains native admission through both reply delivery and retirement.
@internal
abstract final class ContourCompositeNativeRequest {
  /// Composes decorations while leaving every original foreground live.
  static Future<ContourCompositeOutput?> run({
    required Uint8List rgba,
    required int width,
    required int height,
    required Float64List tiles,
    required ContourNativePortSession session,
    required Future<void> cancelled,
  }) async {
    final port = ReceivePort('Contour decoration atlas');
    final result = Completer<ContourCompositeOutput?>();
    final ticket = ContourNativePortBindings.nextTicket();
    List<Object?>? terminal;
    var retired = false;
    void finish() {
      if (terminal == null || !retired || result.isCompleted) return;
      result.complete(_decode(terminal!, tiles.length ~/ 25));
    }

    final subscription = port.cast<Object?>().listen((message) {
      if (message is! List<Object?> || message.isEmpty || message[0] != ticket) return;
      if (message.length == 2 && message[1] == 6) {
        retired = true;
      } else {
        terminal = message;
      }
      finish();
    });
    unawaited(
      cancelled.then<void>((_) async {
        await session.close();
        if (!result.isCompleted) result.complete();
      }),
    );
    try {
      final status = ContourNativePortBindings.submitComposite(
        [port.sendPort, session.ownerId, ticket, rgba, width, height, width * 4, tiles, 2],
        session.ownerId,
        ticket,
        rgba.length,
        64 * 1024 * 1024,
      );
      if (status != 0) return null;
      return await result.future;
    } finally {
      await subscription.cancel();
      port.close();
      session.ack(ticket);
    }
  }

  static ContourCompositeOutput? _decode(List<Object?> message, int count) {
    if (message.length != 7 ||
        message[1] != 0 ||
        message[2] is! int ||
        message[3] is! int ||
        message[4] is! Uint8List ||
        message[5] is! Float64List ||
        message[6] is! Float64List) {
      return null;
    }
    final width = message[2]! as int;
    final height = message[3]! as int;
    final rgba = message[4]! as Uint8List;
    final placements = message[5]! as Float64List;
    final metrics = message[6]! as Float64List;
    if (count < 1 ||
        count > 40 ||
        width < 1 ||
        height < 1 ||
        width > 4096 ||
        height > 4096 ||
        width * height > 4 * 1024 * 1024 ||
        rgba.length != width * height * 4 ||
        placements.length != count * 6 ||
        metrics.length != 10 ||
        metrics.any((value) => !value.isFinite)) {
      return null;
    }
    for (var index = 0; index < count; index++) {
      final at = index * 6;
      for (var n = 0; n < 6; n++) {
        final value = placements[at + n];
        if (!value.isFinite || n < 4 && value != value.truncateToDouble()) return null;
      }
      final x = placements[at];
      final y = placements[at + 1];
      final w = placements[at + 2];
      final h = placements[at + 3];
      if (x < 0 || y < 0 || w < 1 || h < 1 || x + w > width || y + h > height) return null;
    }
    return ContourCompositeOutput(width: width, height: height, rgba: rgba, placements: placements);
  }
}
