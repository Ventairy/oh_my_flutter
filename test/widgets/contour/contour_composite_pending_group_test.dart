@TestOn('vm')
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

import 'contour_composite_capture_test_adapter.dart';

void main() {
  late ContourCompositeCaptureTestAdapter adapter;
  late List<ContourController> controllers;
  late List<GlobalKey> keys;
  final calls = <({int id, int width, int height})>[];
  final replied = <int>{};

  Widget tree({
    int count = 40,
    int first = 0,
    double density = 1,
    String text = 'O',
    String? firstText,
    Offset firstPhase = Offset.zero,
    double firstRotation = 0,
    double firstAmount = 3,
    Color firstColor = const Color(0xFFFFFFFF),
    List<Shadow> firstShadows = const [],
    bool opaqueWrapper = false,
  }) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(devicePixelRatio: density),
      child: Center(
        child: SizedBox(
          width: 480,
          height: 240,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = first; index < count; index++)
                Positioned(
                  key: ValueKey(index),
                  left: (index % 8) * 60,
                  top: (index ~/ 8) * 48,
                  width: 60,
                  height: 48,
                  child: Center(
                    child: Transform.translate(
                      offset: index == 0 ? firstPhase : Offset.zero,
                      child: Transform.rotate(
                        angle: index == 0 ? firstRotation : 0,
                        child: Contour(
                          key: keys[index],
                          controller: controllers[index],
                          amount: index == 0 ? firstAmount : 3,
                          color: index == 0 ? firstColor : const Color(0xFFFFFFFF),
                          shadows: index == 0 ? firstShadows : const [],
                          // The zero-effect wrapper deliberately declines the
                          // exact text whitelist, leaving the unshared path.
                          child: opaqueWrapper
                              ? Opacity(
                                  opacity: 1,
                                  child: Text(
                                    index == 0 ? firstText ?? text : text,
                                    style: const TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1),
                                  ),
                                )
                              : Text(
                                  index == 0 ? firstText ?? text : text,
                                  style: const TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> frames(WidgetTester tester) async {
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump();
    }
  }

  void reply(int index) {
    if (!replied.add(index)) return;
    adapter.complete(calls[index].id);
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.idle();
  }

  setUp(() {
    calls.clear();
    replied.clear();
    controllers = List.generate(40, (_) => ContourController());
    keys = List.generate(40, (_) => GlobalKey());
    adapter = ContourCompositeCaptureTestAdapter.test(
      onCapture: (request) {
        calls.add((id: request.id, width: request.width, height: request.height));
      },
    );
    ContourCompositeSource.testOverride = adapter;
  });

  tearDown(() async {
    await adapter.dispose();
    ContourCompositeSource.testOverride = null;
    for (final controller in controllers) {
      controller.dispose();
    }
  });

  for (final text in ['O', '🤔']) {
    testWidgets('when forty identical $text paragraphs are pending, it should submit one source tile', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(tree(text: text));
      await frames(tester);
      final captures = calls.length;
      for (var index = 0; index < calls.length; index++) {
        reply(index);
      }
      await frames(tester);
      final ready = controllers.where((controller) => controller.isReady).length;
      await cleanup(tester);
      expect((captures, ready), (1, 40));
    });
  }

  testWidgets('when the first subscriber is removed, it should preserve the shared work for the others', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    await tester.pumpWidget(tree(first: 1));
    await frames(tester);
    final pending = adapter.pendingCount;
    reply(0);
    await frames(tester);
    final ready = controllers.skip(1).where((controller) => controller.isReady).length;
    final captures = calls.length;
    await cleanup(tester);
    expect((captures, pending, ready), (1, 1, 39));
  });

  testWidgets('when every subscriber is removed, it should cancel the shared capture', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    final captures = calls.length;
    await cleanup(tester);
    expect((captures, adapter.pendingCount), (1, 0));
  });

  testWidgets('when one pending source changes, it should isolate that owner and keep the original group', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    await tester.pumpWidget(tree(firstText: 'X'));
    await frames(tester);
    reply(0);
    await frames(tester);
    final beforeNewReply = (controllers.first.isReady, controllers.skip(1).where((value) => value.isReady).length);
    reply(1);
    await frames(tester);
    final ready = controllers.where((controller) => controller.isReady).length;
    final captures = calls.length;
    await cleanup(tester);
    expect((captures, beforeNewReply, ready), (2, (false, 39), 40));
  });

  testWidgets('when system fonts change while pending, it should prepare one fresh group for the new epoch', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    await tester.binding.handleSystemMessage(<String, Object>{'type': 'fontsChange'});
    await frames(tester);
    final pending = adapter.pendingCount;
    for (var index = 0; index < calls.length; index++) {
      reply(index);
    }
    await frames(tester);
    final captures = calls.length;
    final ready = controllers.where((controller) => controller.isReady).length;
    await cleanup(tester);
    expect((captures, pending, ready), (2, 1, 40));
  });

  for (final (name, phase, rotation, amount, color) in [
    ('fractional phase', const Offset(.25, 0), 0.0, 3.0, const Color(0xFFFFFFFF)),
    ('rest rotation', Offset.zero, .3, 3.0, const Color(0xFFFFFFFF)),
    ('amount', Offset.zero, 0.0, 4.0, const Color(0xFFFFFFFF)),
    ('color', Offset.zero, 0.0, 3.0, const Color(0xFFFF0000)),
  ]) {
    testWidgets('when one paragraph has different $name, it should use a separate source tile', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(tree(firstPhase: phase, firstRotation: rotation, firstAmount: amount, firstColor: color));
      await frames(tester);
      final captures = calls.length;
      await cleanup(tester);
      expect(captures, 2);
    });
  }

  testWidgets('when one paragraph has a different shadow, it should use a separate source tile', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree(firstShadows: const [Shadow(blurRadius: 2, offset: Offset(1, 2))]));
    await frames(tester);
    final captures = calls.length;
    await cleanup(tester);
    expect(captures, 2);
  });

  testWidgets('when density changes while pending, it should replace the old group at the new density', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(tree(density: 2));
    await frames(tester);
    for (var index = 0; index < calls.length; index++) {
      reply(index);
    }
    await frames(tester);
    final actual = (calls.length, controllers.where((controller) => controller.isReady).length);
    await cleanup(tester);
    expect(actual, (2, 40));
  });
}
