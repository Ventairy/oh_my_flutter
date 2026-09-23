part of '../morph_navigator_observer_test.dart';

final class _MorphNavigationScenario {
  new({this.duration}) {
    for (final notifier in appearances.values) {
      addTearDown(notifier.dispose);
    }
  }

  final Duration? duration;
  final observer = MorphNavigatorObserver();
  final navigator = GlobalKey<NavigatorState>();
  final a = Object();
  final b = Object();
  final c = Object();
  late final target = MorphTarget(tag: 'surface', duration: duration);

  late final Map<Object, String> names = {a: 'A', b: 'B', c: 'C'};
  late final Map<Object, ValueNotifier<List<Object>>> appearances = {
    for (final target in names.keys) target: ValueNotifier([target]),
  };
  final started = <String>[];
  final received = <String>[];
  final flights = <MorphFlight<double>>[];
  late final delegate = _RecordingNavigationFlightDelegate(flights);

  Widget get app => MaterialApp(
    navigatorKey: navigator,
    navigatorObservers: [observer],
    home: page(a),
  );

  Widget endpoint(Object target) => Morph(
    key: ObjectKey(target),
    targets: [this.target],

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

  Widget page(Object? target) => Scaffold(
    body: Center(
      child: target == null
          ? const Text('Unmatched route')
          : ValueListenableBuilder(
              valueListenable: appearances[target]!,
              builder: (context, targets, _) => Column(
                mainAxisSize: .min,
                children: [
                  for (final appearance in targets) ...[
                    Text('Header ${names[appearance]}'),
                    endpoint(appearance),
                  ],
                ],
              ),
            ),
    ),
  );

  void push(Object? target) {
    navigator.currentState!.push<void>(MaterialPageRoute(builder: (_) => page(target)));
  }
}
