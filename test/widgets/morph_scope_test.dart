import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'morph_scope/scope_scene.dart';

void main() {
  for (final disabled in ['none', 'source', 'destination', 'ancestor']) {
    testWidgets('when $disabled is disabled, it should resolve the correct navigation participation', (tester) async {
      final scene = ScopeScene()
        ..sourceEnabled = disabled != 'source'
        ..destinationEnabled = disabled != 'destination';
      scene.enabled.value = disabled != 'ancestor';
      await tester.pumpWidget(scene.app);
      await tester.pumpAndSettle();
      scene.push();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(scene.status, disabled == 'none' ? MorphTagStatus.flying : MorphTagStatus.unmatched);
      await tester.pumpAndSettle();
      expect(scene.starts, disabled == 'none' ? 1 : 0);
      expect(scene.ends, scene.starts);
      expect(tester.takeException(), isNull);
    });
  }

  for (final reverse in [false, true]) {
    testWidgets('when disabled during a flight with reverse $reverse, it should preserve the active flight', (
      tester,
    ) async {
      final scene = ScopeScene();
      await tester.pumpWidget(scene.app);
      await tester.pumpAndSettle();
      scene.push();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(scene.status, MorphTagStatus.flying);
      scene.enabled.value = false;
      await tester.pump();
      expect(scene.status, MorphTagStatus.flying);
      expect(scene.ends, 0);
      if (reverse) scene.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(scene.status, MorphTagStatus.completed);
      expect(scene.starts, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('when disabled during preparation, it should skip the new flight', (tester) async {
    final scene = ScopeScene();
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.push();
    scene.enabled.value = false;
    await tester.pumpAndSettle();
    expect(scene.status, MorphTagStatus.unmatched);
    expect(scene.starts, 0);
  });

  testWidgets('when re-enabled, it should not replay but should allow the next navigation', (tester) async {
    final scene = ScopeScene();
    scene.enabled.value = false;
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.push();
    await tester.pumpAndSettle();
    scene.enabled.value = true;
    await tester.pumpAndSettle();
    expect(scene.starts, 0);
    expect(scene.status, MorphTagStatus.unmatched);
    scene.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(scene.starts, 1);
    expect(scene.status, MorphTagStatus.completed);
  });

  testWidgets('when a settled flight is disabled, it should skip a fresh return flight', (tester) async {
    final scene = ScopeScene();
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.push();
    await tester.pumpAndSettle();
    scene.enabled.value = false;
    await tester.pump();
    scene.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(scene.status, MorphTagStatus.unmatched);
    expect(scene.starts, 1);
  });

  testWidgets('when disabled during a flight then retargeted, it should retain normal retargeting', (tester) async {
    final scene = ScopeScene();
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.push();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    scene.enabled.value = false;
    await tester.pump();
    final third = MorphTarget(tag: 'scope');
    scene.navigator.currentState!.push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => Align(
          alignment: Alignment.bottomRight,
          child: scene.endpoint(third, allowed: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(scene.status, MorphTagStatus.flying);
    await tester.pumpAndSettle();
    expect(scene.status, MorphTagStatus.completed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('when scope changes, it should preserve descendant state and semantics', (tester) async {
    final enabled = ValueNotifier(true);
    final target = MorphTarget(tag: 'input');
    final input = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [MorphNavigatorObserver()],
        home: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          child: Morph(
            target: target,
            child: Material(child: TextField(key: input)),
          ),
          builder: (context, value, child) => MorphScope(enabled: value, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state(find.byKey(input));
    await tester.enterText(find.byKey(input), 'Preserved');
    enabled.value = false;
    await tester.pumpAndSettle();
    expect(identical(tester.state(find.byKey(input)), state), isTrue);
    expect(find.text('Preserved'), findsOneWidget);
    enabled.dispose();
  });

  for (final replacement in [false, true]) {
    testWidgets(
      'when local replacement is $replacement and disabled, it should display current content without flying',
      (tester) async {
        final source = MorphTarget(tag: 'local');
        final destination = MorphTarget(tag: 'local');
        var changed = false;
        var enabled = false;
        var starts = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [MorphNavigatorObserver()],
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return MorphScope(
                  enabled: enabled,
                  child: Center(
                    child: Morph(
                      target: replacement || !changed ? source : destination,
                      animateChildChanges: replacement,
                      onStart: () => starts++,
                      child: SizedBox(
                        key: ValueKey(changed),
                        width: changed ? 180 : 80,
                        height: 80,
                        child: Text(changed ? 'After' : 'Before'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        rebuild(() => changed = true);
        await tester.pumpAndSettle();
        expect(starts, 0);
        expect(find.text('After'), findsOneWidget);
        rebuild(() => enabled = true);
        await tester.pumpAndSettle();
        expect(starts, 0);
        rebuild(() => changed = false);
        await tester.pumpAndSettle();
        expect(starts, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
