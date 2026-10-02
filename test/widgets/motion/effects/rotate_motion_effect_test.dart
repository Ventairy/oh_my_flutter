import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

const _childKey = Key('rotating-child');
const _imageKey = Key('rotating-image');

Widget _app(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Offset _horizontalAxis(WidgetTester tester) {
  final child = tester.renderObject<RenderBox>(find.byKey(_childKey));
  return child.localToGlobal(Offset(child.size.width, 0)) - child.localToGlobal(Offset.zero);
}

Offset _centerDisplacement(WidgetTester tester) {
  final motion = tester.renderObject<RenderBox>(find.byType(Motion));
  final child = tester.renderObject<RenderBox>(find.byKey(_childKey));
  return child.localToGlobal(child.size.center(Offset.zero)) - motion.localToGlobal(motion.size.center(Offset.zero));
}

RenderBox _transition(WidgetTester tester) {
  return tester.renderObject<RenderBox>(
    find.descendant(
      of: find.byType(Motion),
      matching: find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MotionTransition'),
    ),
  );
}

T _textProperty<T>(WidgetTester tester, String name) {
  final renderObject = tester.renderObject<RenderObject>(
    find.descendant(
      of: find.byType(TextMotion),
      matching: find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_OptimizedTextMotion'),
    ),
  );
  final property = renderObject.toDiagnosticsNode().getProperties().singleWhere((property) => property.name == name);
  final value = (property as DiagnosticsProperty<T>).value;
  if (value == null) {
    throw StateError('TextMotion diagnostic $name is null.');
  }
  return value;
}

Future<Rect> _inkBounds(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_imageKey));
  final image = await tester.runAsync(boundary.toImage) ?? (throw StateError('Image capture failed.'));
  final data =
      await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)) ??
      (throw StateError('Image bytes were unavailable.'));
  final bytes = data.buffer.asUint8List();
  var left = image.width;
  var top = image.height;
  var right = 0;
  var bottom = 0;
  for (var y = 0; y < image.height; y += 1) {
    for (var x = 0; x < image.width; x += 1) {
      final pixel = (y * image.width + x) * 4;
      if (bytes[pixel + 3] < 32 || bytes[pixel] > 128 || bytes[pixel + 1] > 128 || bytes[pixel + 2] > 128) {
        continue;
      }
      left = math.min(left, x);
      top = math.min(top, y);
      right = math.max(right, x + 1);
      bottom = math.max(bottom, y + 1);
    }
  }
  image.dispose();
  return Rect.fromLTRB(left.toDouble(), top.toDouble(), right.toDouble(), bottom.toDouble());
}

class _BriefRotationEffect extends MotionEffect {
  const new();

  @override
  MotionEffectBounds get bounds => const MotionEffectBounds(maximumRotationDegrees: 90);

  @override
  void apply(double progress, MotionEffectTransform transform) {
    if (progress > 0.2 && progress < 0.202) {
      transform.rotate(90);
    }
  }
}

