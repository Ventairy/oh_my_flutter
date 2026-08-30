import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('MorphSibling golden', () {
    unawaited(
      goldenTest(
        'when siblings are resting, it should match the reference',
        fileName: 'morph_sibling_resting',
        constraints: const BoxConstraints.tightFor(width: 240, height: 200),
        builder: _MorphSiblingGoldenHarness.new,
      ),
    );

    final midpointKey = GlobalKey<_MorphSiblingGoldenHarnessState>();

    unawaited(
      goldenTest(
        'when siblings reach a flight midpoint, it should preserve their placement, overflow, and paint order',
        fileName: 'morph_sibling_midpoint',
        constraints: const BoxConstraints.tightFor(width: 240, height: 200),
        whilePerforming: (tester) async {
          midpointKey.currentState!.expand();
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          return tester.pumpAndSettle;
        },
        builder: () => _MorphSiblingGoldenHarness(key: midpointKey),
      ),
    );

    final naturalMidpointKey = GlobalKey<_MorphSiblingGoldenHarnessState>();

    unawaited(
      goldenTest(
        'when painting above Morph is disabled, it should keep siblings in their natural paint order',
        fileName: 'morph_sibling_natural_midpoint',
        constraints: const BoxConstraints.tightFor(width: 240, height: 200),
        whilePerforming: (tester) async {
          naturalMidpointKey.currentState!.expand();
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          return tester.pumpAndSettle;
        },
        builder: () => _MorphSiblingGoldenHarness(
          key: naturalMidpointKey,
          paintAboveMorph: false,
        ),
      ),
    );

    final delayedMidpointKey = GlobalKey<_MorphSiblingGoldenHarnessState>();

    unawaited(
      goldenTest(
        'when sibling transitions start late, it should hide them before their interval',
        fileName: 'morph_sibling_delayed_midpoint',
        constraints: const BoxConstraints.tightFor(width: 240, height: 200),
        whilePerforming: (tester) async {
          delayedMidpointKey.currentState!.expand();
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          return tester.pumpAndSettle;
        },
        builder: () => _MorphSiblingGoldenHarness(
          key: delayedMidpointKey,
          delayed: true,
        ),
      ),
    );
  });
}

class _MorphSiblingGoldenHarness extends StatefulWidget {
  const _MorphSiblingGoldenHarness({
    this.delayed = false,
    this.paintAboveMorph = true,
    super.key,
  });

  final bool delayed;
  final bool paintAboveMorph;

  @override
  State<_MorphSiblingGoldenHarness> createState() => _MorphSiblingGoldenHarnessState();
}

class _MorphSiblingGoldenHarnessState extends State<_MorphSiblingGoldenHarness> {
  var _expanded = false;

  void expand() {
    setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4F1EB),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: _expanded ? Alignment.bottomRight : Alignment.topLeft,
            child: Morph(
              tag: 'sibling-golden',
              duration: const Duration(milliseconds: 400),
              child: Container(
                width: _expanded ? 240 : 64,
                height: _expanded ? 200 : 64,
                decoration: BoxDecoration(
                  color: _expanded ? const Color(0xFF4361EE) : const Color(0xFFFF6B6B),
                  borderRadius: BorderRadius.circular(_expanded ? 24 : 12),
                ),
              ),
            ),
          ),
          MorphSibling(
            tag: 'sibling-golden',
            paintAboveMorph: widget.paintAboveMorph,
            transitionBuilder: widget.delayed ? _buildDelayedTransition : null,
            child: Transform.translate(
              offset: const Offset(48, 66),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF2A9D8F),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xCC172A3A),
                      offset: Offset(7, 8),
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: SizedBox(width: 96, height: 64),
              ),
            ),
          ),
          MorphSibling(
            tag: 'sibling-golden',
            paintAboveMorph: widget.paintAboveMorph,
            transitionBuilder: widget.delayed ? _buildDelayedTransition : null,
            child: Transform.translate(
              offset: const Offset(102, 100),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFFC857),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: SizedBox(width: 76, height: 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDelayedTransition(
    Widget child,
    Animation<double> animation,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.8, 1),
      ),
      child: child,
    );
  }
}
