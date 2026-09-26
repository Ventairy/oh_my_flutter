import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('RouteListener', () {
    testWidgets('when mounted on a settled route, it should call onSettled once after the frame', (tester) async {
      var settledCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteListener(onSettled: () => settledCount++, child: const Text('Content')),
          ),
        ),
      );

      expect(settledCount, 0);
      await tester.pump();
      expect(settledCount, 1);
      await tester.pump();
      expect(settledCount, 1);
    });

    testWidgets('when a route enters and leaves, it should report each settled-state change once', (tester) async {
      var settledCount = 0;
      var unsettledCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (routeContext) => Scaffold(
                      body: RouteListener(
                        onSettled: () => settledCount++,
                        onUnsettled: () => unsettledCount++,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(routeContext).pop(),
                          child: const Text('Pop'),
                        ),
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
      expect(settledCount, 0);
      await tester.pumpAndSettle();
      expect(settledCount, 1);

      await tester.tap(find.text('Pop'));
      await tester.pumpAndSettle();
      expect(unsettledCount, 1);
      expect(settledCount, 1);
    });

    testWidgets('when a covering route leaves, it should wait for its exit before settling again', (tester) async {
      var settledCount = 0;
      var unsettledCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  RouteListener(
                    onSettled: () => settledCount++,
                    onUnsettled: () => unsettledCount++,
                    child: const Text('Content'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (routeContext) => Scaffold(
                          body: ElevatedButton(
                            onPressed: () => Navigator.of(routeContext).pop(),
                            child: const Text('Pop'),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Push'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(settledCount, 1);

      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();
      expect(unsettledCount, 1);

      await tester.tap(find.text('Pop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(settledCount, 1);
      await tester.pumpAndSettle();
      expect(settledCount, 2);
    });

    testWidgets('when a navigation gesture is cancelled, it should report un-settle and re-settle', (tester) async {
      var settledCount = 0;
      var unsettledCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteListener(
              onSettled: () => settledCount++,
              onUnsettled: () => unsettledCount++,
              child: const Text('Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigator = Navigator.of(tester.element(find.byType(RouteListener)))..didStartUserGesture();
      await tester.pump();
      expect(unsettledCount, 1);
      navigator.didStopUserGesture();
      await tester.pump();
      expect(settledCount, 2);
    });

    testWidgets('when route state changes twice in one frame, it should report both changes in order', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteListener(
              onSettled: () => events.add('settled'),
              onUnsettled: () => events.add('unsettled'),
              child: const Text('Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(RouteListener)))
        ..didStartUserGesture()
        ..didStopUserGesture();
      await tester.pump();

      expect(events, ['settled', 'unsettled', 'settled']);
    });

    testWidgets('when no route encloses it, it should report settled once', (tester) async {
      var settledCount = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RouteListener(onSettled: () => settledCount++, child: const Text('Content')),
        ),
      );
      await tester.pump();
      expect(settledCount, 1);
    });

    testWidgets('when route state changes, it should not rebuild its child', (tester) async {
      var builds = 0;
      var settledCount = 0;
      final child = Builder(
        builder: (context) {
          builds++;
          return const Text('Content');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteListener(onSettled: () => settledCount++, child: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final originalBuilds = builds;

      final navigator = Navigator.of(tester.element(find.byType(RouteListener)))..didStartUserGesture();
      await tester.pump();
      navigator.didStopUserGesture();
      await tester.pump();

      expect(settledCount, 2);
      expect(builds, originalBuilds);
    });

    testWidgets('when disposed, it should not call onUnsettled', (tester) async {
      var unsettledCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteListener(
              onSettled: () {},
              onUnsettled: () => unsettledCount++,
              child: const Text('Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());

      expect(unsettledCount, 0);
    });
  });
}
