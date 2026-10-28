import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'route_geometry_motion.dart';

part '_geometry_delegate.dart';
part '_nested_geometry_scene.dart';

class RouteGeometryScene {
  new({
    this.motion = .horizontal,
    this.watchDestination = false,
    this.destination = const Rect.fromLTWH(20, 30, 48, 48),
    this.nested = false,
    this.withHero = false,
    this.contentTransform,
    this.scrollOffset,
  });

  final RouteGeometryMotion motion;
  final bool watchDestination;
  final Rect destination;
  final bool nested;
  final bool withHero;
  final Matrix4? contentTransform;
  final double? scrollOffset;
  final _scrollControllers = <ScrollController>[];
  final navigator = GlobalKey<NavigatorState>();
  final observer = MorphNavigatorObserver();
  final delegate = _GeometryDelegate('button');
  late final target = MorphTarget(tag: #button, watchDestination: watchDestination);
  final destinationOffset = ValueNotifier<Offset>(Offset.zero);

  Widget get app {
    final navigation = Navigator(
      key: navigator,
      observers: [observer, if (withHero) HeroController()],
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => page(const Rect.fromLTWH(20, 30, 48, 48))),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HeroControllerScope.none(
        child: nested
            ? Padding(
                padding: const EdgeInsets.fromLTRB(60, 80, 40, 20),
                child: Transform.scale(scale: 0.8, alignment: Alignment.topLeft, child: navigation),
              )
            : navigation,
      ),
    );
  }

  Widget page(Rect bounds, {bool incoming = false}) {
    final content = ColoredBox(
      color: incoming ? const Color(0xFFF1F2F4) : Colors.white,
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: bounds,
            child: ValueListenableBuilder(
              valueListenable: destinationOffset,
              builder: (context, offset, child) =>
                  Transform.translate(offset: incoming ? offset : Offset.zero, child: child),
              child: Transform(
                transform: contentTransform ?? Matrix4.identity(),
                child: Morph(
                  targets: [target],
                  flightConfig: .custom(delegate),
                  child: ColoredBox(key: ValueKey(incoming ? 'destination' : 'source'), color: Colors.blue),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 120,
            top: 200,
            child: Hero(tag: 'coexisting_hero', child: SizedBox.square(dimension: 12)),
          ),
        ],
      ),
    );
    if (scrollOffset == null) return content;
    final scrollController = ScrollController(initialScrollOffset: scrollOffset!);
    _scrollControllers.add(scrollController);
    return SingleChildScrollView(
      controller: scrollController,
      child: SizedBox(height: 1200, child: content),
    );
  }

  void dispose() {
    destinationOffset.dispose();
    for (final scrollController in _scrollControllers) {
      scrollController.dispose();
    }
  }

  PageRoute<void>? pushedRoute;

  void push() {
    final child = page(destination, incoming: true);
    final route = switch (motion) {
      .material => MaterialPageRoute<void>(builder: (_) => child),
      .cupertino => CupertinoPageRoute<void>(builder: (_) => child),
      .horizontal || .vertical || .scale || .none => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (_, animation, _, child) => switch (motion) {
          .horizontal => SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
            child: child,
          ),
          .vertical => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
            child: child,
          ),
          .scale => ScaleTransition(scale: Tween<double>(begin: 0.6, end: 1).animate(animation), child: child),
          .none => child,
          .material || .cupertino => throw StateError('SDK route owns this transition'),
        },
      ),
    };
    pushedRoute = route;
    navigator.currentState!.push<void>(route);
  }
}
