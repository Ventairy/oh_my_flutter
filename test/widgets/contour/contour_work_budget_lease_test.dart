import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

void main() {
  test('when a lease is released repeatedly, it should return its bytes only once', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final lease = await budget.request(bytes: 7, owner: Object()).future;
    lease!
      ..release()
      ..release();
    expect([budget.activeBytes, budget.activeCount], [0, 0]);
  });

  test('when an active request is cancelled, it should keep its bytes reserved until its lease releases', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final request = budget.request(bytes: 7, owner: Object());
    final lease = await request.future;
    request.cancel();
    addTearDown(() => lease?.release());
    expect([budget.activeBytes, budget.activeCount], [7, 1]);
  });

  test('when an active owner is cancelled, it should keep its bytes reserved until its lease releases', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final owner = Object();
    final lease = await budget.request(bytes: 7, owner: owner).future;
    budget.cancel(owner);
    addTearDown(() => lease?.release());
    expect([budget.activeBytes, budget.activeCount], [7, 1]);
  });

  test('when a background lease is released repeatedly, it should return its bytes only once', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final lease = await budget.request(bytes: 7, owner: Object(), background: true).future;
    lease!
      ..release()
      ..release();
    expect([budget.activeBytes, budget.activeCount], [0, 0]);
  });

  test(
    'when an active background request is cancelled, it should keep its bytes until the background lease releases',
    () async {
      final budget = ContourWorkBudget.test(maxBytes: 10);
      final request = budget.request(bytes: 7, owner: Object(), background: true);
      final lease = await request.future;
      request.cancel();
      addTearDown(() => lease?.release());
      expect([budget.activeBytes, budget.activeCount], [7, 1]);
    },
  );

  test(
    'when a background lease releases beside active foreground work, it should keep later background work waiting',
    () async {
      final budget = ContourWorkBudget.test(maxBytes: 10);
      final background = await budget.request(bytes: 4, owner: Object(), background: true).future;
      final foreground = await budget.request(bytes: 4, owner: Object()).future;
      final waiting = budget.request(bytes: 2, owner: Object(), background: true);
      background!.release();
      addTearDown(() {
        waiting.cancel();
        foreground?.release();
      });
      expect([budget.activeBytes, budget.activeCount, budget.pendingCount], [4, 1, 1]);
    },
  );

  test('when the last foreground lease releases beside background work, it should admit another fitting background request', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final background = await budget.request(bytes: 4, owner: Object(), background: true).future;
    final foreground = await budget.request(bytes: 4, owner: Object()).future;
    final waiting = budget.request(bytes: 2, owner: Object(), background: true);
    foreground!.release();
    final lease = await waiting.future;
    addTearDown(() {
      background?.release();
      lease?.release();
    });
    expect([lease?.bytes, budget.activeBytes, budget.activeCount, budget.pendingCount], [2, 6, 2, 0]);
  });
}
