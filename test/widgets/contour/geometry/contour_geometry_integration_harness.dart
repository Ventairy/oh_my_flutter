import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../../../../example/benchmark/contour/contour_benchmark_generic_artwork.dart';
import '../contour_test_harness.dart';

/// Exercises generic composed children through the real capture and shadow path.
class ContourGeometryIntegrationHarness {
  /// The complete composition available for pixel comparison.
  final GlobalKey boundaryKey = GlobalKey();

  /// Stable owners for source reuse and content-change regressions.
  final keys = List<GlobalKey>.generate(40, (_) => GlobalKey());

  /// Mounts repeated or distinct generic widget artwork with optional shadows.
  Future<void> mount(WidgetTester tester, {bool unique = false, bool shadows = true, double amount = 4}) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 3),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: 500,
                height: 400,
                child: ColoredBox(
                  color: const Color(0xFFEAEAEA),
                  child: Wrap(
                    children: [
                      for (var i = 0; i < keys.length; i++)
                        SizedBox(
                          width: 50,
                          height: 80,
                          child: Center(
                            child: Contour(
                              key: keys[i],
                              color: i % 3 == 0 ? const Color(0x80FF7733) : const Color(0xFFFFFFFF),
                              amount: amount,
                              shadows: shadows
                                  ? const [Shadow(color: Color(0x55000000), offset: Offset(0, 3), blurRadius: 6)]
                                  : const [],
                              child: ContourBenchmarkGenericArtwork(variant: unique ? i : i % 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
  }

  /// Reads one source owner's existing rendering diagnostics.
  Object? property(int index, String name) => keys[index].currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((property) => property.name == name)
      .value;

  /// Counts distinct nonempty identities across the mounted owners.
  int unique(String name) => keys.indexed.map((entry) => property(entry.$1, name)).toSet().length;
}
