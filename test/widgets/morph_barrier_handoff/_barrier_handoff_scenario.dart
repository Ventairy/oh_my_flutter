part of '../morph_barrier_handoff_test.dart';

final class _BarrierHandoffScenario {
  new({
    this.barrier,
    this.routeDuration = const Duration(milliseconds: 300),
    this.reverseDuration,
    this.nested = false,
    this.captureContent = false,
  });

  final Color? barrier;
  final Duration? reverseDuration;
  final bool nested;
  final bool captureContent;
  final ValueNotifier<bool> disabled = ValueNotifier(false);
  final Duration routeDuration;
  final navigator = GlobalKey<NavigatorState>();
  final GlobalKey boundary = GlobalKey();
  final observer = MorphNavigatorObserver();
  final source = MorphTarget(tag: 'barrier', duration: const Duration(milliseconds: 230), curve: Curves.easeOutCubic);
  final delegate = _BarrierFlightDelegate();
  int ended = 0;
  late PageRoute<void> route;

  Finder get flights => find.byKey(const ValueKey('barrier-flight'));

  Widget endpoint({bool destination = false}) => Center(
    child: Morph(
      key: ValueKey(destination),

      targets: [source],

      flightConfig: captureContent ? const .custom(_BarrierSnapshotFlightDelegate()) : .custom(delegate),
      onEnd: () => ended++,
      child: SizedBox.square(
        dimension: destination ? 200 : 100,
        child: captureContent
            ? const MorphDescendant(
                flightBehavior: MorphDescendantFlightBehavior.snapshot(),
                child: ColoredBox(color: Colors.blue),
              )
            : const ColoredBox(color: Colors.blue),
      ),
    ),
  );

  Widget get app => RepaintBoundary(
    key: boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: nested ? null : navigator,
      navigatorObservers: nested ? [] : [observer],
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: disabled,
        builder: (context, value, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: value),
          child: child!,
        ),
      ),
      home: nested
          ? Navigator(
              key: navigator,
              observers: [observer],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => ColoredBox(color: Colors.white, child: endpoint()),
              ),
            )
          : ColoredBox(color: Colors.white, child: endpoint()),
    ),
  );

  void push() {
    route = PageRouteBuilder<void>(
      opaque: false,
      barrierColor: barrier,
      transitionDuration: routeDuration,
      reverseTransitionDuration: reverseDuration ?? routeDuration,
      pageBuilder: (context, animation, secondaryAnimation) => endpoint(destination: true),
    );
    navigator.currentState!.push(route);
  }

  Future<int> pixel(WidgetTester tester) async {
    final render = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundary));
    return (await tester.runAsync(() async {
      final image = await render.toImage();
      try {
        final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final offset = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
        return Color.fromARGB(
          data.getUint8(offset + 3),
          data.getUint8(offset),
          data.getUint8(offset + 1),
          data.getUint8(offset + 2),
        ).toARGB32();
      } finally {
        image.dispose();
      }
    }))!;
  }
}
