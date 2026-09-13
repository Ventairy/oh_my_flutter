part of '../morph_registered_descendant_test.dart';

class _SnapshotFlightHarness extends StatefulWidget {
  const _SnapshotFlightHarness({
    this.delegate = const _SnapshotFlightDelegate(),
    this.curve = Curves.linear,
    this.sharedDescendant = false,
    this.watchDestination = false,
    this.behavior = MorphDescendantFlightBehavior.snapshot,
    this.contentBuilder,
    super.key,
  });

  final MorphFlightDelegate<Object?> delegate;
  final Curve curve;
  final bool sharedDescendant;
  final bool watchDestination;
  final MorphDescendantFlightBehavior behavior;
  final Widget Function(int endpoint)? contentBuilder;

  @override
  State<_SnapshotFlightHarness> createState() => _SnapshotFlightHarnessState();
}

class _SnapshotFlightHarnessState extends State<_SnapshotFlightHarness> {
  final _morphTarget1 = MorphTarget(tag: 'registered-descendant');
  final _morphObserver1 = MorphNavigatorObserver();

  static const ValueKey<String> _frameKey = ValueKey('registration-frame');
  int endpoint = 0;
  Size sizeChange = Size.zero;
  Color? color;

  void show(int value) => setState(() => endpoint = value);

  void updateDestination({required Size sizeChange, required Color color}) {
    setState(() {
      this.sizeChange = sizeChange;
      this.color = color;
    });
  }

  Finder get snapshotPaints => find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_MorphContentSnapshotPainter',
  );

  Future<Color> snapshotColor(WidgetTester tester, {int index = 0}) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frameKey));
    final point = boundary.globalToLocal(tester.getCenter(snapshotPaints.at(index)));
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
        return Color.fromARGB(
          bytes.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
      } finally {
        image.dispose();
      }
    }))!;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [_morphObserver1],
      builder: (context, child) => RepaintBoundary(key: _frameKey, child: child),
      home: Scaffold(
        body: Align(
          child: Morph(
            animateChildChanges: true,
            target: _morphTarget1,
            duration: const Duration(seconds: 1),
            curve: widget.curve,
            watchDestination: widget.watchDestination,
            flightConfig: .custom(widget.delegate),
            child: SizedBox(
              key: ValueKey(endpoint),
              width: 80 + endpoint * 40 + sizeChange.width,
              height: 60 + endpoint * 30 + sizeChange.height,
              child:
                  widget.contentBuilder?.call(endpoint) ??
                  (widget.sharedDescendant
                      ? const MorphDescendant(
                          flightBehavior: .snapshot,
                          child: SizedBox.expand(child: ColoredBox(color: Colors.blue)),
                        )
                      : MorphDescendant(
                          key: const ValueKey('content'),
                          flightBehavior: widget.behavior,
                          child: ColoredBox(color: color ?? [Colors.red, Colors.blue, Colors.green][endpoint]),
                        )),
            ),
          ),
        ),
      ),
    );
  }
}
