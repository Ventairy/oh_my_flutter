import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/group/group.dart' show GroupCaptureAccess;

void main() {
  testWidgets(
    'when cross-branch transforms include perspective, it should match '
    'Flutter geometry and revision',
    (tester) async {
      final link = GroupLink();
      final reference = GlobalKey();
      final member = GlobalKey();
      final referenceTransform = Matrix4.identity()
        ..translateByDouble(21, 13, 0, 1)
        ..rotateZ(.19)
        ..scaleByDouble(1.12, .83, 1, 1);
      final memberOuterTransform = Matrix4.identity()
        ..translateByDouble(17, 9, 0, 1)
        ..rotateZ(-.31)
        ..scaleByDouble(.91, 1.24, 1, 1);
      final memberPerspectiveTransform = Matrix4.identity()
        ..setEntry(3, 2, .002)
        ..rotateY(.27)
        ..rotateZ(.14);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 400,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 24,
                  top: 18,
                  child: Transform(
                    alignment: Alignment.topLeft,
                    transform: referenceTransform,
                    child: SizedBox(
                      key: reference,
                      width: 180,
                      height: 160,
                    ),
                  ),
                ),
                Positioned(
                  left: 126,
                  top: 92,
                  child: Transform(
                    alignment: Alignment.topLeft,
                    transform: memberOuterTransform,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: memberPerspectiveTransform,
                      child: Group(
                        key: member,
                        link: link,
                        child: const SizedBox(width: 42, height: 28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
      final memberBox = member.currentContext!.findRenderObject()! as RenderBox;
      final expectedBounds = _frameworkBounds(referenceBox, [memberBox])!;
      final measuredBounds = link.measure(relativeTo: reference.currentContext!)!;
      final capture = GroupCaptureAccess.captureWithRevision(
        link,
        relativeTo: referenceBox,
        pixelRatio: 1,
      )!;

      expect(_largestRectDifference(measuredBounds, expectedBounds), lessThan(.000001));
      expect(_largestRectDifference(capture.snapshot.bounds, expectedBounds), lessThan(.000001));
      expect(capture.revision, GroupCaptureAccess.revision(link, referenceBox));
      capture.snapshot.dispose();
    },
  );

  testWidgets(
    'when transformed members descend from the reference, it should match '
    'Flutter geometry and revision',
    (tester) async {
      final link = GroupLink();
      final reference = GlobalKey();
      final firstMember = GlobalKey();
      final secondMember = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            key: reference,
            width: 240,
            height: 180,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 18,
                  top: 24,
                  child: Transform.rotate(
                    angle: .21,
                    alignment: Alignment.topLeft,
                    child: Group(
                      key: firstMember,
                      link: link,
                      child: const SizedBox(width: 32, height: 18),
                    ),
                  ),
                ),
                Positioned(
                  left: 142,
                  top: 96,
                  child: Transform.scale(
                    scaleX: 1.3,
                    scaleY: .7,
                    alignment: Alignment.bottomRight,
                    child: Group(
                      key: secondMember,
                      link: link,
                      child: const SizedBox(width: 26, height: 34),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
      final memberBoxes = [
        firstMember.currentContext!.findRenderObject()! as RenderBox,
        secondMember.currentContext!.findRenderObject()! as RenderBox,
      ];
      final expectedBounds = _frameworkBounds(referenceBox, memberBoxes)!;
      final capture = GroupCaptureAccess.captureWithRevision(
        link,
        relativeTo: referenceBox,
        pixelRatio: 1,
      )!;

      expect(_largestRectDifference(capture.snapshot.bounds, expectedBounds), lessThan(.000001));
      expect(capture.revision, GroupCaptureAccess.revision(link, referenceBox));
      capture.snapshot.dispose();
    },
  );

  testWidgets(
    'when a member is the reference, it should use identity geometry',
    (tester) async {
      final link = GroupLink();
      final reference = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Group(
              key: reference,
              link: link,
              child: const SizedBox(width: 37, height: 19),
            ),
          ),
        ),
      );
      final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
      final capture = GroupCaptureAccess.captureWithRevision(
        link,
        relativeTo: referenceBox,
        pixelRatio: 1,
      )!;

      expect(
        (
          measuredBounds: link.measure(relativeTo: reference.currentContext!),
          capturedBounds: capture.snapshot.bounds,
          capturedRevision: capture.revision,
        ),
        (
          measuredBounds: const Rect.fromLTWH(0, 0, 37, 19),
          capturedBounds: const Rect.fromLTWH(0, 0, 37, 19),
          capturedRevision: GroupCaptureAccess.revision(link, referenceBox),
        ),
      );
      capture.snapshot.dispose();
    },
  );

  testWidgets(
    'when a singular transform is above the reference, it should keep '
    'descendant geometry available',
    (tester) async {
      final link = GroupLink();
      final reference = GlobalKey();
      final member = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Transform.scale(
            scaleX: 0,
            scaleY: 1,
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: reference,
              width: 100,
              height: 80,
              child: Stack(
                children: [
                  Positioned(
                    left: 23,
                    top: 17,
                    child: Group(
                      key: member,
                      link: link,
                      child: const SizedBox(width: 31, height: 29),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
      final memberBox = member.currentContext!.findRenderObject()! as RenderBox;
      final expectedBounds = _directFrameworkBounds(referenceBox, [memberBox]);

      expect(
        (
          expectedBounds: expectedBounds,
          measuredBounds: link.measure(relativeTo: reference.currentContext!),
          hasRevision: GroupCaptureAccess.revision(link, referenceBox) != null,
        ),
        (
          expectedBounds: const Rect.fromLTWH(23, 17, 31, 29),
          measuredBounds: const Rect.fromLTWH(23, 17, 31, 29),
          hasRevision: true,
        ),
      );
    },
  );

  testWidgets(
    'when a cross-branch reference transform is singular, it should return '
    'unavailable geometry and capture',
    (tester) async {
      final link = GroupLink();
      final reference = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: [
                Transform.scale(
                  scaleX: 0,
                  scaleY: 1,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    key: reference,
                    width: 100,
                    height: 100,
                  ),
                ),
                Positioned(
                  left: 120,
                  top: 40,
                  child: Group(
                    link: link,
                    child: const SizedBox.square(dimension: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;

      expect(
        (
          bounds: link.measure(relativeTo: reference.currentContext!),
          revision: GroupCaptureAccess.revision(link, referenceBox),
          capture: GroupCaptureAccess.captureWithRevision(
            link,
            relativeTo: referenceBox,
            pixelRatio: 1,
          ),
        ),
        (bounds: null, revision: null, capture: null),
      );
    },
  );

  testWidgets('when a scrollable moves a member, it should match Flutter transform geometry', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final link = GroupLink();
    final reference = GlobalKey();
    final member = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: reference,
          width: 200,
          height: 160,
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 70),
              Align(
                alignment: Alignment.centerLeft,
                child: Group(
                  key: member,
                  link: link,
                  child: const SizedBox(width: 36, height: 24),
                ),
              ),
              const SizedBox(height: 300),
            ],
          ),
        ),
      ),
    );
    final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
    final memberBox = member.currentContext!.findRenderObject()! as RenderBox;
    final initialRevision = GroupCaptureAccess.revision(link, referenceBox);

    controller.jumpTo(31);
    await tester.pump();
    final expectedBounds = _frameworkBounds(referenceBox, [memberBox])!;
    final measuredBounds = link.measure(relativeTo: reference.currentContext!)!;

    expect(_largestRectDifference(measuredBounds, expectedBounds), lessThan(.000001));
    expect(GroupCaptureAccess.revision(link, referenceBox), isNot(initialRevision));
  });

  testWidgets('when a member repaints, it should change the inspected revision', (tester) async {
    final color = ValueNotifier(const Color(0xffff0000));
    addTearDown(color.dispose);
    final link = GroupLink();
    final reference = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: reference,
          width: 40,
          height: 40,
          child: ValueListenableBuilder(
            valueListenable: color,
            builder: (context, value, child) => Group(
              link: link,
              child: ColoredBox(color: value),
            ),
          ),
        ),
      ),
    );
    final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
    final before = GroupCaptureAccess.revision(link, referenceBox);

    color.value = const Color(0xff0000ff);
    await tester.pump();

    expect(GroupCaptureAccess.revision(link, referenceBox), isNot(before));
  });

  testWidgets('when a member changes size, it should change the inspected revision', (tester) async {
    final size = ValueNotifier<double>(10);
    addTearDown(size.dispose);
    final link = GroupLink();
    final reference = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: reference,
          width: 40,
          height: 40,
          child: Align(
            alignment: Alignment.topLeft,
            child: ValueListenableBuilder(
              valueListenable: size,
              builder: (context, value, child) => Group(
                link: link,
                child: SizedBox.square(dimension: value),
              ),
            ),
          ),
        ),
      ),
    );
    final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
    final before = GroupCaptureAccess.revision(link, referenceBox);

    size.value = 20;
    await tester.pump();

    expect(GroupCaptureAccess.revision(link, referenceBox), isNot(before));
  });

  testWidgets('when z-order changes after inspection, it should reorder the captured members', (tester) async {
    final redZIndex = ValueNotifier<double>(0);
    addTearDown(redZIndex.dispose);
    final link = GroupLink();
    final reference = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: reference,
          width: 20,
          height: 20,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder(
                valueListenable: redZIndex,
                builder: (context, value, child) => Group(
                  link: link,
                  zIndex: value,
                  child: child,
                ),
                child: const ColoredBox(color: Color(0xffff0000)),
              ),
              Group(
                link: link,
                zIndex: 1,
                child: const ColoredBox(color: Color(0xff0000ff)),
              ),
            ],
          ),
        ),
      ),
    );
    final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
    GroupCaptureAccess.revision(link, referenceBox);

    redZIndex.value = 2;
    await tester.pump();
    final capture = GroupCaptureAccess.captureWithRevision(
      link,
      relativeTo: referenceBox,
      pixelRatio: 1,
    )!;
    final image = await tester.runAsync(capture.snapshot.toImage);
    final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    final firstPixel = bytes!.buffer.asUint8List(bytes.offsetInBytes, 4).toList();

    expect(
      (
        firstPixel: (firstPixel[0], firstPixel[1], firstPixel[2], firstPixel[3]),
        captureRevision: capture.revision,
      ),
      (
        firstPixel: (255, 0, 0, 255),
        captureRevision: GroupCaptureAccess.revision(link, referenceBox),
      ),
    );
    image!.dispose();
    capture.snapshot.dispose();
  });

  testWidgets('when a member ancestor transforms, it should change the inspected revision', (tester) async {
    final offset = ValueNotifier(Offset.zero);
    addTearDown(offset.dispose);
    final link = GroupLink();
    final reference = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: reference,
          width: 100,
          height: 100,
          child: ValueListenableBuilder(
            valueListenable: offset,
            builder: (context, value, child) => Transform.translate(
              offset: value,
              child: Align(
                alignment: Alignment.topLeft,
                child: Group(
                  link: link,
                  child: const SizedBox.square(dimension: 10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
    final before = GroupCaptureAccess.revision(link, referenceBox);

    offset.value = const Offset(10, 15);
    await tester.pump();

    expect(GroupCaptureAccess.revision(link, referenceBox), isNot(before));
  });

  testWidgets('when content transforms inside a member, it should change the inspected revision', (tester) async {
    final offset = ValueNotifier(Offset.zero);
    addTearDown(offset.dispose);
    final link = GroupLink();
    final reference = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: reference,
          width: 40,
          height: 40,
          child: Group(
            link: link,
            child: ValueListenableBuilder(
              valueListenable: offset,
              builder: (context, value, child) => Transform.translate(
                offset: value,
                child: child,
              ),
              child: const ColoredBox(color: Color(0xffff0000)),
            ),
          ),
        ),
      ),
    );
    final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
    final before = GroupCaptureAccess.revision(link, referenceBox);

    offset.value = const Offset(5, 5);
    await tester.pump();

    expect(GroupCaptureAccess.revision(link, referenceBox), isNot(before));
  });

  testWidgets('when same-link members are nested, it should inspect the captured member revision', (tester) async {
    final link = GroupLink();
    final reference = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: reference,
          width: 20,
          height: 20,
          child: Group(
            link: link,
            child: Group(
              link: link,
              zIndex: 1,
              child: const ColoredBox(color: Color(0x80ff0000)),
            ),
          ),
        ),
      ),
    );
    final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
    final capture = GroupCaptureAccess.captureWithRevision(
      link,
      relativeTo: referenceBox,
      pixelRatio: 1,
    )!;
    final image = await tester.runAsync(capture.snapshot.toImage);
    final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));

    expect(
      (capture.revision, bytes!.getUint8(3)),
      (GroupCaptureAccess.revision(link, referenceBox), 128),
    );
    image!.dispose();
    capture.snapshot.dispose();
  });

  testWidgets('when a member detaches and reparents, it should refresh order and geometry', (tester) async {
    final placement = ValueNotifier((attached: true, right: false));
    addTearDown(placement.dispose);
    final link = GroupLink();
    final reference = GlobalKey();
    final movingMember = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: reference,
          width: 100,
          height: 100,
          child: Stack(
            children: [
              Row(
                children: [
                  for (final right in [false, true])
                    SizedBox(
                      width: 50,
                      height: 100,
                      child: ValueListenableBuilder(
                        valueListenable: placement,
                        builder: (context, value, child) => Stack(
                          children: [
                            if (value.attached && value.right == right)
                              Group(
                                key: movingMember,
                                link: link,
                                child: const SizedBox.square(dimension: 10),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Positioned(
                left: 20,
                top: 40,
                child: Group(
                  link: link,
                  child: const SizedBox.square(dimension: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final referenceBox = reference.currentContext!.findRenderObject()! as RenderBox;
    final initialRevision = GroupCaptureAccess.revision(link, referenceBox);

    placement.value = (attached: false, right: false);
    await tester.pump();
    final detachedRevision = GroupCaptureAccess.revision(link, referenceBox);
    final detachedBounds = link.measure(relativeTo: reference.currentContext!);

    placement.value = (attached: true, right: true);
    await tester.pump();
    final reattachedRevision = GroupCaptureAccess.revision(link, referenceBox);
    final reattachedBounds = link.measure(relativeTo: reference.currentContext!);

    placement.value = (attached: true, right: false);
    await tester.pump();
    final reparentedRevision = GroupCaptureAccess.revision(link, referenceBox);
    final reparentedBounds = link.measure(relativeTo: reference.currentContext!);
    final capture = GroupCaptureAccess.captureWithRevision(
      link,
      relativeTo: referenceBox,
      pixelRatio: 1,
    )!;

    expect(
      (
        initialChanged: initialRevision != detachedRevision,
        detachedBounds: detachedBounds,
        reattachedChanged: detachedRevision != reattachedRevision,
        reattachedBounds: reattachedBounds,
        reparentedChanged: reattachedRevision != reparentedRevision,
        reparentedBounds: reparentedBounds,
        capturedRevision: capture.revision,
      ),
      (
        initialChanged: true,
        detachedBounds: const Rect.fromLTWH(20, 40, 10, 10),
        reattachedChanged: true,
        reattachedBounds: const Rect.fromLTWH(20, 0, 40, 50),
        reparentedChanged: true,
        reparentedBounds: const Rect.fromLTWH(0, 0, 30, 50),
        capturedRevision: reparentedRevision,
      ),
    );
    capture.snapshot.dispose();
  });
}

Rect? _frameworkBounds(RenderBox reference, Iterable<RenderBox> members) {
  final referenceInverse = Matrix4.tryInvert(reference.getTransformTo(null));
  if (referenceInverse == null) return null;
  Rect? bounds;
  for (final member in members) {
    final transform = Matrix4.copy(referenceInverse)..multiply(member.getTransformTo(null));
    final memberBounds = MatrixUtils.transformRect(transform, member.paintBounds);
    if (!memberBounds.isFinite) return null;
    bounds = bounds?.expandToInclude(memberBounds) ?? memberBounds;
  }
  return bounds;
}

Rect? _directFrameworkBounds(
  RenderBox reference,
  Iterable<RenderBox> members,
) {
  Rect? bounds;
  for (final member in members) {
    final memberBounds = MatrixUtils.transformRect(
      member.getTransformTo(reference),
      member.paintBounds,
    );
    if (!memberBounds.isFinite) return null;
    bounds = bounds?.expandToInclude(memberBounds) ?? memberBounds;
  }
  return bounds;
}

double _largestRectDifference(Rect first, Rect second) {
  var largestDifference = 0.0;
  for (final difference in [
    (first.left - second.left).abs(),
    (first.top - second.top).abs(),
    (first.right - second.right).abs(),
    (first.bottom - second.bottom).abs(),
  ]) {
    if (difference > largestDifference) largestDifference = difference;
  }
  return largestDifference;
}
