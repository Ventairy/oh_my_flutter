import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/morph/morph.dart' show MorphColumnFlightDelegate;

void main() {
  group('Morph captured environment', () {
    testWidgets(
      'when endpoints contain multiple raw children, it should capture each endpoint environment once',
      (tester) async {
        var sourceThemeReads = 0;
        var destinationThemeReads = 0;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                _CountingInheritedTheme(
                  onRead: () => sourceThemeReads += 1,
                  child: Column(
                    key: const ValueKey('source-column'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Builder(builder: _rawChild),
                      Container(
                        padding: const EdgeInsets.all(1),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Builder(builder: _rawChild),
                            Builder(builder: _rawChild),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _CountingInheritedTheme(
                  onRead: () => destinationThemeReads += 1,
                  child: Column(
                    key: const ValueKey('destination-column'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Builder(builder: _rawChild),
                      Container(
                        padding: const EdgeInsets.all(1),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Builder(builder: _rawChild),
                            Builder(builder: _rawChild),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        final sourceFinder = find.byKey(const ValueKey('source-column'));
        final sourceContext = tester.element(sourceFinder);
        final sourceColumn = tester.widget<Column>(sourceFinder);
        final sourceRenderObject = tester.renderObject<RenderFlex>(
          sourceFinder,
        );
        final destinationFinder = find.byKey(
          const ValueKey('destination-column'),
        );
        final destinationContext = tester.element(destinationFinder);
        final destinationColumn = tester.widget<Column>(destinationFinder);
        final destinationRenderObject = tester.renderObject<RenderFlex>(
          destinationFinder,
        );
        sourceThemeReads = 0;
        destinationThemeReads = 0;
        MorphColumnFlightDelegate.captureColumn(
          context: sourceContext,
          column: sourceColumn,
          renderObject: sourceRenderObject,
          axisScale: const Offset(1, 1),
          switchThreshold: 0.5,
        );
        final sourceCaptureReads = sourceThemeReads;
        destinationThemeReads = 0;
        MorphColumnFlightDelegate.captureColumn(
          context: destinationContext,
          column: destinationColumn,
          renderObject: destinationRenderObject,
          axisScale: const Offset(1, 1),
          switchThreshold: 0.5,
        );

        expect(
          (sourceCaptureReads, destinationThemeReads),
          (1, 1),
        );
      },
    );

    testWidgets(
      'when every compound child is specialized, it should not capture an endpoint environment',
      (tester) async {
        var themeReads = 0;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: _CountingInheritedTheme(
              onRead: () => themeReads += 1,
              child: Column(
                key: const ValueKey('specialized-column'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    color: const Color(0xFF000000),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    color: const Color(0xFFFFFFFF),
                  ),
                ],
              ),
            ),
          ),
        );
        final columnFinder = find.byKey(
          const ValueKey('specialized-column'),
        );
        final context = tester.element(columnFinder);
        final column = tester.widget<Column>(columnFinder);
        final renderObject = tester.renderObject<RenderFlex>(columnFinder);
        themeReads = 0;

        MorphColumnFlightDelegate.captureColumn(
          context: context,
          column: column,
          renderObject: renderObject,
          axisScale: const Offset(1, 1),
          switchThreshold: 0.5,
        );

        expect(themeReads, 0);
      },
    );
  });
}

Widget _rawChild(BuildContext context) {
  return const SizedBox.square(dimension: 12);
}

final class _CountingInheritedTheme extends InheritedTheme {
  const _CountingInheritedTheme({
    required this.onRead,
    required super.child,
  });

  final VoidCallback onRead;

  @override
  InheritedElement createElement() => _CountingInheritedElement(this);

  @override
  bool updateShouldNotify(_CountingInheritedTheme oldWidget) => false;

  @override
  Widget wrap(BuildContext context, Widget child) {
    return _CountingInheritedTheme(
      onRead: onRead,
      child: child,
    );
  }
}

final class _CountingInheritedElement extends InheritedElement {
  _CountingInheritedElement(super.widget);

  @override
  _CountingInheritedTheme get widget {
    final theme = super.widget as _CountingInheritedTheme;
    theme.onRead();
    return theme;
  }
}
