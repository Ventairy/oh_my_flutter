import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'maybe_safe_area_transform_test/resting_surface.dart';

const _marker = Color(0xFF0000FF);
const Key _capture = ValueKey('capture');
const Key _position = ValueKey('position');

void main() {
  testWidgets('when a surface uses resting geometry, it should keep safe-area placement attached while moving', (
    tester,
  ) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    await _pumpSurface(tester, handle: handle);
    expect(handle.adjustedBounds, const Rect.fromLTWH(0, 40, 20, 20));
  });

  testWidgets('when resting geometry is disabled, it should follow the ordinary paint position', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    await _pumpSurface(tester, handle: handle, useRestingGeometry: false);
    expect(handle.adjustedBounds, const Rect.fromLTWH(0, 0, 20, 20));
  });

  for (final capture in [false, true]) {
    testWidgets(
      'when resting content is ${capture ? 'captured' : 'live'}, it should paint at its moving safe position',
      (
        tester,
      ) async {
        final handle = MaybeSafeAreaHandle();
        addTearDown(handle.dispose);
        await _pumpSurface(tester, handle: handle, capture: capture);
        expect(await _pixel(tester, const Offset(10, 195)), _marker);
      },
    );
  }

  testWidgets('when a resting surface has a positioned ancestor, it should retain that ancestor geometry', (
    tester,
  ) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    await _pumpSurface(tester, handle: handle, ancestorInset: 100);
    expect(handle.adjustedBounds, const Rect.fromLTWH(0, 0, 20, 20));
  });

  testWidgets('when a surface uses resting geometry, it should retain its actual interaction position', (
    tester,
  ) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    await _pumpSurface(tester, handle: handle);
    expect(tester.getTopLeft(find.byKey(_position)), const Offset(0, 190));
  });
  for (final capture in [false, true]) {
    testWidgets(
      'when a ${capture ? 'captured' : 'live'} surface has its own resting offset, it should preserve that offset',
      (tester) async {
        final handle = MaybeSafeAreaHandle();
        addTearDown(handle.dispose);
        await _pumpSurface(tester, handle: handle, capture: capture, restingTranslation: const Offset(0, 25));
        expect(
          (bounds: handle.adjustedBounds, painted: await _markerBounds(tester)),
          (bounds: const Rect.fromLTWH(0, 15, 20, 20), painted: const Rect.fromLTWH(0, 190, 20, 20)),
        );
      },
    );
    testWidgets(
      'when a child moves inside a ${capture ? 'captured' : 'live'} resting surface, it should retain its independent transform',
      (tester) async {
        final handle = MaybeSafeAreaHandle();
        addTearDown(handle.dispose);
        await _pumpSurface(tester, handle: handle, capture: capture, descendantTranslation: const Offset(0, 50));
        expect(
          (bounds: handle.adjustedBounds, painted: await _markerBounds(tester)),
          (bounds: const Rect.fromLTWH(0, 0, 20, 20), painted: const Rect.fromLTWH(0, 200, 20, 20)),
        );
      },
    );
    testWidgets(
      'when a ${capture ? 'captured' : 'live'} resting surface is scaled at high pixel density, it should compose both coordinate spaces',
      (tester) async {
        final handle = MaybeSafeAreaHandle();
        addTearDown(handle.dispose);
        await _pumpSurface(tester, handle: handle, capture: capture, ancestorScale: 2, pixelRatio: 2);
        expect(
          (bounds: handle.adjustedBounds, painted: await _markerBounds(tester)),
          (bounds: const Rect.fromLTWH(0, 20, 20, 20), painted: const Rect.fromLTWH(0, 340, 40, 40)),
        );
      },
    );
    testWidgets(
      'when ${capture ? 'captured' : 'live'} resting surfaces are nested, it should compose their resting geometry',
      (tester) async {
        final handle = MaybeSafeAreaHandle();
        addTearDown(handle.dispose);
        await _pumpSurface(tester, handle: handle, capture: capture, nested: true);
        expect(
          (bounds: handle.adjustedBounds, painted: await _markerBounds(tester)),
          (bounds: const Rect.fromLTWH(0, 40, 20, 20), painted: const Rect.fromLTWH(0, 290, 20, 20)),
        );
      },
    );
  }
  testWidgets('when a surface changes its geometry policy, it should resolve the new policy without remounting', (
    tester,
  ) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    final surfaceKey = GlobalKey();
    await _pumpSurface(tester, handle: handle, surfaceKey: surfaceKey);
    final original = tester.renderObject(find.byKey(surfaceKey));
    await _pumpSurface(tester, handle: handle, surfaceKey: surfaceKey, useRestingGeometry: false);
    expect(
      (sameRenderer: identical(original, tester.renderObject(find.byKey(surfaceKey))), bounds: handle.adjustedBounds),
      (sameRenderer: true, bounds: const Rect.fromLTWH(0, 0, 20, 20)),
    );
  });
  testWidgets('when a resting surface is reparented, it should discard its previous coordinate path', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    final surfaceKey = GlobalKey();
    await _pumpSurface(tester, handle: handle, surfaceKey: surfaceKey);
    final original = tester.renderObject(find.byKey(surfaceKey));
    await _pumpSurface(tester, handle: handle, surfaceKey: surfaceKey, positioned: true, ancestorInset: 100);
    expect(
      (sameRenderer: identical(original, tester.renderObject(find.byKey(surfaceKey))), bounds: handle.adjustedBounds),
      (sameRenderer: true, bounds: const Rect.fromLTWH(0, 0, 20, 20)),
    );
  });
}

