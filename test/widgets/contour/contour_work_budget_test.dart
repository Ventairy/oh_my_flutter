import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

void main() {
  test('when a production budget is created, it should allow 64 MiB of concurrent reservations', () {
    expect(ContourWorkBudget().maxBytes, 64 * 1024 * 1024);
  });

  test('when a budget starts, it should have no work or retained reservations', () {
    final budget = ContourWorkBudget.test(maxBytes: 12);
    expect([budget.activeBytes, budget.peakBytes, budget.activeCount, budget.pendingCount], [0, 0, 0, 0]);
  });

  test('when three small requests fit together, it should admit them in parallel', () async {
    final budget = ContourWorkBudget.test(maxBytes: 12);
    final leases = await Future.wait([
      for (var index = 0; index < 3; index++) budget.request(bytes: 4, owner: Object()).future,
    ]);
    addTearDown(() {
      for (final lease in leases) {
        lease?.release();
      }
    });
    expect([budget.activeBytes, budget.activeCount, budget.pendingCount], [12, 3, 0]);
  });

  test('when a large request heads the queue, it should prevent smaller later requests from overtaking it', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final first = await budget.request(bytes: 6, owner: Object()).future;
    final large = budget.request(bytes: 8, owner: Object());
    final small = budget.request(bytes: 2, owner: Object());
    addTearDown(() {
      large.cancel();
      small.cancel();
      first?.release();
    });
    expect([budget.activeBytes, budget.activeCount, budget.pendingCount], [6, 1, 2]);
  });

  test('when earlier large work releases its lease, it should admit the next large request first', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final first = await budget.request(bytes: 8, owner: Object()).future;
    final second = budget.request(bytes: 8, owner: Object());
    final third = budget.request(bytes: 8, owner: Object());
    first!.release();
    final lease = await second.future;
    addTearDown(() {
      third.cancel();
      lease?.release();
    });
    expect([lease?.bytes, budget.activeBytes, budget.activeCount, budget.pendingCount], [8, 8, 1, 1]);
  });

  test('when a queue drains across several releases, it should never exceed its byte capacity', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final requests = [
      for (final bytes in [4, 3, 3, 8, 2, 7, 3]) budget.request(bytes: bytes, owner: Object()),
    ];
    for (final request in requests) {
      (await request.future)!.release();
    }
    expect(budget.peakBytes, lessThanOrEqualTo(budget.maxBytes));
  });

  test('when a request exceeds the whole capacity, it should complete without blocking later work', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final oversized = await budget.request(bytes: 11, owner: Object()).future;
    final lease = await budget.request(bytes: 10, owner: Object()).future;
    addTearDown(() => lease?.release());
    expect([oversized, lease?.bytes, budget.activeBytes, budget.pendingCount], [null, 10, 10, 0]);
  });

  test('when every admitted job finishes, it should return its active and queued accounting to zero', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final requests = [
      for (final bytes in [7, 4, 6, 10]) budget.request(bytes: bytes, owner: Object()),
    ];
    for (final request in requests) {
      (await request.future)!.release();
    }
    expect([budget.activeBytes, budget.activeCount, budget.pendingCount], [0, 0, 0]);
  });

  test('when foreground work is active, it should keep fitting background work queued', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final active = await budget.request(bytes: 6, owner: Object()).future;
    final background = budget.request(bytes: 2, owner: Object(), background: true);
    addTearDown(() {
      background.cancel();
      active?.release();
    });
    expect([budget.activeBytes, budget.activeCount, budget.pendingCount], [6, 1, 1]);
  });

  test(
    'when later foreground work queues behind background work, it should overtake it in foreground arrival order',
    () async {
      final budget = ContourWorkBudget.test(maxBytes: 10);
      final active = await budget.request(bytes: 6, owner: Object()).future;
      final background = budget.request(bytes: 4, owner: Object(), background: true);
      final large = budget.request(bytes: 8, owner: Object());
      final small = budget.request(bytes: 2, owner: Object());
      active!.release();
      final largeLease = await large.future;
      final smallLease = await small.future;
      addTearDown(() {
        background.cancel();
        largeLease?.release();
        smallLease?.release();
      });
      expect(
        [largeLease?.bytes, smallLease?.bytes, budget.activeBytes, budget.activeCount, budget.pendingCount],
        [8, 2, 10, 2, 1],
      );
    },
  );

  test('when parallel foreground leases finish separately, it should admit background work only after the last lease releases', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final first = await budget.request(bytes: 4, owner: Object()).future;
    final second = await budget.request(bytes: 4, owner: Object()).future;
    final background = budget.request(bytes: 2, owner: Object(), background: true);
    first!.release();
    final beforeLastRelease = [budget.activeBytes, budget.activeCount, budget.pendingCount];
    second!.release();
    final backgroundLease = await background.future;
    addTearDown(() => backgroundLease?.release());
    expect(
      [beforeLastRelease, backgroundLease?.bytes, budget.activeBytes, budget.activeCount, budget.pendingCount],
      [
        [4, 1, 1],
        2,
        2,
        1,
        0,
      ],
    );
  });

  test('when only background work waits, it should retain arrival order without exceeding capacity', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final foreground = await budget.request(bytes: 1, owner: Object()).future;
    final first = budget.request(bytes: 8, owner: Object(), background: true);
    final second = budget.request(bytes: 4, owner: Object(), background: true);
    final third = budget.request(bytes: 2, owner: Object(), background: true);
    foreground!.release();
    final firstLease = await first.future;
    final firstAdmission = [budget.activeBytes, budget.activeCount, budget.pendingCount];
    firstLease!.release();
    final secondLease = await second.future;
    final thirdLease = await third.future;
    final finalAdmission = [budget.activeBytes, budget.activeCount, budget.pendingCount];
    secondLease!.release();
    thirdLease!.release();
    expect(
      [firstAdmission, finalAdmission, budget.peakBytes, budget.activeBytes, budget.activeCount, budget.pendingCount],
      [
        [8, 1, 2],
        [6, 2, 0],
        8,
        0,
        0,
        0,
      ],
    );
  });

  test('when foreground work arrives during active background work, it should preserve the background lease and block later background work', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final active = await budget.request(bytes: 8, owner: Object(), background: true).future;
    final foreground = budget.request(bytes: 4, owner: Object());
    final background = budget.request(bytes: 2, owner: Object(), background: true);
    final beforeRelease = [budget.activeBytes, budget.activeCount, budget.pendingCount];
    active!.release();
    final foregroundLease = await foreground.future;
    final foregroundAdmission = [budget.activeBytes, budget.activeCount, budget.pendingCount];
    foregroundLease!.release();
    final backgroundLease = await background.future;
    backgroundLease!.release();
    expect(
      [
        beforeRelease,
        foregroundAdmission,
        budget.peakBytes,
        budget.activeBytes,
        budget.activeCount,
        budget.pendingCount,
      ],
      [
        [8, 1, 2],
        [4, 1, 1],
        8,
        0,
        0,
        0,
      ],
    );
  });
}
