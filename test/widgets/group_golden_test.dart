import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'group/_group_golden_harness.dart';
part 'group/_group_golden_painter.dart';

void main() {
  final key = GlobalKey<_GroupGoldenHarnessState>();
  unawaited(
    goldenTest(
      'when group snapshot order differs from widget order, it should preserve both compositions',
      fileName: 'group_snapshot_order',
      constraints: const BoxConstraints.tightFor(width: 160, height: 220),
      builder: () => _GroupGoldenHarness(key: key),
      whilePerforming: (tester) async {
        await key.currentState!.capture();
        await tester.pump();
        return () async {};
      },
    ),
  );
}
