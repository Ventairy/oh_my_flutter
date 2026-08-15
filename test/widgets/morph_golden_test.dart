import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('Morph golden', () {
    final midpointKey = GlobalKey<_MorphGoldenHarnessState>();

    unawaited(
      goldenTest(
        'when a card transfer reaches its midpoint, it should match the reference',
        fileName: 'morph_midpoint',
        constraints: const BoxConstraints.tightFor(width: 400, height: 700),
        whilePerforming: (tester) async {
          midpointKey.currentState!.expand();
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));

          return tester.pumpAndSettle;
        },
        builder: () => _MorphGoldenHarness(key: midpointKey),
      ),
    );

    final settledKey = GlobalKey<_MorphGoldenHarnessState>();

    unawaited(
      goldenTest(
        'when a card transfer settles, it should match the destination reference',
        fileName: 'morph_settled',
        constraints: const BoxConstraints.tightFor(width: 400, height: 700),
        whilePerforming: (tester) async {
          settledKey.currentState!.expand();
          await tester.pumpAndSettle();
          return null;
        },
        builder: () => _MorphGoldenHarness(key: settledKey),
      ),
    );
  });
}

class _MorphGoldenHarness extends StatefulWidget {
  const _MorphGoldenHarness({super.key});

  @override
  State<_MorphGoldenHarness> createState() => _MorphGoldenHarnessState();
}

class _MorphGoldenHarnessState extends State<_MorphGoldenHarness> {
  var _expanded = false;

  void expand() {
    setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F2F4),
      child: Align(
        alignment: _expanded ? Alignment.bottomRight : Alignment.topLeft,
        child: Morph(
          tag: 'golden-container',
          child: Container(
            width: _expanded ? 310 : 190,
            padding: EdgeInsets.all(_expanded ? 28 : 14),
            decoration: BoxDecoration(
              color: _expanded ? const Color(0xFF3057D5) : const Color(0xFFFF4A4B),
              borderRadius: BorderRadius.circular(_expanded ? 36 : 18),
            ),
            child: Text(
              _expanded ? 'Shared elements without application setup.' : 'Tap to expand',
              key: const ValueKey('description'),
              style: TextStyle(
                color: Colors.white,
                fontSize: _expanded ? 24 : 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
