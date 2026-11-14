import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'morph_tag_status/tag_status_scene.dart';

void main() {
  testWidgets('when a shared route is preparing, it should conceal its resting destination', (tester) async {
    final scene = TagStatusScene();
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.push();
    await tester.pump();
    expect((scene.route.concealed, scene.route.translation), (true, Offset.zero));
    await tester.pumpAndSettle();
  });

  testWidgets('when a shared route is flying, it should keep its destination at rest', (tester) async {
    final scene = TagStatusScene();
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.push();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      (scene.route.status.value, scene.route.concealed, scene.route.translation),
      (MorphTagStatus.flying, false, Offset.zero),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('when a shared route completes, it should never enable its slide', (tester) async {
    final scene = TagStatusScene();
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.push();
    await tester.pumpAndSettle();
    expect((scene.route.status.value, scene.route.translation), (MorphTagStatus.completed, Offset.zero));
    await tester.pumpAndSettle();
  });

  testWidgets('when a route has no match, it should slide from outside its resting bounds', (tester) async {
    final scene = TagStatusScene(matched: false);
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.push();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect((scene.route.status.value, scene.route.translation.dy > 0), (MorphTagStatus.unmatched, true));
    await tester.pumpAndSettle();
  });

  for (final settings in [
    (label: 'disabled animations', disableAnimations: true, reduceMotion: false),
    (label: 'reduced motion', disableAnimations: false, reduceMotion: true),
    (label: 'both motion preferences', disableAnimations: true, reduceMotion: true),
  ]) {
    testWidgets('when the platform requests ${settings.label}, it should show the destination without a Morph flight', (
      tester,
    ) async {
      final scene = TagStatusScene(
        reducedMotion: settings.disableAnimations,
        reduceMotion: settings.reduceMotion,
      );
      await tester.pumpWidget(scene.app);
      await tester.pumpAndSettle();
      scene.push();
      await tester.pumpAndSettle();
      expect(
        (scene.route.status.value, scene.route.concealed, scene.route.translation),
        (MorphTagStatus.unmatched, false, Offset.zero),
      );
      await tester.pumpAndSettle();
    });
  }
}
