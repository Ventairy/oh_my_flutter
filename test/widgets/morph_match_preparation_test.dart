import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../fixtures/morph_paint_probe/morph_paint_probe.dart';
import '../fixtures/morph_targets_test_delegate.dart';

void main() {
  testWidgets('when a rejected push returns through an eligible pop, it should hold the first destination paint', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final decisions = <MorphMatchOperation>[];
    var destinationPaints = 0;
    var flightsStarted = 0;
    final target = MorphTarget(
      tag: 'pop-after-rejection',
      canMatch: (match) {
        decisions.add(match.operation);
        return match.operation == MorphMatchOperation.pop;
      },
    );
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFFFFFFFF),
        navigatorKey: navigatorKey,
        navigatorObservers: [MorphNavigatorObserver()],
        pageRouteBuilder: <T>(settings, builder) =>
            PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
        home: Center(
          child: Morph(
            targets: [target],
            flightConfig: const MorphFlightConfig.custom(MorphTargetsTestDelegate()),
            child: MorphPaintProbe(
              onPaint: () => destinationPaints++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(seconds: 1),
        reverseTransitionDuration: const Duration(seconds: 1),
        transitionsBuilder: (_, _, _, child) => child,
        pageBuilder: (_, _, _) => Center(
          child: Morph(
            targets: [target],
            onStart: () => flightsStarted++,
            flightConfig: const MorphFlightConfig.custom(MorphTargetsTestDelegate()),
            child: const SizedBox(width: 150, height: 150),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    decisions.clear();
    destinationPaints = 0;
    tester.renderObject(find.byType(MorphPaintProbe, skipOffstage: false)).markNeedsPaint();
    navigatorKey.currentState!.pop();
    await tester.pump();
    final firstFramePaints = destinationPaints;
    await tester.pump();
    expect(
      (firstFramePaints, decisions.join(','), flightsStarted),
      (0, 'MorphMatchOperation.pop', 1),
    );
    await tester.pumpAndSettle();
  });

  for (final navigation in [false, true]) {
    testWidgets(
      'when an unselected source alternative matches with navigation=$navigation, it should hold the first paint',
      (tester) async {
        final incoming = ValueNotifier<Widget>(const SizedBox.shrink());
        addTearDown(incoming.dispose);
        final navigatorKey = GlobalKey<NavigatorState>();
        final decisions = <String>[];
        var destinationPaints = 0;
        var flightsStarted = 0;
        final sharedMatch3637 = MorphTarget(
          tag: 'alternative',
          canMatch: (_) {
            decisions.add('source');
            return true;
          },
        );
        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xFFFFFFFF),
            navigatorKey: navigatorKey,
            navigatorObservers: [MorphNavigatorObserver()],
            pageRouteBuilder: <T>(settings, builder) =>
                PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
            home: Stack(
              children: [
                Center(
                  child: Morph(
                    targets: [
                      MorphTarget(tag: 'primary'),
                      sharedMatch3637,
                    ],
                    onStart: () => flightsStarted++,
                    flightConfig: const MorphFlightConfig.custom(MorphTargetsTestDelegate()),
                    child: const SizedBox(width: 100, height: 100),
                  ),
                ),
                ValueListenableBuilder<Widget>(valueListenable: incoming, builder: (_, child, _) => child),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final destination = Center(
          child: Morph(
            targets: [
              sharedMatch3637,
            ],
            flightConfig: const MorphFlightConfig.custom(MorphTargetsTestDelegate()),
            child: MorphPaintProbe(
              onPaint: () => destinationPaints++,
              child: const SizedBox(width: 150, height: 150),
            ),
          ),
        );
        if (navigation) {
          navigatorKey.currentState!.push<void>(
            PageRouteBuilder<void>(
              transitionDuration: const Duration(seconds: 1),
              transitionsBuilder: (_, _, _, child) => child,
              pageBuilder: (_, _, _) => destination,
            ),
          );
        } else {
          incoming.value = destination;
        }
        await tester.pump();
        final firstFramePaints = destinationPaints;
        await tester.pump();
        expect((firstFramePaints, decisions.join(','), flightsStarted), (0, 'source', 1));
        await tester.pumpAndSettle();
      },
    );
  }
}
