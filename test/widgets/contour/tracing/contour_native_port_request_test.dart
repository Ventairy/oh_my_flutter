@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_request.dart';

void main() {
  test('when a copied result arrives before retirement, it should keep the caller pending', () async {
    var completed = false;
    final request = ContourNativePortRequest(
      ticket: 1,
      onComplete: (_) => completed = true,
    );
    addTearDown(request.completeAfterCloseAck);
    request.sendPort.send([
      1,
      0,
      Uint32List.fromList([2]),
      Float64List.fromList([1, 2]),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect((completed, request.isFinished), (false, false));
  });

  test('when retirement arrives before a copied result, it should keep the caller pending', () async {
    var completed = false;
    final request = ContourNativePortRequest(
      ticket: 2,
      onComplete: (_) => completed = true,
    );
    addTearDown(request.completeAfterCloseAck);
    request.sendPort.send([2, 6]);
    await Future<void>.delayed(Duration.zero);
    expect((completed, request.isFinished), (false, false));
  });

  test('when both reply events arrive, it should release ownership before returning geometry', () async {
    var completionCount = 0;
    final request = ContourNativePortRequest(
      ticket: 3,
      onComplete: (_) => completionCount++,
    );
    addTearDown(request.completeAfterCloseAck);
    request.sendPort
      ..send([3, 6])
      ..send([
        3,
        0,
        Uint32List.fromList([2]),
        Float64List.fromList([4, 5]),
      ]);
    final result = await request.future;
    expect(
      [completionCount, request.isFinished, result?.contours.single.toList()],
      [
        1,
        true,
        [4.0, 5.0],
      ],
    );
  });

  test('when a different ticket arrives, it should ignore its result and retirement', () async {
    final request = ContourNativePortRequest(ticket: 4, onComplete: (_) {});
    addTearDown(request.completeAfterCloseAck);
    request.sendPort
      ..send([99, 0, Uint32List(0), Float64List(0)])
      ..send([99, 6]);
    await Future<void>.delayed(Duration.zero);
    expect(request.isFinished, isFalse);
  });

  test('when close cleanup is acknowledged, it should complete pending geometry with null once', () async {
    var completionCount = 0;
    final request =
        ContourNativePortRequest(
            ticket: 5,
            onComplete: (_) => completionCount++,
          )
          ..completeAfterCloseAck()
          ..completeAfterCloseAck();
    expect(
      (await request.future, completionCount, request.isFinished),
      (null, 1, true),
    );
  });

  test(
    'when atomic admission rejects a request, it should release its reply port',
    () {
      var completionCount = 0;
      final request = ContourNativePortRequest(
        ticket: 6,
        onComplete: (_) => completionCount++,
      )..discardUnposted();
      expect((completionCount, request.isFinished), (0, true));
    },
  );

  test('when malformed geometry arrives before retirement, it should defer its error until retirement', () async {
    var decodingFailed = false;
    final request = ContourNativePortRequest(
      ticket: 7,
      onComplete: (error) => decodingFailed = error != null,
    );
    addTearDown(request.completeAfterCloseAck);
    final outcome = request.future.then<Object?>(
      (value) => value,
      onError: (Object error) => error,
    );
    request.sendPort.send([
      7,
      0,
      Uint32List.fromList([3]),
      Float64List(2),
    ]);
    await Future<void>.delayed(Duration.zero);
    final finishedBeforeRetirement = request.isFinished;
    request.sendPort.send([7, 6]);
    expect(
      (
        finishedBeforeRetirement,
        await outcome is FormatException,
        decodingFailed,
      ),
      (false, true, true),
    );
  });

  test('when native reply types are malformed, it should release the caller with an error after retirement', () async {
    var decodingFailed = false;
    final request = ContourNativePortRequest(
      ticket: 8,
      onComplete: (error) => decodingFailed = error != null,
    );
    addTearDown(request.completeAfterCloseAck);
    final outcome = request.future.then<Object?>(
      (value) => value,
      onError: (Object error) => error,
    );
    request.sendPort
      ..send([8, 0, <int>[], Float64List(0)])
      ..send([8, 6]);
    expect(
      (await outcome is FormatException, request.isFinished, decodingFailed),
      (true, true, true),
    );
  });
}
