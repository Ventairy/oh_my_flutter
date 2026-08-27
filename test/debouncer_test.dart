import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('Debouncer scheduling', () {
    testWidgets(
      'when a synchronous callback is scheduled, it should return its value after the delay',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final result = debouncer(() => 42);

        await tester.pump(const Duration(milliseconds: 300));

        expect(await result, 42);
      },
    );

    testWidgets(
      'when an asynchronous callback is scheduled, it should await its value',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final callbackResult = Completer<int>();
        final result = debouncer(() => callbackResult.future);

        await tester.pump(const Duration(milliseconds: 300));
        callbackResult.complete(42);

        expect(await result, 42);
      },
    );

    testWidgets(
      'when a pending call is replaced, it should restart the full delay',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        var invocationCount = 0;
        unawaited(debouncer(() => ++invocationCount));
        await tester.pump(const Duration(milliseconds: 200));

        final result = debouncer(() => ++invocationCount);
        await tester.pump(const Duration(milliseconds: 299));

        expect(invocationCount, 0);
        await tester.pump(const Duration(milliseconds: 1));
        await result;
      },
    );

    testWidgets(
      'when pending calls are replaced, it should execute only the latest callback',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        var invocationCount = 0;
        unawaited(debouncer(() => ++invocationCount));
        unawaited(debouncer(() => invocationCount += 10));

        await tester.pump(const Duration(milliseconds: 300));

        expect(invocationCount, 10);
      },
    );

    testWidgets(
      'when calls share a pending burst, they should return the same future',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final firstResult = debouncer(() => 1);
        final secondResult = debouncer(() => 2);

        expect(identical(firstResult, secondResult), isTrue);
        await tester.pump(const Duration(milliseconds: 300));
        await secondResult;
      },
    );

    testWidgets(
      'when calls share a pending burst, every awaiter should receive the latest value',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final firstResult = debouncer(() => 1);
        final secondResult = debouncer(() => 2);

        await tester.pump(const Duration(milliseconds: 300));

        expect((await firstResult, await secondResult), (2, 2));
      },
    );

    testWidgets(
      'when the latest callback fails, it should propagate the error to the shared future',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final result = debouncer(() => throw StateError('failed'));
        final expectation = expectLater(result, throwsStateError);

        await tester.pump(const Duration(milliseconds: 300));

        await expectation;
      },
    );

    testWidgets(
      'when a call arrives after execution starts, it should cancel the earlier result by default',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final firstCallbackResult = Completer<int>();
        final firstResult = debouncer(() => firstCallbackResult.future);
        final expectation = expectLater(
          firstResult,
          throwsA(isA<DebouncerCanceledException>()),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final secondResult = debouncer(() => 2);
        await expectation;
        firstCallbackResult.complete(1);
        await tester.pump(const Duration(milliseconds: 300));
        await secondResult;
      },
    );

    testWidgets(
      'when a running result is superseded, the latest call should still return its value',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final firstCallbackResult = Completer<int>();
        final firstResult = debouncer(() => firstCallbackResult.future);
        unawaited(firstResult.catchError((Object _) => 0));
        await tester.pump(const Duration(milliseconds: 300));

        final secondResult = debouncer(() => 2);
        firstCallbackResult.complete(1);
        await tester.pump(const Duration(milliseconds: 300));

        expect(await secondResult, 2);
      },
    );

    testWidgets(
      'when a superseded callback later fails, it should consume the discarded error',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final firstCallbackResult = Completer<int>();
        final firstResult = debouncer(() => firstCallbackResult.future);
        unawaited(firstResult.catchError((Object _) => 0));
        await tester.pump(const Duration(milliseconds: 300));

        final secondResult = debouncer(() => 2);
        firstCallbackResult.completeError(StateError('discarded'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(await secondResult, 2);
      },
    );

    testWidgets(
      'when switchLatest is disabled, running callbacks should remain independent',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
          switchLatest: false,
        );
        final firstCallbackResult = Completer<int>();
        final firstResult = debouncer(() => firstCallbackResult.future);
        await tester.pump(const Duration(milliseconds: 300));

        final secondResult = debouncer(() => 2);
        await tester.pump(const Duration(milliseconds: 300));
        firstCallbackResult.complete(1);

        expect((await firstResult, await secondResult), (1, 2));
      },
    );

    testWidgets(
      'when the delay is zero, it should still schedule the callback asynchronously',
      (tester) async {
        final debouncer = Debouncer<int>(delay: Duration.zero);
        var invocationCount = 0;
        final result = debouncer(() => ++invocationCount);

        expect(invocationCount, 0);
        await tester.pump(const Duration(microseconds: 1));
        await result;
      },
    );

    test(
      'when the delay is negative, it should reject the configuration in debug mode',
      () {
        expect(
          () => Debouncer<int>(delay: const Duration(microseconds: -1)),
          throwsAssertionError,
        );
      },
    );
  });

  group('Debouncer cancellation', () {
    testWidgets(
      'when a pending call is canceled, it should complete with a typed cancellation',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final result = debouncer(() => 42);
        final expectation = expectLater(
          result,
          throwsA(isA<DebouncerCanceledException>()),
        );

        debouncer.cancel();

        await expectation;
      },
    );

    testWidgets(
      'when a pending call is canceled, it should not invoke its callback',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        var invocationCount = 0;
        final result = debouncer(() => ++invocationCount);
        unawaited(result.catchError((Object _) => 0));

        debouncer.cancel();
        await tester.pump(const Duration(milliseconds: 300));

        expect(invocationCount, 0);
      },
    );

    testWidgets(
      'when cancellation finishes, it should remain reusable',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final canceledResult = debouncer(() => 1);
        unawaited(canceledResult.catchError((Object _) => 0));
        debouncer.cancel();

        final nextResult = debouncer(() => 2);
        await tester.pump(const Duration(milliseconds: 300));

        expect(await nextResult, 2);
      },
    );

    testWidgets(
      'when a running result is canceled, it should complete with a typed cancellation',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final callbackResult = Completer<int>();
        final result = debouncer(() => callbackResult.future);
        final expectation = expectLater(
          result,
          throwsA(isA<DebouncerCanceledException>()),
        );
        await tester.pump(const Duration(milliseconds: 300));

        debouncer.cancel();

        await expectation;
        callbackResult.complete(42);
      },
    );

    test('when no call is pending, cancel should remain safe', () {
      final debouncer = Debouncer<int>(
        delay: const Duration(milliseconds: 300),
      );

      expect(debouncer.cancel, returnsNormally);
    });
  });

  group('Debouncer disposal', () {
    testWidgets(
      'when disposed with a pending call, it should complete with a typed cancellation',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final result = debouncer(() => 42);
        final expectation = expectLater(
          result,
          throwsA(isA<DebouncerCanceledException>()),
        );

        debouncer.dispose();

        await expectation;
      },
    );

    testWidgets(
      'when disposed with a running result, it should complete with a typed cancellation',
      (tester) async {
        final debouncer = Debouncer<int>(
          delay: const Duration(milliseconds: 300),
        );
        final callbackResult = Completer<int>();
        final result = debouncer(() => callbackResult.future);
        final expectation = expectLater(
          result,
          throwsA(isA<DebouncerCanceledException>()),
        );
        await tester.pump(const Duration(milliseconds: 300));

        debouncer.dispose();

        await expectation;
        callbackResult.complete(42);
      },
    );

    test('when disposed repeatedly, it should remain safe', () {
      final debouncer = Debouncer<int>(
        delay: const Duration(milliseconds: 300),
      );

      expect(
        () {
          debouncer
            ..dispose()
            ..dispose();
        },
        returnsNormally,
      );
    });

    test('when scheduling after disposal, it should reject the call', () {
      final debouncer = Debouncer<int>(
        delay: const Duration(milliseconds: 300),
      )..dispose();

      expect(() => debouncer(() => 42), throwsStateError);
    });
  });
}