Future<void> _pumpSurface(
  WidgetTester tester, {
  required MaybeSafeAreaHandle handle,
  bool useRestingGeometry = true,
  bool capture = false,
  double ancestorInset = 0,
  Offset restingTranslation = .zero,
  Offset descendantTranslation = .zero,
  double ancestorScale = 1,
  double pixelRatio = 1,
  bool nested = false,
  bool positioned = false,
  GlobalKey? surfaceKey,
}) async {
  tester.view
    ..physicalSize = Size(300 * pixelRatio, 600 * pixelRatio)
    ..devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  final controller = SnapshotController(allowSnapshotting: capture);
  addTearDown(controller.dispose);
  Widget surface = RestingSurface(
    key: surfaceKey,
    translation: const Offset(0, 150),
    restingTranslation: restingTranslation,
    useRestingGeometry: useRestingGeometry,
    child: SnapshotWidget(
      controller: controller,
      child: Align(
        alignment: .topLeft,
        child: Transform.translate(
          offset: descendantTranslation,
          child: MaybeSafeArea(
            handle: handle,
            bottom: false,
            child: const SizedBox(
              key: _position,
              width: 20,
              height: 20,
              child: ColoredBox(color: _marker),
            ),
          ),
        ),
      ),
    ),
  );
  if (nested) surface = RestingSurface(translation: const Offset(0, 100), child: surface);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(300, 600),
        devicePixelRatio: pixelRatio,
        padding: const EdgeInsets.only(top: 40),
      ),
      child: Directionality(
        textDirection: .ltr,
        child: RepaintBoundary(
          key: _capture,
          child: Transform.scale(
            scale: ancestorScale,
            alignment: .topLeft,
            child: positioned
                ? Stack(
                    fit: .expand,
                    children: [Positioned.fill(top: ancestorInset, child: surface)],
                  )
                : Padding(
                    padding: EdgeInsets.only(top: ancestorInset),
                    child: surface,
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<Color> _pixel(WidgetTester tester, Offset point) async => (await tester.runAsync(() async {
  final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(_capture)).toImage();
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
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

Future<Rect?> _markerBounds(WidgetTester tester) => tester.runAsync<Rect?>(() async {
  final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(_capture)).toImage();
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    Rect? bounds;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final offset = (y * image.width + x) * 4;
        if (bytes.getUint8(offset) != 0 ||
            bytes.getUint8(offset + 1) != 0 ||
            bytes.getUint8(offset + 2) != 255 ||
            bytes.getUint8(offset + 3) != 255) {
          continue;
        }
        final pixel = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);
        bounds = bounds?.expandToInclude(pixel) ?? pixel;
      }
    }
    return bounds;
  } finally {
    image.dispose();
  }
});