void main() {
  group('RotateMotionEffect', () {
    setUpAll(() async {
      final loader = FontLoader('RotateTestInter')
        ..addFont(File('test/fixtures/fonts/inter.ttf').readAsBytes().then(ByteData.sublistView));
      await loader.load();
    });

    testWidgets('when turning clockwise, it should reach the requested angle from zero', (tester) async {
      await tester.pumpWidget(
        _app(
          const Motion(
            effect: RotateMotionEffect(degrees: 90),
            child: SizedBox(key: _childKey, width: 40, height: 20),
          ),
        ),
      );
      final start = _horizontalAxis(tester);
      await tester.pump(const Duration(milliseconds: 150));
      final middle = _horizontalAxis(tester);
      await tester.pump(const Duration(milliseconds: 150));
      final end = _horizontalAxis(tester);

      expect(
        (
          (start - const Offset(40, 0)).distance < 0.01,
          (middle - const Offset(28.284271, 28.284271)).distance < 0.01,
          (end - const Offset(0, 40)).distance < 0.01,
        ),
        (true, true, true),
      );
    });

    testWidgets('when turning counterclockwise, it should use the negative angle', (tester) async {
      await tester.pumpWidget(
        _app(
          const Motion(
            effect: RotateMotionEffect(degrees: -90),
            child: SizedBox(key: _childKey, width: 40, height: 20),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect((_horizontalAxis(tester) - const Offset(0, -40)).distance < 0.01, isTrue);
    });

    testWidgets('when rotating, it should preserve the child layout size', (tester) async {
      await tester.pumpWidget(
        _app(
          const Motion(
            effect: RotateMotionEffect(degrees: 90),
            child: SizedBox(key: _childKey, width: 40, height: 20),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(tester.getSize(find.byKey(_childKey)), const Size(40, 20));
    });

    testWidgets('when rotation follows movement, it should rotate the earlier translation', (tester) async {
      await tester.pumpWidget(
        _app(
          const Motion.list(
            startup: MotionStartup.skip,
            effects: [
              MoveMotionEffect(begin: Offset(10, 0), end: Offset(10, 0)),
              RotateMotionEffect(degrees: 90),
            ],
            child: SizedBox(key: _childKey, width: 40, height: 20),
          ),
        ),
      );

      expect((_centerDisplacement(tester) - const Offset(0, 10)).distance < 0.01, isTrue);
    });

    testWidgets('when movement follows rotation, it should preserve the later translation', (tester) async {
      await tester.pumpWidget(
        _app(
          const Motion.list(
            startup: MotionStartup.skip,
            effects: [
              RotateMotionEffect(degrees: 90),
              MoveMotionEffect(begin: Offset(10, 0), end: Offset(10, 0)),
            ],
            child: SizedBox(key: _childKey, width: 40, height: 20),
          ),
        ),
      );

      expect((_centerDisplacement(tester) - const Offset(10, 0)).distance < 0.01, isTrue);
    });

    testWidgets('when rotation combines with move and scale, it should preserve effect order', (tester) async {
      await tester.pumpWidget(
        _app(
          const Motion.list(
            startup: MotionStartup.skip,
            effects: [
              MoveMotionEffect(begin: Offset(10, 0), end: Offset(10, 0)),
              RotateMotionEffect(degrees: 90),
              ScaleOutMotionEffect(scale: 0.5),
            ],
            child: SizedBox(key: _childKey, width: 40, height: 20),
          ),
        ),
      );
      final first = _centerDisplacement(tester);
      await tester.pumpWidget(
        _app(
          const Motion.list(
            startup: MotionStartup.skip,
            effects: [
              ScaleOutMotionEffect(scale: 0.5),
              RotateMotionEffect(degrees: 90),
              MoveMotionEffect(begin: Offset(10, 0), end: Offset(10, 0)),
            ],
            child: SizedBox(key: _childKey, width: 40, height: 20),
          ),
        ),
      );
      final second = _centerDisplacement(tester);

      expect(
        (
          (first - const Offset(0, 5)).distance < 0.01,
          (second - const Offset(10, 0)).distance < 0.01,
        ),
        (true, true),
      );
    });

    testWidgets('when rotated outside layout bounds, it should hit test the visible child', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Motion(
            startup: MotionStartup.skip,
            interactive: true,
            effect: const RotateMotionEffect(degrees: 90),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps += 1,
              child: const SizedBox(key: _childKey, width: 40, height: 20),
            ),
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byKey(_childKey)) + const Offset(0, 16));

      expect(taps, 1);
    });

    testWidgets('when making a full turn, it should reserve room for intermediate angles', (tester) async {
      await tester.pumpWidget(
        _app(
          const Motion(
            effect: RotateMotionEffect(degrees: 360),
            child: SizedBox(key: _childKey, width: 40, height: 20),
          ),
        ),
      );

      expect(_transition(tester).paintBounds.contains(const Offset(20, -12)), isTrue);
    });

    testWidgets('when turning by a small angle, it should keep paint bounds close to the child', (tester) async {
      await tester.pumpWidget(
        _app(
          const Motion(
            effect: RotateMotionEffect(degrees: 1),
            child: SizedBox(key: _childKey, width: 40, height: 20),
          ),
        ),
      );

      expect(_transition(tester).paintBounds.top > -1, isTrue);
    });

    testWidgets('when a custom angle is missed by sampling, it should honor declared bounds', (tester) async {
      await tester.pumpWidget(
        _app(
          const Motion(
            effect: _BriefRotationEffect(),
            child: SizedBox(key: _childKey, width: 40, height: 20),
          ),
        ),
      );

      expect(_transition(tester).paintBounds.contains(const Offset(20, -12)), isTrue);
    });

    testWidgets('when text uses an atlas, it should rotate each grapheme with stagger', (tester) async {
      await tester.pumpWidget(
        _app(
          const TextMotion(
            effect: RotateMotionEffect(degrees: 90),
            stagger: Duration(milliseconds: 100),
            child: Text('AB'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      final angles = _textProperty<Iterable<double>>(tester, 'characterRotations').toList();
      expect(
        (
          (angles[0] - 45).abs() < 0.01,
          (angles[1] - 15).abs() < 0.01,
          _textProperty<bool>(tester, 'usesAtlas'),
        ),
        (true, true, true),
      );
    });

    testWidgets('when text rotates in the atlas, it should paint the glyph at the new angle', (tester) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: RepaintBoundary(
              key: _imageKey,
              child: SizedBox(
                width: 100,
                height: 100,
                child: Center(
                  child: TextMotion(
                    key: ValueKey('upright'),
                    startup: MotionStartup.hold,
                    effect: RotateMotionEffect(degrees: 90),
                    child: Text('I', style: TextStyle(fontFamily: 'RotateTestInter', fontSize: 48)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final upright = await _inkBounds(tester);
      await tester.pumpWidget(
        _app(
          const Center(
            child: RepaintBoundary(
              key: _imageKey,
              child: SizedBox(
                width: 100,
                height: 100,
                child: Center(
                  child: TextMotion(
                    key: ValueKey('turned'),
                    startup: MotionStartup.skip,
                    effect: RotateMotionEffect(degrees: 90),
                    child: Text('I', style: TextStyle(fontFamily: 'RotateTestInter', fontSize: 48)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final turned = await _inkBounds(tester);

      expect(
        (upright.height > upright.width, turned.width > turned.height),
        (true, true),
        reason: 'upright=$upright turned=$turned',
      );
    });

    testWidgets('when many graphemes rotate, it should bound each glyph rather than the whole line', (tester) async {
      await tester.pumpWidget(
        _app(
          const TextMotion(
            effect: RotateMotionEffect(degrees: 90),
            child: Text('IIIIIIIIIIIIIIIIIIII', style: TextStyle(fontSize: 20)),
          ),
        ),
      );
      final renderObject = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(TextMotion),
          matching: find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_OptimizedTextMotion'),
        ),
      );

      expect(renderObject.paintBounds.top > -20, isTrue);
    });

    testWidgets('when text cannot use an atlas, it should still rotate each grapheme', (tester) async {
      await tester.pumpWidget(
        _app(
          const TextMotion(
            effect: RotateMotionEffect(degrees: -90),
            child: Text('A', style: TextStyle(fontSize: 2200)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        (
          _textProperty<Iterable<double>>(tester, 'characterRotations').single,
          _textProperty<bool>(tester, 'usesAtlas'),
        ),
        (-90, false),
      );
    });

    testWidgets('when text combines rotation and movement, it should preserve effect order', (tester) async {
      await tester.pumpWidget(
        _app(
          const TextMotion.list(
            startup: MotionStartup.skip,
            effects: [
              MoveMotionEffect(begin: Offset(10, 0), end: Offset(10, 0)),
              RotateMotionEffect(degrees: 90),
            ],
            child: Text('A'),
          ),
        ),
      );
      final moveThenRotate = _textProperty<Iterable<Offset>>(tester, 'characterTranslations').single;
      await tester.pumpWidget(
        _app(
          const TextMotion.list(
            startup: MotionStartup.skip,
            effects: [
              RotateMotionEffect(degrees: 90),
              MoveMotionEffect(begin: Offset(10, 0), end: Offset(10, 0)),
            ],
            child: Text('A'),
          ),
        ),
      );
      final rotateThenMove = _textProperty<Iterable<Offset>>(tester, 'characterTranslations').single;

      expect(
        (
          (moveThenRotate - const Offset(0, 10)).distance < 0.01,
          (rotateThenMove - const Offset(10, 0)).distance < 0.01,
        ),
        (true, true),
      );
    });

    testWidgets('when text motion is reduced, it should show each final angle', (tester) async {
      await tester.pumpWidget(
        _app(
          const TextMotion(
            effect: RotateMotionEffect(degrees: -45),
            child: Text('AB'),
          ),
          disableAnimations: true,
        ),
      );

      expect(_textProperty<Iterable<double>>(tester, 'characterRotations').toList(), <double>[-45, -45]);
    });

    testWidgets('when motion is reduced, it should show the final angle immediately', (tester) async {
      await tester.pumpWidget(
        _app(
          const Motion(
            effect: RotateMotionEffect(degrees: 90),
            child: SizedBox(key: _childKey, width: 40, height: 20),
          ),
          disableAnimations: true,
        ),
      );

      expect((_horizontalAxis(tester) - const Offset(0, 40)).distance < 0.01, isTrue);
    });

    test('when degrees are not finite, it should reject the configuration', () {
      expect(() => RotateMotionEffect(degrees: double.infinity), throwsAssertionError);
    });
  });
}
