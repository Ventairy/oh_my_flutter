import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';

import 'morph_route_geometry/route_geometry_scene.dart';

void main() {
  late RouteGeometryScene stationary;
  unawaited(
    goldenTest(
      'when a page slides past a shared stationary button, it should keep the button at its settled position',
      fileName: 'morph_route_stationary_button',
      constraints: const BoxConstraints.tightFor(width: 400, height: 700),
      builder: () {
        stationary = RouteGeometryScene();
        return stationary.app;
      },
      whilePerforming: (tester) async {
        stationary.push();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        return () async {
          await tester.pumpAndSettle();
          stationary.dispose();
        };
      },
    ),
  );

  late NestedGeometryScene nested;
  unawaited(
    goldenTest(
      'when a surface and header expand together, it should preserve the nested header trajectory',
      fileName: 'morph_route_nested_expansion',
      constraints: const BoxConstraints.tightFor(width: 400, height: 700),
      builder: () {
        nested = NestedGeometryScene();
        return nested.app;
      },
      whilePerforming: (tester) async {
        nested.push();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        return tester.pumpAndSettle;
      },
    ),
  );
}
