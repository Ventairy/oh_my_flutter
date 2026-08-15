import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/morph/morph.dart' show MorphTextFlightDelegate, MorphTextProperties;
import 'package:oh_my_flutter/src/widgets/morph/morph_test_configuration.dart';

final class _InterceptedPictureRecorder implements ui.PictureRecorder {
  _InterceptedPictureRecorder(this.delegate, this.binding);

  final ui.PictureRecorder delegate;
  final _MorphRasterBinding binding;

  @override
  bool get isRecording => delegate.isRecording;

  @override
  ui.Picture endRecording() {
    return _InterceptedPicture(delegate.endRecording(), binding);
  }
}

final class _InterceptedPicture implements ui.Picture {
  _InterceptedPicture(this.delegate, this.binding);

  final ui.Picture delegate;
  final _MorphRasterBinding binding;

  @override
  int get approximateBytesUsed => delegate.approximateBytesUsed;

  @override
  bool get debugDisposed => delegate.debugDisposed;

  @override
  void dispose() {
    delegate.dispose();
  }

  @override
  Future<ui.Image> toImage(int width, int height) {
    binding.rasterStarts += 1;
    return binding.rasterLoader!(delegate, width, height);
  }

  @override
  ui.Image toImageSync(
    int width,
    int height, {
    ui.TargetPixelFormat targetFormat = ui.TargetPixelFormat.dontCare,
  }) {
    return delegate.toImageSync(
      width,
      height,
      targetFormat: targetFormat,
    );
  }
}

final class _MorphRasterBinding extends LiveTestWidgetsFlutterBinding {
  _MorphRasterBinding() {
    framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  }

  Future<ui.Image> Function(ui.Picture picture, int width, int height)? rasterLoader;
  int rasterStarts = 0;

  @override
  ui.PictureRecorder createPictureRecorder() {
    final recorder = super.createPictureRecorder();
    if (rasterLoader == null || !StackTrace.current.toString().contains('_MorphTextRasterCache')) {
      return recorder;
    }
    return _InterceptedPictureRecorder(recorder, this);
  }

  @override
  ui.Canvas createCanvas(ui.PictureRecorder recorder) {
    if (recorder case _InterceptedPictureRecorder(:final delegate)) {
      return super.createCanvas(delegate);
    }
    return super.createCanvas(recorder);
  }

  void resetRasterLoader() {
    rasterLoader = null;
    rasterStarts = 0;
  }
}

final _MorphRasterBinding _binding = _MorphRasterBinding();

class _RasterSegmentCurve extends Curve {
  const _RasterSegmentCurve();

  @override
  double transformInternal(double t) => t < 0.5 ? 0.25 : 0.75;
}

class _TextFlightHarness extends StatelessWidget {
  const _TextFlightHarness({
    required this.source,
    required this.destination,
    required this.animation,
    this.sourceBounds = const Rect.fromLTWH(0, 0, 300, 100),
    this.destinationBounds = const Rect.fromLTWH(0, 0, 300, 100),
  });

  static const boundaryKey = ValueKey<String>('raster-boundary');

  final MorphTextProperties source;
  final MorphTextProperties destination;
  final Animation<double> animation;
  final Rect sourceBounds;
  final Rect destinationBounds;

