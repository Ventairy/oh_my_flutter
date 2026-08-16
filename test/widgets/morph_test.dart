import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Finder _morphOverlay() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_MorphOverlay',
  );
}

class _MorphTestApp extends StatefulWidget {
  const _MorphTestApp({
    required this.source,
    required this.destination,
    this.disableAnimations = false,
  });

  final Widget source;
  final Widget destination;
  final bool disableAnimations;

  @override
  State<_MorphTestApp> createState() => _MorphTestAppState();
}

class _MorphTestAppState extends State<_MorphTestApp> {
  bool _showDestination = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: widget.disableAnimations),
        child: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: _showDestination ? Alignment.bottomRight : Alignment.topLeft,
                child: _showDestination ? widget.destination : widget.source,
              ),
              Align(
                alignment: Alignment.topCenter,
                child: FilledButton(
                  key: const ValueKey('toggle'),
                  onPressed: () {
                    setState(() => _showDestination = !_showDestination);
                  },
                  child: const Text('Toggle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteMorphTestApp extends StatelessWidget {
  const _RouteMorphTestApp({required this.events});

  final List<String> events;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              Morph(
                tag: 'route-shared',
                onStart: () => events.add('source-start'),
                onEnd: () => events.add('source-end'),
                onReceived: () => events.add('source-received'),
                child: const Text('Source'),
              ),
              FilledButton(
                key: const ValueKey('push'),
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    PageRouteBuilder<void>(
                      opaque: false,
                      transitionDuration: const Duration(milliseconds: 400),
                      reverseTransitionDuration: const Duration(
                        milliseconds: 430,
                      ),
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return Scaffold(
                          backgroundColor: Colors.transparent,
                          body: Align(
                            alignment: Alignment.bottomRight,
                            child: Morph(
                              tag: 'route-shared',
                              onStart: () => events.add('destination-start'),
                              onEnd: () => events.add('destination-end'),
                              onReceived: () => events.add(
                                'destination-received',
                              ),
                              child: const Text('Destination'),
                            ),
                          ),
                        );
                      },
                      transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
                    ),
                  );
                },
                child: const Text('Push'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestProperties {
  const _TestProperties(this.color, this.axisScale);

  final Color color;
  final Offset axisScale;
}

class _TestFlightDelegate extends MorphFlightDelegate<_TestProperties> {
  const _TestFlightDelegate(
    this.color,
    this.captures, {
    this.animations,
    this.firstFlightBounds,
    this.flightKinds,
    this.flightPaints,
    this.flightTransforms,
    this.flights,
    this.flightKey,
    this.staticFlight = false,
  });

  final Color color;
  final List<_TestProperties> captures;
  final List<Animation<double>>? animations;
  final List<Rect>? firstFlightBounds;
  final List<MorphFlightKind>? flightKinds;
  final _PaintCounter? flightPaints;
  final List<({Matrix4 source, Matrix4 destination})>? flightTransforms;
  final List<MorphFlight<_TestProperties>>? flights;
  final Key? flightKey;
  final bool staticFlight;

  @override
  _TestProperties properties(MorphEndpointContext endpoint) {
    final properties = _TestProperties(color, endpoint.axisScale);
    captures.add(properties);
    return properties;
  }

  @override
  _TestProperties lerp(
    _TestProperties source,
    _TestProperties destination,
    double progress,
  ) {
    return _TestProperties(
      Color.lerp(source.color, destination.color, progress)!,
      Offset.lerp(source.axisScale, destination.axisScale, progress)!,
    );
  }

  @override
  Widget buildFlight(BuildContext context, MorphFlight<_TestProperties> flight) {
    animations?.add(flight.animation);
    firstFlightBounds?.add(flight.bounds);
    flightKinds?.add(flight.kind);
    flightTransforms?.add((
      source: flight.source.transform.clone(),
      destination: flight.destination.transform.clone(),
    ));
    flights?.add(flight);
    final flightPaints = this.flightPaints;
    Widget buildVisual(Color color) {
      return ColoredBox(
        key: flightKey,
        color: color,
        child: flightPaints == null
            ? null
            : CustomPaint(
                painter: _PaintCounterPainter(
                  flightPaints,
                  Colors.transparent,
                ),
                child: const SizedBox.expand(),
              ),
      );
    }

    if (staticFlight) return buildVisual(color);
    return AnimatedBuilder(
      animation: flight.animation,
      builder: (context, child) => buildVisual(flight.properties.color),
    );
  }
}

class _TransformMutatingTestFlightDelegate extends _TestFlightDelegate {
  const _TransformMutatingTestFlightDelegate(
    super.color,
    super.captures, {
    required this.endpointTransforms,
    required super.flights,
  });

  final List<Matrix4> endpointTransforms;

  @override
  _TestProperties properties(MorphEndpointContext endpoint) {
    endpointTransforms.add(Matrix4.copy(endpoint.transform));
    endpoint.transform.translateByDouble(100, 100, 0, 1);
    return super.properties(endpoint);
  }
}

class _RouteStartSynchronizationTestApp extends StatelessWidget {
  const _RouteStartSynchronizationTestApp({
    required this.captures,
    required this.firstFlightBounds,
    required this.events,
  });

  final List<_TestProperties> captures;
  final List<Rect> firstFlightBounds;
  final List<String> events;

  Morph _endpoint({
    required Color color,
    required Key childKey,
    VoidCallback? onReceived,
  }) {
    return Morph(
      tag: 'route-start-synchronization',
      curve: Curves.linear,
      flightDelegate: _TestFlightDelegate(
        color,
        captures,
        firstFlightBounds: firstFlightBounds,
      ),
      onReceived: onReceived,
      child: SizedBox.square(key: childKey, dimension: 48),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 32,
                  top: 96,
                  child: _endpoint(
                    color: Colors.red,
                    childKey: const ValueKey('synchronized-route-source'),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: FilledButton(
                    key: const ValueKey('push-synchronized-route'),
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        PageRouteBuilder<void>(
                          opaque: false,
                          transitionDuration: const Duration(milliseconds: 400),
                          pageBuilder: (context, animation, secondaryAnimation) {
                            return Material(
                              type: MaterialType.transparency,
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: 40,
                                    bottom: 48,
                                    child: _endpoint(
                                      color: Colors.blue,
                                      childKey: const ValueKey(
                                        'synchronized-route-destination',
                                      ),
                                      onReceived: () => events.add('received'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
                        ),
                      );
                    },
                    child: const Text('Push'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeldRouteForwardSimulation extends Simulation {
  static const double _durationInSeconds = 0.4;

  bool _released = false;
  double _lastHeldTime = 0;

  void release() {
    _released = true;
  }

  @override
  double x(double time) {
    if (!_released) {
      _lastHeldTime = time;
      return 0;
    }

    return ((time - _lastHeldTime) / _durationInSeconds).clamp(0, 1);
  }

  @override
  double dx(double time) {
    if (!_released || isDone(time)) return 0;
    return 1 / _durationInSeconds;
  }

  @override
  bool isDone(double time) {
    return _released && time - _lastHeldTime >= _durationInSeconds;
  }
}

class _HeldMorphPageRoute extends PageRoute<void> {
  _HeldMorphPageRoute({required this.child});

  final Widget child;
  final _simulation = _HeldRouteForwardSimulation();

  void release() {
    _simulation.release();
  }

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get fullscreenDialog => false;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Simulation? createSimulation({required bool forward}) {
    return forward ? _simulation : super.createSimulation(forward: forward);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class _HeldRouteMorphTestApp extends StatefulWidget {
  const _HeldRouteMorphTestApp({
    required this.captures,
    required this.firstFlightBounds,
  });

  final List<_TestProperties> captures;
  final List<Rect> firstFlightBounds;

  @override
  State<_HeldRouteMorphTestApp> createState() => _HeldRouteMorphTestAppState();
}

class _HeldRouteMorphTestAppState extends State<_HeldRouteMorphTestApp> {
  late _HeldMorphPageRoute _route;

  Morph _endpoint({
    required Color color,
    required Key childKey,
    VoidCallback? onStart,
  }) {
    return Morph(
      tag: 'held-route-synchronization',
      curve: Curves.linear,
      flightDelegate: _TestFlightDelegate(
        color,
        widget.captures,
        firstFlightBounds: widget.firstFlightBounds,
      ),
      onStart: onStart,
      child: SizedBox.square(key: childKey, dimension: 48),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 32,
                  top: 96,
                  child: _endpoint(
                    color: Colors.red,
                    childKey: const ValueKey('held-route-source'),
                    onStart: () => _route.release(),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: FilledButton(
                    key: const ValueKey('push-held-route'),
                    onPressed: () async {
                      final route = _HeldMorphPageRoute(
                        child: Material(
                          type: MaterialType.transparency,
                          child: Stack(
                            children: [
                              Positioned(
                                right: 40,
                                bottom: 48,
                                child: _endpoint(
                                  color: Colors.blue,
                                  childKey: const ValueKey(
                                    'held-route-destination',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      _route = route;
                      await Navigator.of(context).push<void>(route);
                    },
                    child: const Text('Push'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IncompatibleTestFlightDelegate extends _TestFlightDelegate {
  const _IncompatibleTestFlightDelegate(
    super.color,
    super.captures,
  );
}

class _ThrowingTestFlightDelegate extends _TestFlightDelegate {
  const _ThrowingTestFlightDelegate(
    super.color,
    super.captures, {
    required this.throwOnCapture,
  });

  final bool throwOnCapture;

  @override
  _TestProperties properties(MorphEndpointContext endpoint) {
    if (throwOnCapture) throw StateError('capture failed');
    return super.properties(endpoint);
  }
}

class _PaintCounter extends ChangeNotifier {
  int count = 0;

  void reset() {
    count = 0;
  }

  void requestPaint() {
    notifyListeners();
  }
}

class _TickCounter extends StatefulWidget {
  const _TickCounter({required this.onTick, required this.child});

  final VoidCallback onTick;
  final Widget child;

  @override
  State<_TickCounter> createState() => _TickCounterState();
}

class _TickCounterState extends State<_TickCounter> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(widget.onTick);
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PaintCounterPainter extends CustomPainter {
  _PaintCounterPainter(this.counter, this.color) : super(repaint: counter);

  final _PaintCounter counter;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    counter.count += 1;
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PaintCounterPainter oldDelegate) {
    return oldDelegate.counter != counter || oldDelegate.color != color;
  }
}

Widget _paintedMorphEndpoint({
  required Object tag,
  required Key endpointKey,
  required Key childKey,
  required _PaintCounter paints,
  required MorphFlightDelegate<_TestProperties> flightDelegate,
  Duration duration = const Duration(milliseconds: 400),
  String? semanticsLabel,
}) {
  Widget child = CustomPaint(
    key: childKey,
    painter: _PaintCounterPainter(paints, Colors.transparent),
    child: const SizedBox.square(dimension: 48),
  );
  if (semanticsLabel != null) {
    child = Semantics(label: semanticsLabel, child: child);
  }
  return Morph(
    key: endpointKey,
    tag: tag,
    duration: duration,
    curve: Curves.linear,
    flightDelegate: flightDelegate,
    child: child,
  );
}

class _OwnershipRouteTestApp extends StatelessWidget {
  const _OwnershipRouteTestApp({
    required this.sourcePaints,
    required this.destinationPaints,
    this.destinationScale,
    this.disableAnimations = false,
  });

  final _PaintCounter sourcePaints;
  final _PaintCounter destinationPaints;
  final ValueNotifier<double>? destinationScale;
  final bool disableAnimations;

  Container _endpoint({
    required _PaintCounter paints,
    required Color color,
    required Key key,
  }) {
    return Container(
      key: key,
      width: 48,
      height: 48,
      color: Colors.transparent,
      child: CustomPaint(
        painter: _PaintCounterPainter(paints, color),
      ),
    );
  }

  Widget _destination() {
    final destination = Morph(
      tag: 'ownership-shared',
      child: _endpoint(
        paints: destinationPaints,
        color: Colors.blue,
        key: const ValueKey('destination-paint'),
      ),
    );
    final scale = destinationScale;
    if (scale == null) return destination;

    return ValueListenableBuilder<double>(
      valueListenable: scale,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: destination,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        if (!disableAnimations) return child!;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        );
      },
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Morph(
                    tag: 'ownership-shared',
                    child: _endpoint(
                      paints: sourcePaints,
                      color: Colors.red,
                      key: const ValueKey('source-paint'),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: FilledButton(
                    key: const ValueKey('push-ownership-route'),
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        PageRouteBuilder<void>(
                          opaque: false,
                          transitionDuration: const Duration(
                            milliseconds: 400,
                          ),
                          reverseTransitionDuration: const Duration(
                            milliseconds: 430,
                          ),
                          pageBuilder: (context, animation, secondaryAnimation) {
                            return Material(
                              type: MaterialType.transparency,
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: _destination(),
                              ),
                            );
                          },
                          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
                        ),
                      );
                    },
                    child: const Text('Push'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RebuildingRouteTestApp extends StatelessWidget {
  const _RebuildingRouteTestApp({
    required this.destinationRebuild,
    required this.captures,
    required this.flightKinds,
  });

  final ValueNotifier<int> destinationRebuild;
  final List<_TestProperties> captures;
  final List<MorphFlightKind> flightKinds;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Column(
              children: [
                Morph(
                  tag: 'rebuild-shared',
                  flightDelegate: _TestFlightDelegate(
                    Colors.red,
                    captures,
                    flightKinds: flightKinds,
                  ),
                  child: const SizedBox.square(dimension: 48),
                ),
                FilledButton(
                  key: const ValueKey('push-rebuilding-route'),
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      PageRouteBuilder<void>(
                        opaque: false,
                        transitionDuration: const Duration(milliseconds: 400),
                        pageBuilder: (context, animation, secondaryAnimation) {
                          return Material(
                            type: MaterialType.transparency,
                            child: ValueListenableBuilder<int>(
                              valueListenable: destinationRebuild,
                              builder: (context, rebuild, child) {
                                return Align(
                                  alignment: Alignment.bottomRight,
                                  child: Morph(
                                    tag: 'rebuild-shared',
                                    flightDelegate: _TestFlightDelegate(
                                      Colors.blue,
                                      captures,
                                      flightKinds: flightKinds,
                                    ),
                                    child: SizedBox.square(
                                      dimension: 48 + (rebuild * 0),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
                      ),
                    );
                  },
                  child: const Text('Push'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RetargetOwnershipTestApp extends StatelessWidget {
  const _RetargetOwnershipTestApp({
    required this.stage,
    required this.sourcePaints,
    required this.destinationPaints,
    required this.thirdPaints,
    required this.captures,
    this.compatibleThird = false,
    this.exposeSemantics = false,
  });

  final ValueNotifier<int> stage;
  final _PaintCounter sourcePaints;
  final _PaintCounter destinationPaints;
  final _PaintCounter thirdPaints;
  final List<_TestProperties> captures;
  final bool compatibleThird;
  final bool exposeSemantics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<int>(
          valueListenable: stage,
          builder: (context, value, child) {
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: _paintedMorphEndpoint(
                    tag: 'retarget-shared',
                    endpointKey: const ValueKey('retarget-source-endpoint'),
                    childKey: const ValueKey('retarget-source-child'),
                    paints: sourcePaints,
                    flightDelegate: _TestFlightDelegate(Colors.red, captures),
                    semanticsLabel: exposeSemantics ? 'Retarget source' : null,
                  ),
                ),
                if (value >= 1)
                  Align(
                    alignment: Alignment.center,
                    child: _paintedMorphEndpoint(
                      tag: 'retarget-shared',
                      endpointKey: const ValueKey(
                        'retarget-destination-endpoint',
                      ),
                      childKey: const ValueKey('retarget-destination-child'),
                      paints: destinationPaints,
                      flightDelegate: _TestFlightDelegate(Colors.blue, captures),
                      semanticsLabel: exposeSemantics ? 'Retarget destination' : null,
                    ),
                  ),
                if (value >= 2)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: _paintedMorphEndpoint(
                      tag: 'retarget-shared',
                      endpointKey: const ValueKey('retarget-third-endpoint'),
                      childKey: const ValueKey('retarget-third-child'),
                      paints: thirdPaints,
                      flightDelegate: compatibleThird
                          ? _TestFlightDelegate(Colors.green, captures)
                          : _IncompatibleTestFlightDelegate(
                              Colors.green,
                              captures,
                            ),
                      semanticsLabel: exposeSemantics ? 'Retarget third' : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ThirdEndpointRouteTestApp extends StatelessWidget {
  const _ThirdEndpointRouteTestApp({
    required this.showThird,
    required this.sourcePaints,
    required this.destinationPaints,
    required this.thirdPaints,
    required this.captures,
  });

  final ValueNotifier<bool> showThird;
  final _PaintCounter sourcePaints;
  final _PaintCounter destinationPaints;
  final _PaintCounter thirdPaints;
  final List<_TestProperties> captures;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: _paintedMorphEndpoint(
                    tag: 'third-route-shared',
                    endpointKey: const ValueKey('third-route-source-endpoint'),
                    childKey: const ValueKey('third-route-source-child'),
                    paints: sourcePaints,
                    flightDelegate: _TestFlightDelegate(Colors.red, captures),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: FilledButton(
                    key: const ValueKey('push-third-endpoint-route'),
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        PageRouteBuilder<void>(
                          opaque: false,
                          transitionDuration: const Duration(
                            milliseconds: 400,
                          ),
                          pageBuilder: (context, animation, secondaryAnimation) {
                            return Material(
                              type: MaterialType.transparency,
                              child: ValueListenableBuilder<bool>(
                                valueListenable: showThird,
                                builder: (context, visible, child) {
                                  return Stack(
                                    children: [
                                      Align(
                                        alignment: Alignment.center,
                                        child: _paintedMorphEndpoint(
                                          tag: 'third-route-shared',
                                          endpointKey: const ValueKey(
                                            'third-route-destination-endpoint',
                                          ),
                                          childKey: const ValueKey(
                                            'third-route-destination-child',
                                          ),
                                          paints: destinationPaints,
                                          flightDelegate: _TestFlightDelegate(
                                            Colors.blue,
                                            captures,
                                          ),
                                        ),
                                      ),
                                      if (visible)
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: _paintedMorphEndpoint(
                                            tag: 'third-route-shared',
                                            endpointKey: const ValueKey(
                                              'third-route-third-endpoint',
                                            ),
                                            childKey: const ValueKey(
                                              'third-route-third-child',
                                            ),
                                            paints: thirdPaints,
                                            flightDelegate: _TestFlightDelegate(
                                              Colors.green,
                                              captures,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
                        ),
                      );
                    },
                    child: const Text('Push'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CrossRouteRetargetTestApp extends StatelessWidget {
  const _CrossRouteRetargetTestApp({
    required this.showSameScreenDestination,
    required this.sourcePaints,
    required this.sameScreenDestinationPaints,
    required this.routeDestinationPaints,
    required this.captures,
    required this.animations,
    required this.firstFlightBounds,
    required this.flightKinds,
    this.routeDuration = const Duration(milliseconds: 800),
  });

  final ValueNotifier<bool> showSameScreenDestination;
  final _PaintCounter sourcePaints;
  final _PaintCounter sameScreenDestinationPaints;
  final _PaintCounter routeDestinationPaints;
  final List<_TestProperties> captures;
  final List<Animation<double>> animations;
  final List<Rect> firstFlightBounds;
  final List<MorphFlightKind> flightKinds;
  final Duration routeDuration;

  Widget _endpoint({
    required Color color,
    required Key endpointKey,
    required Key childKey,
    required _PaintCounter paints,
  }) {
    return _paintedMorphEndpoint(
      tag: 'cross-route-retarget-shared',
      endpointKey: endpointKey,
      childKey: childKey,
      paints: paints,
      duration: const Duration(milliseconds: 300),
      flightDelegate: _TestFlightDelegate(
        color,
        captures,
        animations: animations,
        firstFlightBounds: firstFlightBounds,
        flightKinds: flightKinds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: showSameScreenDestination,
                  builder: (context, showDestination, child) {
                    if (showDestination) {
                      return Positioned(
                        left: 160,
                        top: 360,
                        child: _endpoint(
                          color: Colors.blue,
                          endpointKey: const ValueKey(
                            'cross-route-same-screen-destination-endpoint',
                          ),
                          childKey: const ValueKey(
                            'cross-route-same-screen-destination-child',
                          ),
                          paints: sameScreenDestinationPaints,
                        ),
                      );
                    }
                    return Positioned(
                      left: 24,
                      top: 96,
                      child: _endpoint(
                        color: Colors.red,
                        endpointKey: const ValueKey(
                          'cross-route-source-endpoint',
                        ),
                        childKey: const ValueKey(
                          'cross-route-source-child',
                        ),
                        paints: sourcePaints,
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: FilledButton(
                    key: const ValueKey('push-cross-route-retarget'),
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        PageRouteBuilder<void>(
                          opaque: false,
                          transitionDuration: routeDuration,
                          pageBuilder:
                              (
                                context,
                                animation,
                                secondaryAnimation,
                              ) {
                                return Material(
                                  type: MaterialType.transparency,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        right: 32,
                                        bottom: 48,
                                        child: _endpoint(
                                          color: Colors.green,
                                          endpointKey: const ValueKey(
                                            'cross-route-destination-endpoint',
                                          ),
                                          childKey: const ValueKey(
                                            'cross-route-destination-child',
                                          ),
                                          paints: routeDestinationPaints,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                          transitionsBuilder:
                              (
                                context,
                                animation,
                                secondaryAnimation,
                                child,
                              ) => child,
                        ),
                      );
                    },
                    child: const Text('Push'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SkippedRouteOwnershipTestApp extends StatelessWidget {
  const _SkippedRouteOwnershipTestApp({
    required this.sourcePaints,
    required this.destinationPaints,
    required this.captures,
  });

  final _PaintCounter sourcePaints;
  final _PaintCounter destinationPaints;
  final List<_TestProperties> captures;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: _paintedMorphEndpoint(
                    tag: 'skipped-route-shared',
                    endpointKey: const ValueKey('skipped-route-source-endpoint'),
                    childKey: const ValueKey('skipped-route-source-child'),
                    paints: sourcePaints,
                    flightDelegate: _TestFlightDelegate(Colors.red, captures),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: FilledButton(
                    key: const ValueKey('push-skipped-route'),
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        PageRouteBuilder<void>(
                          opaque: false,
                          transitionDuration: const Duration(
                            milliseconds: 400,
                          ),
                          reverseTransitionDuration: const Duration(
                            milliseconds: 430,
                          ),
                          pageBuilder: (context, animation, secondaryAnimation) {
                            return Material(
                              type: MaterialType.transparency,
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: _paintedMorphEndpoint(
                                  tag: 'skipped-route-shared',
                                  endpointKey: const ValueKey(
                                    'skipped-route-destination-endpoint',
                                  ),
                                  childKey: const ValueKey(
                                    'skipped-route-destination-child',
                                  ),
                                  paints: destinationPaints,
                                  flightDelegate: _IncompatibleTestFlightDelegate(
                                    Colors.blue,
                                    captures,
                                  ),
                                ),
                              ),
                            );
                          },
                          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
                        ),
                      );
                    },
                    child: const Text('Push'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SameScreenDuringRoutePopTestApp extends StatelessWidget {
  const _SameScreenDuringRoutePopTestApp({
    required this.showSecondDestination,
    required this.captures,
  });

  final ValueNotifier<bool> showSecondDestination;
  final List<_TestProperties> captures;

  Morph _endpoint({
    required Color color,
    required Key childKey,
  }) {
    return Morph(
      tag: 'same-screen-during-pop',
      duration: const Duration(milliseconds: 400),
      curve: Curves.linear,
      flightDelegate: _TestFlightDelegate(color, captures),
      child: SizedBox.square(key: childKey, dimension: 48),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 24,
                  top: 96,
                  child: _endpoint(
                    color: Colors.red,
                    childKey: const ValueKey('pop-underlying-source'),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: FilledButton(
                    key: const ValueKey('push-same-screen-pop-route'),
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        PageRouteBuilder<void>(
                          opaque: false,
                          transitionDuration: const Duration(
                            milliseconds: 400,
                          ),
                          reverseTransitionDuration: const Duration(
                            milliseconds: 400,
                          ),
                          pageBuilder: (context, animation, secondaryAnimation) {
                            return Material(
                              type: MaterialType.transparency,
                              child: ValueListenableBuilder<bool>(
                                valueListenable: showSecondDestination,
                                builder: (context, showSecond, child) {
                                  return Align(
                                    alignment: Alignment.bottomRight,
                                    child: _endpoint(
                                      color: showSecond ? Colors.green : Colors.blue,
                                      childKey: ValueKey(
                                        showSecond ? 'pop-destination-second' : 'pop-destination-first',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          transitionsBuilder:
                              (
                                context,
                                animation,
                                secondaryAnimation,
                                child,
                              ) => child,
                        ),
                      );
                    },
                    child: const Text('Push'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DynamicReducedMotionRouteTestApp extends StatelessWidget {
  const _DynamicReducedMotionRouteTestApp({required this.disableAnimations});

  final ValueNotifier<bool> disableAnimations;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: disableAnimations,
          child: child,
          builder: (context, disabled, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: disabled,
              ),
              child: child!,
            );
          },
        );
      },
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                const Positioned(
                  left: 24,
                  top: 96,
                  child: Morph(
                    tag: 'dynamic-reduced-route',
                    child: Text(
                      'Reduced source',
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: FilledButton(
                    key: const ValueKey('push-dynamic-reduced-route'),
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        PageRouteBuilder<void>(
                          opaque: false,
                          transitionDuration: const Duration(
                            milliseconds: 400,
                          ),
                          reverseTransitionDuration: const Duration(
                            milliseconds: 400,
                          ),
                          pageBuilder: (context, animation, secondaryAnimation) {
                            return const Material(
                              type: MaterialType.transparency,
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: Morph(
                                  tag: 'dynamic-reduced-route',
                                  child: Text(
                                    'Reduced destination',
                                  ),
                                ),
                              ),
                            );
                          },
                          transitionsBuilder:
                              (
                                context,
                                animation,
                                secondaryAnimation,
                                child,
                              ) => child,
                        ),
                      );
                    },
                    child: const Text('Push'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void main() {
  group('Morph', () {
    testWidgets(
      'when no Morph supplies a duration, it should use 300 milliseconds',
      (tester) async {
        final captures = <_TestProperties>[];
        final animations = <Animation<double>>[];

        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'default-effective-duration',
              curve: Curves.linear,
              flightDelegate: _TestFlightDelegate(
                Colors.red,
                captures,
                animations: animations,
              ),
              child: const SizedBox.square(dimension: 48),
            ),
            destination: Morph(
              tag: 'default-effective-duration',
              curve: Curves.linear,
              flightDelegate: _TestFlightDelegate(
                Colors.blue,
                captures,
              ),
              child: const SizedBox.square(dimension: 48),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final progress = animations.single.value;
        await tester.pumpAndSettle();

        expect(progress, closeTo(0.5, 0.001));
      },
    );

    test('when no curve is provided, it should defer curve resolution', () {
      const morph = Morph(
        tag: 'default-curve',
        flightDelegate: _TestFlightDelegate(Colors.red, []),
        child: SizedBox.shrink(),
      );

      expect(morph.curve, isNull);
    });

    testWidgets(
      'when no Morph supplies a curve, it should use linear motion',
      (tester) async {
        final captures = <_TestProperties>[];
        final animations = <Animation<double>>[];

        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'default-effective-curve',
              duration: const Duration(milliseconds: 600),
              flightDelegate: _TestFlightDelegate(
                Colors.red,
                captures,
                animations: animations,
              ),
              child: const SizedBox.square(dimension: 48),
            ),
            destination: Morph(
              tag: 'default-effective-curve',
              duration: const Duration(milliseconds: 600),
              flightDelegate: _TestFlightDelegate(
                Colors.blue,
                captures,
              ),
              child: const SizedBox.square(dimension: 48),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final progress = animations.single.value;
        await tester.pumpAndSettle();

        expect(progress, closeTo(0.5, 0.001));
      },
    );

    testWidgets(
      'when a delegate mutates its endpoint transform, it should not change the captured flight geometry',
      (tester) async {
        final captures = <_TestProperties>[];
        final endpointTransforms = <Matrix4>[];
        final flights = <MorphFlight<_TestProperties>>[];
        final delegate = _TransformMutatingTestFlightDelegate(
          Colors.red,
          captures,
          endpointTransforms: endpointTransforms,
          flights: flights,
        );

        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'defensive-endpoint-transform',
              flightDelegate: delegate,
              child: const SizedBox.square(dimension: 48),
            ),
            destination: Morph(
              tag: 'defensive-endpoint-transform',
              flightDelegate: delegate,
              child: const SizedBox.square(dimension: 48),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        final flight = flights.single;
        final geometryWasPreserved = (
          MatrixUtils.matrixEquals(flight.source.transform, endpointTransforms[0]),
          MatrixUtils.matrixEquals(flight.destination.transform, endpointTransforms[1]),
        );
        await tester.pumpAndSettle();

        expect(geometryWasPreserved, (true, true));
      },
    );

    testWidgets(
      'when an endpoint remains unmatched, it should not capture its properties',
      (tester) async {
        final captures = <_TestProperties>[];
        var generation = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Morph(
                  tag: 'idle-rebuild',
                  flightDelegate: _TestFlightDelegate(Colors.red, captures),
                  child: SizedBox.square(
                    key: const ValueKey('stable-child'),
                    dimension: 48 + (generation * 0),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(captures, isEmpty);

        rebuild(() => generation += 1);
        await tester.pump();
        await tester.pump();

        expect(captures, isEmpty);
      },
    );

    testWidgets(
      'when an unmatched Overlay detaches, it should not look up its inactive render object',
      (tester) async {
        final captures = <_TestProperties>[];
        var showOverlay = true;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                if (!showOverlay) return const SizedBox();
                return Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) => Morph(
                        tag: 'detaching-overlay',
                        flightDelegate: _TestFlightDelegate(
                          Colors.red,
                          captures,
                        ),
                        child: const SizedBox.square(dimension: 48),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        rebuild(() => showOverlay = false);
        await tester.pump();

        expect(captures, isEmpty);
      },
    );

    testWidgets(
      'when equal tags live in different Overlays, '
      'it should isolate ownership and flights to each nearest Overlay',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final leftGeneration = ValueNotifier<int>(0);
        final rightGeneration = ValueNotifier<int>(0);
        final leftOverlayKey = GlobalKey<OverlayState>();
        final rightOverlayKey = GlobalKey<OverlayState>();
        addTearDown(leftGeneration.dispose);
        addTearDown(rightGeneration.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Row(
              children: [
                Expanded(
                  child: Overlay(
                    key: leftOverlayKey,
                    initialEntries: [
                      OverlayEntry(
                        builder: (context) => Center(
                          child: ValueListenableBuilder<int>(
                            valueListenable: leftGeneration,
                            builder: (context, generation, child) {
                              return Morph(
                                tag: 'overlay-isolated',
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.linear,
                                child: Text(
                                  'Left $generation',
                                  key: ValueKey('left-$generation'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Overlay(
                    key: rightOverlayKey,
                    initialEntries: [
                      OverlayEntry(
                        builder: (context) => Center(
                          child: ValueListenableBuilder<int>(
                            valueListenable: rightGeneration,
                            builder: (context, generation, child) {
                              return Morph(
                                tag: 'overlay-isolated',
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.linear,
                                child: Text(
                                  'Right $generation',
                                  key: ValueKey('right-$generation'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        leftGeneration.value = 1;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final leftFlight = (
          all: _morphOverlay().evaluate().length,
          left: find
              .descendant(
                of: find.byKey(leftOverlayKey),
                matching: _morphOverlay(),
              )
              .evaluate()
              .length,
          right: find
              .descendant(
                of: find.byKey(rightOverlayKey),
                matching: _morphOverlay(),
              )
              .evaluate()
              .length,
          restingRight: find.semantics.byLabel('Right 0').evaluate().length,
        );
        await tester.pumpAndSettle();

        rightGeneration.value = 1;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final rightFlight = (
          all: _morphOverlay().evaluate().length,
          left: find
              .descendant(
                of: find.byKey(leftOverlayKey),
                matching: _morphOverlay(),
              )
              .evaluate()
              .length,
          right: find
              .descendant(
                of: find.byKey(rightOverlayKey),
                matching: _morphOverlay(),
              )
              .evaluate()
              .length,
          settledLeft: find.semantics.byLabel('Left 1').evaluate().length,
        );

        expect(
          (leftFlight, rightFlight),
          (
            (all: 1, left: 1, right: 0, restingRight: 1),
            (all: 1, left: 0, right: 1, settledLeft: 1),
          ),
        );
        semantics.dispose();
      },
    );

    testWidgets(
      'when a same-screen flight starts, it should capture destination properties once',
      (tester) async {
        final captures = <_TestProperties>[];
        final showDestination = ValueNotifier<bool>(false);
        addTearDown(showDestination.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: showDestination,
                builder: (context, visible, child) {
                  return Stack(
                    children: [
                      Morph(
                        key: const ValueKey('same-screen-source-endpoint'),
                        tag: 'same-screen-capture',
                        flightDelegate: _TestFlightDelegate(
                          Colors.red,
                          captures,
                        ),
                        child: const SizedBox.square(
                          key: ValueKey('same-screen-source-child'),
                          dimension: 40,
                        ),
                      ),
                      if (visible)
                        Morph(
                          key: const ValueKey(
                            'same-screen-destination-endpoint',
                          ),
                          tag: 'same-screen-capture',
                          flightDelegate: _TestFlightDelegate(
                            Colors.blue,
                            captures,
                          ),
                          child: const SizedBox.square(
                            key: ValueKey('same-screen-destination-child'),
                            dimension: 80,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        captures.clear();

        showDestination.value = true;
        await tester.pump();
        await tester.pump();

        expect(
          captures.where((capture) => capture.color == Colors.blue),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'when a match appears, it should capture the source properties from that frame',
      (tester) async {
        final captures = <_TestProperties>[];
        final source = ValueNotifier(
          (color: Colors.red, showDestination: false),
        );
        addTearDown(source.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<({Color color, bool showDestination})>(
                valueListenable: source,
                builder: (context, value, child) {
                  return Stack(
                    children: [
                      Morph(
                        tag: 'fresh-live-source',
                        flightDelegate: _TestFlightDelegate(
                          value.color,
                          captures,
                        ),
                        child: const SizedBox.square(dimension: 40),
                      ),
                      if (value.showDestination)
                        Morph(
                          key: const ValueKey('fresh-live-destination'),
                          tag: 'fresh-live-source',
                          flightDelegate: _TestFlightDelegate(
                            Colors.blue,
                            captures,
                          ),
                          child: const SizedBox.square(dimension: 80),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        source.value = (color: Colors.green, showDestination: true);
        await tester.pumpAndSettle();

        expect(
          captures.where((properties) => properties.color == Colors.green),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'when a route flight starts, it should capture destination properties once',
      (tester) async {
        final captures = <_TestProperties>[];
        final firstFlightBounds = <Rect>[];
        final events = <String>[];
        await tester.pumpWidget(
          _RouteStartSynchronizationTestApp(
            captures: captures,
            firstFlightBounds: firstFlightBounds,
            events: events,
          ),
        );
        await tester.pumpAndSettle();
        captures.clear();

        await tester.tap(
          find.byKey(const ValueKey('push-synchronized-route')),
        );
        await tester.pump();
        await tester.pump();

        expect(
          captures.where((capture) => capture.color == Colors.blue),
          hasLength(1),
        );
      },
    );

    test(
      'when a flight properties is read, it should interpolate at the current animation progress',
      () {
        final captures = <_TestProperties>[];
        final delegate = _TestFlightDelegate(Colors.red, captures);
        final source = MorphEndpoint<_TestProperties>(
          properties: const _TestProperties(Colors.red, Offset(1, 1)),
          bounds: const Rect.fromLTWH(0, 0, 40, 40),
          localSize: const Size(40, 40),
          transform: Matrix4.identity(),
          axisScale: const Offset(1, 1),
        );
        final destination = MorphEndpoint<_TestProperties>(
          properties: const _TestProperties(Colors.blue, Offset(1, 1)),
          bounds: const Rect.fromLTWH(40, 40, 80, 80),
          localSize: const Size(80, 80),
          transform: Matrix4.identity(),
          axisScale: const Offset(1, 1),
        );
        final flight = MorphFlight<_TestProperties>(
          source: source,
          destination: destination,
          kind: MorphFlightKind.sameScreen,
          animation: const AlwaysStoppedAnimation<double>(0.5),
          flightDelegate: delegate,
        );

        expect(flight.properties.color, Color.lerp(Colors.red, Colors.blue, 0.5));
      },
    );

    testWidgets(
      'when resting, it should keep the child lean without a repaint boundary',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Morph(tag: 'resting', child: Text('Resting')),
            ),
          ),
        );

        final morph = find.byWidgetPredicate((widget) => widget is Morph);
        expect(
          find.descendant(of: morph, matching: find.byType(RepaintBoundary)),
          findsNothing,
        );
      },
    );

    testWidgets(
      'when ownership changes on one screen, it should report one completed flight',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'shared',
              onStart: () => events.add('start'),
              onEnd: () => events.add('end'),
              child: const Text('Source'),
            ),
            destination: Morph(
              tag: 'shared',
              onReceived: () => events.add('received'),
              child: const Text('Destination'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(events, ['start', 'received', 'end']);
      },
    );

    testWidgets(
      'when one Morph state rebuilds with a stable child key, it should not transfer ownership',
      (tester) async {
        final events = <String>[];
        var generation = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Scaffold(
                  body: Morph(
                    tag: 'stable-rebuild',
                    onStart: () => events.add('start'),
                    child: Text(
                      'Generation $generation',
                      key: const ValueKey('stable-morph-child'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        rebuild(() => generation += 1);
        await tester.pumpAndSettle();

        expect(events, isEmpty);
      },
    );

    testWidgets(
      'when one Morph state rebuilds with a different child key, it should transfer ownership',
      (tester) async {
        final events = <String>[];
        var generation = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Scaffold(
                  body: Morph(
                    tag: 'changing-rebuild',
                    onStart: () => events.add('start'),
                    onEnd: () => events.add('end'),
                    onReceived: () => events.add('received'),
                    child: Text(
                      'Generation $generation',
                      key: ValueKey('morph-child-$generation'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        rebuild(() => generation += 1);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(events, ['start', 'received', 'end']);
      },
    );

    testWidgets(
      'when a Morph reattaches before its old endpoint purges, it should preserve paint ownership with the new handle',
      (tester) async {
        final captures = <_TestProperties>[];
        final sourcePaints = _PaintCounter();
        final destinationPaints = _PaintCounter();
        final showDestination = ValueNotifier<bool>(false);
        final morphKey = GlobalKey();
        addTearDown(sourcePaints.dispose);
        addTearDown(destinationPaints.dispose);
        addTearDown(showDestination.dispose);
        var overlayGeneration = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Overlay(
                  key: ValueKey(overlayGeneration),
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) => ValueListenableBuilder<bool>(
                        valueListenable: showDestination,
                        builder: (context, visible, child) {
                          return Stack(
                            children: [
                              _paintedMorphEndpoint(
                                tag: 'reattached-visibility',
                                endpointKey: morphKey,
                                childKey: const ValueKey(
                                  'reattached-source-child',
                                ),
                                paints: sourcePaints,
                                flightDelegate: _TestFlightDelegate(
                                  Colors.red,
                                  captures,
                                ),
                              ),
                              if (visible)
                                _paintedMorphEndpoint(
                                  tag: 'reattached-visibility',
                                  endpointKey: const ValueKey(
                                    'reattached-destination-endpoint',
                                  ),
                                  childKey: const ValueKey(
                                    'reattached-destination-child',
                                  ),
                                  paints: destinationPaints,
                                  flightDelegate: _TestFlightDelegate(
                                    Colors.blue,
                                    captures,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final initialState = morphKey.currentState;

        rebuild(() => overlayGeneration += 1);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        showDestination.value = true;
        await tester.pumpAndSettle();
        sourcePaints.reset();
        destinationPaints.reset();
        sourcePaints.requestPaint();
        destinationPaints.requestPaint();
        await tester.pump();

        expect(
          (
            identical(initialState, morphKey.currentState),
            sourcePaints.count,
            destinationPaints.count,
          ),
          (true, 0, 1),
        );
      },
    );

    testWidgets(
      'when the final endpoint awaits its second-frame purge, it should request that frame',
      (tester) async {
        var visible = true;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Scaffold(
                  body: visible
                      ? const Morph(
                          tag: 'scheduled-endpoint-purge',
                          child: Text('Purge source'),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => visible = false);
        await tester.pump();
        final followUpFrameScheduled = tester.binding.hasScheduledFrame;
        await tester.pump();

        expect(followUpFrameScheduled, isTrue);
      },
    );

    testWidgets(
      'when an endpoint subtree is paint-hidden, it should pause tickers without changing layout, semantics, or input ownership',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final ticks = ValueNotifier<int>(0);
        final captures = <_TestProperties>[];
        var sourceTaps = 0;
        var destinationTaps = 0;
        addTearDown(ticks.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  const Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox.square(dimension: 48),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: Morph(
                      tag: 'ticker-ownership',
                      flightDelegate: _TestFlightDelegate(
                        Colors.red,
                        captures,
                      ),
                      child: Semantics(
                        label: 'Hidden Morph source',
                        button: true,
                        child: GestureDetector(
                          key: const ValueKey('ticker-source'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => sourceTaps += 1,
                          child: _TickCounter(
                            onTick: () => ticks.value += 1,
                            child: const SizedBox.square(dimension: 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Morph(
                      tag: 'ticker-ownership',
                      flightDelegate: _TestFlightDelegate(
                        Colors.blue,
                        captures,
                      ),
                      child: Semantics(
                        label: 'Visible Morph destination',
                        button: true,
                        child: GestureDetector(
                          key: const ValueKey('ticker-destination'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => destinationTaps += 1,
                          child: const SizedBox.square(dimension: 80),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final ticksBeforeHiddenPump = ticks.value;

        await tester.tap(
          find.byKey(const ValueKey('ticker-source')),
          warnIfMissed: false,
        );
        await tester.tap(find.byKey(const ValueKey('ticker-destination')));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          (
            ticks.value,
            tester.getSize(find.byKey(const ValueKey('ticker-source'))),
            find.semantics.byLabel('Hidden Morph source').evaluate().length,
            find.semantics.byLabel('Visible Morph destination').evaluate().length,
            sourceTaps,
            destinationTaps,
          ),
          (ticksBeforeHiddenPump, const Size(48, 48), 0, 1, 0, 1),
        );
        semantics.dispose();
      },
    );

    testWidgets(
      'when reduced motion is enabled, it should transfer ownership without flight callbacks',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _MorphTestApp(
            disableAnimations: true,
            source: Morph(
              tag: 'shared',
              onStart: () => events.add('start'),
              child: const Text('Source'),
            ),
            destination: Morph(
              tag: 'shared',
              onReceived: () => events.add('received'),
              child: const Text('Destination'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pumpAndSettle();

        expect(events, isEmpty);
      },
    );

    testWidgets(
      'when ownership returns before settling, it should retarget and reveal the current endpoint',
      (tester) async {
        await tester.pumpWidget(
          const _MorphTestApp(
            source: Morph(tag: 'shared', child: Text('Source')),
            destination: Morph(tag: 'shared', child: Text('Destination')),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Source'), findsOneWidget);
      },
    );

    testWidgets(
      'when a transparent route is pushed and popped, it should follow both route animations',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(_RouteMorphTestApp(events: events));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final forwardMidpoint = ModalRoute.of(
          tester.element(find.text('Destination')),
        )!.animation!.value;
        await tester.pumpAndSettle();
        Navigator.of(
          tester.element(find.text('Destination').first),
        ).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 215));
        final reverseMidpoint = ModalRoute.of(
          tester.element(find.text('Destination')),
        )!.animation!.value;
        await tester.pumpAndSettle();

        expect(
          (
            forwardMidpoint > 0 && forwardMidpoint < 1,
            reverseMidpoint > 0 && reverseMidpoint < 1,
          ),
          (true, true),
        );
      },
    );

    testWidgets(
      'when a route push overlay first paints, it should retain progress from flight capture and settle at the destination',
      (tester) async {
        final captures = <_TestProperties>[];
        final firstFlightBounds = <Rect>[];
        final events = <String>[];
        await tester.pumpWidget(
          _RouteStartSynchronizationTestApp(
            captures: captures,
            firstFlightBounds: firstFlightBounds,
            events: events,
          ),
        );
        await tester.pumpAndSettle();
        final sourceBounds = tester.getRect(
          find.byKey(const ValueKey('synchronized-route-source')),
        );

        await tester.tap(
          find.byKey(const ValueKey('push-synchronized-route')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final routeProgress = ModalRoute.of(
          tester.element(
            find.byKey(const ValueKey('synchronized-route-destination')),
          ),
        )!.animation!.value;
        final destinationBounds = tester.getRect(
          find.byKey(const ValueKey('synchronized-route-destination')),
        );
        final expectedFirstFlightBounds = Rect.lerp(
          sourceBounds,
          destinationBounds,
          routeProgress,
        )!;
        await tester.pumpAndSettle();

        expect(
          [
            routeProgress > 0,
            firstFlightBounds.single == expectedFirstFlightBounds,
            _morphOverlay().evaluate().isEmpty,
            ...events,
          ],
          [true, true, true, 'received'],
        );
      },
    );

    testWidgets(
      'when a held route is released by onStart, its first flight frame should retain one frame of route progress',
      (tester) async {
        final captures = <_TestProperties>[];
        final firstFlightBounds = <Rect>[];
        await tester.pumpWidget(
          _HeldRouteMorphTestApp(
            captures: captures,
            firstFlightBounds: firstFlightBounds,
          ),
        );
        await tester.pumpAndSettle();
        final sourceBounds = tester.getRect(
          find.byKey(const ValueKey('held-route-source')),
        );

        await tester.tap(find.byKey(const ValueKey('push-held-route')));
        await tester.pump();
        await tester.pump();
        final route = ModalRoute.of(
          tester.element(
            find.byKey(const ValueKey('held-route-destination')),
          ),
        )!;
        await tester.pump(const Duration(milliseconds: 16));
        final destinationBounds = tester.getRect(
          find.byKey(const ValueKey('held-route-destination')),
        );
        final expectedFlightBounds = Rect.lerp(
          sourceBounds,
          destinationBounds,
          route.animation!.value,
        )!;
        final renderedFlightBounds = tester.getRect(
          find.descendant(
            of: _morphOverlay(),
            matching: find.byType(ColoredBox),
          ),
        );

        expect(
          [
            route.animation!.value,
            renderedFlightBounds.left,
            renderedFlightBounds.top,
            renderedFlightBounds.right,
            renderedFlightBounds.bottom,
          ],
          [
            closeTo(0.04, 0.000001),
            closeTo(expectedFlightBounds.left, 0.000001),
            closeTo(expectedFlightBounds.top, 0.000001),
            closeTo(expectedFlightBounds.right, 0.000001),
            closeTo(expectedFlightBounds.bottom, 0.000001),
          ],
        );
      },
    );

    testWidgets(
      'when a route push starts, it should invoke only the departing endpoint onStart',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(_RouteMorphTestApp(events: events));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pump();
        await tester.pump();

        expect(events, ['source-start']);
      },
    );

    testWidgets(
      'when a route push settles, it should receive before ending the departing endpoint',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(_RouteMorphTestApp(events: events));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pumpAndSettle();

        expect(
          events,
          ['source-start', 'destination-received', 'source-end'],
        );
      },
    );

    testWidgets(
      'when a route pop starts, it should invoke only the departing destination onStart',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(_RouteMorphTestApp(events: events));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pumpAndSettle();
        events.clear();

        Navigator.of(tester.element(find.text('Destination'))).pop();
        await tester.pump();
        await tester.pump();

        expect(events, ['destination-start']);
      },
    );

    testWidgets(
      'when a route pop settles, it should receive before ending the departing destination',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(_RouteMorphTestApp(events: events));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pumpAndSettle();
        events.clear();

        Navigator.of(tester.element(find.text('Destination'))).pop();
        await tester.pumpAndSettle();

        expect(
          events,
          ['destination-start', 'source-received', 'destination-end'],
        );
      },
    );

    testWidgets(
      'when a route flight has not settled, it should not invoke onReceived',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(_RouteMorphTestApp(events: events));
        await tester.pumpAndSettle();

        expect(events, isEmpty);
        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(events, ['source-start']);
      },
    );

    testWidgets(
      'when a transparent route push settles, it should keep the source paint-hidden while the destination owns the tag',
      (tester) async {
        final sourcePaints = _PaintCounter();
        final destinationPaints = _PaintCounter();
        addTearDown(sourcePaints.dispose);
        addTearDown(destinationPaints.dispose);
        await tester.pumpWidget(
          _OwnershipRouteTestApp(
            sourcePaints: sourcePaints,
            destinationPaints: destinationPaints,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('push-ownership-route')),
        );
        await tester.pumpAndSettle();
        sourcePaints.reset();
        destinationPaints.reset();
        sourcePaints.requestPaint();
        destinationPaints.requestPaint();
        await tester.pump();

        expect(
          (sourcePaints.count, destinationPaints.count),
          (0, 1),
        );
      },
    );

    testWidgets(
      'when a destination is scaled for an interactive preview, it should paint only the destination endpoint',
      (tester) async {
        final sourcePaints = _PaintCounter();
        final destinationPaints = _PaintCounter();
        final destinationScale = ValueNotifier<double>(1);
        addTearDown(sourcePaints.dispose);
        addTearDown(destinationPaints.dispose);
        addTearDown(destinationScale.dispose);
        await tester.pumpWidget(
          _OwnershipRouteTestApp(
            sourcePaints: sourcePaints,
            destinationPaints: destinationPaints,
            destinationScale: destinationScale,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('push-ownership-route')),
        );
        await tester.pumpAndSettle();

        destinationScale.value = 0.72;
        await tester.pump();
        sourcePaints.reset();
        destinationPaints.reset();
        sourcePaints.requestPaint();
        destinationPaints.requestPaint();
        await tester.pump();

        expect(
          (sourcePaints.count, destinationPaints.count),
          (0, 1),
        );
      },
    );

    testWidgets(
      'when an unkeyed child rebuilds during a route flight, it should keep the route flight without retargeting',
      (tester) async {
        final destinationRebuild = ValueNotifier<int>(0);
        final captures = <_TestProperties>[];
        final flightKinds = <MorphFlightKind>[];
        addTearDown(destinationRebuild.dispose);
        await tester.pumpWidget(
          _RebuildingRouteTestApp(
            destinationRebuild: destinationRebuild,
            captures: captures,
            flightKinds: flightKinds,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('push-rebuilding-route')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        destinationRebuild.value += 1;
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();

        expect(flightKinds.toSet(), {MorphFlightKind.routePush});
      },
    );

    testWidgets(
      'when reduced motion transfers route ownership, it should paint only the destination endpoint',
      (tester) async {
        final sourcePaints = _PaintCounter();
        final destinationPaints = _PaintCounter();
        addTearDown(sourcePaints.dispose);
        addTearDown(destinationPaints.dispose);
        await tester.pumpWidget(
          _OwnershipRouteTestApp(
            sourcePaints: sourcePaints,
            destinationPaints: destinationPaints,
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('push-ownership-route')),
        );
        await tester.pumpAndSettle();
        sourcePaints.reset();
        destinationPaints.reset();
        sourcePaints.requestPaint();
        destinationPaints.requestPaint();
        await tester.pump();

        expect(
          (sourcePaints.count, destinationPaints.count),
          (0, 1),
        );
      },
    );

    testWidgets(
      'when a reduced-motion route pops, it should immediately transfer paint ownership to the underlying endpoint',
      (tester) async {
        final sourcePaints = _PaintCounter();
        final destinationPaints = _PaintCounter();
        addTearDown(sourcePaints.dispose);
        addTearDown(destinationPaints.dispose);
        await tester.pumpWidget(
          _OwnershipRouteTestApp(
            sourcePaints: sourcePaints,
            destinationPaints: destinationPaints,
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('push-ownership-route')),
        );
        await tester.pumpAndSettle();

        Navigator.of(
          tester.element(find.byKey(const ValueKey('destination-paint'))),
        ).pop();
        await tester.pump();
        sourcePaints.reset();
        destinationPaints.reset();
        sourcePaints.requestPaint();
        destinationPaints.requestPaint();
        await tester.pump();

        expect(
          (sourcePaints.count, destinationPaints.count),
          (1, 0),
        );
      },
    );

    testWidgets(
      'when an incompatible route pop is skipped, it should immediately transfer paint ownership to the underlying endpoint',
      (tester) async {
        final sourcePaints = _PaintCounter();
        final destinationPaints = _PaintCounter();
        final captures = <_TestProperties>[];
        addTearDown(sourcePaints.dispose);
        addTearDown(destinationPaints.dispose);
        await tester.pumpWidget(
          _SkippedRouteOwnershipTestApp(
            sourcePaints: sourcePaints,
            destinationPaints: destinationPaints,
            captures: captures,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('push-skipped-route')));
        await tester.pumpAndSettle();
        final pushDiagnostic = tester.takeException();

        Navigator.of(
          tester.element(
            find.byKey(const ValueKey('skipped-route-destination-child')),
          ),
        ).pop();
        await tester.pump();
        final popDiagnostic = tester.takeException();
        sourcePaints.reset();
        destinationPaints.reset();
        sourcePaints.requestPaint();
        destinationPaints.requestPaint();
        await tester.pump();

        expect(
          (
            pushDiagnostic is FlutterError,
            popDiagnostic is FlutterError,
            sourcePaints.count,
            destinationPaints.count,
          ),
          (true, true, 1, 0),
        );
      },
    );

    testWidgets(
      'when an incompatible endpoint retargets a same-screen flight, it should cancel the overlay and preserve only the new owner',
      (tester) async {
        final stage = ValueNotifier<int>(0);
        final sourcePaints = _PaintCounter();
        final destinationPaints = _PaintCounter();
        final thirdPaints = _PaintCounter();
        final captures = <_TestProperties>[];
        addTearDown(stage.dispose);
        addTearDown(sourcePaints.dispose);
        addTearDown(destinationPaints.dispose);
        addTearDown(thirdPaints.dispose);
        await tester.pumpWidget(
          _RetargetOwnershipTestApp(
            stage: stage,
            sourcePaints: sourcePaints,
            destinationPaints: destinationPaints,
            thirdPaints: thirdPaints,
            captures: captures,
          ),
        );
        await tester.pumpAndSettle();

        stage.value = 1;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        stage.value = 2;
        await tester.pump();
        await tester.pump();
        final diagnostic = tester.takeException();
        await tester.pumpAndSettle();
        sourcePaints.reset();
        destinationPaints.reset();
        thirdPaints.reset();
        sourcePaints.requestPaint();
        destinationPaints.requestPaint();
        thirdPaints.requestPaint();
        await tester.pump();

        expect(
          (
            diagnostic is FlutterError,
            _morphOverlay().evaluate().length,
            sourcePaints.count,
            destinationPaints.count,
            thirdPaints.count,
          ),
          (true, 0, 0, 0, 1),
        );
      },
    );

    testWidgets(
      'when a compatible endpoint retargets a same-screen flight, it should keep every resting endpoint hidden until the third owns the tag',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final stage = ValueNotifier<int>(0);
        final sourcePaints = _PaintCounter();
        final destinationPaints = _PaintCounter();
        final thirdPaints = _PaintCounter();
        final captures = <_TestProperties>[];
        addTearDown(stage.dispose);
        addTearDown(sourcePaints.dispose);
        addTearDown(destinationPaints.dispose);
        addTearDown(thirdPaints.dispose);
        await tester.pumpWidget(
          _RetargetOwnershipTestApp(
            stage: stage,
            sourcePaints: sourcePaints,
            destinationPaints: destinationPaints,
            thirdPaints: thirdPaints,
            captures: captures,
            compatibleThird: true,
            exposeSemantics: true,
          ),
        );
        await tester.pumpAndSettle();

        stage.value = 1;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        stage.value = 2;
        await tester.pump();
        await tester.pump();
        final inFlight = (
          overlayCount: _morphOverlay().evaluate().length,
          sourceSemantics: find.semantics.byLabel('Retarget source').evaluate().length,
          destinationSemantics: find.semantics.byLabel('Retarget destination').evaluate().length,
          thirdSemantics: find.semantics.byLabel('Retarget third').evaluate().length,
        );

        await tester.pumpAndSettle();

        expect(
          (
            inFlight,
            settledOverlayCount: _morphOverlay().evaluate().length,
            settledSourceSemantics: find.semantics.byLabel('Retarget source').evaluate().length,
            settledDestinationSemantics: find.semantics.byLabel('Retarget destination').evaluate().length,
            settledThirdSemantics: find.semantics.byLabel('Retarget third').evaluate().length,
          ),
          (
            (
              overlayCount: 1,
              sourceSemantics: 0,
              destinationSemantics: 0,
              thirdSemantics: 0,
            ),
            settledOverlayCount: 0,
            settledSourceSemantics: 0,
            settledDestinationSemantics: 0,
            settledThirdSemantics: 1,
          ),
        );
        semantics.dispose();
      },
    );

    testWidgets(
      'when a retained compound flight repaints, it should contain dirty propagation within its local paint bounds',
      (tester) async {
        await tester.pumpWidget(
          const _MorphTestApp(
            source: Morph(
              tag: 'retained-repaint-boundary',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Source')],
              ),
            ),
            destination: Morph(
              tag: 'retained-repaint-boundary',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Destination title'),
                  Text('Destination detail'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final renderObject = tester.renderObject<RenderBox>(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
          ),
        );
        final localPaintBounds = renderObject.paintBounds;
        final fullPaintBounds = Offset.zero & renderObject.size;

        expect(
          (
            renderObject.isRepaintBoundary,
            localPaintBounds.isFinite,
            localPaintBounds != fullPaintBounds,
            fullPaintBounds.intersect(localPaintBounds) == localPaintBounds,
          ),
          (true, true, true, true),
        );
      },
    );

    testWidgets(
      'when a retained Container flight paints a BoxShadow, it should include the shadow overflow in its paint bounds',
      (tester) async {
        const shadow = BoxShadow(
          color: Colors.black,
          offset: Offset(12, -8),
          spreadRadius: 6,
        );
        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'retained-shadow-bounds',
              duration: const Duration(milliseconds: 400),
              curve: Curves.linear,
              child: Container(
                key: const ValueKey('shadow-source'),
                width: 80,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  boxShadow: [shadow],
                ),
              ),
            ),
            destination: Morph(
              tag: 'retained-shadow-bounds',
              duration: const Duration(milliseconds: 400),
              curve: Curves.linear,
              child: Container(
                key: const ValueKey('shadow-destination'),
                width: 140,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  boxShadow: [shadow],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sourceBounds = tester.getRect(
          find.byKey(const ValueKey('shadow-source')),
        );

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final destinationBounds = tester.getRect(
          find.byKey(const ValueKey('shadow-destination')),
        );
        final renderObject = tester.renderObject<RenderBox>(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
          ),
        );
        final flightBounds = Rect.lerp(sourceBounds, destinationBounds, 0.3)!;
        final shadowBounds = flightBounds.shift(shadow.offset).inflate(shadow.spreadRadius);
        final requiredPaintBounds = flightBounds.expandToInclude(shadowBounds);

        expect(renderObject.paintBounds, requiredPaintBounds);
      },
    );

    testWidgets(
      'when a same-screen flight retargets onto a forward route, it should follow the remaining route animation without flashing',
      (tester) async {
        final showSameScreenDestination = ValueNotifier<bool>(false);
        final sourcePaints = _PaintCounter();
        final sameScreenDestinationPaints = _PaintCounter();
        final routeDestinationPaints = _PaintCounter();
        final captures = <_TestProperties>[];
        final animations = <Animation<double>>[];
        final firstFlightBounds = <Rect>[];
        final flightKinds = <MorphFlightKind>[];
        addTearDown(showSameScreenDestination.dispose);
        addTearDown(sourcePaints.dispose);
        addTearDown(sameScreenDestinationPaints.dispose);
        addTearDown(routeDestinationPaints.dispose);
        await tester.pumpWidget(
          _CrossRouteRetargetTestApp(
            showSameScreenDestination: showSameScreenDestination,
            sourcePaints: sourcePaints,
            sameScreenDestinationPaints: sameScreenDestinationPaints,
            routeDestinationPaints: routeDestinationPaints,
            captures: captures,
            animations: animations,
            firstFlightBounds: firstFlightBounds,
            flightKinds: flightKinds,
          ),
        );
        await tester.pumpAndSettle();

        showSameScreenDestination.value = true;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        final overlayFlight = find.descendant(
          of: _morphOverlay(),
          matching: find.byType(ColoredBox),
        );
        final sampledBounds = tester.getRect(overlayFlight);
        final sampledColor = tester.widget<ColoredBox>(overlayFlight).color;
        final sameScreenKind = flightKinds.last;
        sameScreenDestinationPaints.reset();
        routeDestinationPaints.reset();

        await tester.tap(
          find.byKey(const ValueKey('push-cross-route-retarget')),
        );
        await tester.pump();
        await tester.pump();
        final routeDestination = find.byKey(
          const ValueKey('cross-route-destination-child'),
        );
        final routeAnimation = ModalRoute.of(
          tester.element(routeDestination),
        )!.animation!;
        final routeStart = routeAnimation.value;
        final routeDestinationBounds = tester.getRect(routeDestination);
        final retargetKind = flightKinds.last;
        final retargetAnimation = animations.last;
        final retargetStartBounds = tester.getRect(overlayFlight);
        final retargetStartColor = tester
            .widget<ColoredBox>(
              overlayFlight,
            )
            .color;
        final retargetCapturedSourceBounds = firstFlightBounds.last;
        final routeDestinationMountPaints = routeDestinationPaints.count;
        sameScreenDestinationPaints.requestPaint();
        routeDestinationPaints.requestPaint();
        await tester.pump();
        final hiddenEndpointPaints = (
          sameScreenDestinationPaints.count,
          routeDestinationPaints.count,
        );

        await tester.pump(const Duration(milliseconds: 200));
        final normalizedRouteProgress = ((routeAnimation.value - routeStart) / (1 - routeStart)).clamp(0.0, 1.0);
        final retargetProgress = retargetAnimation.value;
        final expectedInFlightBounds = Rect.lerp(
          sampledBounds,
          routeDestinationBounds,
          normalizedRouteProgress,
        )!;
        final inFlightBounds = tester.getRect(overlayFlight);
        final expectedInFlightColor = Color.lerp(
          sampledColor,
          Colors.green,
          normalizedRouteProgress,
        );
        final inFlightColor = tester.widget<ColoredBox>(overlayFlight).color;
        await tester.pump(const Duration(milliseconds: 150));
        final activeAfterSameScreenDuration = _morphOverlay().evaluate().length;

        await tester.pumpAndSettle();
        sameScreenDestinationPaints.reset();
        routeDestinationPaints.reset();
        sameScreenDestinationPaints.requestPaint();
        routeDestinationPaints.requestPaint();
        await tester.pump();
        final settledEndpointPaints = (
          sameScreenDestinationPaints.count,
          routeDestinationPaints.count,
        );
        final inFlightBoundsMatch =
            (inFlightBounds.left - expectedInFlightBounds.left).abs() < 0.000001 &&
            (inFlightBounds.top - expectedInFlightBounds.top).abs() < 0.000001 &&
            (inFlightBounds.right - expectedInFlightBounds.right).abs() < 0.000001 &&
            (inFlightBounds.bottom - expectedInFlightBounds.bottom).abs() < 0.000001;
        final retargetCapturedSourceBoundsMatch =
            (retargetCapturedSourceBounds.left - sampledBounds.left).abs() < 0.000001 &&
            (retargetCapturedSourceBounds.top - sampledBounds.top).abs() < 0.000001 &&
            (retargetCapturedSourceBounds.right - sampledBounds.right).abs() < 0.000001 &&
            (retargetCapturedSourceBounds.bottom - sampledBounds.bottom).abs() < 0.000001;
        final retargetStartBoundsMatch =
            (retargetStartBounds.left - sampledBounds.left).abs() < 0.000001 &&
            (retargetStartBounds.top - sampledBounds.top).abs() < 0.000001 &&
            (retargetStartBounds.right - sampledBounds.right).abs() < 0.000001 &&
            (retargetStartBounds.bottom - sampledBounds.bottom).abs() < 0.000001;

        expect(
          (
            sameScreenKind,
            retargetKind,
            retargetStartBoundsMatch,
            retargetStartColor.toARGB32() == sampledColor.toARGB32(),
            retargetCapturedSourceBoundsMatch,
            routeAnimation.status,
            routeDestinationMountPaints,
            hiddenEndpointPaints,
            (retargetProgress - normalizedRouteProgress).abs() < 0.000001,
            inFlightBoundsMatch,
            inFlightColor.toARGB32() == expectedInFlightColor?.toARGB32(),
            activeAfterSameScreenDuration,
            _morphOverlay().evaluate().length,
            settledEndpointPaints,
          ),
          (
            MorphFlightKind.sameScreen,
            MorphFlightKind.routePush,
            true,
            true,
            true,
            AnimationStatus.completed,
            0,
            (0, 0),
            true,
            true,
            true,
            1,
            0,
            (0, 1),
          ),
        );
      },
    );

    testWidgets(
      'when a same-screen flight retargets onto a settled route, it should transfer ownership without a replacement flight',
      (tester) async {
        final showSameScreenDestination = ValueNotifier<bool>(false);
        final sourcePaints = _PaintCounter();
        final sameScreenDestinationPaints = _PaintCounter();
        final routeDestinationPaints = _PaintCounter();
        final captures = <_TestProperties>[];
        final animations = <Animation<double>>[];
        final firstFlightBounds = <Rect>[];
        final flightKinds = <MorphFlightKind>[];
        addTearDown(showSameScreenDestination.dispose);
        addTearDown(sourcePaints.dispose);
        addTearDown(sameScreenDestinationPaints.dispose);
        addTearDown(routeDestinationPaints.dispose);
        await tester.pumpWidget(
          _CrossRouteRetargetTestApp(
            showSameScreenDestination: showSameScreenDestination,
            sourcePaints: sourcePaints,
            sameScreenDestinationPaints: sameScreenDestinationPaints,
            routeDestinationPaints: routeDestinationPaints,
            captures: captures,
            animations: animations,
            firstFlightBounds: firstFlightBounds,
            flightKinds: flightKinds,
            routeDuration: Duration.zero,
          ),
        );
        await tester.pumpAndSettle();

        showSameScreenDestination.value = true;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        sameScreenDestinationPaints.reset();
        routeDestinationPaints.reset();

        await tester.tap(
          find.byKey(const ValueKey('push-cross-route-retarget')),
        );
        await tester.pump();
        await tester.pump();
        final routeDestination = find.byKey(
          const ValueKey('cross-route-destination-child'),
        );
        final routeStatus = ModalRoute.of(
          tester.element(routeDestination),
        )!.animation!.status;
        sameScreenDestinationPaints.reset();
        routeDestinationPaints.reset();
        sameScreenDestinationPaints.requestPaint();
        routeDestinationPaints.requestPaint();
        await tester.pump();

        expect(
          (
            routeStatus,
            flightKinds.last,
            flightKinds.every(
              (kind) => kind == MorphFlightKind.sameScreen,
            ),
            _morphOverlay().evaluate().length,
            sameScreenDestinationPaints.count,
            routeDestinationPaints.count,
          ),
          (
            AnimationStatus.completed,
            MorphFlightKind.sameScreen,
            true,
            0,
            0,
            1,
          ),
        );
      },
    );

    testWidgets(
      'when a third endpoint mounts during a route flight, it should deterministically own the tag after pending flights settle',
      (tester) async {
        final showThird = ValueNotifier<bool>(false);
        final sourcePaints = _PaintCounter();
        final destinationPaints = _PaintCounter();
        final thirdPaints = _PaintCounter();
        final captures = <_TestProperties>[];
        addTearDown(showThird.dispose);
        addTearDown(sourcePaints.dispose);
        addTearDown(destinationPaints.dispose);
        addTearDown(thirdPaints.dispose);
        await tester.pumpWidget(
          _ThirdEndpointRouteTestApp(
            showThird: showThird,
            sourcePaints: sourcePaints,
            destinationPaints: destinationPaints,
            thirdPaints: thirdPaints,
            captures: captures,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('push-third-endpoint-route')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        showThird.value = true;
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();
        sourcePaints.reset();
        destinationPaints.reset();
        thirdPaints.reset();
        sourcePaints.requestPaint();
        destinationPaints.requestPaint();
        thirdPaints.requestPaint();
        await tester.pump();

        expect(
          (
            _morphOverlay().evaluate().length,
            sourcePaints.count,
            destinationPaints.count,
            thirdPaints.count,
          ),
          (0, 0, 0, 1),
        );
      },
    );

    testWidgets(
      'when matching plain text children omit a delegate, it should use the optimized text flight',
      (tester) async {
        await tester.pumpWidget(
          const _MorphTestApp(
            source: Morph(
              tag: 'automatic-text',
              child: Text('Source', style: TextStyle(fontSize: 16)),
            ),
            destination: Morph(
              tag: 'automatic-text',
              child: Text('Destination', style: TextStyle(fontSize: 24)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'when automatic text is loosely constrained, it should capture its rendered endpoint width',
      (tester) async {
        const sourceKey = ValueKey('automatic-loose-source');
        const destinationKey = ValueKey(
          'automatic-loose-destination',
        );
        await tester.pumpWidget(
          const _MorphTestApp(
            source: Morph(
              tag: 'automatic-loose-text',
              child: Text('Source', key: sourceKey),
            ),
            destination: Morph(
              tag: 'automatic-loose-text',
              child: Text(
                'A longer centered destination',
                key: destinationKey,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sourceWidth = tester.getSize(find.byKey(sourceKey)).width;

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        final destinationWidth = tester.getSize(find.byKey(destinationKey)).width;
        await tester.pump(const Duration(milliseconds: 180));
        final renderObject = tester.renderObject<RenderBox>(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
          ),
        );
        final layoutWidth =
            renderObject
                    .toDiagnosticsNode()
                    .getProperties()
                    .singleWhere(
                      (property) => property.name == 'interpolatedTextLayoutWidth',
                    )
                    .value!
                as double;

        expect(
          layoutWidth,
          lessThanOrEqualTo(math.max(sourceWidth, destinationWidth)),
        );
      },
    );

    testWidgets(
      'when automatic endpoints have different child types, it should switch the generic child at the threshold',
      (tester) async {
        await tester.pumpWidget(
          _MorphTestApp(
            source: const Morph(
              tag: 'automatic-generic',
              child: Text('Source'),
            ),
            destination: Morph(
              tag: 'automatic-generic',
              child: Container(
                width: 80,
                height: 80,
                color: Colors.blue,
                child: const Text('Destination'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final sourceBeforeThreshold = find
            .descendant(
              of: _morphOverlay(),
              matching: find.text('Source'),
            )
            .evaluate()
            .length;

        await tester.pump(const Duration(milliseconds: 100));
        final destinationAfterThreshold = find
            .descendant(
              of: _morphOverlay(),
              matching: find.text('Destination'),
            )
            .evaluate()
            .length;

        expect(
          (
            sourceBeforeThreshold,
            destinationAfterThreshold,
            tester.takeException(),
          ),
          (1, 1, null),
        );
      },
    );

    testWidgets(
      'when a generic flight advances, it should rebuild its child only at the switch threshold',
      (tester) async {
        var sourceBuilds = 0;
        var destinationBuilds = 0;
        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'automatic-generic-builds',
              child: Builder(
                builder: (context) {
                  sourceBuilds += 1;
                  return const SizedBox.square(
                    dimension: 80,
                    child: Placeholder(),
                  );
                },
              ),
            ),
            destination: Morph(
              tag: 'automatic-generic-builds',
              child: Builder(
                builder: (context) {
                  destinationBuilds += 1;
                  return const SizedBox.square(
                    dimension: 100,
                    child: ColoredBox(color: Colors.blue),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        final buildsAtStart = (sourceBuilds, destinationBuilds);
        await tester.pump(const Duration(milliseconds: 40));
        await tester.pump(const Duration(milliseconds: 40));
        final buildsBeforeThreshold = (sourceBuilds, destinationBuilds);
        await tester.pump(const Duration(milliseconds: 100));
        final buildsAfterThreshold = (sourceBuilds, destinationBuilds);
        await tester.pump(const Duration(milliseconds: 40));

        expect(
          (
            buildsBeforeThreshold == buildsAtStart,
            buildsAfterThreshold.$1 == buildsAtStart.$1,
            buildsAfterThreshold.$2 == buildsAtStart.$2 + 1,
            (sourceBuilds, destinationBuilds) == buildsAfterThreshold,
          ),
          (true, true, true, true),
        );
      },
    );

    testWidgets(
      'when a same-state delegate type changes, it should reveal the destination without a flight',
      (tester) async {
        final captures = <_TestProperties>[];
        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'incompatible',
              flightDelegate: _TestFlightDelegate(
                Colors.red,
                captures,
              ),
              child: const Text('Source'),
            ),
            destination: Morph(
              tag: 'incompatible',
              flightDelegate: _IncompatibleTestFlightDelegate(
                Colors.blue,
                captures,
              ),
              child: Container(
                key: const ValueKey('destination-container'),
                width: 80,
                height: 80,
                color: Colors.blue,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pumpAndSettle();

        expect(
          (
            tester.takeException() == null,
            find.byKey(const ValueKey('destination-container')).evaluate().length,
          ),
          (true, 1),
        );
      },
    );

    testWidgets(
      'when a custom typed delegate captures a transform, it should expose the resolved scale',
      (tester) async {
        final captures = <_TestProperties>[];
        await tester.pumpWidget(
          _MorphTestApp(
            source: Transform.scale(
              scale: 0.5,
              child: Morph(
                tag: 'custom',
                flightDelegate: _TestFlightDelegate(Colors.red, captures),
                child: const SizedBox.square(dimension: 40),
              ),
            ),
            destination: Morph(
              tag: 'custom',
              flightDelegate: _TestFlightDelegate(Colors.blue, captures),
              child: const SizedBox.square(dimension: 80),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pumpAndSettle();

        expect(
          captures.any(
            (properties) => (properties.axisScale.dx - 0.5).abs() < 0.001,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'when a custom flight advances, it should position without an outer per-frame builder',
      (tester) async {
        final captures = <_TestProperties>[];
        final flights = <MorphFlight<_TestProperties>>[];
        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'render-positioned-custom',
              duration: const Duration(milliseconds: 400),
              curve: Curves.linear,
              flightDelegate: _TestFlightDelegate(
                Colors.red,
                captures,
                flights: flights,
              ),
              child: const SizedBox.square(dimension: 40),
            ),
            destination: Morph(
              tag: 'render-positioned-custom',
              duration: const Duration(milliseconds: 400),
              curve: Curves.linear,
              flightDelegate: _TestFlightDelegate(
                Colors.blue,
                captures,
                flights: flights,
              ),
              child: const SizedBox.square(dimension: 80),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final overlay = _morphOverlay();
        final flight = flights.single;
        final progress = flight.animation.value;
        final expectedBounds = Rect.fromLTWH(
          ui.lerpDouble(flight.source.bounds.left, flight.destination.bounds.left, progress)!,
          ui.lerpDouble(flight.source.bounds.top, flight.destination.bounds.top, progress)!,
          ui.lerpDouble(flight.source.bounds.width, flight.destination.bounds.width, progress)!,
          ui.lerpDouble(flight.source.bounds.height, flight.destination.bounds.height, progress)!,
        );
        final actualBounds = tester.getRect(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphFlightBoundary',
          ),
        );
        expect(
          (
            overlay.evaluate().length,
            find
                .descendant(
                  of: overlay,
                  matching: find.byWidgetPredicate(
                    (widget) => widget.runtimeType.toString() == '_MorphPositionedFlight',
                  ),
                )
                .evaluate()
                .length,
            find
                .descendant(
                  of: overlay,
                  matching: find.byType(AnimatedBuilder),
                )
                .evaluate()
                .length,
            find.descendant(of: overlay, matching: find.byType(PositionedTransition)).evaluate().length,
            (actualBounds.left - expectedBounds.left).abs() <= precisionErrorTolerance &&
                (actualBounds.top - expectedBounds.top).abs() <= precisionErrorTolerance &&
                (actualBounds.width - expectedBounds.width).abs() <= precisionErrorTolerance &&
                (actualBounds.height - expectedBounds.height).abs() <= precisionErrorTolerance,
          ),
          (1, 1, 2, 0, true),
        );
      },
    );

    testWidgets(
      'when a static custom flight moves, it should reuse its painted child layer',
      (tester) async {
        final captures = <_TestProperties>[];
        final flightPaints = _PaintCounter();
        addTearDown(flightPaints.dispose);
        Morph endpoint(Color color) {
          return Morph(
            tag: 'static-custom-layer',
            duration: const Duration(milliseconds: 400),
            curve: Curves.linear,
            flightDelegate: _TestFlightDelegate(
              color,
              captures,
              flightPaints: flightPaints,
              staticFlight: true,
            ),
            child: SizedBox.square(
              key: ValueKey<int>(color.toARGB32()),
              dimension: 48,
            ),
          );
        }

        await tester.pumpWidget(
          _MorphTestApp(
            source: endpoint(Colors.red),
            destination: endpoint(Colors.blue),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        flightPaints.reset();
        final before = tester.getRect(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphFlightBoundary',
          ),
        );
        final positionedFlight = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MorphPositionedFlight',
        );
        final positionedRenderObject = tester.renderObject(positionedFlight);
        int positionedLayoutCount() {
          final property = positionedRenderObject.toDiagnosticsNode().getProperties().singleWhere(
            (property) => property.name == 'layoutCount',
          );
          return property.value! as int;
        }

        final layerBoundary = tester.renderObject<RenderRepaintBoundary>(
          find.descendant(
            of: positionedFlight,
            matching: find.byType(RepaintBoundary),
          ),
        );
        final constraintsBefore = layerBoundary.constraints;
        final layoutCountBefore = positionedLayoutCount();
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pump(const Duration(milliseconds: 80));
        final after = tester.getRect(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphFlightBoundary',
          ),
        );

        expect(
          (
            moved: before != after,
            sizeStable:
                (before.width - after.width).abs() <= precisionErrorTolerance &&
                (before.height - after.height).abs() <= precisionErrorTolerance,
            constraintsStable: layerBoundary.constraints == constraintsBefore,
            layoutStable: positionedLayoutCount() == layoutCountBefore,
            paints: flightPaints.count,
          ),
          (
            moved: true,
            sizeStable: true,
            constraintsStable: true,
            layoutStable: true,
            paints: 0,
          ),
        );
      },
    );

    testWidgets(
      'when a detached source changed since mounting, it should capture its last painted properties and transform',
      (tester) async {
        final captures = <_TestProperties>[];
        final source = ValueNotifier(
          (showDestination: false, color: Colors.red, scale: 0.5),
        );
        addTearDown(source.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<({Color color, double scale, bool showDestination})>(
                valueListenable: source,
                builder: (context, value, child) {
                  if (value.showDestination) {
                    return Morph(
                      tag: 'changed-detached-source',
                      flightDelegate: _TestFlightDelegate(
                        Colors.blue,
                        captures,
                      ),
                      child: const SizedBox.square(dimension: 80),
                    );
                  }
                  return Transform.scale(
                    scale: value.scale,
                    child: Morph(
                      tag: 'changed-detached-source',
                      flightDelegate: _TestFlightDelegate(
                        value.color,
                        captures,
                      ),
                      child: const SizedBox.square(dimension: 40),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        source.value = (
          showDestination: false,
          color: Colors.green,
          scale: 0.75,
        );
        await tester.pump();

        source.value = (
          showDestination: true,
          color: Colors.green,
          scale: 0.75,
        );
        await tester.pumpAndSettle();

        expect(
          captures.any(
            (properties) => properties.color == Colors.green && (properties.axisScale.dx - 0.75).abs() < 0.001,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'when a resting endpoint is reparented, it should capture geometry from its current ancestry',
      (tester) async {
        final stage = ValueNotifier<int>(0);
        final endpointKey = GlobalKey();
        final captures = <_TestProperties>[];
        final flights = <MorphFlight<_TestProperties>>[];
        addTearDown(stage.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<int>(
                valueListenable: stage,
                builder: (context, value, child) {
                  final endpoint = Morph(
                    key: endpointKey,
                    tag: 'reparented-geometry',
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.linear,
                    flightDelegate: _TestFlightDelegate(
                      value == 2 ? Colors.blue : Colors.red,
                      captures,
                      flights: flights,
                    ),
                    child: SizedBox.square(
                      key: ValueKey(value == 2 ? 'reparented-destination' : 'reparented-source'),
                      dimension: 48,
                    ),
                  );
                  if (value == 0) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: endpoint,
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(left: 180, top: 120),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: endpoint,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        stage.value = 1;
        await tester.pump();
        final expectedSourceBounds = tester.getRect(
          find.byKey(const ValueKey('reparented-source')),
        );
        stage.value = 2;
        await tester.pump();
        await tester.pump();
        final capturedSourceBounds = flights.single.source.bounds;
        await tester.pumpAndSettle();

        expect(capturedSourceBounds, expectedSourceBounds);
      },
    );

    testWidgets(
      'when a third endpoint retargets an active flight, it should expose the sampled source transform',
      (tester) async {
        final stage = ValueNotifier<int>(0);
        final captures = <_TestProperties>[];
        final animations = <Animation<double>>[];
        final flightTransforms = <({Matrix4 source, Matrix4 destination})>[];
        addTearDown(stage.dispose);
        Widget endpoint({
          required String id,
          required double left,
          required double scale,
          required Color color,
        }) {
          return Positioned(
            left: left,
            top: 96,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: Morph(
                key: ValueKey('sampled-transform-$id'),
                tag: 'sampled-transform-retarget',
                duration: const Duration(milliseconds: 400),
                curve: Curves.linear,
                flightDelegate: _TestFlightDelegate(
                  color,
                  captures,
                  animations: animations,
                  flightTransforms: flightTransforms,
                ),
                child: SizedBox.square(
                  key: ValueKey('sampled-transform-$id-child'),
                  dimension: 40,
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<int>(
                valueListenable: stage,
                builder: (context, value, child) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      endpoint(
                        id: 'source',
                        left: 20,
                        scale: 0.5,
                        color: Colors.red,
                      ),
                      if (value >= 1)
                        endpoint(
                          id: 'destination',
                          left: 180,
                          scale: 1,
                          color: Colors.blue,
                        ),
                      if (value >= 2)
                        endpoint(
                          id: 'third',
                          left: 320,
                          scale: 1.5,
                          color: Colors.green,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        stage.value = 1;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final sampledProgress = animations.single.value;
        stage.value = 2;
        await tester.pump();
        await tester.pump();
        final expectedSourceTransform = Matrix4Tween(
          begin: flightTransforms.first.source,
          end: flightTransforms.first.destination,
        ).lerp(sampledProgress);
        final actualSourceTransform = flightTransforms[1].source;
        final greatestDelta = List<double>.generate(
          16,
          (index) => (actualSourceTransform.storage[index] - expectedSourceTransform.storage[index]).abs(),
        ).reduce(math.max);

        expect(greatestDelta, lessThan(0.001));
      },
    );

    testWidgets(
      'when same-frame flights have matching timing, they should expose synchronized progress',
      (tester) async {
        final captures = <_TestProperties>[];
        final animations = <Animation<double>>[];
        Widget endpoint(String suffix, Color color, String phase) {
          return Morph(
            tag: 'shared-$suffix',
            flightDelegate: _TestFlightDelegate(
              color,
              captures,
              animations: animations,
            ),
            child: SizedBox.square(
              key: ValueKey('$suffix-$phase'),
              dimension: 40,
            ),
          );
        }

        await tester.pumpWidget(
          _MorphTestApp(
            source: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                endpoint('first', Colors.red, 'source'),
                endpoint('second', Colors.orange, 'source'),
              ],
            ),
            destination: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                endpoint('first', Colors.blue, 'destination'),
                endpoint('second', Colors.green, 'destination'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(animations.map((animation) => animation.value).toSet().length, 1);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'when same-State source properties throw, it should report the error and reveal the destination without a flight',
      (tester) async {
        final captures = <_TestProperties>[];
        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'throwing-same-state-capture',
              flightDelegate: _ThrowingTestFlightDelegate(
                Colors.red,
                captures,
                throwOnCapture: true,
              ),
              child: const SizedBox.square(
                key: ValueKey('throwing-capture-source'),
                dimension: 48,
              ),
            ),
            destination: Morph(
              tag: 'throwing-same-state-capture',
              flightDelegate: _ThrowingTestFlightDelegate(
                Colors.blue,
                captures,
                throwOnCapture: false,
              ),
              child: const SizedBox.square(
                key: ValueKey('throwing-capture-destination'),
                dimension: 48,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        final exception = tester.takeException();
        await tester.pump();

        expect(
          (
            exception is StateError,
            _morphOverlay().evaluate().length,
            find.byKey(const ValueKey('throwing-capture-destination')).evaluate().length,
          ),
          (true, 0, 1),
        );
      },
    );

    testWidgets(
      'when an overlay unmounts during an active same-screen flight, it should dispose the flight before the overlay',
      (tester) async {
        await tester.pumpWidget(
          const _MorphTestApp(
            source: Morph(
              tag: 'unmount-active-flight',
              duration: Duration(seconds: 1),
              curve: Curves.linear,
              child: Text('Unmount source'),
            ),
            destination: Morph(
              tag: 'unmount-active-flight',
              duration: Duration(seconds: 1),
              curve: Curves.linear,
              child: Text('Unmount destination'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(const SizedBox.shrink());
        final unmountError = tester.takeException();
        await tester.pump();
        final deferredError = tester.takeException();

        expect((unmountError, deferredError), (null, null));
      },
    );

    testWidgets(
      'when onStart throws, it should still reveal an endpoint and remove the flight overlay',
      (tester) async {
        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'throwing-start',
              duration: const Duration(milliseconds: 100),
              curve: Curves.linear,
              onStart: () => throw StateError('start failed'),
              child: const Text('Throwing start source'),
            ),
            destination: const Morph(
              tag: 'throwing-start',
              duration: Duration(milliseconds: 100),
              curve: Curves.linear,
              child: Text(
                'Throwing start destination',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        final error = tester.takeException();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump();
        final observed = (
          error is StateError,
          _morphOverlay().evaluate().length,
          find.text('Throwing start destination').evaluate().length,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();

        expect(observed, (true, 0, 1));
      },
    );

    testWidgets(
      'when onReceived throws, it should still remove the settled flight overlay',
      (tester) async {
        await tester.pumpWidget(
          _MorphTestApp(
            source: const Morph(
              tag: 'throwing-receive',
              duration: Duration(milliseconds: 100),
              curve: Curves.linear,
              child: Text('Throwing receive source'),
            ),
            destination: Morph(
              tag: 'throwing-receive',
              duration: const Duration(milliseconds: 100),
              curve: Curves.linear,
              onReceived: () => throw StateError('receive failed'),
              child: const Text(
                'Throwing receive destination',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump();
        final error = tester.takeException();
        final observed = (
          error is StateError,
          _morphOverlay().evaluate().length,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();

        expect(observed, (true, 0));
      },
    );

    testWidgets(
      'when onEnd throws, it should still remove the settled flight overlay',
      (tester) async {
        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'throwing-end',
              duration: const Duration(milliseconds: 100),
              curve: Curves.linear,
              onEnd: () => throw StateError('end failed'),
              child: const Text('Throwing end source'),
            ),
            destination: const Morph(
              tag: 'throwing-end',
              duration: Duration(milliseconds: 100),
              curve: Curves.linear,
              child: Text('Throwing end destination'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump();
        final error = tester.takeException();
        final observed = (
          error is StateError,
          _morphOverlay().evaluate().length,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();

        expect(observed, (true, 0));
      },
    );

    testWidgets(
      'when a retained Column contains a shadowed Container, its local paint bounds should include the nested shadow',
      (tester) async {
        const shadow = BoxShadow(
          color: Colors.black,
          offset: Offset(12, -8),
          spreadRadius: 6,
        );
        await tester.pumpWidget(
          _MorphTestApp(
            source: Morph(
              tag: 'retained-nested-shadow-bounds',
              duration: const Duration(milliseconds: 400),
              curve: Curves.linear,
              child: Column(
                key: const ValueKey('nested-shadow-source-column'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const ValueKey('nested-shadow-child'),
                    width: 80,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      boxShadow: [shadow],
                    ),
                  ),
                ],
              ),
            ),
            destination: Morph(
              tag: 'retained-nested-shadow-bounds',
              duration: const Duration(milliseconds: 400),
              curve: Curves.linear,
              child: Column(
                key: const ValueKey('nested-shadow-destination-column'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const ValueKey('nested-shadow-child'),
                    width: 140,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      boxShadow: [shadow],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sourceBounds = tester.getRect(
          find.byKey(const ValueKey('nested-shadow-source-column')),
        );

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final destinationBounds = tester.getRect(
          find.byKey(const ValueKey('nested-shadow-destination-column')),
        );
        final renderObject = tester.renderObject<RenderBox>(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
          ),
        );
        final flightBounds = Rect.lerp(sourceBounds, destinationBounds, 0.3)!;
        final shadowBounds = flightBounds.shift(shadow.offset).inflate(shadow.spreadRadius);
        final requiredPaintBounds = flightBounds.expandToInclude(shadowBounds);

        expect(renderObject.paintBounds, requiredPaintBounds);
      },
    );

    testWidgets(
      'when a retained Column paints a nested Container shadow, it should not clip the shadow to the child layout rect',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        const screenKey = ValueKey('nested-shadow-screen');
        const shadowColor = Color(0xFFFF00FF);
        await tester.pumpWidget(
          RepaintBoundary(
            key: screenKey,
            child: _MorphTestApp(
              source: Morph(
                tag: 'retained-nested-shadow-paint',
                duration: const Duration(milliseconds: 400),
                curve: Curves.linear,
                child: Column(
                  key: const ValueKey('painted-shadow-source-column'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      key: const ValueKey('painted-shadow-child'),
                      width: 80,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            offset: Offset(12, 0),
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              destination: Morph(
                tag: 'retained-nested-shadow-paint',
                duration: const Duration(milliseconds: 400),
                curve: Curves.linear,
                child: Column(
                  key: const ValueKey('painted-shadow-destination-column'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      key: const ValueKey('painted-shadow-child'),
                      width: 80,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            offset: Offset(12, 0),
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sourceBounds = tester.getRect(
          find.byKey(const ValueKey('painted-shadow-source-column')),
        );

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final destinationBounds = tester.getRect(
          find.byKey(const ValueKey('painted-shadow-destination-column')),
        );
        final flightBounds = Rect.lerp(sourceBounds, destinationBounds, 0.3)!;
        final screenBounds = tester.getRect(find.byKey(screenKey));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(screenKey),
        );
        final sampleX = (flightBounds.right + 10 - screenBounds.left).round();
        final sampleY = (flightBounds.center.dy - screenBounds.top).round();
        final sampledColor = await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final byteOffset = (sampleY * image.width + sampleX) * 4;
          final color = Color.fromARGB(
            bytes!.getUint8(byteOffset + 3),
            bytes.getUint8(byteOffset),
            bytes.getUint8(byteOffset + 1),
            bytes.getUint8(byteOffset + 2),
          );
          image.dispose();
          return color;
        });

        expect(sampledColor, shadowColor);
      },
    );

    testWidgets(
      'when a route pops during a same-screen flight, it should keep a continuous overlay flight',
      (tester) async {
        final showSecondDestination = ValueNotifier<bool>(false);
        final captures = <_TestProperties>[];
        addTearDown(showSecondDestination.dispose);
        await tester.pumpWidget(
          _SameScreenDuringRoutePopTestApp(
            showSecondDestination: showSecondDestination,
            captures: captures,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('push-same-screen-pop-route')),
        );
        await tester.pumpAndSettle();

        showSecondDestination.value = true;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        Navigator.of(
          tester.element(find.byKey(const ValueKey('pop-destination-second'))),
        ).pop();
        await tester.pump();
        final overlayWasRetained = _morphOverlay().evaluate().length == 1;
        await tester.pumpAndSettle();

        expect(overlayWasRetained, isTrue);
      },
    );

    testWidgets(
      'when a completion rebuild starts another flight, it should not let the old overlay cancel it',
      (tester) async {
        var firstDestination = false;
        var secondDestination = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Stack(
                  children: [
                    Align(
                      alignment: firstDestination ? Alignment.bottomRight : Alignment.topLeft,
                      child: Morph(
                        tag: 'overlay-generation-first',
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.linear,
                        onEnd: () => update(() => secondDestination = true),
                        child: SizedBox.square(
                          key: ValueKey('overlay-generation-first-$firstDestination'),
                          dimension: 48,
                        ),
                      ),
                    ),
                    Align(
                      alignment: secondDestination ? Alignment.bottomLeft : Alignment.topRight,
                      child: Morph(
                        tag: 'overlay-generation-second',
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.linear,
                        child: SizedBox.square(
                          key: ValueKey('overlay-generation-second-$secondDestination'),
                          dimension: 48,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();

        update(() => firstDestination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        for (var frame = 0; frame < 4 && !secondDestination; frame += 1) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        await tester.pump();
        await tester.pump();
        final observed = (
          secondDestination,
          find.byKey(const ValueKey<Object>('overlay-generation-second')).evaluate().length,
          _morphOverlay().evaluate().length,
        );
        await tester.pumpAndSettle();

        expect(observed, (true, 1, 1));
      },
    );

    testWidgets(
      'when reduced motion becomes enabled before a route pop, it should transfer ownership without a flight',
      (tester) async {
        final disableAnimations = ValueNotifier<bool>(false);
        addTearDown(disableAnimations.dispose);
        await tester.pumpWidget(
          _DynamicReducedMotionRouteTestApp(
            disableAnimations: disableAnimations,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('push-dynamic-reduced-route')),
        );
        await tester.pumpAndSettle();

        disableAnimations.value = true;
        await tester.pump();
        Navigator.of(tester.element(find.text('Reduced destination'))).pop();
        await tester.pump();
        final overlayCount = _morphOverlay().evaluate().length;
        await tester.pumpAndSettle();

        expect(overlayCount, 0);
      },
    );

    testWidgets(
      'when a reduced-motion endpoint arrives during an active flight, it should cancel the flight immediately',
      (tester) async {
        final disableAnimations = ValueNotifier<bool>(false);
        final stage = ValueNotifier<int>(0);
        final captures = <_TestProperties>[];
        final flightPaints = _PaintCounter();
        addTearDown(disableAnimations.dispose);
        addTearDown(stage.dispose);
        addTearDown(flightPaints.dispose);
        Widget endpoint(
          String text,
          Alignment alignment,
          Color color,
        ) {
          return Align(
            alignment: alignment,
            child: Morph(
              key: ValueKey(text),
              tag: 'dynamic-reduced-active-flight',
              duration: const Duration(milliseconds: 400),
              curve: Curves.linear,
              flightDelegate: _TestFlightDelegate(
                color,
                captures,
                flightPaints: flightPaints,
              ),
              child: SizedBox.square(
                key: ValueKey('$text-child'),
                dimension: 48,
              ),
            ),
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) {
              return ValueListenableBuilder<bool>(
                valueListenable: disableAnimations,
                child: child,
                builder: (context, disabled, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations: disabled,
                    ),
                    child: child!,
                  );
                },
              );
            },
            home: Scaffold(
              body: ValueListenableBuilder<int>(
                valueListenable: stage,
                builder: (context, value, child) {
                  return Stack(
                    children: [
                      endpoint(
                        'Reduced active source',
                        Alignment.topLeft,
                        Colors.red,
                      ),
                      if (value >= 1)
                        endpoint(
                          'Reduced active destination',
                          Alignment.center,
                          Colors.blue,
                        ),
                      if (value >= 2)
                        endpoint(
                          'Reduced active third',
                          Alignment.bottomRight,
                          Colors.green,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        stage.value = 1;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        flightPaints.reset();
        disableAnimations.value = true;
        stage.value = 2;
        await tester.pump();
        final sameFramePaintCount = flightPaints.count;
        final sameFrameOverlayCount = _morphOverlay().evaluate().length;
        await tester.pump();
        final settledOverlayCount = _morphOverlay().evaluate().length;

        expect(
          (
            sameFramePaintCount,
            sameFrameOverlayCount,
            settledOverlayCount,
          ),
          (0, 1, 0),
        );
      },
    );

    testWidgets(
      'when reduced motion becomes enabled during an active flight, it should cancel without completion callbacks',
      (tester) async {
        final disableAnimations = ValueNotifier<bool>(false);
        final showDestination = ValueNotifier<bool>(false);
        final events = <String>[];
        addTearDown(disableAnimations.dispose);
        addTearDown(showDestination.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) {
              return ValueListenableBuilder<bool>(
                valueListenable: disableAnimations,
                child: child,
                builder: (context, disabled, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations: disabled,
                    ),
                    child: child!,
                  );
                },
              );
            },
            home: Scaffold(
              body: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Morph(
                      tag: 'dynamic-reduced-running-flight',
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      onStart: () => events.add('start'),
                      onEnd: () => events.add('end'),
                      child: const Text(
                        'Dynamic reduced source',
                        key: ValueKey('dynamic-reduced-source-child'),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: showDestination,
                    builder: (context, show, child) {
                      if (!show) return const SizedBox.shrink();
                      return Align(
                        alignment: Alignment.bottomRight,
                        child: Morph(
                          tag: 'dynamic-reduced-running-flight',
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.linear,
                          onReceived: () => events.add('received'),
                          child: const Text(
                            'Dynamic reduced destination',
                            key: ValueKey(
                              'dynamic-reduced-destination-child',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        showDestination.value = true;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        disableAnimations.value = true;
        await tester.pump();
        await tester.pump();

        expect(
          (_morphOverlay().evaluate().length, events.join(',')),
          (0, 'start'),
        );
      },
    );

    testWidgets(
      'when ownership returns to the origin, it should reverse over the elapsed forward duration',
      (tester) async {
        await tester.pumpWidget(
          const _MorphTestApp(
            source: Morph(
              tag: 'timed-reverse',
              duration: Duration(milliseconds: 400),
              curve: Curves.linear,
              child: Text(
                'Timed reverse source',
                key: ValueKey('timed-reverse-source'),
              ),
            ),
            destination: Morph(
              tag: 'timed-reverse',
              duration: Duration(milliseconds: 400),
              curve: Curves.linear,
              child: Text(
                'Timed reverse destination',
                key: ValueKey('timed-reverse-destination'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));
        await tester.pump();
        final overlayCount = _morphOverlay().evaluate().length;
        await tester.pumpAndSettle();

        expect(overlayCount, 0);
      },
    );

    testWidgets(
      'when ownership returns through a distinct endpoint State, it should reverse over the elapsed forward duration',
      (tester) async {
        var showDestination = false;
        var originVersion = 0;
        late StateSetter update;
        final captures = <_TestProperties>[];
        final events = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  final builtOriginVersion = originVersion;
                  return Stack(
                    children: [
                      if (!showDestination)
                        KeyedSubtree(
                          key: const ValueKey('distinct-source-owner'),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Morph(
                              tag: 'distinct-origin-reversal',
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.linear,
                              onStart: () => events.add('a$builtOriginVersion-start'),
                              onEnd: () => events.add('a$builtOriginVersion-end'),
                              onReceived: () => events.add('a$builtOriginVersion-received'),
                              flightDelegate: _TestFlightDelegate(
                                Colors.red,
                                captures,
                              ),
                              child: SizedBox.square(
                                key: ValueKey<String>(
                                  'distinct-source-child'.substring(0),
                                ),
                                dimension: 48,
                              ),
                            ),
                          ),
                        ),
                      if (showDestination)
                        KeyedSubtree(
                          key: const ValueKey('distinct-destination-owner'),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Morph(
                              tag: 'distinct-origin-reversal',
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.linear,
                              onStart: () => events.add('b-start'),
                              onEnd: () => events.add('b-end'),
                              onReceived: () => events.add('b-received'),
                              flightDelegate: _TestFlightDelegate(
                                Colors.blue,
                                captures,
                              ),
                              child: const SizedBox.square(
                                key: ValueKey('distinct-destination-child'),
                                dimension: 48,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => showDestination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final forwardOverlayCount = _morphOverlay().evaluate().length;
        update(() {
          originVersion = 1;
          showDestination = false;
        });
        await tester.pump();
        await tester.pump();
        final returnOverlayCount = _morphOverlay().evaluate().length;
        await tester.pump(const Duration(milliseconds: 110));
        await tester.pump();

        expect(
          (
            forwardOverlayCount,
            returnOverlayCount,
            _morphOverlay().evaluate().length,
            events.join(','),
          ),
          (1, 1, 0, 'a0-start,b-start,a1-received,b-end'),
        );
      },
    );

    testWidgets(
      'when ownership returns to a moved origin, it should target the current origin geometry',
      (tester) async {
        final state = ValueNotifier(
          (showDestination: false, moveOrigin: false),
        );
        final captures = <_TestProperties>[];
        final flights = <MorphFlight<_TestProperties>>[];
        addTearDown(state.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<({bool showDestination, bool moveOrigin})>(
                valueListenable: state,
                builder: (context, value, child) {
                  final showDestination = value.showDestination;
                  return Align(
                    alignment: showDestination
                        ? Alignment.bottomRight
                        : value.moveOrigin
                        ? Alignment.centerLeft
                        : Alignment.topLeft,
                    child: Morph(
                      tag: 'moved-origin-reversal',
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      flightDelegate: _TestFlightDelegate(
                        showDestination ? Colors.blue : Colors.red,
                        captures,
                        flights: flights,
                      ),
                      child: SizedBox.square(
                        key: ValueKey(
                          showDestination ? 'moved-origin-destination' : 'moved-origin-source',
                        ),
                        dimension: 48,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        state.value = (showDestination: true, moveOrigin: false);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        state.value = (showDestination: false, moveOrigin: true);
        await tester.pump();
        await tester.pump();
        final returnBounds = tester.getRect(
          find.byKey(const ValueKey('moved-origin-source')),
        );
        final returnFlight = flights[1];
        final flightTarget = returnFlight.animation.status == AnimationStatus.reverse
            ? returnFlight.source.bounds
            : returnFlight.destination.bounds;

        expect(flightTarget, returnBounds);
      },
    );

    testWidgets(
      'when watchDestination is enabled on the source and the destination moves, it should follow the live geometry',
      (tester) async {
        final destinationTop = ValueNotifier<double>(500);
        final captures = <_TestProperties>[];
        final flights = <MorphFlight<_TestProperties>>[];
        addTearDown(destinationTop.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Morph(
                      tag: 'watched-destination',
                      watchDestination: true,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      flightDelegate: _TestFlightDelegate(
                        Colors.red,
                        captures,
                        flights: flights,
                      ),
                      child: const SizedBox.square(
                        key: ValueKey('watched-source'),
                        dimension: 48,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: destinationTop,
                    builder: (context, top, child) => Positioned(
                      top: top,
                      left: 250,
                      child: child!,
                    ),
                    child: RepaintBoundary(
                      child: Morph(
                        tag: 'watched-destination',
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.linear,
                        flightDelegate: _TestFlightDelegate(
                          Colors.blue,
                          captures,
                          flights: flights,
                        ),
                        child: const SizedBox.square(
                          key: ValueKey('watched-destination'),
                          dimension: 48,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final originalTarget = flights.single.destination.bounds;

        destinationTop.value = 300;
        await tester.pump();
        final mutableDestination = flights.single.destination;
        final updatedTarget = mutableDestination.bounds;
        final expectedTransform = List<double>.of(
          mutableDestination.transform.storage,
        );
        mutableDestination.transform.storage[12] += 1000;
        final protectedDestination = flights.single.destination;
        await tester.pump();
        final overlay = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MorphOverlay',
        );
        final flightBoundary = find.descendant(
          of: overlay,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphFlightBoundary',
          ),
        );
        final renderedTop = tester.getTopLeft(flightBoundary).dy;
        final progress = flights.single.animation.value;
        final currentBounds = flights.single.bounds;
        final updatedRenderedTop = Rect.lerp(
          flights.single.source.bounds,
          flights.single.destination.bounds,
          progress,
        )!.top;
        final originalRenderedTop = Rect.lerp(
          flights.single.source.bounds,
          originalTarget,
          progress,
        )!.top;
        await tester.pumpAndSettle();

        expect(
          (
            originalTarget.top,
            updatedTarget.top,
            (renderedTop - updatedRenderedTop).abs() < (renderedTop - originalRenderedTop).abs(),
            listEquals(
              expectedTransform,
              protectedDestination.transform.storage,
            ),
            currentBounds ==
                Rect.lerp(
                  flights.single.source.bounds,
                  protectedDestination.bounds,
                  progress,
                ),
          ),
          (500.0, 300.0, true, true, true),
        );
      },
    );

    testWidgets(
      'when a watched nested flight is held, it should follow destination geometry until its parent arrives',
      (tester) async {
        final nestedGeometry = ValueNotifier<({double size, double top})>(
          (size: 40, top: 100),
        );
        final captures = <_TestProperties>[];
        var destination = false;
        late StateSetter update;
        addTearDown(nestedGeometry.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Align(
                    alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                    child: Morph(
                      tag: 'held-watch-parent',
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.linear,
                      child: Container(
                        key: ValueKey(
                          'held-watch-parent-$destination',
                        ),
                        width: destination ? 260 : 180,
                        height: destination ? 320 : 220,
                        color: destination ? Colors.blue : Colors.red,
                        child: Stack(
                          children: [
                            ValueListenableBuilder<({double size, double top})>(
                              valueListenable: nestedGeometry,
                              builder: (context, geometry, _) {
                                return Positioned(
                                  left: 20,
                                  top: destination ? geometry.top : 20,
                                  child: Morph(
                                    tag: 'held-watch-child',
                                    watchDestination: true,
                                    duration: const Duration(
                                      milliseconds: 200,
                                    ),
                                    curve: Curves.linear,
                                    flightDelegate: _TestFlightDelegate(
                                      destination ? Colors.yellow : Colors.green,
                                      captures,
                                      flightKey: const ValueKey(
                                        'held-watch-rendered-child',
                                      ),
                                    ),
                                    child: SizedBox.square(
                                      key: ValueKey(
                                        'held-watch-child-$destination',
                                      ),
                                      dimension: geometry.size,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final renderedFlight = find.byKey(
          const ValueKey('held-watch-rendered-child'),
        );
        final heldTargetTop = tester.getRect(renderedFlight).top;

        nestedGeometry.value = (size: 0, top: 140);
        await tester.pump();
        nestedGeometry.value = (size: 40, top: 180);
        await tester.pump();
        final movedTargetTop = tester.getRect(renderedFlight).top;
        final renderedFlightCount = renderedFlight.evaluate().length;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        expect(
          (
            renderedFlightCount,
            movedTargetTop - heldTargetTop,
            tester.takeException(),
          ),
          (1, 80, null),
        );
      },
    );

    testWidgets('when watchDestination is disabled, it should keep the geometry captured at flight start', (
      tester,
    ) async {
      final destinationTop = ValueNotifier<double>(500);
      final captures = <_TestProperties>[];
      final flights = <MorphFlight<_TestProperties>>[];
      addTearDown(destinationTop.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Morph(
                    tag: 'unwatched-destination',
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.linear,
                    flightDelegate: _TestFlightDelegate(
                      Colors.red,
                      captures,
                      flights: flights,
                    ),
                    child: const SizedBox.square(
                      key: ValueKey('unwatched-source'),
                      dimension: 48,
                    ),
                  ),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: destinationTop,
                  builder: (context, top, child) => Positioned(
                    top: top,
                    left: 250,
                    child: child!,
                  ),
                  child: Morph(
                    tag: 'unwatched-destination',
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.linear,
                    flightDelegate: _TestFlightDelegate(
                      Colors.blue,
                      captures,
                      flights: flights,
                    ),
                    child: const SizedBox.square(
                      key: ValueKey('unwatched-destination'),
                      dimension: 48,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      destinationTop.value = 300;
      await tester.pump();
      final target = flights.single.destination.bounds;
      await tester.pumpAndSettle();

      expect(target.top, 500);
    });

    testWidgets(
      'when watchDestination is disabled, it should not allocate live flight geometry',
      (tester) async {
        await tester.pumpWidget(
          const _MorphTestApp(
            source: Morph(
              tag: 'lazy-flight-geometry',
              duration: Duration(milliseconds: 400),
              child: Text('Source'),
            ),
            destination: Morph(
              tag: 'lazy-flight-geometry',
              duration: Duration(milliseconds: 400),
              child: Text('Destination'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        var liveGeometryCreations = 0;
        void listener(ObjectEvent event) {
          if (event is ObjectCreated && event.object.runtimeType.toString() == '_MorphFlightGeometry') {
            liveGeometryCreations += 1;
          }
        }

        FlutterMemoryAllocations.instance.addListener(listener);
        addTearDown(
          () => FlutterMemoryAllocations.instance.removeListener(listener),
        );
        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pump();
        await tester.pump();
        FlutterMemoryAllocations.instance.removeListener(listener);
        await tester.pumpAndSettle();

        expect(liveGeometryCreations, 0);
      },
    );

    testWidgets(
      'when multiple text endpoints use explicit tags, every transfer should complete without error',
      (tester) async {
        await tester.pumpWidget(
          const _MorphTestApp(
            source: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Morph(tag: 'hello', child: Text('Hello')),
                Morph(tag: 'hola', child: Text('Hola')),
              ],
            ),
            destination: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Morph(tag: 'hello', child: Text('Hello detail')),
                Morph(tag: 'hola', child: Text('Hola detail')),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when a nested Morph omits duration, it should inherit its nearest Morph ancestor duration',
      (tester) async {
        var expanded = false;
        var childEnded = false;
        var parentEnded = false;
        late StateSetter update;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: expanded ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'inherited-duration-parent',
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.linear,
                    onEnd: () => parentEnded = true,
                    child: SizedBox(
                      key: ValueKey('inherited-duration-parent-$expanded'),
                      width: expanded ? 180 : 100,
                      height: expanded ? 120 : 80,
                      child: Morph(
                        tag: 'inherited-duration-child',
                        curve: Curves.linear,
                        onEnd: () => childEnded = true,
                        child: Text(
                          expanded ? 'Destination' : 'Source',
                          key: ValueKey('inherited-duration-child-$expanded'),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        final observed = (childEnded, parentEnded);
        await tester.pumpAndSettle();

        expect(observed, (false, false));
      },
    );

    testWidgets(
      'when a nested Morph supplies duration, it should override its Morph ancestor duration',
      (tester) async {
        var expanded = false;
        var childEnded = false;
        var parentEnded = false;
        late StateSetter update;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: expanded ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'overridden-duration-parent',
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.linear,
                    onEnd: () => parentEnded = true,
                    child: SizedBox(
                      key: ValueKey('overridden-duration-parent-$expanded'),
                      width: expanded ? 180 : 100,
                      height: expanded ? 120 : 80,
                      child: Morph(
                        tag: 'overridden-duration-child',
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.linear,
                        onEnd: () => childEnded = true,
                        child: Text(
                          expanded ? 'Destination' : 'Source',
                          key: ValueKey('overridden-duration-child-$expanded'),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final observed = (childEnded, parentEnded);
        await tester.pumpAndSettle();

        expect(observed, (true, false));
      },
    );

    testWidgets(
      'when a nested Morph omits curve, it should inherit its nearest Morph ancestor curve',
      (tester) async {
        var expanded = false;
        late StateSetter update;
        final childCaptures = <_TestProperties>[];
        final childAnimations = <Animation<double>>[];

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: expanded ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'inherited-curve-parent',
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeIn,
                    child: SizedBox(
                      key: ValueKey('inherited-curve-parent-$expanded'),
                      width: expanded ? 180 : 100,
                      height: expanded ? 120 : 80,
                      child: Morph(
                        tag: 'inherited-curve-child',
                        duration: const Duration(milliseconds: 600),
                        flightDelegate: _TestFlightDelegate(
                          Colors.red,
                          childCaptures,
                          animations: childAnimations,
                        ),
                        child: SizedBox.expand(
                          key: ValueKey(
                            'inherited-curve-child-$expanded',
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final progress = childAnimations.single.value;
        await tester.pumpAndSettle();

        expect(progress, closeTo(Curves.easeIn.transform(0.5), 0.001));
      },
    );

    testWidgets(
      'when a nested Morph supplies curve, it should override its Morph ancestor curve',
      (tester) async {
        var expanded = false;
        late StateSetter update;
        final childCaptures = <_TestProperties>[];
        final childAnimations = <Animation<double>>[];

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: expanded ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'overridden-curve-parent',
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeIn,
                    child: SizedBox(
                      key: ValueKey('overridden-curve-parent-$expanded'),
                      width: expanded ? 180 : 100,
                      height: expanded ? 120 : 80,
                      child: Morph(
                        tag: 'overridden-curve-child',
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        flightDelegate: _TestFlightDelegate(
                          Colors.red,
                          childCaptures,
                          animations: childAnimations,
                        ),
                        child: SizedBox.expand(
                          key: ValueKey(
                            'overridden-curve-child-$expanded',
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final progress = childAnimations.single.value;
        await tester.pumpAndSettle();

        expect(progress, closeTo(Curves.easeOut.transform(0.5), 0.001));
      },
    );

    testWidgets(
      'when an ancestor curve changes before a nested flight, it should inherit the updated curve',
      (tester) async {
        var expanded = false;
        var parentCurve = Curves.linear;
        late StateSetter update;
        final childCaptures = <_TestProperties>[];
        final childAnimations = <Animation<double>>[];

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: expanded ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'updated-inherited-curve-parent',
                    duration: const Duration(milliseconds: 600),
                    curve: parentCurve,
                    child: SizedBox(
                      key: ValueKey(
                        'updated-inherited-curve-parent-$expanded',
                      ),
                      width: expanded ? 180 : 100,
                      height: expanded ? 120 : 80,
                      child: Morph(
                        tag: 'updated-inherited-curve-child',
                        duration: const Duration(milliseconds: 600),
                        flightDelegate: _TestFlightDelegate(
                          Colors.red,
                          childCaptures,
                          animations: childAnimations,
                        ),
                        child: SizedBox.expand(
                          key: ValueKey(
                            'updated-inherited-curve-child-$expanded',
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        update(() => parentCurve = Curves.easeInOut);
        await tester.pump();
        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final progress = childAnimations.single.value;
        await tester.pumpAndSettle();

        expect(
          progress,
          closeTo(Curves.easeInOut.transform(0.25), 0.001),
        );
      },
    );

    testWidgets(
      'when an ancestor duration changes before a nested flight, it should inherit the updated duration',
      (tester) async {
        var expanded = false;
        var parentDuration = const Duration(milliseconds: 600);
        var childEnded = false;
        var parentEnded = false;
        late StateSetter update;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: expanded ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'updated-inherited-duration-parent',
                    duration: parentDuration,
                    curve: Curves.linear,
                    onEnd: () => parentEnded = true,
                    child: SizedBox(
                      key: ValueKey('updated-inherited-duration-parent-$expanded'),
                      width: expanded ? 180 : 100,
                      height: expanded ? 120 : 80,
                      child: Morph(
                        tag: 'updated-inherited-duration-child',
                        curve: Curves.linear,
                        onEnd: () => childEnded = true,
                        child: Text(
                          expanded ? 'Destination' : 'Source',
                          key: ValueKey('updated-inherited-duration-child-$expanded'),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        update(() => parentDuration = const Duration(milliseconds: 900));
        await tester.pump();
        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 650));
        final observed = (childEnded, parentEnded);
        await tester.pumpAndSettle();

        expect(observed, (false, false));
      },
    );

    testWidgets(
      'when a short flight settles before its transfer cohort, it should remain visible until the cohort arrives',
      (tester) async {
        const boundaryKey = ValueKey('short-flight-handoff-boundary');
        final sequenceController = SequenceController();
        addTearDown(sequenceController.dispose);

        int flightBoundaryCount() {
          return find
              .descendant(
                of: _morphOverlay(),
                matching: find.byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_MorphFlightBoundary',
                ),
              )
              .evaluate()
              .length;
        }

        Widget screen({required bool destination}) {
          return SizedBox(
            key: ValueKey('short-flight-screen-$destination'),
            width: 300,
            height: 300,
            child: Stack(
              children: [
                Align(
                  alignment: destination ? Alignment.bottomCenter : Alignment.topCenter,
                  child: Morph(
                    tag: 'long-handoff-flight',
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.linear,
                    child: Container(
                      key: ValueKey('long-handoff-surface-$destination'),
                      width: destination ? 180 : 120,
                      height: destination ? 100 : 60,
                      color: destination ? Colors.blue : Colors.red,
                    ),
                  ),
                ),
                Align(
                  alignment: destination ? Alignment.topLeft : Alignment.topRight,
                  child: Morph(
                    tag: 'short-handoff-flight',
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.linear,
                    child: SizedBox.square(
                      key: ValueKey('short-handoff-child-$destination'),
                      dimension: 40,
                      child: Builder(
                        builder: (context) => const ColoredBox(color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: ColoredBox(
                  color: Colors.white,
                  child: Sequence(
                    controller: sequenceController,
                    duration: const Duration(milliseconds: 80),
                    reverseDuration: const Duration(milliseconds: 80),
                    nextTransition: (child, animation) => child,
                    children: [
                      screen(destination: false),
                      screen(destination: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        sequenceController.next();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final pixel = await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
            const x = 20;
            const y = 20;
            final offset = ((y * image.width) + x) * 4;
            return Color.fromARGB(
              bytes!.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          } finally {
            image.dispose();
          }
        });
        final flightBoundaries = flightBoundaryCount();
        await tester.pump(const Duration(milliseconds: 100));
        final boundariesWhileLongFlightContinues = flightBoundaryCount();
        await tester.pump(const Duration(milliseconds: 200));
        final boundariesAtCohortHandoff = flightBoundaryCount();
        await tester.pump();
        final boundariesAfterHandoff = _morphOverlay().evaluate().length;
        await tester.pumpAndSettle();

        sequenceController.previous();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final reversePixel = await tester.runAsync(() async {
          final reverseImage = await boundary.toImage();
          try {
            final bytes = await reverseImage.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            const x = 280;
            const y = 20;
            final offset = ((y * reverseImage.width) + x) * 4;
            return Color.fromARGB(
              bytes!.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          } finally {
            reverseImage.dispose();
          }
        });
        final reverseFlightBoundaries = flightBoundaryCount();
        await tester.pump(const Duration(milliseconds: 100));
        final reverseBoundariesWhileLongFlightContinues = flightBoundaryCount();
        await tester.pump(const Duration(milliseconds: 200));
        final reverseBoundariesAtCohortHandoff = flightBoundaryCount();
        await tester.pump();
        final reverseBoundariesAfterHandoff = _morphOverlay().evaluate().length;
        await tester.pumpAndSettle();

        expect(
          (
            pixel,
            flightBoundaries,
            boundariesWhileLongFlightContinues,
            boundariesAtCohortHandoff,
            boundariesAfterHandoff,
            reversePixel,
            reverseFlightBoundaries,
            reverseBoundariesWhileLongFlightContinues,
            reverseBoundariesAtCohortHandoff,
            reverseBoundariesAfterHandoff,
          ),
          (Colors.black, 2, 2, 2, 0, Colors.black, 2, 2, 2, 0),
        );
      },
    );
  });
}
