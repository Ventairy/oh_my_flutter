part of '../morph_navigator_observer_test.dart';

final class _MorphNavigationScenario {
  _MorphNavigationScenario({this.duration}) {
    for (final notifier in appearances.values) {
      addTearDown(notifier.dispose);
    }
  }

  final Duration? duration;
  final observer = MorphNavigatorObserver();
  final navigator = GlobalKey<NavigatorState>();
  final a = MorphTarget(tag: 'surface');
  final b = MorphTarget(tag: 'surface');
  final c = MorphTarget(tag: 'surface');
  late final Map<MorphTarget, String> names = {a: 'A', b: 'B', c: 'C'};
  late final Map<MorphTarget, ValueNotifier<List<MorphTarget>>> appearances = {
    for (final target in names.keys) target: ValueNotifier([target]),
  };
  final started = <String>[];
  final received = <String>[];
  final flights = <MorphFlight<double>>[];
  final progress = <MorphTarget, Animation<double>>{};
  late final delegate = _RecordingNavigationFlightDelegate(flights);

  Widget get app => MaterialApp(
    navigatorKey: navigator,
    navigatorObservers: [observer],
    home: page(a),
  );

  Widget endpoint(MorphTarget target) => Morph(
    animateChildChanges: true,
    key: ObjectKey(target),
    target: target,
    duration: duration,
    flightConfig: .custom(delegate),
    onStart: () => started.add(names[target]!),
    onReceived: () => received.add(names[target]!),
    child: SizedBox(
      key: ValueKey('body-${names[target]}'),
      width: identical(target, a) ? 100 : 200,
      height: 100,
      child: const ColoredBox(color: Colors.blue),
    ),
  );

  Widget page(MorphTarget? target) => Scaffold(
    body: Center(
      child: target == null
          ? const Text('Unmatched route')
          : ValueListenableBuilder(
              valueListenable: appearances[target]!,
              builder: (context, targets, _) => Column(
                mainAxisSize: .min,
                children: [
                  for (final appearance in targets) ...[
                    MorphSibling(
                      target: appearance,
                      transitionBuilder: (child, curved, uncurved) {
                        progress[appearance] = uncurved;
                        return FadeTransition(opacity: uncurved, child: child);
                      },
                      child: Text('Header ${names[appearance]}'),
                    ),
                    endpoint(appearance),
                  ],
                ],
              ),
            ),
    ),
  );

  void push(MorphTarget? target) {
    navigator.currentState!.push<void>(MaterialPageRoute(builder: (_) => page(target)));
  }
}
