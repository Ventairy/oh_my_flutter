import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class _MorphTransitionTestApp extends StatefulWidget {
  const _MorphTransitionTestApp({required this.transitionBuilder});

  final AnimatedSwitcherTransitionBuilder transitionBuilder;

  @override
  State<_MorphTransitionTestApp> createState() => _MorphTransitionTestAppState();
}

class _MorphTransitionTestAppState extends State<_MorphTransitionTestApp> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Stack(
        children: [
          Align(
            alignment: _expanded ? Alignment.bottomRight : Alignment.topLeft,
            child: Morph(
              tag: 'transition-animation',
              duration: const Duration(milliseconds: 100),
              curve: Curves.linear,
              switchTransition: widget.transitionBuilder,
              child: Builder(
                key: ValueKey<bool>(_expanded),
                builder: (context) {
                  return const SizedBox.square(dimension: 48);
                },
              ),
            ),
          ),
          FilledButton(
            key: const ValueKey<String>('toggle'),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: const Text('Toggle'),
          ),
        ],
      ),
    );
  }
}

class _MorphTextSwitchTransitionTestApp extends StatefulWidget {
  const _MorphTextSwitchTransitionTestApp();

  @override
  State<_MorphTextSwitchTransitionTestApp> createState() => _MorphTextSwitchTransitionTestAppState();
}

class _MorphTextSwitchTransitionTestAppState extends State<_MorphTextSwitchTransitionTestApp> {
  bool _showsDestination = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Stack(
        children: [
          Morph(
            tag: 'text-switch-transition',
            duration: const Duration(milliseconds: 100),
            curve: Curves.linear,
            switchTransition: (child, animation) {
              return FadeTransition(
                key: const ValueKey('text-switch-fade'),
                opacity: animation,
                child: child,
              );
            },
            child: Text(_showsDestination ? 'Destination' : 'Source'),
          ),
          FilledButton(
            key: const ValueKey('switch-text'),
            onPressed: () {
              setState(() => _showsDestination = !_showsDestination);
            },
            child: const Text('Switch'),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets(
    'when automatic Text changes with a switch transition, it should drive the transition around the switch threshold',
    (tester) async {
      await tester.pumpWidget(const _MorphTextSwitchTransitionTestApp());
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('switch-text')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));
      final departingOpacity = tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('text-switch-fade')),
          )
          .opacity
          .value;
      await tester.pump(const Duration(milliseconds: 50));
      final arrivingOpacity = tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('text-switch-fade')),
          )
          .opacity
          .value;
      await tester.pumpAndSettle();

      expect(
        [departingOpacity, arrivingOpacity],
        everyElement(closeTo(0.5, 1e-9)),
      );
    },
  );

  testWidgets(
    'when automatic Text keeps the same value, it should not apply the switch transition',
    (tester) async {
      var emphasized = false;
      var transitionBuilds = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Morph(
                tag: 'same-text-switch-transition',
                duration: const Duration(milliseconds: 100),
                switchTransition: (child, animation) {
                  transitionBuilds += 1;
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Text(
                  'Unchanged',
                  style: TextStyle(
                    fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      update(() => emphasized = true);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(transitionBuilds, 0);
    },
  );

  testWidgets(
    'when transition progress reaches an endpoint, it should expose the matching status to value listeners',
    (tester) async {
      final observations = <({AnimationStatus status, double value})>[];
      var listenerInstalled = false;
      await tester.pumpWidget(
        _MorphTransitionTestApp(
          transitionBuilder: (child, animation) {
            if (!listenerInstalled) {
              listenerInstalled = true;
              animation.addListener(() {
                observations.add((status: animation.status, value: animation.value));
              });
            }
            return child;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('toggle')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final terminal = observations.lastWhere((observation) => observation.value == 0);
      await tester.pumpAndSettle();

      expect(terminal.status, AnimationStatus.dismissed);
    },
  );

  testWidgets(
    'when a transition listener removes another listener, it should not invoke the removed listener',
    (tester) async {
      var listenerInstalled = false;
      var removedListenerCalls = 0;
      await tester.pumpWidget(
        _MorphTransitionTestApp(
          transitionBuilder: (child, animation) {
            if (!listenerInstalled) {
              listenerInstalled = true;
              void removedListener() => removedListenerCalls += 1;
              animation
                ..addListener(() => animation.removeListener(removedListener))
                ..addListener(removedListener);
            }
            return child;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('toggle')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();

      expect(removedListenerCalls, 0);
    },
  );

  testWidgets(
    'when a transition listener throws, it should report the error and continue notifying listeners',
    (tester) async {
      var listenerInstalled = false;
      var followingListenerCalled = false;
      await tester.pumpWidget(
        _MorphTransitionTestApp(
          transitionBuilder: (child, animation) {
            if (!listenerInstalled) {
              listenerInstalled = true;
              late VoidCallback throwingListener;
              throwingListener = () {
                animation.removeListener(throwingListener);
                throw StateError('listener failed');
              };
              animation
                ..addListener(throwingListener)
                ..addListener(() => followingListenerCalled = true);
            }
            return child;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('toggle')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      final error = tester.takeException();
      await tester.pumpAndSettle();

      expect((error is StateError, followingListenerCalled), (true, true));
    },
  );

  testWidgets(
    'when a transition status listener removes another listener, it should not invoke the removed listener',
    (tester) async {
      var listenerInstalled = false;
      var removedListenerCalls = 0;
      await tester.pumpWidget(
        _MorphTransitionTestApp(
          transitionBuilder: (child, animation) {
            if (!listenerInstalled) {
              listenerInstalled = true;
              void removedListener(AnimationStatus status) {
                removedListenerCalls += 1;
              }

              animation
                ..addStatusListener((status) => animation.removeStatusListener(removedListener))
                ..addStatusListener(removedListener);
            }
            return child;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('toggle')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();

      expect(removedListenerCalls, 0);
    },
  );

  testWidgets(
    'when a transition status listener throws, it should report the error and continue notifying listeners',
    (tester) async {
      var listenerInstalled = false;
      var followingListenerCalled = false;
      await tester.pumpWidget(
        _MorphTransitionTestApp(
          transitionBuilder: (child, animation) {
            if (!listenerInstalled) {
              listenerInstalled = true;
              late AnimationStatusListener throwingListener;
              throwingListener = (status) {
                animation.removeStatusListener(throwingListener);
                throw StateError('status listener failed');
              };
              animation
                ..addStatusListener(throwingListener)
                ..addStatusListener((status) => followingListenerCalled = true);
            }
            return child;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('toggle')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      final error = tester.takeException();
      await tester.pumpAndSettle();

      expect((error is StateError, followingListenerCalled), (true, true));
    },
  );
}
