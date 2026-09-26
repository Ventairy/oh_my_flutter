import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  for (final zIndex in [-1.0, 1.0]) {
    testWidgets('when a route flight starts with node depth $zIndex, it should paint at that depth', (tester) async {
      final target = MorphTarget(tag: 'route-node');
      final navigatorKey = GlobalKey<NavigatorState>();
      var builderCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [MorphNavigatorObserver()],
          home: Scaffold(
            body: Morph(targets: [target], child: const SizedBox(width: 100, height: 100)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigatorKey.currentState!.push<void>(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
            body: Stack(
              children: [
                Morph(targets: [target], child: const SizedBox(width: 120, height: 120)),
                MorphNode(
                  target: target,
                  zIndex: zIndex,
                  transitionBuilder: (context, child, curved, uncurved) {
                    builderCalls += 1;
                    return FadeTransition(opacity: uncurved, child: child);
                  },
                  child: const Text('stationary content'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final projected = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MorphNodePaint');
      final overlayStack = tester.widget<Stack>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Stack &&
              widget.children.any((child) => child is KeyedSubtree && child.key is ValueKey<Object>) &&
              widget.children.any((child) => child is Positioned && child.key is ObjectKey),
        ),
      );
      final nodeIndex = overlayStack.children.indexWhere((child) => child is Positioned && child.key is ObjectKey);
      final flightIndex = overlayStack.children.indexWhere((child) => child is KeyedSubtree);
      expect(
        (projected.evaluate().length, builderCalls > 0, nodeIndex.compareTo(flightIndex)),
        (1, true, zIndex < 0 ? -1 : 1),
      );
      await tester.pumpAndSettle();
      expect(projected, findsNothing);
    });
  }

  testWidgets('when a local flight starts, it should project every node sharing its target', (tester) async {
    final target = MorphTarget(tag: 'local-node');
    final destination = ValueNotifier(false);
    addTearDown(destination.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [MorphNavigatorObserver()],
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: destination,
            builder: (context, expanded, child) => Stack(
              children: [
                Align(
                  alignment: expanded ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    key: ValueKey(expanded),
                    targets: [target],
                    child: const SizedBox(width: 100, height: 100),
                  ),
                ),
                MorphNode(target: target, zIndex: 1, child: const Text('local content')),
                MorphNode(target: target, zIndex: 2, child: const Text('second node')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    destination.value = true;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MorphNodePaint'), findsNWidgets(2));
    await tester.pumpAndSettle();
  });

  testWidgets('when the destination scrolls during a flight, its node should follow without settling', (tester) async {
    final target = MorphTarget(tag: 'scroll-node');
    final navigatorKey = GlobalKey<NavigatorState>();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [MorphNavigatorObserver()],
        home: Scaffold(
          body: Morph(targets: [target], child: const SizedBox(width: 100, height: 100)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
          body: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                Morph(targets: [target], child: const SizedBox(width: 120, height: 120)),
                MorphNode(target: target, zIndex: 1, child: const SizedBox(width: 120, height: 120)),
                const SizedBox(height: 1500),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final projected = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MorphNodePaint');
    final before = tester.getTopLeft(projected).dy;
    scrollController.jumpTo(40);
    await tester.pump();
    expect(tester.getTopLeft(projected).dy, closeTo(before - 40, 0.1));
    await tester.pumpAndSettle();
  });
}
