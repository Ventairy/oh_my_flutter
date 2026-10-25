import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List coverage(int width, int height) {
    final pixels = Uint8List(width * height * 4);
    for (var y = 2; y < height - 2; y++) {
      for (var x = 2; x < width - 2; x++) {
        pixels[(y * width + x) * 4 + 3] = 255;
      }
    }
    return pixels;
  }

  Future<void> until(bool Function() ready) async {
    for (var i = 0; i < 1000 && !ready(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    if (!ready()) throw StateError('Lifecycle condition did not become ready.');
  }

  test(
    'when a ready worker exits before its start completes, it should settle the source and release capacity',
    () async {
      final barrier = Completer<void>();
      final exited = Completer<void>();
      final exitsBefore = ContourProcessorTestHarness.exits;
      ContourProcessorTestHarness.afterSpawn = (isolate) async {
        await until(() => ContourProcessorTestHarness.ready);
        isolate.kill();
        await until(() => ContourProcessorTestHarness.exits > exitsBefore);
        exited.complete();
        await barrier.future;
      };
      ContourProcessorTestHarness.acquire();
      final lease = await ContourProcessorTestHarness.admission
          .request(width: 16, height: 16, legacyBytes: 1024 * 1024, owner: Object())
          .future;
      final trace = ContourProcessorTestHarness.trace(
        coverage(16, 16),
        16,
        16,
        lease: lease,
      ).then<int?>((value) => value, onError: (Object error, StackTrace stack) => -1);
      await exited.future;
      barrier.complete();
      final result = await trace.timeout(const Duration(milliseconds: 100), onTimeout: () => -2);
      lease!.release();
      ContourProcessorTestHarness.afterSpawn = null;
      ContourProcessorTestHarness.release();
      await ContourProcessorTestHarness.waitForStop();
      await Future<void>.delayed(Duration.zero);
      expect([result != -2, ContourWorkBudget.shared.activeBytes], [true, 0]);
    },
    skip: kIsWeb,
  );

  test('when a pooled reply awaits consumption, it should hold the native serial slot until acknowledgement', () async {
    ContourProcessorTestHarness.acquire();
    final firstLease = await ContourProcessorTestHarness.admission
        .request(width: 16, height: 16, legacyBytes: 1024 * 1024, owner: Object())
        .future;
    final secondLease = await ContourProcessorTestHarness.admission
        .request(width: 16, height: 16, legacyBytes: 1024 * 1024, owner: Object())
        .future;
    final first = ContourProcessorTestHarness.trace(coverage(16, 16), 16, 16, lease: firstLease);
    var secondFinished = false;
    final second = ContourProcessorTestHarness.trace(coverage(16, 16), 16, 16, lease: secondLease).then((value) {
      secondFinished = true;
      return value;
    });
    final firstResult = await first;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final before = [
      secondFinished,
      ContourProcessorTestHarness.queuedNative,
      ContourProcessorTestHarness.activeNative != null,
    ];
    firstLease!.release();
    final secondResult = await second;
    secondLease!.release();
    ContourProcessorTestHarness.release();
    await ContourProcessorTestHarness.waitForStop();
    await Future<void>.delayed(Duration.zero);
    expect(
      [
        firstResult! > 0,
        before,
        secondResult! > 0,
        ContourWorkBudget.shared.activeBytes,
        ContourProcessorTestHarness.acknowledgements,
      ],
      [
        true,
        [false, 1, true],
        true,
        0,
        0,
      ],
    );
  }, skip: kIsWeb);

  test('when the last client leaves while a worker start waits for the previous exit, it should cancel the trace without an error', () async {
    final barrier = Completer<void>();
    final entered = Completer<void>();
    var hookCalls = 0;
    ContourProcessorTestHarness.afterSpawn = (isolate) async {
      if (hookCalls++ > 0) return;
      entered.complete();
      await barrier.future;
    };
    ContourProcessorTestHarness.acquire();
    ContourProcessorTestHarness.prepare();
    await entered.future;
    ContourProcessorTestHarness.release();
    ContourProcessorTestHarness.acquire();
    final lease = await ContourProcessorTestHarness.admission
        .request(width: 16, height: 16, legacyBytes: 1024 * 1024, owner: Object())
        .future;
    final trace = ContourProcessorTestHarness.trace(coverage(16, 16), 16, 16, lease: lease).then<(int?, String?)>(
      (value) => (value, null),
      onError: (Object error, StackTrace stack) => (null, error.toString()),
    );
    ContourProcessorTestHarness.release();
    final before = (ContourProcessorTestHarness.stopping, ContourWorkBudget.shared.activeBytes > 0);
    barrier.complete();
    final result = await trace;
    lease!.release();
    ContourProcessorTestHarness.afterSpawn = null;
    await ContourProcessorTestHarness.waitForStop();
    await Future<void>.delayed(Duration.zero);
    expect(
      (
        before,
        result,
        ContourWorkBudget.shared.activeBytes,
        ContourProcessorTestHarness.acknowledgements,
        ContourProcessorTestHarness.activeNative,
        ContourProcessorTestHarness.queuedNative,
      ),
      ((true, true), (null, null), 0, 0, null, 0),
    );
  }, skip: kIsWeb);

  test(
    'when a live client encounters a worker startup failure, it should preserve the error and release capacity',
    () async {
      final failure = StateError('controlled worker startup failure');
      ContourProcessorTestHarness.afterSpawn = (isolate) async => throw failure;
      ContourProcessorTestHarness.acquire();
      final lease = await ContourProcessorTestHarness.admission
          .request(width: 16, height: 16, legacyBytes: 1024 * 1024, owner: Object())
          .future;
      final result = await ContourProcessorTestHarness.trace(
        coverage(16, 16),
        16,
        16,
        lease: lease,
      ).then<Object?>((value) => value, onError: (Object error, StackTrace stack) => error);
      lease!.release();
      ContourProcessorTestHarness.afterSpawn = null;
      ContourProcessorTestHarness.release();
      await ContourProcessorTestHarness.waitForStop();
      await Future<void>.delayed(Duration.zero);
      expect(
        (
          identical(result, failure),
          ContourWorkBudget.shared.activeBytes,
          ContourProcessorTestHarness.acknowledgements,
        ),
        (true, 0, 0),
      );
    },
    skip: kIsWeb,
  );

  test('when the last client detaches during spawn, it should retain scratch until exit before a new generation dispatches', () async {
    final barrier = Completer<void>();
    final entered = Completer<void>();
    var hookCalls = 0;
    ContourProcessorTestHarness.afterSpawn = (isolate) async {
      if (hookCalls++ > 0) return;
      entered.complete();
      await barrier.future;
    };
    ContourProcessorTestHarness.acquire();
    final firstLease = await ContourProcessorTestHarness.admission
        .request(width: 16, height: 16, legacyBytes: 1024 * 1024, owner: Object())
        .future;
    final first = ContourProcessorTestHarness.trace(coverage(16, 16), 16, 16, lease: firstLease);
    await entered.future;
    final startsBefore = ContourProcessorTestHarness.starts;
    ContourProcessorTestHarness.release();
    ContourProcessorTestHarness.acquire();
    final secondLease = await ContourProcessorTestHarness.admission
        .request(width: 16, height: 16, legacyBytes: 1024 * 1024, owner: Object())
        .future;
    final second = ContourProcessorTestHarness.trace(coverage(16, 16), 16, 16, lease: secondLease);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final before = [
      ContourProcessorTestHarness.starts == startsBefore,
      ContourProcessorTestHarness.stopping,
      ContourWorkBudget.shared.activeBytes > 0,
    ];
    barrier.complete();
    final firstResult = await first;
    firstLease!.release();
    final secondResult = await second;
    secondLease!.release();
    ContourProcessorTestHarness.afterSpawn = null;
    ContourProcessorTestHarness.release();
    await ContourProcessorTestHarness.waitForStop();
    await Future<void>.delayed(Duration.zero);
    expect(
      [
        before,
        firstResult,
        secondResult! > 0,
        ContourWorkBudget.shared.activeBytes,
        ContourProcessorTestHarness.acknowledgements,
      ],
      [
        [true, true, true],
        null,
        true,
        0,
        0,
      ],
    );
  }, skip: kIsWeb);
}
