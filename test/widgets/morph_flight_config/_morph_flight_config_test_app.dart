part of '../morph_flight_config_test.dart';

class _MorphFlightConfigTestApp extends StatefulWidget {
  const new({
    this.configuration,
    this.curve = Curves.linear,
    this.snapshot = false,
    super.key,
  });

  static const ValueKey<String> sourceKey = ValueKey('source-child');
  static const ValueKey<String> destinationKey = ValueKey('destination-child');
  static const ValueKey<String> snapshotKey = ValueKey('snapshot');

  final MorphFlightConfig? configuration;
  final Curve curve;
  final bool snapshot;

  @override
  State<_MorphFlightConfigTestApp> createState() => _MorphFlightConfigTestAppState();
}

class _MorphFlightConfigTestAppState extends State<_MorphFlightConfigTestApp> {
  final _morphTarget1 = MorphTarget(tag: 'child-config');
  final _morphTarget2 = MorphTarget(tag: 'child-config');
  final _morphObserver1 = MorphNavigatorObserver();

  var _destination = false;

  void showDestination() => setState(() => _destination = true);

  @override
  Widget build(BuildContext context) {
    final size = _destination ? 80.0 : 40.0;
    final child = Builder(
      key: _destination ? _MorphFlightConfigTestApp.destinationKey : _MorphFlightConfigTestApp.sourceKey,
      builder: (context) {
        final content = SizedBox.square(
          dimension: size,
          child: const ColoredBox(color: Colors.blue),
        );
        return widget.snapshot
            ? MorphDescendant(
                key: _MorphFlightConfigTestApp.snapshotKey,
                flightBehavior: MorphDescendantFlightBehavior.snapshot,
                child: content,
              )
            : content;
      },
    );
    final configuration = widget.configuration;
    return MaterialApp(
      navigatorObservers: [_morphObserver1],
      home: Align(
        alignment: _destination ? Alignment.bottomRight : Alignment.topLeft,
        child: configuration == null
            ? Morph(
                animateChildChanges: true,
                target: _morphTarget1,
                duration: const Duration(seconds: 1),
                curve: widget.curve,
                child: child,
              )
            : Morph(
                animateChildChanges: true,
                target: _morphTarget2,
                duration: const Duration(seconds: 1),
                curve: widget.curve,
                flightConfig: configuration,
                child: child,
              ),
      ),
    );
  }
}
