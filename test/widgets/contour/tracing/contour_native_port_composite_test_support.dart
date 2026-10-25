import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_bindings.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session.dart';

/// Exercises the packaged composite binding with an owned native session.
abstract final class ContourNativePortCompositeTestSupport {
  /// Waits for both a composite reply and its native retirement before ACK.
  ///
  /// Malformed packet options exercise rejection without changing the source.
  static Future<
    ({
      int status,
      int width,
      int height,
      Uint8List rgba,
      Float64List placements,
    })
  >
  submit(
    ContourNativePortSession session, {
    bool? obsoleteForegroundField,
    bool missingWorkers = false,
    bool malformedDescriptor = false,
    int workers = 2,
    Uint8List? rgba,
    int width = 32,
    int height = 32,
    Float64List? tiles,
  }) async {
    final source = rgba ?? Uint8List(width * height * 4);
    if (rgba == null) {
      for (var y = 8; y < 24; y++) {
        for (var x = 8; x < 24; x++) {
          final offset = (y * width + x) * 4;
          source[offset] = 255;
          source[offset + 3] = 255;
        }
      }
    }
    // A transparent contour and no shadows expose accidental foreground copies.
    // Amount zero is unsupported by the native compositor, so retain amount two.
    final descriptor =
        (malformedDescriptor && tiles != null ? Float64List.fromList(tiles) : tiles) ??
        (Float64List(25)
          ..[2] = width.toDouble()
          ..[3] = height.toDouble()
          ..[4] = 3
          ..[5] = 3
          ..[6] = 2);
    if (malformedDescriptor) descriptor[0] = double.nan;
    final ticket = ContourNativePortBindings.nextTicket();
    final replies = ReceivePort();
    final completion = Completer<List<Object?>>();
    List<Object?>? result;
    var retired = false;
    replies.listen((message) {
      if (completion.isCompleted) return;
      if (message case [final int key, 6] when key == ticket) {
        retired = true;
      } else if (message
          case [
            final int key,
            int _,
            int _,
            int _,
            Uint8List _,
            Float64List _,
            Float64List _,
          ]
          when key == ticket) {
        result = message;
      } else {
        completion.completeError(
          StateError('Unexpected native composite reply.'),
        );
      }
      if (!completion.isCompleted && retired && result != null) {
        completion.complete(result);
      }
    });
    try {
      final admission = ContourNativePortBindings.submitComposite(
        <Object>[
          replies.sendPort,
          session.ownerId,
          ticket,
          source,
          width,
          height,
          width * 4,
          descriptor,
          if (!missingWorkers) workers,
          ?obsoleteForegroundField,
        ],
        session.ownerId,
        ticket,
        source.lengthInBytes,
        64 * 1024 * 1024,
      );
      if (admission != 0) {
        throw StateError('Native composite admission failed: $admission');
      }
      final fields = await completion.future.timeout(
        const Duration(seconds: 10),
      );
      return (
        status: fields[1]! as int,
        width: fields[2]! as int,
        height: fields[3]! as int,
        rgba: fields[4]! as Uint8List,
        placements: fields[5]! as Float64List,
      );
    } finally {
      replies.close();
      session.ack(ticket);
    }
  }

  /// Creates forty arbitrary surfaces with different RGB and equal alpha.
  ///
  /// [differingAlphaAndStyle] changes one alpha plane and one contour amount.
  static ({
    Uint8List rgba,
    int width,
    int height,
    Float64List tiles,
    List<int> colors,
  })
  coloredBatch({bool differingAlphaAndStyle = false}) {
    const width = 256;
    const height = 160;
    final rgba = Uint8List(width * height * 4);
    final tiles = Float64List(40 * 25);
    final colors = <int>[];
    for (var tile = 0; tile < 40; tile++) {
      final left = tile % 8 * 32;
      final top = tile ~/ 8 * 32;
      final red = (tile + 1) * 3;
      final green = 255 - tile * 2;
      final blue = tile * 5;
      colors.add(red << 16 | green << 8 | blue);
      for (var y = 8; y < 24; y++) {
        for (var x = 8; x < 24; x++) {
          final offset = ((top + y) * width + left + x) * 4;
          rgba[offset] = red;
          rgba[offset + 1] = green;
          rgba[offset + 2] = blue;
          rgba[offset + 3] = 255;
        }
      }
      if (differingAlphaAndStyle && tile == 1) {
        // A connected protrusion changes alpha while retaining the same style.
        for (var y = 14; y < 18; y++) {
          final offset = ((top + y) * width + left + 7) * 4;
          rgba[offset] = red;
          rgba[offset + 1] = green;
          rgba[offset + 2] = blue;
          rgba[offset + 3] = 255;
        }
      }
      final row = tile * 25;
      tiles[row] = left.toDouble();
      tiles[row + 1] = top.toDouble();
      tiles[row + 2] = 32;
      tiles[row + 3] = 32;
      tiles[row + 4] = 3;
      tiles[row + 5] = 3;
      tiles[row + 6] = differingAlphaAndStyle && tile == 2 ? 3 : 2;
      tiles[row + 7] = 0xffffffff;
      tiles[row + 8] = 1;
      tiles[row + 9] = 1.5;
      tiles[row + 10] = 1;
      tiles[row + 11] = 2;
      tiles[row + 12] = 0x44000000;
    }
    return (
      rgba: rgba,
      width: width,
      height: height,
      tiles: tiles,
      colors: colors,
    );
  }

  /// Counts independently allocated atlas placements, including local origins.
  static int uniquePlacementCount(Float64List placements) => {
    for (var offset = 0; offset < placements.length; offset += 6)
      (
        placements[offset],
        placements[offset + 1],
        placements[offset + 2],
        placements[offset + 3],
        placements[offset + 4],
        placements[offset + 5],
      ),
  }.length;

  /// Counts opaque output pixels by their original RGB color.
  static Map<int, int> opaquePixelCounts(Uint8List rgba) {
    final counts = <int, int>{};
    for (var offset = 0; offset < rgba.length; offset += 4) {
      if (rgba[offset + 3] != 255) continue;
      final color = rgba[offset] << 16 | rgba[offset + 1] << 8 | rgba[offset + 2];
      counts.update(color, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}
