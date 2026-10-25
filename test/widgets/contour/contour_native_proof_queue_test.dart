import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_native_proof_queue.dart';

void main() {
  late List<FlutterErrorDetails> failures;
  void Function(FlutterErrorDetails)? previousErrorHandler;

  setUp(() {
    failures = [];
    previousErrorHandler = FlutterError.onError;
    FlutterError.onError = failures.add;
  });

  tearDown(() {
    FlutterError.onError = previousErrorHandler;
  });

  Future<void> finish(Completer<void> completion) async {
    completion.complete();
    await completion.future;
  }

  test('when the production queue is requested repeatedly, it should return the same shared queue', () {
    expect(identical(ContourNativeProofQueue.shared, ContourNativeProofQueue.shared), isTrue);
  });

  test('when an isolated queue starts, it should have no initial, pending, or active work', () {
    final queue = ContourNativeProofQueue.test();
    expect(
      [queue.initialWorkCount, queue.pendingCount, queue.active, queue.buildCount, queue.maximumInitialWorkAtStart],
      [0, 0, false, 0, 0],
    );
  });

  test('when several initial operations finish separately, it should start proofs only after the last one', () async {
    final queue = ContourNativeProofQueue.test()
      ..beginInitial()
      ..beginInitial();
    final started = Completer<void>();
    final completed = Completer<void>();
    queue.enqueue(
      owner: Object(),
      run: () {
        started.complete();
        return completed.future;
      },
      onCancel: () {},
    );
    await Future<void>.value();
    final before = [queue.initialWorkCount, queue.pendingCount, started.isCompleted];
    queue.endInitial();
    await Future<void>.value();
    final afterFirst = [queue.initialWorkCount, queue.pendingCount, started.isCompleted];
    queue.endInitial();
    await started.future;
    final afterLast = [queue.initialWorkCount, queue.pendingCount, queue.active, queue.maximumInitialWorkAtStart];
    await finish(completed);
    expect(
      [before, afterFirst, afterLast, queue.active],
      [
        [2, 1, false],
        [1, 1, false],
        [0, 0, true, 0],
        false,
      ],
    );
  });

  test('when initial work starts before a scheduled drain runs, it should keep the proof waiting', () async {
    final queue = ContourNativeProofQueue.test();
    final started = Completer<void>();
    final completed = Completer<void>();
    queue
      ..enqueue(
        owner: Object(),
        run: () {
          started.complete();
          return completed.future;
        },
        onCancel: () {},
      )
      ..beginInitial();
    await Future<void>.value();
    final blocked = [queue.active, queue.pendingCount, queue.buildCount, started.isCompleted];
    queue.endInitial();
    await started.future;
    await finish(completed);
    expect(
      [blocked, queue.buildCount, queue.maximumInitialWorkAtStart],
      [
        [false, 1, 0, false],
        1,
        0,
      ],
    );
  });

  test('when several proofs are ready, it should run them serially in arrival order', () async {
    final queue = ContourNativeProofQueue.test();
    final started = List.generate(3, (_) => Completer<void>());
    final completed = List.generate(3, (_) => Completer<void>());
    final order = <int>[];
    for (var index = 0; index < 3; index++) {
      queue.enqueue(
        owner: Object(),
        run: () {
          order.add(index);
          started[index].complete();
          return completed[index].future;
        },
        onCancel: () {},
      );
    }
    final states = <List<Object>>[];
    for (var index = 0; index < 3; index++) {
      await started[index].future;
      states.add([queue.active, queue.pendingCount, queue.buildCount]);
      await finish(completed[index]);
    }
    expect(
      [order, states, queue.active, queue.pendingCount],
      [
        [0, 1, 2],
        [
          [true, 2, 1],
          [true, 1, 2],
          [true, 0, 3],
        ],
        false,
        0,
      ],
    );
  });

  test(
    'when initial work begins during an active proof, it should block the next proof without interrupting the first',
    () async {
      final queue = ContourNativeProofQueue.test();
      final firstStarted = Completer<void>();
      final firstCompleted = Completer<void>();
      final nextStarted = Completer<void>();
      final nextCompleted = Completer<void>();
      queue.enqueue(
        owner: Object(),
        run: () {
          firstStarted.complete();
          return firstCompleted.future;
        },
        onCancel: () {},
      );
      await firstStarted.future;
      queue
        ..beginInitial()
        ..enqueue(
          owner: Object(),
          run: () {
            nextStarted.complete();
            return nextCompleted.future;
          },
          onCancel: () {},
        );
      await finish(firstCompleted);
      final blocked = [queue.active, queue.pendingCount, nextStarted.isCompleted];
      queue.endInitial();
      await nextStarted.future;
      await finish(nextCompleted);
      expect(
        [blocked, queue.buildCount, queue.maximumInitialWorkAtStart],
        [
          [false, 1, false],
          2,
          0,
        ],
      );
    },
  );

  test(
    'when the waiting queue reaches its default capacity, it should reject the next proof without cancelling it',
    () {
      final queue = ContourNativeProofQueue.test()..beginInitial();
      final owners = List.generate(64, (_) => Object());
      final accepted = [for (final owner in owners) queue.enqueue(owner: owner, run: () async {}, onCancel: () {})];
      var rejectedCancellations = 0;
      final rejected = queue.enqueue(owner: Object(), run: () async {}, onCancel: () => rejectedCancellations++);
      final pending = queue.pendingCount;
      owners.forEach(queue.cancel);
      queue.endInitial();
      expect([accepted.every((value) => value), rejected, pending, rejectedCancellations], [true, false, 64, 0]);
    },
  );

  test('when a queue has no waiting capacity, it should reject work without retaining callbacks', () {
    final queue = ContourNativeProofQueue.test(maximumPending: 0);
    final owner = Object();
    var cancelled = 0;
    final accepted = queue.enqueue(owner: owner, run: () async {}, onCancel: () => cancelled++);
    queue.cancel(owner);
    expect([accepted, cancelled, queue.pendingCount, queue.active, queue.buildCount], [false, 0, 0, false, 0]);
  });

  test('when pending work is cancelled repeatedly, it should notify once and release waiting capacity', () {
    final queue = ContourNativeProofQueue.test(maximumPending: 1)..beginInitial();
    final owner = Object();
    final replacement = Object();
    var cancelled = 0;
    queue
      ..enqueue(owner: owner, run: () async {}, onCancel: () => cancelled++)
      ..cancel(owner)
      ..cancel(owner);
    final accepted = queue.enqueue(owner: replacement, run: () async {}, onCancel: () {});
    final pending = queue.pendingCount;
    queue
      ..cancel(replacement)
      ..endInitial();
    expect([cancelled, accepted, pending, queue.buildCount], [1, true, 1, 0]);
  });

  test('when distinct owners compare equal, it should cancel only the identical owner', () {
    final queue = ContourNativeProofQueue.test()..beginInitial();
    final first = DateTime.utc(2000);
    final second = DateTime.utc(2000);
    final cancelled = [0, 0];
    final firstAccepted = queue.enqueue(owner: first, run: () async {}, onCancel: () => cancelled[0]++);
    final secondAccepted = queue.enqueue(owner: second, run: () async {}, onCancel: () => cancelled[1]++);
    queue.cancel(first);
    final beforeCleanup = [
      first == second,
      identical(first, second),
      firstAccepted,
      secondAccepted,
      [...cancelled],
      queue.pendingCount,
    ];
    queue
      ..cancel(second)
      ..endInitial();
    expect(beforeCleanup, [
      true,
      false,
      true,
      true,
      [1, 0],
      1,
    ]);
  });

  test('when one owner is enqueued twice, it should reject the duplicate without replacing its cancellation', () {
    final queue = ContourNativeProofQueue.test()..beginInitial();
    final owner = Object();
    var firstCancelled = 0;
    var duplicateCancelled = 0;
    queue.enqueue(owner: owner, run: () async {}, onCancel: () => firstCancelled++);
    final accepted = queue.enqueue(owner: owner, run: () async {}, onCancel: () => duplicateCancelled++);
    queue
      ..cancel(owner)
      ..endInitial();
    expect([accepted, firstCancelled, duplicateCancelled, queue.pendingCount], [false, 1, 0, 0]);
  });

  test('when active work is cancelled, it should retain its serial slot until its future finishes', () async {
    final queue = ContourNativeProofQueue.test(maximumPending: 1);
    final owner = Object();
    final firstStarted = Completer<void>();
    final firstCompleted = Completer<void>();
    final nextStarted = Completer<void>();
    final nextCompleted = Completer<void>();
    var cancelled = 0;
    queue.enqueue(
      owner: owner,
      run: () {
        firstStarted.complete();
        return firstCompleted.future;
      },
      onCancel: () => cancelled++,
    );
    await firstStarted.future;
    queue
      ..enqueue(
        owner: Object(),
        run: () {
          nextStarted.complete();
          return nextCompleted.future;
        },
        onCancel: () {},
      )
      ..cancel(owner)
      ..cancel(owner);
    final blocked = [cancelled, queue.active, queue.pendingCount, queue.buildCount, nextStarted.isCompleted];
    await finish(firstCompleted);
    await nextStarted.future;
    await finish(nextCompleted);
    expect(
      [blocked, queue.active, queue.pendingCount, queue.buildCount],
      [
        [1, true, 1, 1, false],
        false,
        0,
        2,
      ],
    );
  });

  test(
    'when an active cancellation enqueues the same owner again, it should defer the replacement until completion',
    () async {
      final queue = ContourNativeProofQueue.test();
      final owner = Object();
      final firstStarted = Completer<void>();
      final firstCompleted = Completer<void>();
      final nextStarted = Completer<void>();
      final nextCompleted = Completer<void>();
      var replacementAccepted = false;
      var cancelled = 0;
      queue.enqueue(
        owner: owner,
        run: () {
          firstStarted.complete();
          return firstCompleted.future;
        },
        onCancel: () {
          cancelled++;
          replacementAccepted = queue.enqueue(
            owner: owner,
            run: () {
              nextStarted.complete();
              return nextCompleted.future;
            },
            onCancel: () {},
          );
        },
      );
      await firstStarted.future;
      queue.cancel(owner);
      final blocked = [replacementAccepted, cancelled, queue.active, queue.pendingCount, nextStarted.isCompleted];
      await finish(firstCompleted);
      await nextStarted.future;
      await finish(nextCompleted);
      expect(
        [blocked, queue.buildCount],
        [
          [true, 1, true, 1, false],
          2,
        ],
      );
    },
  );

  test('when a pending cancellation enqueues its owner again, it should preserve the replacement', () async {
    final queue = ContourNativeProofQueue.test()..beginInitial();
    final owner = Object();
    final started = Completer<void>();
    final completed = Completer<void>();
    var accepted = false;
    var cancelled = 0;
    queue.enqueue(
      owner: owner,
      run: () async {},
      onCancel: () {
        cancelled++;
        accepted = queue.enqueue(
          owner: owner,
          run: () {
            started.complete();
            return completed.future;
          },
          onCancel: () {},
        );
      },
    );
    queue.cancel(owner);
    final pending = queue.pendingCount;
    queue.endInitial();
    await started.future;
    await finish(completed);
    expect([accepted, cancelled, pending, queue.buildCount], [true, 1, 1, 1]);
  });

  test(
    'when running work cancels itself synchronously, it should keep a replacement queued until its future finishes',
    () async {
      final queue = ContourNativeProofQueue.test();
      final owner = Object();
      final firstStarted = Completer<void>();
      final firstCompleted = Completer<void>();
      final nextStarted = Completer<void>();
      final nextCompleted = Completer<void>();
      var accepted = false;
      var cancelled = 0;
      queue.enqueue(
        owner: owner,
        run: () {
          queue.cancel(owner);
          accepted = queue.enqueue(
            owner: owner,
            run: () {
              nextStarted.complete();
              return nextCompleted.future;
            },
            onCancel: () {},
          );
          firstStarted.complete();
          return firstCompleted.future;
        },
        onCancel: () => cancelled++,
      );
      await firstStarted.future;
      final blocked = [accepted, cancelled, queue.active, queue.pendingCount, nextStarted.isCompleted];
      await finish(firstCompleted);
      await nextStarted.future;
      await finish(nextCompleted);
      expect(
        [blocked, queue.buildCount],
        [
          [true, 1, true, 1, false],
          2,
        ],
      );
    },
  );

  test('when completed work is cancelled later, it should no longer retain its cancellation callback', () async {
    final queue = ContourNativeProofQueue.test();
    final owner = Object();
    final started = Completer<void>();
    final completed = Completer<void>();
    var cancelled = 0;
    queue.enqueue(
      owner: owner,
      run: () {
        started.complete();
        return completed.future;
      },
      onCancel: () => cancelled++,
    );
    await started.future;
    await finish(completed);
    queue.cancel(owner);
    expect([cancelled, queue.active, queue.pendingCount], [0, false, 0]);
  });

  test('when a proof throws synchronously, it should report the failure and continue with the next proof', () async {
    final queue = ContourNativeProofQueue.test();
    final error = StateError('synchronous proof failure');
    final started = Completer<void>();
    final completed = Completer<void>();
    queue
      ..enqueue(owner: Object(), run: () => throw error, onCancel: () {})
      ..enqueue(
        owner: Object(),
        run: () {
          started.complete();
          return completed.future;
        },
        onCancel: () {},
      );
    await started.future;
    await finish(completed);
    expect(
      [failures.map((details) => details.exception).toList(), queue.buildCount, queue.active, queue.pendingCount],
      [
        [error],
        2,
        false,
        0,
      ],
    );
  });

  test('when a proof future fails, it should report the failure and continue with the next proof', () async {
    final queue = ContourNativeProofQueue.test();
    final error = StateError('asynchronous proof failure');
    final firstStarted = Completer<void>();
    final firstCompleted = Completer<void>();
    final nextStarted = Completer<void>();
    final nextCompleted = Completer<void>();
    queue
      ..enqueue(
        owner: Object(),
        run: () {
          firstStarted.complete();
          return firstCompleted.future;
        },
        onCancel: () {},
      )
      ..enqueue(
        owner: Object(),
        run: () {
          nextStarted.complete();
          return nextCompleted.future;
        },
        onCancel: () {},
      );
    await firstStarted.future;
    firstCompleted.completeError(error, StackTrace.current);
    await nextStarted.future;
    await finish(nextCompleted);
    expect(
      [failures.map((details) => details.exception).toList(), queue.buildCount, queue.active, queue.pendingCount],
      [
        [error],
        2,
        false,
        0,
      ],
    );
  });

  test('when a cancellation callback throws, it should release the pending slot and continue draining', () async {
    final queue = ContourNativeProofQueue.test()..beginInitial();
    final owner = Object();
    final error = StateError('cancellation failure');
    final started = Completer<void>();
    final completed = Completer<void>();
    queue
      ..enqueue(owner: owner, run: () async {}, onCancel: () => throw error)
      ..enqueue(
        owner: Object(),
        run: () {
          started.complete();
          return completed.future;
        },
        onCancel: () {},
      )
      ..cancel(owner)
      ..endInitial();
    await started.future;
    await finish(completed);
    expect(
      [failures.map((details) => details.exception).toList(), queue.buildCount, queue.pendingCount],
      [
        [error],
        1,
        0,
      ],
    );
  });

  test('when the error reporter throws, it should still release the active slot and start the next proof', () async {
    final queue = ContourNativeProofQueue.test();
    var reported = 0;
    FlutterError.onError = (details) {
      reported++;
      throw StateError('error reporter failure');
    };
    final started = Completer<void>();
    final completed = Completer<void>();
    queue
      ..enqueue(owner: Object(), run: () => throw StateError('proof failure'), onCancel: () {})
      ..enqueue(
        owner: Object(),
        run: () {
          started.complete();
          return completed.future;
        },
        onCancel: () {},
      );
    await started.future;
    await finish(completed);
    expect([reported, queue.buildCount, queue.active, queue.pendingCount], [1, 2, false, 0]);
  });

  test('when a proof becomes ready later, it should remain idle until explicitly woken', () async {
    final queue = ContourNativeProofQueue.test();
    var ready = false;
    var readinessChecks = 0;
    final started = Completer<void>();
    final completed = Completer<void>();
    queue.enqueue(
      owner: Object(),
      canRun: () {
        readinessChecks++;
        return ready;
      },
      run: () {
        started.complete();
        return completed.future;
      },
      onCancel: () {},
    );
    await Future<void>.value();
    final blocked = [queue.pendingCount, queue.active, queue.buildCount, readinessChecks];
    ready = true;
    await Future<void>.value();
    final beforeWake = [started.isCompleted, readinessChecks];
    queue.wake();
    await started.future;
    await finish(completed);
    expect(
      [blocked, beforeWake, readinessChecks, queue.buildCount],
      [
        [1, false, 0, 1],
        [false, 1],
        2,
        1,
      ],
    );
  });

  test('when an unready proof heads the queue, it should allow later ready work to proceed', () async {
    final queue = ContourNativeProofQueue.test();
    final blockedOwner = Object();
    var blockedRan = false;
    var blockedCancelled = 0;
    final started = Completer<void>();
    final completed = Completer<void>();
    queue
      ..enqueue(
        owner: blockedOwner,
        canRun: () => false,
        run: () async {
          blockedRan = true;
        },
        onCancel: () => blockedCancelled++,
      )
      ..enqueue(
        owner: Object(),
        run: () {
          started.complete();
          return completed.future;
        },
        onCancel: () {},
      );
    await started.future;
    final pending = queue.pendingCount;
    await finish(completed);
    queue.cancel(blockedOwner);
    expect([pending, blockedRan, blockedCancelled, queue.buildCount, queue.pendingCount], [1, false, 1, 1, 0]);
  });

  test('when a readiness predicate throws, it should cancel that proof once and drain later ready work', () async {
    final queue = ContourNativeProofQueue.test();
    final owner = Object();
    final error = StateError('readiness failure');
    var cancelled = 0;
    var failedProofRan = false;
    final started = Completer<void>();
    final completed = Completer<void>();
    queue
      ..enqueue(
        owner: owner,
        canRun: () => throw error,
        run: () async {
          failedProofRan = true;
        },
        onCancel: () => cancelled++,
      )
      ..enqueue(
        owner: Object(),
        run: () {
          started.complete();
          return completed.future;
        },
        onCancel: () {},
      );
    await started.future;
    await finish(completed);
    queue.cancel(owner);
    expect(
      [
        cancelled,
        failedProofRan,
        failures.map((details) => details.exception).toList(),
        queue.buildCount,
        queue.pendingCount,
      ],
      [
        1,
        false,
        [error],
        1,
        0,
      ],
    );
  });
}