  @override
  Widget build(BuildContext context) {
    const delegate = MorphTextFlightDelegate();
    return MaterialApp(
      home: RepaintBoundary(
        key: boundaryKey,
        child: ColoredBox(
          color: Colors.white,
          child: SizedBox(
            width: 300,
            height: 100,
            child: delegate.buildFlight(
              context,
              MorphFlight<MorphTextProperties>(
                source: MorphEndpoint<MorphTextProperties>(
                  properties: source,
                  bounds: sourceBounds,
                  localSize: sourceBounds.size,
                  transform: Matrix4.identity(),
                  axisScale: const Offset(1, 1),
                ),
                destination: MorphEndpoint<MorphTextProperties>(
                  properties: destination,
                  bounds: destinationBounds,
                  localSize: destinationBounds.size,
                  transform: Matrix4.identity(),
                  axisScale: const Offset(1, 1),
                ),
                kind: MorphFlightKind.sameScreen,
                animation: animation,
                flightDelegate: delegate,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossFlightRasterApp extends StatefulWidget {
  const _CrossFlightRasterApp({super.key});

  @override
  State<_CrossFlightRasterApp> createState() => _CrossFlightRasterAppState();
}

class _CrossFlightRasterAppState extends State<_CrossFlightRasterApp> {
  bool _expanded = false;
  bool _alternatePalette = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void toggle() {
    final expanded = !_expanded;
    _expanded = expanded;
    unawaited(
      _navigatorKey.currentState!.push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) {
            return _buildPage(expanded: expanded);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child;
          },
        ),
      ),
    );
  }

  void pop() {
    _expanded = false;
    _navigatorKey.currentState!.pop();
  }

  void useAlternatePalette() {
    setState(() => _alternatePalette = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      home: _buildPage(expanded: false),
    );
  }

  Widget _buildPage({required bool expanded}) {
    final color = _alternatePalette ? (expanded ? Colors.purple : Colors.green) : (expanded ? Colors.blue : Colors.red);
    return Scaffold(
      body: Align(
        alignment: expanded ? Alignment.bottomCenter : Alignment.topCenter,
        child: SizedBox(
          width: 300,
          height: 80,
          child: Morph(
            tag: 'cross-flight-raster',
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: Text(
              expanded ? 'Destination raster' : 'Source raster',
              style: TextStyle(
                color: color,
                fontSize: expanded ? 34 : 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColumnRasterWorkingSetApp extends StatefulWidget {
  const _ColumnRasterWorkingSetApp({
    this.childCount = 4,
    this.duplicateLast = false,
    this.duplicateTail = false,
    this.duplicateText = false,
    super.key,
  });

  final int childCount;
  final bool duplicateLast;
  final bool duplicateTail;
  final bool duplicateText;

  @override
  State<_ColumnRasterWorkingSetApp> createState() => _ColumnRasterWorkingSetAppState();
}

class _ColumnRasterWorkingSetAppState extends State<_ColumnRasterWorkingSetApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _changeFirstDestination = false;

  void push() {
    unawaited(
      _navigatorKey.currentState!.push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(seconds: 2),
          reverseTransitionDuration: const Duration(seconds: 2),
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) {
            return _buildPage(expanded: true);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child;
          },
        ),
      ),
    );
  }

  void pop() {
    _navigatorKey.currentState!.pop();
  }

  void changeFirstDestination() {
    _changeFirstDestination = true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      home: _buildPage(expanded: false),
    );
  }

  Widget _buildPage({required bool expanded}) {
    return Scaffold(
      body: Align(
        alignment: expanded ? Alignment.bottomCenter : Alignment.topCenter,
        child: SizedBox(
          width: 180,
          child: Morph(
            tag: 'column-raster-working-set',
            curve: const _RasterSegmentCurve(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List<Widget>.generate(widget.childCount, (index) {
                final contentIndex = widget.duplicateLast && index == widget.childCount - 1 ? index - 1 : index;
                return Text(
                  widget.duplicateText
                      ? (expanded ? 'Destination raster' : 'Source raster')
                      : widget.duplicateTail && index > 0
                      ? (expanded ? 'Destination duplicate' : 'Source duplicate')
                      : '${expanded ? 'Destination' : 'Source'} '
                            '${contentIndex + 1}'
                            '${_changeFirstDestination && expanded && index == 0 ? ' changed' : ''}',
                  key: ValueKey<int>(index),
                  style: TextStyle(
                    color: expanded ? Colors.blue : Colors.red,
                    fontSize: expanded ? 20 : 16,
                    height: 1.2,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      floatingActionButton: Morph(
        tag: 'column-raster-pool-probe',
        curve: Curves.linear,
        child: Text(
          expanded ? 'Probe destination' : 'Probe source',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _StaggeredRasterLeaseApp extends StatefulWidget {
  const _StaggeredRasterLeaseApp({
    required this.childCount,
    required this.endpointSize,
    required this.sourceFontSize,
    required this.destinationFontSize,
    this.duplicateText = false,
    this.duplicateContentIndices = const <int, int>{},
    this.shortBatches = const <int>{},
    super.key,
  });

  final int childCount;
  final Size endpointSize;
  final double sourceFontSize;
  final double destinationFontSize;
  final bool duplicateText;
  final Map<int, int> duplicateContentIndices;
  final Set<int> shortBatches;

  @override
  State<_StaggeredRasterLeaseApp> createState() {
    return _StaggeredRasterLeaseAppState();
  }
}

class _StaggeredRasterLeaseAppState extends State<_StaggeredRasterLeaseApp> {
  final Set<int> _startedBatches = <int>{};

  void startBatch(int batch) {
    setState(() => _startedBatches.add(batch));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: List<Widget>.generate(widget.childCount, (index) {
            final batch = index ~/ 4;
            final destination = _startedBatches.contains(batch);
            final contentIndex = widget.duplicateContentIndices[index] ?? index;
            return Align(
              alignment: Alignment(
                (index % 4) * 0.5 - 0.75,
                ((index ~/ 4) % 4) * 0.5 - 0.75,
              ),
              child: SizedBox.fromSize(
                size: widget.endpointSize,
                child: Morph(
                  tag: 'staggered-raster-$index',
                  duration: widget.shortBatches.contains(batch)
                      ? const Duration(milliseconds: 300)
                      : const Duration(seconds: 10),
                  curve: const _RasterSegmentCurve(),
                  child: Text(
                    widget.duplicateText
                        ? '${destination ? 'Destination' : 'Source'} raster'
                        : '${destination ? 'Destination' : 'Source'} $contentIndex',
                    key: ValueKey<String>(
                      'staggered-raster-$index-$destination',
                    ),
                    style: TextStyle(
                      color: destination ? Colors.blue : Colors.red,
                      fontSize: destination ? widget.destinationFontSize : widget.sourceFontSize,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

RenderBox _flightRenderObject(WidgetTester tester) {
  return tester.renderObject<RenderBox>(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
    ),
  );
}

T? _diagnostic<T>(WidgetTester tester, String name) {
  return _flightRenderObject(
        tester,
      ).toDiagnosticsNode().getProperties().singleWhere((property) => property.name == name).value
      as T?;
}

T? _firstFlightDiagnostic<T>(WidgetTester tester, String name) {
  final element = find
      .byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
      )
      .evaluate()
      .first;
  return _renderObjectDiagnostic<T>(element.renderObject!, name);
}

T? _renderObjectDiagnostic<T>(RenderObject renderObject, String name) {
  return renderObject.toDiagnosticsNode().getProperties().singleWhere((property) => property.name == name).value as T?;
}

Future<void> _drainRasterBatch(
  WidgetTester tester, {
  int remainingReservations = 0,
}) async {
  for (var frame = 0; frame < 100; frame += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
    final reserved = _firstFlightDiagnostic<int>(
      tester,
      'retainedTextRasterPoolReservedEntries',
    );
    final deferred = _firstFlightDiagnostic<int>(
      tester,
      'retainedTextRasterPoolDeferred',
    );
    final frameScheduled = _firstFlightDiagnostic<bool>(
      tester,
      'retainedTextRasterPoolFrameScheduled',
    );
    if (reserved == remainingReservations && deferred == 0 && frameScheduled == false) {
      return;
    }
  }
  throw StateError('The Morph raster batch did not finish draining.');
}

T? _compoundTextLayoutDiagnostic<T>(
  WidgetTester tester, {
  required String text,
  required String name,
}) {
  final layout = find
      .byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
      )
      .evaluate()
      .map(
        (element) =>
            element.renderObject!
                    .toDiagnosticsNode()
                    .getProperties()
                    .singleWhere((property) => property.name == 'retainedTextLayouts')
                    .value!
                as List<Map<String, Object?>>,
      )
      .expand((layouts) => layouts)
      .singleWhere(
        (layout) => layout['text'] == text,
      );
  return layout[name] as T?;
}

Future<({MorphTextProperties source, MorphTextProperties destination})> _captureProperties(
  WidgetTester tester, {
  required TextStyle sourceStyle,
  required TextStyle destinationStyle,
  double sourceWidth = 300,
  double destinationWidth = 300,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: sourceWidth,
                child: Text(
                  'Raster continuity',
                  key: const ValueKey<String>('raster-source'),
                  style: sourceStyle,
                ),
              ),
              SizedBox(
                width: destinationWidth,
                child: Text(
                  'Raster continuity',
                  key: const ValueKey<String>('raster-destination'),
                  style: destinationStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  MorphTextProperties capture(ValueKey<String> key) {
    final element = find.byKey(key).evaluate().single;
    final text = element.widget as Text;
    final size = (element.renderObject! as RenderBox).size;
    return MorphTextFlightDelegate.captureText(
      context: element,
      text: text,
      size: size,
      axisScale: const Offset(1, 1),
      switchThreshold: 0.5,
    );
  }

  return (
    source: capture(const ValueKey<String>('raster-source')),
    destination: capture(const ValueKey<String>('raster-destination')),
  );
}

Future<ui.Image> _waitForRaster(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    final flights = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
    );
    if (flights.evaluate().length == 1) {
      final raster = _diagnostic<ui.Image>(tester, 'retainedTextRaster');
      if (raster != null) {
        await tester.pump();
        return raster;
      }
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  final flightCount = find
      .byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
      )
      .evaluate()
      .length;
  if (flightCount != 1) {
    throw StateError(
      'The retained text raster did not become ready because Morph had '
      '$flightCount text flights.',
    );
  }
  throw StateError(
    'The retained text raster did not become ready: '
    '${_diagnostic<String>(tester, 'rasterRetentionBlocker')}, '
    'pending=${_diagnostic<bool>(tester, 'retainedTextRasterPending')}.',
  );
}

Future<ui.Image> _toggleAndWaitForRaster(
  WidgetTester tester,
  _CrossFlightRasterAppState state,
) async {
  state.toggle();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 60));
  return _waitForRaster(tester);
}

Future<ui.Image> _popAndWaitForRaster(
  WidgetTester tester,
  _CrossFlightRasterAppState state,
) async {
  state.pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
  return _waitForRaster(tester);
}

({int entries, int pixels, int creates, int hits}) _poolStats(
  WidgetTester tester,
) {
  return (
    entries: _diagnostic<int>(tester, 'retainedTextRasterPoolEntries')!,
    pixels: _diagnostic<int>(tester, 'retainedTextRasterPoolPixels')!,
    creates: _diagnostic<int>(tester, 'retainedTextRasterPoolCreates')!,
    hits: _diagnostic<int>(tester, 'retainedTextRasterPoolHits')!,
  );
}

Future<({int entries, int pixels, int creates, int hits})> _waitForPoolEntries(
  WidgetTester tester, {
  required int minimumEntries,
}) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    final stats = _poolStats(tester);
    if (stats.entries >= minimumEntries) return stats;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  throw StateError(
    'The Morph raster pool did not reach $minimumEntries entries: '
    '${_poolStats(tester)}.',
  );
}

Future<({int entries, int pixels, int creates, int hits})> _pushAndPopulateColumnRasters(
  WidgetTester tester,
  _ColumnRasterWorkingSetAppState state, {
  required int firstSegmentEntries,
  required int secondSegmentEntries,
}) async {
  state.push();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 399));
  await _waitForPoolEntries(
    tester,
    minimumEntries: firstSegmentEntries,
  );
  await tester.pump(const Duration(milliseconds: 800));
  return _waitForPoolEntries(
    tester,
    minimumEntries: secondSegmentEntries,
  );
}

Future<({int entries, int pixels, int creates, int hits})> _popAndPopulateColumnRasters(
  WidgetTester tester,
  _ColumnRasterWorkingSetAppState state, {
  required int firstSegmentEntries,
  required int secondSegmentEntries,
}) async {
  state.pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await _waitForPoolEntries(
    tester,
    minimumEntries: firstSegmentEntries,
  );
  await tester.pump(const Duration(milliseconds: 800));
  return _waitForPoolEntries(
    tester,
    minimumEntries: secondSegmentEntries,
  );
}

Future<void> _completeColumnRoute(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump();
}

Future<Uint8List> _capturePixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_TextFlightHarness.boundaryKey),
  );
  final image = await boundary.toImage();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

({double averageChannelDelta, double changedChannelRatio}) _pixelDelta(
  Uint8List first,
  Uint8List second,
) {
  var totalDelta = 0;
  var changedChannels = 0;
  for (var index = 0; index < first.length; index += 1) {
    final delta = (first[index] - second[index]).abs();
    totalDelta += delta;
    if (delta > 8) changedChannels += 1;
  }
  return (
    averageChannelDelta: totalDelta / first.length,
    changedChannelRatio: changedChannels / first.length,
  );
}

void main() {
  MorphTestConfiguration.rasterizationEnabled = true;
  assert(
    _binding.runtimeType.toString() == '_MorphRasterBinding',
    'The raster tests require their asynchronous test binding.',
  );

  group('Morph text raster cache', () {
    testWidgets(
      'when active raster leases fill the pixel budget, it should share a full-budget key',
      (tester) async {
        tester.view.physicalSize = const Size(800, 800);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final images = <ui.Image>[];
        _binding.rasterLoader = (picture, width, height) async {
          final image = await picture.toImage(width, height);
          images.add(image);
          return image;
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_StaggeredRasterLeaseAppState>();
        await tester.pumpWidget(
          _StaggeredRasterLeaseApp(
            key: appKey,
            childCount: 16,
            endpointSize: const Size(380, 100),
            sourceFontSize: 40,
            destinationFontSize: 80,
            duplicateContentIndices: const <int, int>{
              8: 0,
              9: 0,
              10: 0,
              11: 0,
            },
          ),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.startBatch(0);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        final firstBatch = List<ui.Image>.of(images);

        appKey.currentState!.startBatch(1);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        final startsWhileLeased = _binding.rasterStarts;
        final liveWhileLeased = images.where((image) => !image.debugDisposed).toList(growable: false);
        final livePixelsWhileLeased = liveWhileLeased.fold<int>(
          0,
          (pixels, image) => pixels + image.width * image.height,
        );
        final firstBatchPaintableWhileLeased = firstBatch.every(
          (image) => !image.debugDisposed,
        );
        final poolAccountingWhileLeased = (
          ownedPixels: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedPixels',
          ),
          reservedPixels: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolReservedPixels',
          ),
          budgetedPixels: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolBudgetedPixels',
          ),
        );

        appKey.currentState!.startBatch(2);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        final startsAfterFullBudgetJoins = _binding.rasterStarts;
        final sharedImageRemainedPaintable = !firstBatch.first.debugDisposed;
        expect(
          (
            firstBatch.length,
            firstBatchPaintableWhileLeased,
            livePixelsWhileLeased <= 4 * 1024 * 1024,
            poolAccountingWhileLeased.ownedPixels == livePixelsWhileLeased,
            poolAccountingWhileLeased.reservedPixels == 0,
            poolAccountingWhileLeased.budgetedPixels! <= 4 * 1024 * 1024,
            4 * 1024 * 1024 - livePixelsWhileLeased < firstBatch.first.width * firstBatch.first.height,
            startsWhileLeased < 8,
            startsAfterFullBudgetJoins == startsWhileLeased,
            sharedImageRemainedPaintable,
          ),
          (
            4,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
          ),
        );
      },
    );

    testWidgets(
      'when active pixel-budget leases release, it should resume unique raster admission',
      (tester) async {
        tester.view.physicalSize = const Size(800, 800);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        _binding.rasterLoader = (picture, width, height) {
          return picture.toImage(width, height);
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_StaggeredRasterLeaseAppState>();
        await tester.pumpWidget(
          _StaggeredRasterLeaseApp(
            key: appKey,
            childCount: 12,
            endpointSize: const Size(380, 100),
            sourceFontSize: 40,
            destinationFontSize: 80,
          ),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.startBatch(0);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        appKey.currentState!.startBatch(1);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        final startsWhileLeased = _binding.rasterStarts;

        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
        appKey.currentState!.startBatch(2);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);

        expect(
          (
            startsWhileLeased < 8,
            _binding.rasterStarts > startsWhileLeased,
            _firstFlightDiagnostic<int>(
              tester,
              'retainedTextRasterPoolReservedEntries',
            ),
          ),
          (true, true, 0),
        );
      },
    );

    testWidgets(
      'when staggered active raster leases fill the entry budget, it should admit exactly sixteen and share a full-budget key',
      (tester) async {
        tester.view.physicalSize = const Size(800, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final images = <ui.Image>[];
        _binding.rasterLoader = (picture, width, height) async {
          final image = await picture.toImage(width, height);
          images.add(image);
          return image;
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_StaggeredRasterLeaseAppState>();
        await tester.pumpWidget(
          _StaggeredRasterLeaseApp(
            key: appKey,
            childCount: 24,
            endpointSize: const Size(80, 30),
            sourceFontSize: 8,
            destinationFontSize: 16,
            duplicateContentIndices: const <int, int>{
              20: 0,
              21: 0,
              22: 0,
              23: 0,
            },
          ),
        );
        await tester.pumpAndSettle();

        for (var batch = 0; batch < 5; batch += 1) {
          appKey.currentState!.startBatch(batch);
          await tester.pump();
          await tester.pump();
          await _drainRasterBatch(tester);
        }
        final admittedBeforeFullBudgetJoins = _binding.rasterStarts;
        appKey.currentState!.startBatch(5);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        final liveImages = images.where((image) => !image.debugDisposed).toList(growable: false);
        final poolAccounting = (
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          reserved: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolReservedEntries',
          ),
          budgeted: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolBudgetedEntries',
          ),
        );

        expect(
          (
            images.length,
            liveImages.length,
            images.every((image) => !image.debugDisposed),
            admittedBeforeFullBudgetJoins,
            _binding.rasterStarts,
            poolAccounting.owned,
            poolAccounting.reserved,
            poolAccounting.budgeted,
          ),
          (16, 16, true, 16, 16, 16, 0, 16),
        );
      },
    );

    testWidgets(
      'when an active raster lease survives clear and pool disposal, it should remain paintable until release and then dispose',
      (tester) async {
        ui.Image? image;
        _binding.rasterLoader = (picture, width, height) async {
          image = await picture.toImage(width, height);
          return image!;
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_StaggeredRasterLeaseAppState>();
        await tester.pumpWidget(
          _StaggeredRasterLeaseApp(
            key: appKey,
            childCount: 4,
            endpointSize: const Size(180, 60),
            sourceFontSize: 20,
            destinationFontSize: 40,
            duplicateText: true,
          ),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.startBatch(0);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        final flightRenderObject = find
            .byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
            )
            .evaluate()
            .first
            .renderObject!;
        final beforeClear = (
          imageExists: image != null,
          disposed: image?.debugDisposed,
          reusable: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolEntries',
          ),
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          finalizerAttached: _firstFlightDiagnostic<bool>(
            tester,
            'retainedTextRasterPoolFinalizerAttached',
          ),
        );

        _binding.handleMemoryPressure();
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );
        final afterClear = (
          disposed: image?.debugDisposed,
          reusable: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolEntries',
          ),
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          finalizerAttached: _firstFlightDiagnostic<bool>(
            tester,
            'retainedTextRasterPoolFinalizerAttached',
          ),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );
        await tester.pump();
        final afterRelease = (
          owned: _renderObjectDiagnostic<int>(
            flightRenderObject,
            'retainedTextRasterPoolOwnedEntries',
          ),
          finalizerAttached: _renderObjectDiagnostic<bool>(
            flightRenderObject,
            'retainedTextRasterPoolFinalizerAttached',
          ),
        );

        expect(
          (
            beforeClear,
            afterClear,
            image?.debugDisposed,
            afterRelease,
            _binding.transientCallbackCount,
            tester.takeException(),
          ),
          (
            (
              imageExists: true,
              disposed: false,
              reusable: 1,
              owned: 1,
              finalizerAttached: true,
            ),
            (
              disposed: false,
              reusable: 0,
              owned: 1,
              finalizerAttached: true,
            ),
            true,
            (owned: 0, finalizerAttached: false),
            0,
            null,
          ),
        );
      },
    );

    testWidgets(
      'when the oldest raster is actively leased, it should evict a later unleased raster to admit new work',
      (tester) async {
        tester.view.physicalSize = const Size(800, 800);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final images = <ui.Image>[];
        _binding.rasterLoader = (picture, width, height) async {
          final image = await picture.toImage(width, height);
          images.add(image);
          return image;
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_StaggeredRasterLeaseAppState>();
        await tester.pumpWidget(
          _StaggeredRasterLeaseApp(
            key: appKey,
            childCount: 12,
            endpointSize: const Size(380, 100),
            sourceFontSize: 40,
            destinationFontSize: 60,
            shortBatches: const <int>{1},
          ),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.startBatch(0);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        final activeOldest = List<ui.Image>.of(images);

        appKey.currentState!.startBatch(1);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        final laterUnleased = images
            .skip(activeOldest.length)
            .where((image) => !image.debugDisposed)
            .toList(growable: false);
        final beforePressure = (
          activePaintable: activeOldest.every(
            (image) => !image.debugDisposed,
          ),
          laterReusable: laterUnleased.every(
            (image) => !image.debugDisposed,
          ),
        );

        final startsBeforePressure = _binding.rasterStarts;
        appKey.currentState!.startBatch(2);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        final newlyAdmitted = images.skip(startsBeforePressure).toList(growable: false);
        final afterPressure = (
          activePaintable: activeOldest.every(
            (image) => !image.debugDisposed,
          ),
          laterEvicted: laterUnleased.every(
            (image) => image.debugDisposed,
          ),
          newPaintable: newlyAdmitted.every(
            (image) => !image.debugDisposed,
          ),
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          reserved: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolReservedEntries',
          ),
        );

        expect(
          (
            activeOldest.length,
            laterUnleased.isNotEmpty,
            beforePressure,
            newlyAdmitted.length,
            afterPressure.activePaintable,
            afterPressure.laterEvicted,
            afterPressure.newPaintable,
            afterPressure.owned == activeOldest.length + newlyAdmitted.length,
            afterPressure.reserved,
          ),
          (
            4,
            true,
            (activePaintable: true, laterReusable: true),
            4,
            true,
            true,
            true,
            true,
            0,
          ),
        );
      },
    );

    testWidgets(
      'when clear invalidates a running raster and the same key reloads, it should account for both generations independently',
      (tester) async {
        final releaseOldRaster = Completer<void>();
        addTearDown(() {
          if (!releaseOldRaster.isCompleted) releaseOldRaster.complete();
        });
        ui.Image? oldImage;
        ui.Image? newImage;
        var load = 0;
        _binding.rasterLoader = (picture, width, height) async {
          load += 1;
          final image = await picture.toImage(width, height);
          if (load == 1) {
            oldImage = image;
            await releaseOldRaster.future;
          } else {
            newImage = image;
          }
          return image;
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_StaggeredRasterLeaseAppState>();
        await tester.pumpWidget(
          _StaggeredRasterLeaseApp(
            key: appKey,
            childCount: 8,
            endpointSize: const Size(180, 60),
            sourceFontSize: 20,
            destinationFontSize: 40,
            duplicateText: true,
          ),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.startBatch(0);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        for (var attempt = 0; attempt < 100 && oldImage == null; attempt += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        final beforeClear = (
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          reserved: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolReservedEntries',
          ),
          budgeted: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolBudgetedEntries',
          ),
        );

        _binding.handleMemoryPressure();
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );
        appKey.currentState!.startBatch(1);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester, remainingReservations: 1);
        final whileBothGenerationsExist = (
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          reserved: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolReservedEntries',
          ),
          budgeted: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolBudgetedEntries',
          ),
        );

        releaseOldRaster.complete();
        for (var attempt = 0; attempt < 100 && !(oldImage?.debugDisposed ?? false); attempt += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        await tester.pump();
        final afterLateDisposal = (
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          reserved: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolReservedEntries',
          ),
          budgeted: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolBudgetedEntries',
          ),
        );

        expect(
          (
            oldImage != null,
            beforeClear,
            _binding.rasterStarts,
            newImage != null,
            whileBothGenerationsExist,
            oldImage?.debugDisposed,
            newImage?.debugDisposed,
            afterLateDisposal,
            _firstFlightDiagnostic<int>(
              tester,
              'retainedTextRasterPoolLateDisposals',
            ),
          ),
          (
            true,
            (owned: 0, reserved: 1, budgeted: 1),
            2,
            true,
            (owned: 1, reserved: 1, budgeted: 2),
            true,
            false,
            (owned: 1, reserved: 0, budgeted: 1),
            1,
          ),
        );
      },
    );

    testWidgets(
      'when a cleared raster fails late after the same key reloads, it should release only the failed generation reservation',
      (tester) async {
        final failOldRaster = Completer<void>();
        addTearDown(() {
          if (!failOldRaster.isCompleted) failOldRaster.complete();
        });
        ui.Image? newImage;
        var load = 0;
        _binding.rasterLoader = (picture, width, height) async {
          load += 1;
          if (load == 1) {
            await failOldRaster.future;
            throw StateError('late raster failure');
          }
          final image = await picture.toImage(width, height);
          newImage = image;
          return image;
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_StaggeredRasterLeaseAppState>();
        await tester.pumpWidget(
          _StaggeredRasterLeaseApp(
            key: appKey,
            childCount: 8,
            endpointSize: const Size(180, 60),
            sourceFontSize: 20,
            destinationFontSize: 40,
            duplicateText: true,
          ),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.startBatch(0);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        final beforeClear = (
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          reserved: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolReservedEntries',
          ),
        );

        _binding.handleMemoryPressure();
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );
        appKey.currentState!.startBatch(1);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester, remainingReservations: 1);
        final whileBothGenerationsExist = (
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          reserved: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolReservedEntries',
          ),
        );

        failOldRaster.complete();
        for (var attempt = 0; attempt < 100; attempt += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
          if (_firstFlightDiagnostic<int>(
                tester,
                'retainedTextRasterPoolReservedEntries',
              ) ==
              0) {
            break;
          }
        }
        final afterLateFailure = (
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          reserved: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolReservedEntries',
          ),
        );

        expect(
          (
            beforeClear,
            _binding.rasterStarts,
            newImage != null,
            whileBothGenerationsExist,
            newImage?.debugDisposed,
            afterLateFailure,
            tester.takeException(),
          ),
          (
            (owned: 0, reserved: 1),
            2,
            true,
            (owned: 1, reserved: 1),
            false,
            (owned: 1, reserved: 0),
            null,
          ),
        );
      },
    );

    testWidgets(
      'when a raster loader throws synchronously, it should release its reservation and admit the next same-key generation',
      (tester) async {
        ui.Image? recoveredImage;
        var load = 0;
        _binding.rasterLoader = (picture, width, height) {
          load += 1;
          if (load == 1) {
            throw StateError('synchronous raster failure');
          }
          return picture.toImage(width, height).then((image) {
            recoveredImage = image;
            return image;
          });
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_StaggeredRasterLeaseAppState>();
        await tester.pumpWidget(
          _StaggeredRasterLeaseApp(
            key: appKey,
            childCount: 8,
            endpointSize: const Size(180, 60),
            sourceFontSize: 20,
            destinationFontSize: 40,
            duplicateText: true,
          ),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.startBatch(0);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        final afterSynchronousFailure = (
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          reserved: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolReservedEntries',
          ),
          budgeted: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolBudgetedEntries',
          ),
        );

        appKey.currentState!.startBatch(1);
        await tester.pump();
        await tester.pump();
        await _drainRasterBatch(tester);
        final afterRecovery = (
          owned: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolOwnedEntries',
          ),
          reserved: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolReservedEntries',
          ),
          budgeted: _firstFlightDiagnostic<int>(
            tester,
            'retainedTextRasterPoolBudgetedEntries',
          ),
        );

        expect(
          (
            afterSynchronousFailure,
            _binding.rasterStarts,
            recoveredImage != null,
            recoveredImage?.debugDisposed,
            afterRecovery,
            tester.takeException(),
          ),
          (
            (owned: 0, reserved: 0, budgeted: 0),
            2,
            true,
            false,
            (owned: 1, reserved: 0, budgeted: 1),
            null,
          ),
        );
      },
    );

    testWidgets(
      'when four unique rasters miss in one frame, it should start one rasterization per scheduler frame',
      (tester) async {
        _binding.rasterLoader = (picture, width, height) {
          return picture.toImage(width, height);
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(key: appKey),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final states = <String>[];
        void captureState() {
          states.add(
            '${_binding.rasterStarts}/'
            '${_diagnostic<int>(tester, 'retainedTextRasterPoolStarts')}/'
            '${_diagnostic<int>(tester, 'retainedTextRasterPoolDeferred')}/'
            '${_diagnostic<bool>(tester, 'retainedTextRasterPoolFrameScheduled')}',
          );
        }

        captureState();
        for (var frame = 1; frame < 4; frame += 1) {
          await tester.pump();
          captureState();
        }
        await tester.pump();
        captureState();

        expect(
          states.join('|'),
          '1/1/3/true|2/2/2/true|3/3/1/true|4/4/0/true|4/4/0/false',
        );
      },
    );

    testWidgets(
      'when four same-key rasters miss in one frame, it should share the running raster without deferral',
      (tester) async {
        _binding.rasterLoader = (picture, width, height) {
          return picture.toImage(width, height);
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(
            key: appKey,
            duplicateText: true,
          ),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final observed = (
          _binding.rasterStarts,
          _diagnostic<int>(tester, 'retainedTextRasterPoolStarts'),
          _diagnostic<int>(tester, 'retainedTextRasterPoolHits'),
          _diagnostic<int>(tester, 'retainedTextRasterPoolDeferred'),
        );
        await tester.pump();

        expect(observed, (1, 1, 3, 0));
      },
    );

    testWidgets(
      'when repeated same-key rasters are deferred, it should queue one retry and share the admitted load',
      (tester) async {
        _binding.rasterLoader = (picture, width, height) {
          return picture.toImage(width, height);
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(
            key: appKey,
            childCount: 3,
            duplicateTail: true,
          ),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final beforeRetry = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
        );
        await tester.pump();
        final afterRetry = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
          hits: _diagnostic<int>(tester, 'retainedTextRasterPoolHits'),
        );
        await tester.pump();

        expect(
          (
            beforeRetry.starts,
            beforeRetry.deferred,
            afterRetry.starts,
            afterRetry.deferred,
            afterRetry.hits! >= 1,
          ),
          (1, 1, 2, 0, true),
        );
      },
    );

    testWidgets(
      'when an admitted rasterization fails, it should drain the next deferred raster on the following frame',
      (tester) async {
        _binding.rasterLoader = (picture, width, height) {
          if (_binding.rasterStarts == 1) {
            return Future<ui.Image>.error(StateError('failed raster'));
          }
          return picture.toImage(width, height);
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(key: appKey),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final startsBeforeDrain = _binding.rasterStarts;
        await tester.pump();
        final observed = (
          startsBeforeDrain,
          _binding.rasterStarts,
          _diagnostic<int>(tester, 'retainedTextRasterPoolStarts'),
          _diagnostic<int>(tester, 'retainedTextRasterPoolDeferred'),
          _diagnostic<int>(
                tester,
                'retainedTextRasterPoolBudgetedEntries',
              )! <=
              1,
        );
        for (var frame = 0; frame < 3; frame += 1) {
          await tester.pump();
        }

        expect(observed, (1, 2, 2, 2, true));
      },
    );

    testWidgets(
      'when memory pressure clears deferred rasters before admission, it should keep that segment on fallback without starting their loaders',
      (tester) async {
        _binding.rasterLoader = (picture, width, height) {
          return picture.toImage(width, height);
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(key: appKey),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final beforeClear = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
        );

        _binding.handleMemoryPressure();
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );
        final afterClear = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
          frameScheduled: _diagnostic<bool>(
            tester,
            'retainedTextRasterPoolFrameScheduled',
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
        final startsAfterSameSegmentPaint = _binding.rasterStarts;
        await tester.pump(const Duration(seconds: 1));
        final afterSegmentChange = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );

        expect(
          (
            beforeClear.starts,
            beforeClear.deferred,
            afterClear.starts,
            afterClear.deferred,
            afterClear.frameScheduled,
            startsAfterSameSegmentPaint,
            afterSegmentChange.starts,
            afterSegmentChange.deferred,
            _binding.transientCallbackCount,
            tester.takeException(),
          ),
          (1, 3, 1, 0, false, 1, 2, 3, 0, null),
        );
      },
    );

    testWidgets(
      'when system fonts change with deferred rasters, it should cancel their frame and keep that segment on fallback',
      (tester) async {
        _binding.rasterLoader = (picture, width, height) {
          return picture.toImage(width, height);
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(key: appKey),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final beforeClear = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
          frameScheduled: _diagnostic<bool>(
            tester,
            'retainedTextRasterPoolFrameScheduled',
          ),
        );

        await PaintingBinding.instance.handleSystemMessage(
          <String, Object>{'type': 'fontsChange'},
        );
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );
        final afterClear = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
          frameScheduled: _diagnostic<bool>(
            tester,
            'retainedTextRasterPoolFrameScheduled',
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
        final startsAfterSameSegmentPaint = _binding.rasterStarts;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );

        expect(
          (
            beforeClear.starts,
            beforeClear.deferred,
            beforeClear.frameScheduled,
            afterClear.starts,
            afterClear.deferred,
            afterClear.frameScheduled,
            startsAfterSameSegmentPaint,
            _binding.transientCallbackCount,
            tester.takeException(),
          ),
          (1, 3, true, 1, 0, false, 1, 0, null),
        );
      },
    );

    testWidgets(
      'when memory pressure clears deferred and running rasters, it should cancel retries and dispose the late image',
      (tester) async {
        final releaseRaster = Completer<void>();
        ui.Image? lateImage;
        _binding.rasterLoader = (picture, width, height) async {
          final image = await picture.toImage(width, height);
          lateImage = image;
          await releaseRaster.future;
          return image;
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(key: appKey),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        for (var attempt = 0; attempt < 100 && lateImage == null; attempt += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        final beforeClear = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
          frameScheduled: _diagnostic<bool>(
            tester,
            'retainedTextRasterPoolFrameScheduled',
          ),
        );

        _binding.handleMemoryPressure();
        final afterClear = (
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
          frameScheduled: _diagnostic<bool>(
            tester,
            'retainedTextRasterPoolFrameScheduled',
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );
        final startsAfterCancellation = _binding.rasterStarts;
        releaseRaster.complete();
        for (var attempt = 0; attempt < 100 && !(lateImage?.debugDisposed ?? false); attempt += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        final lateDisposals = _diagnostic<int>(
          tester,
          'retainedTextRasterPoolLateDisposals',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );

        expect(
          (
            lateImage != null,
            beforeClear.starts,
            beforeClear.deferred,
            beforeClear.frameScheduled,
            afterClear.deferred,
            afterClear.frameScheduled,
            startsAfterCancellation,
            lateImage?.debugDisposed,
            lateDisposals,
            _binding.transientCallbackCount,
            tester.takeException(),
          ),
          (true, 1, 3, true, 0, false, 1, true, 1, 0, null),
        );
      },
    );

    testWidgets(
      'when four unique rasters are outstanding, it should keep a fifth on direct fallback without queueing work',
      (tester) async {
        final releaseRasters = Completer<void>();
        _binding.rasterLoader = (picture, width, height) async {
          final image = await picture.toImage(width, height);
          await releaseRasters.future;
          return image;
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(
            key: appKey,
            childCount: 5,
          ),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final atCapacity = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
          fifthRaster: _compoundTextLayoutDiagnostic<ui.Image>(
            tester,
            text: 'Source 5',
            name: 'raster',
          ),
          fifthBlocker: _compoundTextLayoutDiagnostic<String>(
            tester,
            text: 'Source 5',
            name: 'rasterRetentionBlocker',
          ),
        );
        for (var frame = 1; frame < 4; frame += 1) {
          await tester.pump();
        }
        await tester.pump();
        final whileFull = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
          frameScheduled: _diagnostic<bool>(
            tester,
            'retainedTextRasterPoolFrameScheduled',
          ),
        );

        releaseRasters.complete();
        for (var attempt = 0; attempt < 100; attempt += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
          if (_diagnostic<int>(tester, 'retainedTextRasterPoolCreates') == 4) {
            break;
          }
        }
        await tester.pump();
        final startsAfterCompletion = _binding.rasterStarts;
        await tester.pump();

        expect(
          (
            atCapacity.starts,
            atCapacity.deferred,
            atCapacity.fifthRaster,
            atCapacity.fifthBlocker,
            whileFull.starts,
            whileFull.deferred,
            whileFull.frameScheduled,
            startsAfterCompletion,
            _diagnostic<bool>(
              tester,
              'retainedTextRasterPoolFrameScheduled',
            ),
          ),
          (1, 3, null, 'raster pool unavailable', 4, 0, false, 4, false),
        );
      },
    );

    testWidgets(
      'when four unique rasters are outstanding, it should still join a same-key deferred raster at the cap',
      (tester) async {
        final releaseRasters = Completer<void>();
        _binding.rasterLoader = (picture, width, height) async {
          final image = await picture.toImage(width, height);
          await releaseRasters.future;
          return image;
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(
            key: appKey,
            childCount: 5,
            duplicateLast: true,
          ),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final atCapacity = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
        );
        for (var frame = 1; frame < 4; frame += 1) {
          await tester.pump();
        }
        await tester.pump();
        final drained = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
          frameScheduled: _diagnostic<bool>(
            tester,
            'retainedTextRasterPoolFrameScheduled',
          ),
          hits: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolHits',
          ),
        );

        releaseRasters.complete();
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );
        await tester.pump();

        expect(
          (
            atCapacity.starts,
            atCapacity.deferred,
            drained.starts,
            drained.deferred,
            drained.frameScheduled,
            drained.hits! >= 1,
          ),
          (1, 3, 4, 0, false, true),
        );
      },
    );

    testWidgets(
      'when a cold raster uses the frame quota, it should still serve warm cache hits in that frame',
      (tester) async {
        _binding.rasterLoader = (picture, width, height) {
          return picture.toImage(width, height);
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(key: appKey),
        );
        await tester.pumpAndSettle();

        await _pushAndPopulateColumnRasters(
          tester,
          appKey.currentState!,
          firstSegmentEntries: 4,
          secondSegmentEntries: 8,
        );
        await _completeColumnRoute(tester);
        await _popAndPopulateColumnRasters(
          tester,
          appKey.currentState!,
          firstSegmentEntries: 12,
          secondSegmentEntries: 16,
        );
        await _completeColumnRoute(tester);
        final startsBeforeMixedFrame = _binding.rasterStarts;
        appKey.currentState!.changeFirstDestination();

        appKey.currentState!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 399));
        await tester.pump(const Duration(milliseconds: 800));
        final observed = (
          starts: _binding.rasterStarts,
          deferred: _diagnostic<int>(
            tester,
            'retainedTextRasterPoolDeferred',
          ),
          hits: _diagnostic<int>(tester, 'retainedTextRasterPoolHits'),
        );
        await tester.pump();

        expect(
          (
            observed.starts - startsBeforeMixedFrame,
            observed.deferred,
            observed.hits! >= 3,
          ),
          (1, 0, true),
        );
      },
    );

    testWidgets(
      'when the owning overlay is disposed during rasterization, it should cancel its frame and dispose the late image',
      (tester) async {
        final releaseRaster = Completer<void>();
        ui.Image? lateImage;
        _binding.rasterLoader = (picture, width, height) async {
          final image = await picture.toImage(width, height);
          lateImage = image;
          await releaseRaster.future;
          return image;
        };
        addTearDown(_binding.resetRasterLoader);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(key: appKey),
        );
        await tester.pumpAndSettle();

        appKey.currentState!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        for (var attempt = 0; attempt < 100 && lateImage == null; attempt += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Future<void>.delayed(Duration.zero),
        );
        final callbacksAfterDispose = _binding.transientCallbackCount;
        releaseRaster.complete();
        for (var attempt = 0; attempt < 100 && !(lateImage?.debugDisposed ?? false); attempt += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }

        expect(
          (
            lateImage != null,
            _binding.rasterStarts,
            callbacksAfterDispose,
            lateImage?.debugDisposed,
            tester.takeException(),
          ),
          (true, 1, 0, true, null),
        );
      },
    );

    testWidgets(
      'when owning overlays churn, it should keep only live raster pools registered',
      (tester) async {
        Future<int> mountFlight(int generation) async {
          final appKey = GlobalKey<_CrossFlightRasterAppState>();
          await tester.pumpWidget(
            KeyedSubtree(
              key: ValueKey<int>(generation),
              child: _CrossFlightRasterApp(key: appKey),
            ),
          );
          await tester.pumpAndSettle();
          appKey.currentState!.toggle();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          return _diagnostic<int>(
            tester,
            'retainedTextRasterPoolRegistryEntries',
          )!;
        }

        final firstRegistryEntries = await mountFlight(0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final secondRegistryEntries = await mountFlight(1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        expect(
          (
            firstRegistryEntries,
            secondRegistryEntries,
            tester.takeException(),
          ),
          (1, 1, null),
        );
      },
    );

    testWidgets(
      'when a paint-only flight reaches its midpoint, it should match native text at the interpolated bounds',
      (tester) async {
        const sourceBounds = Rect.fromLTWH(20, 10, 220, 50);
        const destinationBounds = Rect.fromLTWH(60, 36, 220, 50);
        final properties = await _captureProperties(
          tester,
          sourceStyle: const TextStyle(
            color: Colors.red,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          destinationStyle: const TextStyle(
            color: Colors.blue,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        );
        final animation = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 300),
          value: 0.5,
        );
        addTearDown(animation.dispose);
        await tester.pumpWidget(
          _TextFlightHarness(
            source: properties.source,
            destination: properties.destination,
            animation: animation,
            sourceBounds: sourceBounds,
            destinationBounds: destinationBounds,
          ),
        );
        final flightPixels = await _capturePixels(tester);
        final midpoint = const MorphTextFlightDelegate().lerp(
          properties.source,
          properties.destination,
          0.5,
        );
        final midpointBounds = Rect.lerp(
          sourceBounds,
          destinationBounds,
          0.5,
        )!;

        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: _TextFlightHarness.boundaryKey,
              child: ColoredBox(
                color: Colors.white,
                child: Stack(
                  children: [
                    Positioned.fromRect(
                      rect: midpointBounds,
                      child: Text(
                        midpoint.text,
                        style: midpoint.paintStyle,
                        textAlign: midpoint.textAlign,
                        textDirection: midpoint.textDirection,
                        locale: midpoint.locale,
                        softWrap: midpoint.softWrap,
                        overflow: midpoint.overflow,
                        textScaler: midpoint.textScaler,
                        maxLines: midpoint.maxLines,
                        semanticsLabel: midpoint.semanticsLabel,
                        textWidthBasis: midpoint.textWidthBasis,
                        textHeightBehavior: midpoint.textHeightBehavior,
                        strutStyle: midpoint.strutStyle,
                        selectionColor: midpoint.selectionColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final nativePixels = await _capturePixels(tester);
        final delta = _pixelDelta(nativePixels, flightPixels);

        expect(
          (
            delta.averageChannelDelta < 0.5,
            delta.changedChannelRatio < 0.005,
          ),
          (true, true),
          reason: 'pixel delta: $delta',
        );
      },
    );

    testWidgets(
      'when an alpha-colored raster becomes ready, it should match the direct fallback and canonical layout',
      (tester) async {
        const sourceStyle = TextStyle(
          color: Color(0x66FF0000),
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.3,
        );
        const destinationStyle = TextStyle(
          color: Color(0xCC0000FF),
          fontSize: 34,
          fontWeight: FontWeight.w700,
          height: 1.1,
        );
        final properties = await _captureProperties(
          tester,
          sourceStyle: sourceStyle,
          destinationStyle: destinationStyle,
        );
        final animation = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 300),
          value: 0.6,
        );
        addTearDown(animation.dispose);
        await tester.pumpWidget(
          _TextFlightHarness(
            source: properties.source,
            destination: properties.destination,
            animation: animation,
          ),
        );
        await _waitForRaster(tester);
        final readyPixels = await _capturePixels(tester);
        final readyColor = _diagnostic<Color>(tester, 'paintedColor');
        final readyHeight = _diagnostic<double>(
          tester,
          'paintedTextHeight',
        );
        final readyRaster = _diagnostic<ui.Image>(
          tester,
          'retainedTextRaster',
        );
        final expected = const MorphTextFlightDelegate().lerp(
          properties.source,
          properties.destination,
          0.6,
        );
        final destinationPainter =
            TextPainter(
              text: TextSpan(
                text: properties.destination.text,
                style: properties.destination.style,
              ),
              textAlign: properties.destination.textAlign ?? TextAlign.start,
              textDirection: properties.destination.textDirection,
              textScaler: properties.destination.textScaler,
              locale: properties.destination.locale,
              maxLines: properties.destination.maxLines,
              ellipsis: properties.destination.overflow == TextOverflow.ellipsis ? '…' : null,
              textWidthBasis: properties.destination.textWidthBasis ?? TextWidthBasis.parent,
              textHeightBehavior: properties.destination.textHeightBehavior,
              strutStyle: properties.destination.strutStyle,
            )..layout(
              minWidth: expected.reservedLayoutWidth!,
              maxWidth: expected.reservedLayoutWidth!,
            );
        final canonicalHeight = destinationPainter.height;
        destinationPainter.dispose();

        final fallbackProperties = await _captureProperties(
          tester,
          sourceStyle: sourceStyle.copyWith(
            backgroundColor: Colors.transparent,
          ),
          destinationStyle: destinationStyle.copyWith(
            backgroundColor: Colors.transparent,
          ),
        );
        await tester.pumpWidget(
          _TextFlightHarness(
            source: fallbackProperties.source,
            destination: fallbackProperties.destination,
            animation: animation,
          ),
        );
        final fallbackPixels = await _capturePixels(tester);
        final delta = _pixelDelta(fallbackPixels, readyPixels);

        expect(
          (
            readyColor,
            readyHeight,
            readyRaster != null,
            _diagnostic<ui.Image>(tester, 'retainedTextRaster'),
            _diagnostic<String>(tester, 'rasterRetentionBlocker'),
            delta.averageChannelDelta < 1.5,
            delta.changedChannelRatio < 0.02,
          ),
          (
            Color.lerp(
              properties.source.style.color,
              properties.destination.style.color,
              0.6,
            ),
            canonicalHeight,
            true,
            null,
            'background',
            true,
            true,
          ),
          reason: 'pixel delta: $delta',
        );
      },
    );

    testWidgets(
      'when a forward raster advances within one text segment, it should reuse the image and update its tint',
      (tester) async {
        final properties = await _captureProperties(
          tester,
          sourceStyle: const TextStyle(
            color: Color(0xFFFF0000),
            fontSize: 22,
            height: 1.3,
          ),
          destinationStyle: const TextStyle(
            color: Color(0xFF0000FF),
            fontSize: 34,
            height: 1.1,
          ),
        );
        final animation = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 300),
          value: 0.6,
        );
        addTearDown(animation.dispose);
        await tester.pumpWidget(
          _TextFlightHarness(
            source: properties.source,
            destination: properties.destination,
            animation: animation,
          ),
        );
        final raster = await _waitForRaster(tester);

        animation.value = 0.8;
        await tester.pump();

        expect(
          (
            identical(
              raster,
              _diagnostic<ui.Image>(tester, 'retainedTextRaster'),
            ),
            _diagnostic<Color>(tester, 'paintedColor'),
          ),
          (
            true,
            Color.lerp(
              properties.source.style.color,
              properties.destination.style.color,
              0.8,
            ),
          ),
        );
      },
    );

    testWidgets(
      'when a text raster exceeds the low-memory pixel budget, it should use the direct fallback',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        final properties = await _captureProperties(
          tester,
          sourceStyle: const TextStyle(
            color: Colors.red,
            fontSize: 180,
          ),
          destinationStyle: const TextStyle(
            color: Colors.blue,
            fontSize: 34,
          ),
        );
        final animation = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 300),
          value: 0.6,
        );
        addTearDown(animation.dispose);
        await tester.pumpWidget(
          _TextFlightHarness(
            source: properties.source,
            destination: properties.destination,
            animation: animation,
          ),
        );

        expect(
          (
            _diagnostic<ui.Image>(tester, 'retainedTextRaster'),
            _diagnostic<bool>(tester, 'retainedTextRasterPending'),
            _diagnostic<String>(tester, 'rasterRetentionBlocker'),
            _diagnostic<String>(tester, 'paintedText'),
          ),
          (null, false, 'raster pixels', 'Raster continuity'),
        );
      },
    );

    testWidgets(
      'when a text raster exceeds the conservative texture dimension, it should use the direct fallback',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        final properties = await _captureProperties(
          tester,
          sourceStyle: const TextStyle(
            color: Colors.red,
            fontSize: 37.4,
          ),
          destinationStyle: const TextStyle(
            color: Colors.blue,
            fontSize: 34,
          ),
          sourceWidth: 1900,
          destinationWidth: 1900,
        );
        final animation = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 300),
          value: 0.6,
        );
        addTearDown(animation.dispose);
        await tester.pumpWidget(
          _TextFlightHarness(
            source: properties.source,
            destination: properties.destination,
            animation: animation,
            sourceBounds: const Rect.fromLTWH(0, 0, 1900, 100),
            destinationBounds: const Rect.fromLTWH(0, 0, 1900, 100),
          ),
        );

        expect(
          (
            _diagnostic<ui.Image>(tester, 'retainedTextRaster'),
            _diagnostic<bool>(tester, 'retainedTextRasterPending'),
            _diagnostic<String>(tester, 'rasterRetentionBlocker'),
            _diagnostic<String>(tester, 'paintedText'),
          ),
          (null, false, 'raster dimensions', 'Raster continuity'),
        );
      },
    );

    testWidgets(
      'when a reverse raster shrinks within one text segment, it should reuse its oversampled image',
      (tester) async {
        final captured = await _captureProperties(
          tester,
          sourceStyle: const TextStyle(
            color: Color(0xFFFF0000),
            fontSize: 22,
            height: 1.3,
          ),
          destinationStyle: const TextStyle(
            color: Color(0xFF0000FF),
            fontSize: 34,
            height: 1.1,
          ),
        );
        final animation = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 300),
          value: 0.2,
        );
        addTearDown(animation.dispose);
        await tester.pumpWidget(
          _TextFlightHarness(
            source: captured.destination,
            destination: captured.source,
            animation: animation,
          ),
        );
        final raster = await _waitForRaster(tester);
        final rasterDensity = _diagnostic<double>(
          tester,
          'retainedTextRasterDevicePixelRatio',
        );

        animation.value = 0.4;
        await tester.pump();

        expect(
          (
            identical(
              raster,
              _diagnostic<ui.Image>(tester, 'retainedTextRaster'),
            ),
            rasterDensity! > tester.view.devicePixelRatio,
          ),
          (true, true),
        );
      },
    );

    testWidgets(
      'when four matched Column texts alternate directions after warmup, it should retain the complete bounded raster working set',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        final appKey = GlobalKey<_ColumnRasterWorkingSetAppState>();
        await tester.pumpWidget(
          _ColumnRasterWorkingSetApp(key: appKey),
        );
        await tester.pumpAndSettle();

        await _pushAndPopulateColumnRasters(
          tester,
          appKey.currentState!,
          firstSegmentEntries: 4,
          secondSegmentEntries: 8,
        );
        await _completeColumnRoute(tester);
        final warm = await _popAndPopulateColumnRasters(
          tester,
          appKey.currentState!,
          firstSegmentEntries: 12,
          secondSegmentEntries: 16,
        );
        await _completeColumnRoute(tester);

        await _pushAndPopulateColumnRasters(
          tester,
          appKey.currentState!,
          firstSegmentEntries: 16,
          secondSegmentEntries: 16,
        );
        await _completeColumnRoute(tester);
        final steady = await _popAndPopulateColumnRasters(
          tester,
          appKey.currentState!,
          firstSegmentEntries: 16,
          secondSegmentEntries: 16,
        );
        await _completeColumnRoute(tester);

        expect(
          (
            warm.creates,
            warm.entries,
            warm.pixels <= 4194304,
            steady.entries,
            steady.pixels,
            steady.creates == warm.creates,
            steady.hits > warm.hits,
          ),
          (16, 16, true, 16, warm.pixels, true, true),
          reason: 'warm=$warm, steady=$steady',
        );
      },
    );

    testWidgets(
      'when a later flight repeats a text segment, it should reuse the coordinator raster',
      (tester) async {
        final appKey = GlobalKey<_CrossFlightRasterAppState>();
        await tester.pumpWidget(_CrossFlightRasterApp(key: appKey));
        await tester.pumpAndSettle();

        final first = await _toggleAndWaitForRaster(
          tester,
          appKey.currentState!,
        );
        await tester.pumpAndSettle();
        await _popAndWaitForRaster(tester, appKey.currentState!);
        final hitsBeforeRepeatedFlight = _diagnostic<int>(
          tester,
          'retainedTextRasterPoolHits',
        );
        await tester.pumpAndSettle();
        final repeated = await _toggleAndWaitForRaster(
          tester,
          appKey.currentState!,
        );

        expect(
          (
            identical(first, repeated),
            first.isCloneOf(repeated),
            _diagnostic<int>(tester, 'retainedTextRasterPoolEntries'),
            _diagnostic<int>(tester, 'retainedTextRasterPoolPixels')! <= 4194304,
            _diagnostic<int>(tester, 'retainedTextRasterPoolHits')! > hitsBeforeRepeatedFlight!,
          ),
          (true, true, 3, true, true),
        );
      },
    );

    testWidgets(
      'when only endpoint tint changes between flights, it should reuse the white raster',
      (tester) async {
        final appKey = GlobalKey<_CrossFlightRasterAppState>();
        await tester.pumpWidget(_CrossFlightRasterApp(key: appKey));
        await tester.pump();

        final first = await _toggleAndWaitForRaster(
          tester,
          appKey.currentState!,
        );
        await tester.pumpAndSettle();
        await _popAndWaitForRaster(tester, appKey.currentState!);
        await tester.pumpAndSettle();
        appKey.currentState!.useAlternatePalette();
        await tester.pump();
        const previousTint = Colors.blue;
        final recolored = await _toggleAndWaitForRaster(
          tester,
          appKey.currentState!,
        );

        expect(
          (
            first.isCloneOf(recolored),
            _diagnostic<Color>(tester, 'paintedColor') != previousTint,
          ),
          (true, true),
        );
      },
    );

    testWidgets(
      'when the view pixel ratio changes, it should not reuse the former raster',
      (tester) async {
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        final appKey = GlobalKey<_CrossFlightRasterAppState>();
        await tester.pumpWidget(_CrossFlightRasterApp(key: appKey));
        await tester.pump();

        final first = await _toggleAndWaitForRaster(
          tester,
          appKey.currentState!,
        );
        await tester.pumpAndSettle();
        await _popAndWaitForRaster(tester, appKey.currentState!);
        await tester.pumpAndSettle();
        tester.view.devicePixelRatio = 3;
        await tester.pump();
        final changedDensity = await _toggleAndWaitForRaster(
          tester,
          appKey.currentState!,
        );

        expect(first.isCloneOf(changedDensity), isFalse);
      },
    );

    testWidgets(
      'when system fonts change, it should invalidate reusable rasters',
      (tester) async {
        final appKey = GlobalKey<_CrossFlightRasterAppState>();
        await tester.pumpWidget(_CrossFlightRasterApp(key: appKey));
        await tester.pump();

        final first = await _toggleAndWaitForRaster(
          tester,
          appKey.currentState!,
        );
        await tester.pumpAndSettle();
        await _popAndWaitForRaster(tester, appKey.currentState!);
        await tester.pumpAndSettle();
        await PaintingBinding.instance.handleSystemMessage(
          <String, Object>{'type': 'fontsChange'},
        );
        final afterFontChange = await _toggleAndWaitForRaster(
          tester,
          appKey.currentState!,
        );

        expect(first.isCloneOf(afterFontChange), isFalse);
      },
    );

    testWidgets(
      'when memory pressure is reported, it should release reusable rasters',
      (tester) async {
        final appKey = GlobalKey<_CrossFlightRasterAppState>();
        await tester.pumpWidget(_CrossFlightRasterApp(key: appKey));
        await tester.pump();

        final first = await _toggleAndWaitForRaster(
          tester,
          appKey.currentState!,
        );
        await tester.pumpAndSettle();
        await _popAndWaitForRaster(tester, appKey.currentState!);
        await tester.pumpAndSettle();
        _binding.handleMemoryPressure();
        final afterMemoryPressure = await _toggleAndWaitForRaster(
          tester,
          appKey.currentState!,
        );

        expect(first.isCloneOf(afterMemoryPressure), isFalse);
      },
    );

    final unsupportedStyles = <({String name, TextStyle source, TextStyle destination, String blocker})>[
      (
        name: 'foreground',
        source: TextStyle(
          foreground: Paint()..color = Colors.red,
          fontSize: 22,
        ),
        destination: TextStyle(
          foreground: Paint()..color = Colors.red,
          fontSize: 34,
        ),
        blocker: 'foreground',
      ),
      (
        name: 'shadows',
        source: const TextStyle(
          color: Colors.red,
          fontSize: 22,
          shadows: [Shadow(blurRadius: 2)],
        ),
        destination: const TextStyle(
          color: Colors.blue,
          fontSize: 34,
          shadows: [Shadow(blurRadius: 2)],
        ),
        blocker: 'shadows',
      ),
      (
        name: 'decoration',
        source: const TextStyle(
          color: Colors.red,
          fontSize: 22,
          decoration: TextDecoration.underline,
        ),
        destination: const TextStyle(
          color: Colors.blue,
          fontSize: 34,
          decoration: TextDecoration.underline,
        ),
        blocker: 'decoration',
      ),
      (
        name: 'another delta',
        source: const TextStyle(
          color: Colors.red,
          fontSize: 22,
          letterSpacing: 0,
        ),
        destination: const TextStyle(
          color: Colors.blue,
          fontSize: 34,
          letterSpacing: 1,
        ),
        blocker: 'different endpoint style',
      ),
    ];
    for (final variant in unsupportedStyles) {
      testWidgets(
        'when ${variant.name} is present, it should use the direct fallback',
        (tester) async {
          final properties = await _captureProperties(
            tester,
            sourceStyle: variant.source,
            destinationStyle: variant.destination,
          );
          final animation = AnimationController(
            vsync: tester,
            duration: const Duration(milliseconds: 300),
            value: 0.5,
          );
          addTearDown(animation.dispose);
          await tester.pumpWidget(
            _TextFlightHarness(
              source: properties.source,
              destination: properties.destination,
              animation: animation,
            ),
          );

          expect(
            (
              _diagnostic<ui.Image>(tester, 'retainedTextRaster'),
              _diagnostic<bool>(tester, 'retainedTextRasterPending'),
              _diagnostic<String>(tester, 'rasterRetentionBlocker'),
            ),
            (null, false, variant.blocker),
          );
        },
      );
    }
  });
}
