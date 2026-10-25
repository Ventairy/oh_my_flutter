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

  test(
    'when no processing client is attached, it should leave optional worker preparation idle',
    () async {
      await ContourProcessorTestHarness.waitForStop();
      final before = ContourProcessorTestHarness.prepared;
      ContourProcessorTestHarness.prepare();
      expect((before, ContourProcessorTestHarness.prepared), (false, false));
    },
    skip: kIsWeb,
  );

  test(
    'when an attached client requests preparation, it should report preparation before tracing starts',
    () async {
      await ContourProcessorTestHarness.waitForStop();
      final before = ContourProcessorTestHarness.prepared;
      ContourProcessorTestHarness.acquire();
      ContourProcessorTestHarness.prepare();
      final observed = (before, ContourProcessorTestHarness.prepared);
      ContourProcessorTestHarness.release();
      await ContourProcessorTestHarness.waitForStop();
      expect(observed, (false, true));
    },
    skip: kIsWeb,
  );

  test(
    'when proof work waits behind tracing, it should admit verification only after the shared acknowledgement releases',
    () async {
      ContourProcessorTestHarness.acquire();
      final source = await ContourProcessorTestHarness.admission
          .request(width: 16, height: 16, legacyBytes: 1024 * 1024, owner: Object())
          .future;
      final traced = await ContourProcessorTestHarness.trace(coverage(16, 16), 16, 16, lease: source);
      var proofGranted = false;
      final proof = ContourWorkBudget.shared.request(bytes: 1024 * 1024, owner: Object(), background: true).future.then(
        (lease) {
          proofGranted = true;
          return lease;
        },
      );
      await Future<void>.delayed(Duration.zero);
      final before = proofGranted;
      source!.release();
      final proofLease = await proof;
      final verified = await ContourProcessorTestHarness.verifyEmpty();
      proofLease!.release();
      ContourProcessorTestHarness.release();
      await ContourProcessorTestHarness.waitForStop();
      await Future<void>.delayed(Duration.zero);
      expect([traced! > 0, before, verified, ContourWorkBudget.shared.activeBytes], [true, false, true, 0]);
    },
    skip: kIsWeb,
  );
}
