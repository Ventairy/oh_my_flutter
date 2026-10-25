import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

/// Controls real native handler barriers through typed test-only entrypoints.
abstract final class ContourNativePortSessionTestSupport {
  /// Reserves a native ticket before arming its handler barrier.
  @Native<Uint64 Function()>(
    symbol: 'ct_np_next_ticket',
    assetId: 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_bindings.dart',
  )
  external static int nextTicket();

  /// Blocks the requested ticket at one native handler stage.
  @Native<Void Function(Uint64, Uint32)>(
    symbol: 'ct_np_test_block',
    assetId: 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_bindings.dart',
  )
  external static void block(int ticket, int stage);

  /// Releases a native handler barrier.
  @Native<Void Function(Uint64)>(
    symbol: 'ct_np_test_release',
    assetId: 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_bindings.dart',
  )
  external static void release(int ticket);

  /// Reads the real phase for one admitted ticket.
  @Native<Uint32 Function(Uint64)>(
    symbol: 'ct_np_test_phase',
    assetId: 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_bindings.dart',
  )
  external static int phase(int ticket);

  /// Waits for a real native handler phase without blocking the Dart isolate.
  static Future<void> waitForPhase(int ticket, int expected) async {
    final clock = Stopwatch()..start();
    while (phase(ticket) != expected) {
      if (clock.elapsed > const Duration(seconds: 10)) {
        throw StateError(
          'Native ticket $ticket did not reach phase $expected.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  /// Creates a transparent RGBA source containing one solid inset rectangle.
  static Uint8List source() {
    final rgba = Uint8List(32 * 32 * 4);
    for (var y = 6; y < 26; y++) {
      for (var x = 6; x < 26; x++) {
        rgba[(y * 32 + x) * 4 + 3] = 255;
      }
    }
    return rgba;
  }
}
