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
      await Future<void>.delayed(Duration.zero);
    }
    if (!ready()) throw StateError('Web lifecycle condition did not become ready.');
  }

  test('when a web reply awaits consumption, it should keep later tracing behind its acknowledgement', () async {
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
    await Future<void>.delayed(Duration.zero);
    final before = [
      secondFinished,
      ContourProcessorTestHarness.webQueuedBytes > 0,
      ContourProcessorTestHarness.admission.activeScratchBytes > 0,
    ];
    firstLease!.release();
    final secondResult = await second;
    secondLease!.release();
    ContourProcessorTestHarness.release();
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
        [false, true, true],
        true,
        0,
        0,
      ],
    );
  }, skip: !kIsWeb);

  test(
    'when a yielding web owner detaches, it should keep active scratch until cleanup and serialize a new owner',
    () async {
      ContourProcessorTestHarness.acquire();
      final firstLease = await ContourProcessorTestHarness.admission
          .request(width: 512, height: 512, legacyBytes: 32 * 1024 * 1024, owner: Object())
          .future;
      final secondLease = await ContourProcessorTestHarness.admission
          .request(width: 16, height: 16, legacyBytes: 1024 * 1024, owner: Object())
          .future;
      final first = ContourProcessorTestHarness.trace(coverage(512, 512), 512, 512, lease: firstLease);
      final second = ContourProcessorTestHarness.trace(coverage(16, 16), 16, 16, lease: secondLease);
      await until(() => ContourProcessorTestHarness.webActive == 1 && ContourProcessorTestHarness.webQueuedBytes > 0);
      ContourProcessorTestHarness.release();
      final before = [
        ContourProcessorTestHarness.webActive,
        ContourProcessorTestHarness.admission.activeScratchBytes > 0,
      ];
      final secondResult = await second;
      secondLease!.release();
      ContourProcessorTestHarness.acquire();
      final thirdLease = await ContourProcessorTestHarness.admission
          .request(width: 16, height: 16, legacyBytes: 1024 * 1024, owner: Object())
          .future;
      var thirdFinished = false;
      final third = ContourProcessorTestHarness.trace(coverage(16, 16), 16, 16, lease: thirdLease).then((value) {
        thirdFinished = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      final remainedSerial = !thirdFinished;
      final firstResult = await first;
      firstLease!.release();
      final thirdResult = await third;
      thirdLease!.release();
      ContourProcessorTestHarness.release();
      await Future<void>.delayed(Duration.zero);
      expect(
        [
          before,
          remainedSerial,
          firstResult,
          secondResult,
          thirdResult! > 0,
          ContourProcessorTestHarness.webActive,
          ContourProcessorTestHarness.webQueuedBytes,
          ContourProcessorTestHarness.acknowledgements,
          ContourWorkBudget.shared.activeBytes,
        ],
        [
          [1, true],
          true,
          null,
          null,
          true,
          0,
          0,
          0,
          0,
        ],
      );
    },
    skip: !kIsWeb,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
