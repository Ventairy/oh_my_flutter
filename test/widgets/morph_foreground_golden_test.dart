import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('MorphForeground golden', () {
    unawaited(
      goldenTest(
        'when foregrounds are resting, it should match the reference',
        fileName: 'morph_foreground_resting',
        constraints: const BoxConstraints.tightFor(width: 240, height: 200),
        builder: _MorphForegroundGoldenHarness.new,
      ),
    );

    final midpointKey = GlobalKey<_MorphForegroundGoldenHarnessState>();

    unawaited(
      goldenTest(
        'when foregrounds reach a flight midpoint, it should preserve their placement, overflow, and paint order',
        fileName: 'morph_foreground_midpoint',
        constraints: const BoxConstraints.tightFor(width: 240, height: 200),
        whilePerforming: (tester) async {
          midpointKey.currentState!.expand();
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          return tester.pumpAndSettle;
        },
        builder: () => _MorphForegroundGoldenHarness(key: midpointKey),
      ),
    );
  });
}

class _MorphForegroundGoldenHarness extends StatefulWidget {
  const _MorphForegroundGoldenHarness({super.key});

  @override
  State<_MorphForegroundGoldenHarness> createState() => _MorphForegroundGoldenHarnessState();
}

class _MorphForegroundGoldenHarnessState extends State<_MorphForegroundGoldenHarness> {
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
              tag: 'foreground-golden',
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
          MorphForeground(
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
          MorphForeground(
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
}
