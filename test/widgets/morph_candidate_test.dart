import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_candidate/_candidate_delegate.dart';
part 'morph_candidate/_snapshot_candidate_delegate.dart';

void main() {
  Widget visual(
    List<MorphTarget> targets, {
    bool Function(MorphTarget, MorphMatchContext)? canMatch,
    void Function(MorphTarget)? onCapture,
    void Function(MorphFlight<MorphTarget>)? onFlight,
    VoidCallback? onStart,
    Key? key,
  }) => Center(
    child: Morph(
      key: key,
      targets: targets,
      canMatch: canMatch,
      onStart: onStart,
      flightConfig: .custom(
        _CandidateDelegate(onCapture: onCapture, onFlight: onFlight),
      ),
      child: const SizedBox(width: 100, height: 100),
    ),
  );

  Future<NavigatorState> mount(WidgetTester tester, Widget child) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [MorphNavigatorObserver()],
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  PageRoute<void> route(Widget child) => PageRouteBuilder<void>(
    transitionDuration: const Duration(seconds: 1),
    reverseTransitionDuration: const Duration(seconds: 1),
    pageBuilder: (_, _, _) => Scaffold(body: child),
  );

  Future<void> advance(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('when target ordering differs, it should capture the chosen candidate on push and pop', (tester) async {
    final a = MorphTarget(tag: 'a');
    final b = MorphTarget(tag: 'b');
    MorphFlight<MorphTarget>? active;
    final navigator = await mount(tester, visual([a, b], onFlight: (flight) => active = flight));
    navigator.push<void>(route(visual([b, a], onFlight: (flight) => active = flight)));
    await advance(tester);
    final forward = (active!.source.properties, active!.destination.properties);
    await tester.pumpAndSettle();
    navigator.pop();
    await advance(tester);
    expect((forward, (active!.source.properties, active!.destination.properties)), ((b, b), (a, a)));
    await tester.pumpAndSettle();
  });

  testWidgets('when a candidate capture fails, it should recapture both endpoints for the fallback target', (
    tester,
  ) async {
    final a = MorphTarget(tag: 'a');
    final b = MorphTarget(tag: 'b');
    final captures = <String>[];
    var rejectFirstCapture = true;
    MorphFlight<MorphTarget>? active;
    final navigator = await mount(
      tester,
      visual(
        [a, b],
        onCapture: (target) => captures.add('source ${target.tag}'),
        onFlight: (flight) => active = flight,
      ),
    );
    captures.clear();
    navigator.push<void>(
      route(
        visual(
          [a, b],
          onCapture: (target) {
            captures.add('destination ${target.tag}');
            if (identical(target, a) && rejectFirstCapture) {
              rejectFirstCapture = false;
              throw StateError('This candidate cannot be captured.');
            }
          },
        ),
      ),
    );
    await advance(tester);
    final exception = tester.takeException();
    expect(
      [captures, active?.source.properties, active?.destination.properties, exception is StateError],
      [
        ['source a', 'destination a', 'source b', 'destination b'],
        b,
        b,
        true,
      ],
    );
    await tester.pumpAndSettle();
  });

  testWidgets('when a departing appearance is removed, it should retain captures for its alternative targets', (
    tester,
  ) async {
    final a = MorphTarget(tag: 'a');
    final b = MorphTarget(tag: 'b');
    final destinationVisible = ValueNotifier(false);
    addTearDown(destinationVisible.dispose);
    MorphFlight<MorphTarget>? active;
    await mount(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: destinationVisible,
        builder: (_, destination, _) => visual(
          destination ? [b] : [a, b],
          key: ValueKey(destination),
          onFlight: (flight) => active = flight,
        ),
      ),
    );
    destinationVisible.value = true;
    await advance(tester);
    expect((active?.source.properties, active?.destination.properties), (b, b));
    await tester.pumpAndSettle();
  });

  for (final alternativeCount in [2, 3]) {
    for (final changesBetweenCandidates in [false, true]) {
      testWidgets(
        'when a departing appearance has $alternativeCount alternatives${changesBetweenCandidates ? ' and its descendant changes' : ''}, it should ${changesBetweenCandidates ? 'recapture' : 'share'} its descendant image through fallback and disposal',
        (tester) async {
          final a = MorphTarget(tag: 'a');
          final b = MorphTarget(tag: 'b');
          final c = MorphTarget(tag: 'c');
          final targets = [a, b, if (alternativeCount == 3) c];
          final destinationVisible = ValueNotifier(false);
          final snapshotChanges = ValueNotifier(0);
          addTearDown(destinationVisible.dispose);
          addTearDown(snapshotChanges.dispose);
          final liveImages = <ui.Image>{};
          var imageCreations = 0;
          final previousOnCreate = ui.Image.onCreate;
          final previousOnDispose = ui.Image.onDispose;
          ui.Image.onCreate = (image) {
            previousOnCreate?.call(image);
            imageCreations += 1;
            liveImages.add(image);
          };
          ui.Image.onDispose = (image) {
            previousOnDispose?.call(image);
            liveImages.remove(image);
          };
          addTearDown(() {
            ui.Image.onCreate = previousOnCreate;
            ui.Image.onDispose = previousOnDispose;
          });

          MorphFlight<({MorphTarget target, Widget child})>? active;
          var rejectFirstCapture = true;
          await mount(
            tester,
            ValueListenableBuilder<bool>(
              valueListenable: destinationVisible,
              builder: (_, destination, _) => Center(
                child: Morph(
                  key: ValueKey(destination),
                  targets: targets,
                  flightConfig: .custom(
                    _SnapshotCandidateDelegate(
                      onCapture: destination
                          ? (target) {
                              if (identical(target, a) && rejectFirstCapture) {
                                rejectFirstCapture = false;
                                throw StateError('This candidate cannot be captured.');
                              }
                            }
                          : (target) {
                              if (changesBetweenCandidates && identical(target, b)) {
                                snapshotChanges.value += 1;
                              }
                            },
                      onFlight: (flight) => active = flight,
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 100,
                    child: destination
                        ? const ColoredBox(color: Colors.green)
                        : MorphDescendant(
                            flightBehavior: .snapshot(changes: snapshotChanges),
                            child: const ColoredBox(color: Colors.blue),
                          ),
                  ),
                ),
              ),
            ),
          );
          imageCreations = 0;
          destinationVisible.value = true;
          await advance(tester);
          final selectedTarget = active?.source.properties.target;
          final exception = tester.takeException();
          final imagesDuringFlight = imageCreations;
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();

          expect(
            (imagesDuringFlight, selectedTarget, exception is StateError, liveImages.isEmpty),
            (changesBetweenCandidates ? 2 : 1, b, true, true),
          );
        },
      );
    }
  }

  testWidgets('when an accepted flight reverses early, it should retain its captured target configuration', (
    tester,
  ) async {
    final a = MorphTarget(tag: 'a');
    final b = MorphTarget(tag: 'b');
    MorphFlight<MorphTarget>? active;
    final navigator = await mount(tester, visual([a, b], onFlight: (flight) => active = flight));
    navigator.push<void>(route(visual([b, a], onFlight: (flight) => active = flight)));
    await advance(tester);
    navigator.pop();
    await tester.pump();
    await tester.pump();
    expect((active?.source.properties, active?.destination.properties), (b, b));
    await tester.pumpAndSettle();
  });

  for (final rejects in ['contract', 'destination', 'source', 'none']) {
    testWidgets('when $rejects filters a candidate, it should check shared then destination then source policy', (
      tester,
    ) async {
      final events = <String>[];
      final target = MorphTarget(
        tag: 'connection',
        canMatch: (_) {
          events.add('contract');
          return rejects != 'contract';
        },
      );
      final navigator = await mount(
        tester,
        visual(
          [target],
          canMatch: (_, _) {
            events.add('source');
            return rejects != 'source';
          },
          onCapture: (_) => events.add('capture source'),
          onStart: () => events.add('start'),
        ),
      );
      events.clear();
      navigator.push<void>(
        route(
          visual(
            [target],
            canMatch: (_, _) {
              events.add('destination');
              return rejects != 'destination';
            },
            onCapture: (_) => events.add('capture destination'),
          ),
        ),
      );
      await advance(tester);
      expect(events, switch (rejects) {
        'contract' => ['contract'],
        'destination' => ['contract', 'destination'],
        'source' => ['contract', 'destination', 'source'],
        _ => ['contract', 'destination', 'source', 'capture source', 'capture destination', 'start'],
      });
      await tester.pumpAndSettle();
    });
  }

  for (final throws in [false, true]) {
    testWidgets('when an appearance rejects with throws=$throws, it should consider its next target without capture', (
      tester,
    ) async {
      final a = MorphTarget(tag: 'a');
      final b = MorphTarget(tag: 'b');
      final captures = <MorphTarget>[];
      MorphFlight<MorphTarget>? active;
      final navigator = await mount(
        tester,
        visual([a, b], onCapture: captures.add, onFlight: (flight) => active = flight),
      );
      captures.clear();
      navigator.push<void>(
        route(
          visual(
            [a, b],
            canMatch: (target, _) {
              if (identical(target, b)) return true;
              if (throws) throw StateError('Rejected by this appearance.');
              return false;
            },
            onCapture: captures.add,
          ),
        ),
      );
      await advance(tester);
      final exception = tester.takeException();
      expect(
        [captures, active?.source.properties, active?.destination.properties, exception is StateError],
        [
          [b, b],
          b,
          b,
          throws,
        ],
      );
      await tester.pumpAndSettle();
    });
  }

  testWidgets('when appearance policy changes during a flight, it should preserve acceptance and check the next pop', (
    tester,
  ) async {
    final target = MorphTarget(tag: 'connection');
    var allows = true;
    final operations = <MorphMatchOperation>[];
    final navigator = await mount(
      tester,
      visual(
        [target],
        canMatch: (_, match) {
          operations.add(match.operation);
          return allows;
        },
      ),
    );
    navigator.push<void>(route(visual([target])));
    await advance(tester);
    allows = false;
    await tester.pump(const Duration(milliseconds: 100));
    final inFlightStatus = target.status.value;
    await tester.pumpAndSettle();
    navigator.pop();
    await advance(tester);
    expect(
      [operations, inFlightStatus, target.status.value],
      [
        [MorphMatchOperation.push, MorphMatchOperation.pop],
        MorphTagStatus.flying,
        MorphTagStatus.unmatched,
      ],
    );
    await tester.pumpAndSettle();
  });
}
