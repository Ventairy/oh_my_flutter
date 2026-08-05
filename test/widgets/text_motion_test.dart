import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Widget _testApp({
  required Widget child,
  bool disableAnimations = false,
  bool tickersEnabled = true,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: TickerMode(
        enabled: tickersEnabled,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

List<double> _fadeValues(WidgetTester tester) {
  return List<double>.of(
    _debugProperty<Iterable<double>>(tester, 'characterOpacities'),
  );
}

Finder _optimizedTextMotion() {
  return find.descendant(
    of: find.byType(TextMotion),
    matching: find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_OptimizedTextMotion',
    ),
  );
}

T _debugProperty<T>(WidgetTester tester, String name) {
  final renderObject = tester.renderObject<RenderObject>(
    _optimizedTextMotion(),
  );
  final property = renderObject.toDiagnosticsNode().getProperties().singleWhere((property) => property.name == name);
  final value = (property as DiagnosticsProperty<T>).value;
  if (value == null) {
    throw StateError('TextMotion diagnostic $name is null.');
  }
  return value;
}

List<double> _probeValues(WidgetTester tester) {
  return _debugProperty<Iterable<Offset>>(
    tester,
    'characterTranslations',
  ).map((translation) => translation.dx).toList(growable: false);
}

void main() {
  group('TextMotion', () {
    testWidgets(
      'when built, it should own rendering without delegating through Motion',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: MoveMotionEffect(
                begin: Offset(0, 8),
                end: Offset.zero,
              ),
              child: Text('Text'),
            ),
          ),
        );

        expect(
          find.descendant(
            of: find.byType(TextMotion),
            matching: find.byType(Motion),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'when text contains multiple letters, it should stagger one effect across them',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FadeInMotionEffect(
                duration: Duration(milliseconds: 100),
              ),
              stagger: Duration(milliseconds: 50),
              child: Text('AB'),
            ),
          ),
        );
        final start = _fadeValues(tester);
        await tester.pump(const Duration(milliseconds: 50));
        final afterFirstStagger = _fadeValues(tester);
        await tester.pump(const Duration(milliseconds: 50));
        final afterOneEffectDuration = _fadeValues(tester);
        await tester.pump(const Duration(milliseconds: 50));
        final end = _fadeValues(tester);

        expect(
          listEquals(start, <double>[0, 0]) &&
              listEquals(afterFirstStagger, <double>[0.5, 0]) &&
              listEquals(afterOneEffectDuration, <double>[1, 0.5]) &&
              listEquals(end, <double>[1, 1]),
          isTrue,
        );
      },
    );

    testWidgets(
      'when text contains extended graphemes, it should keep each grapheme together',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FadeInMotionEffect(),
              child: Text(
                'Aé👨‍👩‍👧‍👦'
                '🇧🇷',
              ),
            ),
          ),
        );

        expect(
          _debugProperty<int>(tester, 'animatedCharacterCount'),
          4,
        );
      },
    );

    testWidgets(
      'when text contains whitespace, it should animate only visible graphemes',
      (tester) async {
        const textKey = Key('text_with_whitespace');
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FadeInMotionEffect(),
              child: Text('A B\nC', key: textKey),
            ),
          ),
        );
        expect(
          (
            _debugProperty<int>(tester, 'animatedCharacterCount'),
            _debugProperty<Iterable<String>>(
              tester,
              'graphemes',
            ).join(),
          ),
          (3, 'A B\nC'),
        );
      },
    );

    testWidgets(
      'when text contains invisible break controls, it should keep them in the paragraph',
      (tester) async {
        const textKey = Key('text_with_break_controls');
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FadeInMotionEffect(),
              child: Text('A\u200BB\u00ADC', key: textKey),
            ),
          ),
        );
        expect(
          (
            _debugProperty<int>(tester, 'animatedCharacterCount'),
            _debugProperty<Iterable<String>>(
              tester,
              'graphemes',
            ).join(),
          ),
          (3, 'A\u200BB\u00ADC'),
        );
      },
    );

    testWidgets(
      'when text has no visible graphemes, it should schedule no motion work',
      (tester) async {
        const textKey = Key('whitespace_only_text');
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FloatingMotionEffect(),
              child: Text(' \n\u200B', key: textKey),
            ),
          ),
        );

        expect(
          tester.binding.transientCallbackCount == 0 &&
              _optimizedTextMotion().evaluate().isEmpty &&
              find.byKey(textKey).evaluate().length == 1,
          isTrue,
        );
      },
    );

    testWidgets(
      'when effects are listed, it should apply every effect to every letter',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion.list(
              effects: [
                FadeInMotionEffect(),
                MoveMotionEffect(
                  begin: Offset(0, 8),
                  end: Offset.zero,
                ),
              ],
              child: Text('AB'),
            ),
          ),
        );
        expect(
          listEquals(
                _debugProperty<Iterable<String>>(
                  tester,
                  'effects',
                ).toList(),
                <String>['FadeInMotionEffect', 'MoveMotionEffect'],
              ) &&
              _debugProperty<int>(tester, 'animatedCharacterCount') == 2 &&
              _debugProperty<bool>(tester, 'usesAtlas'),
          isTrue,
        );
      },
    );

    testWidgets(
      'when built-in transforms are listed, it should preserve declaration order',
      (tester) async {
        const move = MoveMotionEffect(
          begin: Offset(10, 0),
          end: Offset.zero,
        );
        const scale = ScaleInMotionEffect(scale: 0.5);
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion.list(
              effects: [move, scale],
              child: Text('A'),
            ),
          ),
        );
        final moveThenScale = _debugProperty<Iterable<Offset>>(
          tester,
          'characterTranslations',
        ).single;
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion.list(
              effects: [scale, move],
              child: Text('A'),
            ),
          ),
        );
        final scaleThenMove = _debugProperty<Iterable<Offset>>(
          tester,
          'characterTranslations',
        ).single;

        expect(
          (moveThenScale.dx - 5).abs() < 0.01 && (scaleThenMove.dx - 10).abs() < 0.01,
          isTrue,
        );
      },
    );

    testWidgets(
      'when one effect animates many letters, it should use one scheduler entry',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FloatingMotionEffect(),
              child: Text('Shared scheduler'),
            ),
          ),
        );

        expect(tester.binding.transientCallbackCount, 1);
      },
    );

    testWidgets(
      'when looping with stagger, it should preserve the effect period and offset letter phases',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: _ProbeMotionEffect(
                duration: Duration(milliseconds: 100),
              ),
              stagger: Duration(milliseconds: 25),
              child: Text('AB'),
            ),
          ),
        );
        final start = _probeValues(tester);
        await tester.pump(const Duration(milliseconds: 25));
        final quarterCycle = _probeValues(tester);
        await tester.pump(const Duration(milliseconds: 75));
        final completeCycle = _probeValues(tester);

        expect(
          (start[0] - 0).abs() < 0.01 &&
              (start[1] - 0.75).abs() < 0.01 &&
              (quarterCycle[0] - 0.25).abs() < 0.01 &&
              (quarterCycle[1] - 0).abs() < 0.01 &&
              (completeCycle[0] - 0).abs() < 0.01 &&
              (completeCycle[1] - 0.75).abs() < 0.01 &&
              tester.hasRunningAnimations,
          isTrue,
        );
      },
    );

    testWidgets(
      'when one-shot playback finishes, it should call lifecycle callbacks once',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            child: TextMotion(
              effect: FadeInMotionEffect(
                duration: const Duration(milliseconds: 100),
                onStart: () => events.add('start'),
                onEnd: () => events.add('end'),
              ),
              stagger: const Duration(milliseconds: 50),
              child: const Text('AB'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(events, <String>['start', 'end']);
      },
    );

    testWidgets(
      'when animations are disabled, it should show every letter at the endpoint',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            disableAnimations: true,
            child: const TextMotion(
              effect: FadeInMotionEffect(),
              stagger: Duration(milliseconds: 50),
              child: Text('ABC'),
            ),
          ),
        );

        expect(
          listEquals(_fadeValues(tester), <double>[1, 1, 1]) && tester.binding.transientCallbackCount == 0,
          isTrue,
        );
      },
    );

    testWidgets(
      'when the source text is configured, it should preserve its public presentation values',
      (tester) async {
        const textKey = Key('source_text');
        const style = TextStyle(fontSize: 24, letterSpacing: 2);
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FadeInMotionEffect(),
              child: Text(
                'AB',
                key: textKey,
                style: style,
                textAlign: TextAlign.end,
                textDirection: TextDirection.rtl,
                locale: Locale('pt', 'BR'),
                softWrap: false,
                overflow: TextOverflow.fade,
                textScaler: TextScaler.linear(1.2),
                maxLines: 1,
                semanticsLabel: 'Letters A and B',
                semanticsIdentifier: 'animated_letters',
                textWidthBasis: TextWidthBasis.longestLine,
                selectionColor: Colors.purple,
              ),
            ),
          ),
        );
        expect(
          (
            _debugProperty<TextStyle>(tester, 'style').fontSize,
            _debugProperty<TextStyle>(tester, 'style').letterSpacing,
            _debugProperty<TextAlign>(tester, 'textAlign'),
            _debugProperty<TextDirection>(tester, 'textDirection'),
            _debugProperty<Locale>(tester, 'locale'),
            _debugProperty<bool>(tester, 'softWrap'),
            _debugProperty<TextOverflow>(tester, 'overflow'),
            _debugProperty<TextScaler>(tester, 'textScaler'),
            _debugProperty<int>(tester, 'maxLines'),
            _debugProperty<TextWidthBasis>(tester, 'textWidthBasis'),
          ),
          (
            style.fontSize,
            style.letterSpacing,
            TextAlign.end,
            TextDirection.rtl,
            const Locale('pt', 'BR'),
            false,
            TextOverflow.fade,
            const TextScaler.linear(1.2),
            1,
            TextWidthBasis.longestLine,
          ),
        );
      },
    );

    testWidgets(
      'when the source uses an ideographic baseline, it should align letter placeholders to it',
      (tester) async {
        const textKey = Key('ideographic_text');
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FadeInMotionEffect(),
              child: Text(
                '文',
                key: textKey,
                style: TextStyle(textBaseline: TextBaseline.ideographic),
              ),
            ),
          ),
        );
        expect(
          _debugProperty<TextBaseline>(tester, 'baseline'),
          TextBaseline.ideographic,
        );
      },
    );

    testWidgets(
      'when text scaling is configured, it should apply the scale once',
      (tester) async {
        const unscaledKey = Key('unscaled_text');
        const motionKey = Key('motion_text');
        await tester.pumpWidget(
          _testApp(
            disableAnimations: true,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextMotion(
                  effect: FadeInMotionEffect(),
                  child: Text(
                    'A',
                    key: unscaledKey,
                    style: TextStyle(fontSize: 20),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
                TextMotion(
                  effect: FadeInMotionEffect(),
                  child: Text(
                    'A',
                    key: motionKey,
                    style: TextStyle(fontSize: 20),
                    textScaler: TextScaler.linear(2),
                  ),
                ),
              ],
            ),
          ),
        );
        final unscaledSize = tester.getSize(find.byKey(unscaledKey));
        final scaledSize = tester.getSize(find.byKey(motionKey));

        expect(
          (scaledSize.width / unscaledSize.width - 2).abs() < 0.05 &&
              (scaledSize.height / unscaledSize.height - 2).abs() < 0.05,
          isTrue,
          reason: 'unscaled: $unscaledSize, scaled: $scaledSize',
        );
      },
    );

    testWidgets(
      'when legacy text scaling is configured, it should preserve the scale',
      (tester) async {
        const unscaledKey = Key('legacy_unscaled_text');
        const scaledKey = Key('legacy_scaled_text');
        await tester.pumpWidget(
          _testApp(
            disableAnimations: true,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextMotion(
                  effect: FadeInMotionEffect(),
                  child: Text(
                    'A',
                    key: unscaledKey,
                    style: TextStyle(fontSize: 20),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
                TextMotion(
                  effect: FadeInMotionEffect(),
                  child: Text(
                    'A',
                    key: scaledKey,
                    style: TextStyle(fontSize: 20),
                    // Regression coverage for Flutter's supported legacy API.
                    // ignore: deprecated_member_use
                    textScaleFactor: 2,
                  ),
                ),
              ],
            ),
          ),
        );
        final unscaledSize = tester.getSize(find.byKey(unscaledKey));
        final scaledSize = tester.getSize(find.byKey(scaledKey));

        expect(
          (scaledSize.width / unscaledSize.width - 2).abs() < 0.05 &&
              (scaledSize.height / unscaledSize.height - 2).abs() < 0.05,
          isTrue,
          reason: 'unscaled: $unscaledSize, scaled: $scaledSize',
        );
      },
    );

    testWidgets(
      'when text is scaled, it should keep move distances in logical pixels',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: MoveMotionEffect(
                begin: Offset(0, 8),
                end: Offset.zero,
                duration: Duration(milliseconds: 100),
              ),
              child: Text(
                'A',
                style: TextStyle(fontSize: 20),
                textScaler: TextScaler.linear(2),
              ),
            ),
          ),
        );
        final start = _debugProperty<Iterable<Offset>>(
          tester,
          'characterTranslations',
        ).single;
        await tester.pump(const Duration(milliseconds: 100));
        final end = _debugProperty<Iterable<Offset>>(
          tester,
          'characterTranslations',
        ).single;

        expect(
          (start.dy - 8).abs() < 0.01 && end.dy.abs() < 0.01,
          isTrue,
        );
      },
    );

    testWidgets(
      'when built-in effects animate many letters, it should use one compact render path',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion.list(
              effects: [
                FadeInMotionEffect(),
                MoveMotionEffect(begin: Offset(0, 8), end: Offset.zero),
                ScaleInMotionEffect(scale: 0.8),
                FloatingMotionEffect(),
              ],
              child: Text('Galaxy J5 performance path'),
            ),
          ),
        );
        final descendants = find
            .descendant(
              of: find.byType(TextMotion),
              matching: find.byWidgetPredicate((widget) => true),
            )
            .evaluate()
            .length;

        expect(
          _optimizedTextMotion().evaluate().length == 1 &&
              descendants < 10 &&
              _debugProperty<bool>(tester, 'usesAtlas'),
          isTrue,
        );
      },
    );

    testWidgets(
      'when plain text uses the atlas, it should skip the empty paragraph draw',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FloatingMotionEffect(),
              child: Text('Galaxy J5 performance path'),
            ),
          ),
        );

        expect(_debugProperty<bool>(tester, 'paintsParagraph'), isFalse);
      },
    );

    testWidgets(
      'when decoration spans whitespace, it should retain the paragraph draw',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FloatingMotionEffect(),
              child: Text(
                'A A',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ),
        );

        expect(_debugProperty<bool>(tester, 'paintsParagraph'), isTrue);
      },
    );

    testWidgets(
      'when text is ellipsized, it should retain the paragraph draw',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const SizedBox(
              width: 24,
              child: TextMotion(
                effect: FloatingMotionEffect(),
                child: Text(
                  'Overflowing text',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );

        expect(_debugProperty<bool>(tester, 'paintsParagraph'), isTrue);
      },
    );

    testWidgets(
      'when a built-in curve overshoots, it should include the peak in its paint bounds',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: MoveMotionEffect(
                begin: Offset.zero,
                end: Offset(100, 0),
                curve: _PeakCurve(),
              ),
              child: Text('A'),
            ),
          ),
        );
        final renderObject = tester.renderObject<RenderBox>(
          _optimizedTextMotion(),
        );

        expect(
          renderObject.paintBounds.right >= renderObject.size.width + 199.9,
          isTrue,
        );
      },
    );

    testWidgets(
      'when no semantics label is supplied, it should expose the complete text once',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FadeInMotionEffect(),
              child: Text(
                'Hello',
                locale: Locale('en', 'US'),
                semanticsIdentifier: 'greeting',
              ),
            ),
          ),
        );
        final completeText = find.bySemanticsLabel('Hello');
        final node = tester.getSemantics(completeText);
        final localeAttribute = node.attributedLabel.attributes.single as LocaleStringAttribute;
        final result = (
          completeText.evaluate().length,
          find.bySemanticsLabel(RegExp(r'^H$')).evaluate().length,
          find.bySemanticsLabel(RegExp(r'^e$')).evaluate().length,
          find.bySemanticsLabel(RegExp(r'^l$')).evaluate().length,
          find.bySemanticsLabel(RegExp(r'^o$')).evaluate().length,
          node.identifier,
          localeAttribute.locale.toLanguageTag(),
        );
        semantics.dispose();

        expect(result, (1, 0, 0, 0, 0, 'greeting', 'en-US'));
      },
    );

    testWidgets(
      'when a semantics label is supplied, it should replace the visible text for accessibility',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FadeInMotionEffect(),
              child: Text(
                'OMF',
                semanticsLabel: 'Oh My Flutter',
              ),
            ),
          ),
        );
        final result = (
          find.bySemanticsLabel('Oh My Flutter').evaluate().length,
          find.bySemanticsLabel('OMF').evaluate().length,
        );
        semantics.dispose();

        expect(result, (1, 0));
      },
    );

    testWidgets(
      'when stagger is negative, it should reject mounting',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FadeInMotionEffect(),
              stagger: Duration(milliseconds: -1),
              child: Text('AB'),
            ),
          ),
        );

        expect(tester.takeException(), isArgumentError);
      },
    );

    testWidgets(
      'when effects are empty, it should reject mounting',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion.list(
              effects: <MotionEffect>[],
              child: Text('AB'),
            ),
          ),
        );

        expect(tester.takeException(), isArgumentError);
      },
    );

    testWidgets(
      'when the source effect duration is zero, it should reject mounting',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FadeInMotionEffect(duration: Duration.zero),
              stagger: Duration(milliseconds: 100),
              child: Text('AB'),
            ),
          ),
        );

        expect(tester.takeException(), isArgumentError);
      },
    );

    testWidgets(
      'when the source uses rich text, it should reject mounting',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: FadeInMotionEffect(),
              child: Text.rich(TextSpan(text: 'AB')),
            ),
          ),
        );

        expect(tester.takeException(), isArgumentError);
      },
    );
  });
}

class _ProbeMotionEffect extends MotionEffect {
  const _ProbeMotionEffect({required super.duration}) : super(playback: MotionPlayback.loop);

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.translate(x: progress, y: 0);
  }
}

class _PeakCurve extends Curve {
  const _PeakCurve();

  @override
  double transformInternal(double t) {
    return t <= 0.5 ? t * 4 : (1 - t) * 4;
  }
}
