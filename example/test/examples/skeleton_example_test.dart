import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter_example/examples/skeleton_example.dart';

void main() {
  testWidgets(
    'when the Skeleton example builds, it should use the shimmer treatment',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SkeletonExample())),
      );

      final skeleton = tester.widget<Skeleton>(find.byType(Skeleton));
      expect(skeleton.style.effect, isA<SkeletonShimmerEffect>());
    },
  );
}
