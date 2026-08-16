import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('MorphDescendant golden', () {
    for (final behavior in MorphDescendantFlightBehavior.values) {
      final harnessKey = GlobalKey<_MorphDescendantGoldenHarnessState>();

      unawaited(
        goldenTest(
          'when ${behavior.name} content reaches the flight midpoint, it should match the reference',
          fileName: 'morph_descendant_${behavior.name}',
          constraints: const BoxConstraints.tightFor(width: 400, height: 700),
          whilePerforming: (tester) async {
            harnessKey.currentState!._expand();
            await tester.pump();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 150));

            return tester.pumpAndSettle;
          },
          builder: () => _MorphDescendantGoldenHarness(
            key: harnessKey,
            behavior: behavior,
          ),
        ),
      );
    }

    final atlasHarnessKey = GlobalKey<_MorphDescendantGoldenHarnessState>();
    unawaited(
      goldenTest(
        'when several snapshots share a flight, they should preserve their individual pixels',
        fileName: 'morph_descendant_snapshot_atlas',
        constraints: const BoxConstraints.tightFor(width: 400, height: 700),
        whilePerforming: (tester) async {
          atlasHarnessKey.currentState!._expand();
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          return tester.pumpAndSettle;
        },
        builder: () => _MorphDescendantGoldenHarness(
          key: atlasHarnessKey,
          behavior: MorphDescendantFlightBehavior.snapshot,
          multipleSnapshots: true,
        ),
      ),
    );
  });
}

class _MorphDescendantGoldenHarness extends StatefulWidget {
  const _MorphDescendantGoldenHarness({
    required this.behavior,
    this.multipleSnapshots = false,
    super.key,
  });

  final MorphDescendantFlightBehavior behavior;
  final bool multipleSnapshots;

  @override
  State<_MorphDescendantGoldenHarness> createState() => _MorphDescendantGoldenHarnessState();
}

class _MorphDescendantGoldenHarnessState extends State<_MorphDescendantGoldenHarness> {
  var _expanded = false;

  void _expand() {
    setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final atlasColors = _expanded
        ? const [Color(0xFFFFC857), Color(0xFF44AF69), Color(0xFF7D53DE)]
        : const [Color(0xFFFF8C42), Color(0xFF2F7D32), Color(0xFF4E2A84)];
    return ColoredBox(
      color: const Color(0xFFF1F2F4),
      child: Align(
        alignment: _expanded ? Alignment.bottomRight : Alignment.topLeft,
        child: Morph(
          tag: 'descendant-golden-${widget.behavior.name}',
          child: Container(
            width: _expanded ? 310 : 190,
            height: _expanded ? 220 : 140,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _expanded ? const Color(0xFF3057D5) : const Color(0xFFFF4A4B),
              borderRadius: BorderRadius.circular(_expanded ? 36 : 18),
            ),
            child: widget.multipleSnapshots
                ? Row(
                    children: List<Widget>.generate(
                      atlasColors.length,
                      (index) => Expanded(
                        child: MorphDescendant(
                          key: ValueKey<int>(index),
                          flightBehavior: MorphDescendantFlightBehavior.snapshot,
                          child: SizedBox.expand(
                            child: ColoredBox(color: atlasColors[index]),
                          ),
                        ),
                      ),
                    ),
                  )
                : MorphDescendant(
                    flightBehavior: widget.behavior,
                    child: const ColoredBox(
                      color: Color(0xFFF1F2F4),
                      child: Center(
                        child: Text(
                          'Stateful content',
                          style: TextStyle(
                            color: Color(0xFF202124),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
