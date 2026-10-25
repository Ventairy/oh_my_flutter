import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

void main() {
  test('when a waiting request is cancelled, it should complete with no lease', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final active = await budget.request(bytes: 10, owner: Object()).future;
    final queued = budget.request(bytes: 4, owner: Object())..cancel();
    addTearDown(() => active?.release());
    expect(await queued.future, isNull);
  });

  test('when a queued head is cancelled, it should admit the next request that now fits', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final active = await budget.request(bytes: 6, owner: Object()).future;
    final head = budget.request(bytes: 8, owner: Object());
    final next = budget.request(bytes: 4, owner: Object());
    head.cancel();
    final lease = await next.future;
    addTearDown(() {
      active?.release();
      lease?.release();
    });
    expect([lease?.bytes, budget.activeBytes, budget.pendingCount], [4, 10, 0]);
  });

  test('when an owner is cancelled, it should remove all of its queued reservations', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final active = await budget.request(bytes: 10, owner: Object()).future;
    final owner = Object();
    final first = budget.request(bytes: 8, owner: owner);
    final second = budget.request(bytes: 4, owner: owner);
    budget.cancel(owner);
    addTearDown(() => active?.release());
    expect([await first.future, await second.future, budget.pendingCount], [null, null, 0]);
  });

  test('when different owners compare equal, it should cancel only the identical owner', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final active = await budget.request(bytes: 10, owner: Object()).future;
    final milliseconds = int.parse('1');
    final owner = Duration(milliseconds: milliseconds);
    final first = budget.request(bytes: 8, owner: owner);
    final second = budget.request(bytes: 4, owner: Duration(microseconds: milliseconds * 1000));
    budget.cancel(owner);
    addTearDown(() {
      second.cancel();
      active?.release();
    });
    expect([await first.future, budget.pendingCount], [null, 1]);
  });

  test('when a cancelled request is cancelled again, it should leave other queued work unchanged', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final active = await budget.request(bytes: 10, owner: Object()).future;
    final first = budget.request(bytes: 8, owner: Object());
    final second = budget.request(bytes: 4, owner: Object());
    first
      ..cancel()
      ..cancel();
    addTearDown(() {
      second.cancel();
      active?.release();
    });
    expect(budget.pendingCount, 1);
  });

  test('when a waiting background request is cancelled, it should release its queue entry without affecting active foreground work', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final active = await budget.request(bytes: 6, owner: Object()).future;
    final background = budget.request(bytes: 2, owner: Object(), background: true)..cancel();
    addTearDown(() => active?.release());
    expect([await background.future, budget.activeBytes, budget.activeCount, budget.pendingCount], [null, 6, 1, 0]);
  });

  test(
    'when an owner has queued work at both priorities, it should cancel both without cancelling another owner',
    () async {
      final budget = ContourWorkBudget.test(maxBytes: 10);
      final active = await budget.request(bytes: 10, owner: Object()).future;
      final owner = Object();
      final foreground = budget.request(bytes: 8, owner: owner);
      final background = budget.request(bytes: 4, owner: owner, background: true);
      final other = budget.request(bytes: 2, owner: Object(), background: true);
      budget.cancel(owner);
      addTearDown(() {
        other.cancel();
        active?.release();
      });
      expect([await foreground.future, await background.future, budget.pendingCount], [null, null, 1]);
    },
  );

  test('when the last queued foreground request is cancelled, it should admit background work that now fits beside an active background lease', () async {
    final budget = ContourWorkBudget.test(maxBytes: 10);
    final active = await budget.request(bytes: 8, owner: Object(), background: true).future;
    final foreground = budget.request(bytes: 4, owner: Object());
    final background = budget.request(bytes: 2, owner: Object(), background: true);
    foreground.cancel();
    final lease = await background.future;
    addTearDown(() {
      active?.release();
      lease?.release();
    });
    expect(
      [await foreground.future, lease?.bytes, budget.activeBytes, budget.activeCount, budget.pendingCount],
      [null, 2, 10, 2, 0],
    );
  });
}
