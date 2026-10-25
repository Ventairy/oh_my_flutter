import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour_test_harness.dart';

/// Exercises verified text rendering and two equivalent contour owners.
class ContourNativeTestHarness extends ContourTestHarness {
  /// The first owner of a paired composition.
  final GlobalKey firstKey = GlobalKey();

  /// The second owner of a paired composition.
  final GlobalKey secondKey = GlobalKey();

  /// An opaque glyph fixture available on VM and browser test platforms.
  static const glyph = Text(
    'O',
    style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFFE84A5F)),
  );

  /// Reads a rendering diagnostic without depending on private implementation types.
  Object? diagnostic(String name, {GlobalKey? key}) => (key ?? backdropKey).currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((property) => property.name == name)
      .value;

  /// Mounts equivalent glyphs with room for their expanded edges and shadows.
  Future<void> mountPair(WidgetTester tester) => mount(
    tester,
    color: const Color(0x00000000),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final key in [firstKey, secondKey])
          SizedBox(
            width: 50,
            height: 80,
            child: Center(
              child: Contour(
                key: key,
                color: const Color(0xFFFFFFFF),
                amount: 3,
                shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(1, 2))],
                child: glyph,
              ),
            ),
          ),
      ],
    ),
  );

  /// Captures each half of the paired composition at four pixels per logical pixel.
  Future<(Uint8List, Uint8List)> pairPixels(WidgetTester tester) async {
    final composition = await pixels(tester, pixelRatio: 4);
    final first = BytesBuilder();
    final second = BytesBuilder();
    for (var y = 0; y < 400; y++) {
      first.add(composition.sublist(y * 400 * 4, (y * 400 + 200) * 4));
      second.add(composition.sublist((y * 400 + 200) * 4, (y * 400 + 400) * 4));
    }
    return (first.takeBytes(), second.takeBytes());
  }

  /// The paint overflow bounds of an owner in the paired composition.
  Rect paintBounds(GlobalKey key) => (key.currentContext!.findRenderObject()! as RenderBox).paintBounds;
}
