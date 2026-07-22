import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

final Finder _settledFinder = find.byType(RouteSettled);

Widget _fade(Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child);

FadeTransition _fadeWithinSettled(WidgetTester tester) => tester.widget<FadeTransition>(
  find.descendant(
    of: _settledFinder,
    matching: find.byType(FadeTransition),
  ),
);

Visibility _visibilityWithinSettled(WidgetTester tester) => tester.widget<Visibility>(
  find.descendant(
    of: _settledFinder,
    matching: find.byType(Visibility),
  ),
);

Widget _app(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: child),
  ),
);

void main() {
  group('RouteSettled', () {
    testWidgets('when built inside a settled route, it should show the child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const RouteSettled(showTransition: _fade, child: Text('X')),
        ),
      );
      await tester.pumpAndSettle();

      expect(_fadeWithinSettled(tester).opacity.value, 1);
    });

    testWidgets(
      'when mounted during a route push, it should stay hidden until the push settles',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(
                        body: RouteSettled(
                          showTransition: _fade,
                          child: Text('X'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Push'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Push'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        expect(_visibilityWithinSettled(tester).visible, isFalse);

        await tester.pumpAndSettle();
        expect(_fadeWithinSettled(tester).opacity.value, 1);
      },
    );

    testWidgets(
      'when the route begins to pop without a hide transition, it should hide instantly',
      (tester) async {
        await tester.pumpWidget(_pushableRoute());
        await tester.tap(find.text('Push'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pop'));
        await tester.pump();

        expect(_visibilityWithinSettled(tester).visible, isFalse);
      },
    );

    testWidgets(
      'when a navigation gesture starts and stops, it should hide and show the child',
      (tester) async {
        await tester.pumpWidget(_pushableRoute(showTransition: _fade));
        await tester.tap(find.text('Push'));
        await tester.pumpAndSettle();

        final navigator = Navigator.of(tester.element(_settledFinder))..didStartUserGesture();
        await tester.pump();
        expect(_visibilityWithinSettled(tester).visible, isFalse);

        navigator.didStopUserGesture();
        await tester.pumpAndSettle();
        expect(_fadeWithinSettled(tester).opacity.value, 1);
      },
    );

    testWidgets(
      'when independent transitions are provided, it should use the hide transition and timing',
      (tester) async {
        await tester.pumpWidget(
          _pushableRoute(
            showTransition: _fade,
            hideTransition: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            hideDuration: const Duration(milliseconds: 100),
          ),
        );
        await tester.tap(find.text('Push'));
        await tester.pumpAndSettle();

        Navigator.of(tester.element(_settledFinder)).didStartUserGesture();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final scale = tester.widget<ScaleTransition>(
          find.descendant(
            of: _settledFinder,
            matching: find.byType(ScaleTransition),
          ),
        );
        expect(scale.scale.value, closeTo(0.5, 0.01));
      },
    );

    testWidgets(
      'when custom show timing is provided, it should honor the duration',
      (tester) async {
        await tester.pumpWidget(
          _app(
            const RouteSettled(
              showTransition: _fade,
              showDuration: Duration(milliseconds: 100),
              child: Text('X'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(_fadeWithinSettled(tester).opacity.value, closeTo(0.5, 0.01));
      },
    );

    testWidgets(
      'when reduced motion is requested, it should show immediately',
      (tester) async {
        await tester.pumpWidget(
          _app(
            const RouteSettled(showTransition: _fade, child: Text('X')),
            disableAnimations: true,
          ),
        );
        await tester.pump();

        expect(_visibilityWithinSettled(tester).visible, isTrue);
        expect(
          find.descendant(
            of: _settledFinder,
            matching: find.byType(FadeTransition),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'when the child changes, it should keep the current visibility state',
      (tester) async {
        await tester.pumpWidget(_app(const RouteSettled(child: Text('A'))));
        await tester.pumpAndSettle();

        await tester.pumpWidget(_app(const RouteSettled(child: Text('B'))));

        expect(find.text('B'), findsOneWidget);
        expect(_visibilityWithinSettled(tester).visible, isTrue);
      },
    );

    testWidgets(
      'when no enclosing route exists, it should treat the child as settled',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: RouteSettled(child: Text('X')),
          ),
        );
        await tester.pump();

        expect(_visibilityWithinSettled(tester).visible, isTrue);
      },
    );
  });
}

Widget _pushableRoute({
  Widget Function(Widget child, Animation<double> animation)? showTransition,
  Widget Function(Widget child, Animation<double> animation)? hideTransition,
  Duration hideDuration = Duration.zero,
}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (routeContext) => Scaffold(
              body: Column(
                children: [
                  RouteSettled(
                    showTransition: showTransition,
                    hideTransition: hideTransition,
                    hideDuration: hideDuration,
                    child: const Text('X'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(routeContext).maybePop(),
                    child: const Text('Pop'),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: const Text('Push'),
      ),
    ),
  ),
);
