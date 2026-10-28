part of 'route_geometry_scene.dart';

class NestedGeometryScene {
  final navigator = GlobalKey<NavigatorState>();
  final observer = MorphNavigatorObserver();
  final surface = MorphTarget(tag: #surface);
  final header = MorphTarget(tag: #header);
  final surfaceDelegate = _GeometryDelegate('surface');
  final headerDelegate = _GeometryDelegate('header');

  Widget get app => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Navigator(
      key: navigator,
      observers: [observer],
      onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => page(expanded: false)),
    ),
  );

  Widget page({required bool expanded}) => ColoredBox(
    color: Colors.white,
    child: Stack(
      children: [
        Positioned.fromRect(
          rect: expanded ? const Rect.fromLTWH(0, 0, 400, 600) : const Rect.fromLTWH(30, 120, 240, 180),
          child: Morph(
            targets: [surface],
            flightConfig: .custom(surfaceDelegate),
            child: ColoredBox(
              color: const Color(0xFFE0E7FF),
              child: Padding(
                padding: EdgeInsets.all(expanded ? 40 : 20),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Morph(
                    targets: [header],
                    flightConfig: .custom(headerDelegate),
                    child: SizedBox(
                      width: expanded ? 200 : 140,
                      height: expanded ? 60 : 40,
                      child: const ColoredBox(color: Colors.blue),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  void push() => navigator.currentState!.push<void>(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, _, _) => page(expanded: true),
      transitionsBuilder: (_, _, _, child) => child,
    ),
  );
}
