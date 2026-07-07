import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('OmfDateTimeExtension', () {
    // All tests pin time to this fixed instant.
    final fixedNow = DateTime.utc(2026, 7, 6, 12, 0, 0);

    // ─────────────────────────────────────────────────────────────────────────
    // Group A: matched-bucket direct hits (all callbacks supplied, none fallback)
    // ─────────────────────────────────────────────────────────────────────────
    group('when all callbacks are supplied and the matched bucket fires directly', () {
      test('when the date is in the future, it should invoke onNow', () {
        withClock(Clock.fixed(fixedNow), () {
          final future = fixedNow.add(const Duration(hours: 1));
          final result = future.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'now');
        });
      });

      test('when the date is exactly now, it should invoke onNow', () {
        withClock(Clock.fixed(fixedNow), () {
          final result = fixedNow.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'now');
        });
      });

      test('when 500 milliseconds have elapsed, it should invoke onMillisecondsAgo with 500', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(milliseconds: 500));
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (c) => 'ms:$c',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'ms:500');
        });
      });

      test('when 999 milliseconds have elapsed, it should invoke onMillisecondsAgo with 999', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(milliseconds: 999));
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (c) => 'ms:$c',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'ms:999');
        });
      });

      test('when exactly 1 second has elapsed, it should invoke onSecondsAgo with 1', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(seconds: 1));
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (c) => 's:$c',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 's:1');
        });
      });

      test('when 59 seconds have elapsed, it should invoke onSecondsAgo with 59', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(seconds: 59));
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (c) => 's:$c',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 's:59');
        });
      });

      test('when exactly 60 seconds have elapsed, it should invoke onMinutesAgo with 1', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(seconds: 60));
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (c) => 'm:$c',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'm:1');
        });
      });

      test('when 59 minutes have elapsed, it should invoke onMinutesAgo with 59', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(minutes: 59));
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (c) => 'm:$c',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'm:59');
        });
      });

      test('when exactly 60 minutes have elapsed, it should invoke onHoursAgo with 1', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(minutes: 60));
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (c) => 'h:$c',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'h:1');
        });
      });

      test('when 23 hours have elapsed, it should invoke onHoursAgo with 23', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(hours: 23));
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (c) => 'h:$c',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'h:23');
        });
      });

      test('when exactly 24 hours have elapsed, it should invoke onDaysAgo with 1', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(hours: 24));
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (c) => 'd:$c',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'd:1');
        });
      });

      test('when 29 days have elapsed, it should invoke onDaysAgo with 29', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(days: 29));
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (c) => 'd:$c',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'd:29');
        });
      });

      test('when 30 days have elapsed, it should invoke onMonthsAgo with the correct month count', () {
        withClock(Clock.fixed(fixedNow), () {
          // fixedNow = 2026-07-06 12:00:00 UTC
          // 30 days before = 2026-06-06 12:00:00 UTC => 1 calendar month
          final past = fixedNow.subtract(const Duration(days: 30));
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (c) => 'mo:$c',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'mo:1');
        });
      });

      test('when 11 months have elapsed, it should invoke onMonthsAgo with 11', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = DateTime.utc(2025, 8, 6, 12, 0, 0);
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (c) => 'mo:$c',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'mo:11');
        });
      });

      test('when 12 months have elapsed, it should invoke onYearsAgo with 1', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = DateTime.utc(2025, 7, 6, 12, 0, 0);
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (c) => 'y:$c',
          );

          expect(result, 'y:1');
        });
      });

      test('when the day-of-month is not yet reached, it should not count a full month', () {
        withClock(Clock.fixed(fixedNow), () {
          // fixedNow = 2026-07-06, past = 2026-06-10 → 0 months (day not reached)
          final past = DateTime.utc(2026, 6, 10, 12, 0, 0);
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (c) => 'd:$c',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (_) => 'y',
          );

          expect(result, 'd:26');
        });
      });

      test('when several years have elapsed, it should invoke onYearsAgo with the correct year count', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = DateTime.utc(2020, 7, 6, 12, 0, 0);
          final result = past.timeAgo(
            onNow: () => 'now',
            onMillisecondsAgo: (_) => 'ms',
            onSecondsAgo: (_) => 's',
            onMinutesAgo: (_) => 'm',
            onHoursAgo: (_) => 'h',
            onDaysAgo: (_) => 'd',
            onMonthsAgo: (_) => 'mo',
            onYearsAgo: (c) => 'y:$c',
          );

          expect(result, 'y:6');
        });
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Group B: generic inference (T follows the callbacks)
    // ─────────────────────────────────────────────────────────────────────────
    group('when callbacks return types other than String', () {
      test('when callbacks return int, it should return an int', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(seconds: 5));
          final result = past.timeAgo<int>(
            onSecondsAgo: (c) => c,
          );

          expect(result, 5);
        });
      });

      test('when onMiss returns double and fallback is none with a missing matched bucket, it should return the onMiss double', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(hours: 5));
          final result = past.timeAgo<double>(
            onMiss: () => 3.14,
          );

          expect(result, 3.14);
        });
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Group C: fallback: none + matched missing (terminal case)
    // ─────────────────────────────────────────────────────────────────────────
    group('when fallback is none and the matched bucket callback is missing', () {
      test('when onMiss is supplied, it should return the onMiss value', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(hours: 5));
          final result = past.timeAgo(
            onNow: () => 'now',
            onHoursAgo: null, // matched, missing
            onDaysAgo: (_) => 'd',
            onMiss: () => 'miss',
          );

          expect(result, 'miss');
        });
      });

      test('when onMiss is null, it should throw ArgumentError', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(hours: 5));
          expect(
            () => past.timeAgo(
              onNow: () => 'now',
              onHoursAgo: null, // matched, missing
              onDaysAgo: (_) => 'd',
              // no onMiss
            ),
            throwsArgumentError,
          );
        });
      });

      test('when the matched bucket is onYearsAgo and only onNow is supplied with fallback none, it should invoke onMiss (not onNow)', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = DateTime.utc(2020, 7, 6, 12, 0, 0);
          final result = past.timeAgo(
            onNow: () => 'now',
            onMiss: () => 'miss',
            // no onYearsAgo
          );

          expect(result, 'miss');
        });
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Group D: fallback: finer
    // ─────────────────────────────────────────────────────────────────────────
    group('when fallback is finer and the matched bucket callback is missing', () {
      test('when a finer count-bucket is supplied, it should invoke it with the recomputed count', () {
        withClock(Clock.fixed(fixedNow), () {
          // matched = hours (3), finer = minutes (4)
          final past = fixedNow.subtract(const Duration(hours: 2, minutes: 30));
          final result = past.timeAgo(
            onHoursAgo: null, // matched, missing
            onMinutesAgo: (c) => 'm:$c',
            onNow: () => 'now',
            fallback: OmfTimeAgoFallback.finer,
            onMillisecondsAgo: null,
            onSecondsAgo: null,
          );

          expect(result, 'm:150');
        });
      });

      test('when only the finest count-bucket is supplied, it should invoke that bucket', () {
        withClock(Clock.fixed(fixedNow), () {
          // matched = hours (3), finer: minutes(null), seconds(null), ms(supplied)
          final past = fixedNow.subtract(const Duration(hours: 2));
          final result = past.timeAgo(
            onHoursAgo: null, // matched, missing
            onMinutesAgo: null,
            onSecondsAgo: null,
            onMillisecondsAgo: (c) => 'ms:$c',
            onNow: () => 'now',
            fallback: OmfTimeAgoFallback.finer,
          );

          expect(result, 'ms:7200000');
        });
      });

      test('when only onNow is supplied (collapse-to-now edge), it should invoke onNow', () {
        withClock(Clock.fixed(fixedNow), () {
          // matched = hours (3), finer: minutes(null), seconds(null), ms(null),
          // then onNow
          final past = fixedNow.subtract(const Duration(days: 2));
          final result = past.timeAgo(
            onDaysAgo: null, // matched, missing
            onNow: () => 'now',
            fallback: OmfTimeAgoFallback.finer,
          );

          expect(result, 'now');
        });
      });

      test('when no finer callback (including onNow) is supplied and onMiss is supplied, it should invoke onMiss', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(seconds: 30));
          final result = past.timeAgo(
            onSecondsAgo: null, // matched, missing
            onMillisecondsAgo: null,
            onNow: null,
            onMiss: () => 'miss',
            fallback: OmfTimeAgoFallback.finer,
          );

          expect(result, 'miss');
        });
      });

      test('when no finer callback (including onNow) is supplied and onMiss is null, it should throw ArgumentError', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(seconds: 30));
          expect(
            () => past.timeAgo<String>(
              onSecondsAgo: null, // matched, missing
              onMillisecondsAgo: null,
              onNow: null,
              // no onMiss
              fallback: OmfTimeAgoFallback.finer,
            ),
            throwsArgumentError,
          );
        });
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Group E: fallback: coarser
    // ─────────────────────────────────────────────────────────────────────────
    group('when fallback is coarser and the matched bucket callback is missing', () {
      test('when a coarser count-bucket is supplied, it should invoke it with the recomputed count', () {
        withClock(Clock.fixed(fixedNow), () {
          // matched = hours (3), coarser = days (2)
          final past = fixedNow.subtract(const Duration(hours: 50));
          final result = past.timeAgo(
            onHoursAgo: null, // matched, missing
            onDaysAgo: (c) => 'd:$c',
            fallback: OmfTimeAgoFallback.coarser,
          );

          expect(result, 'd:2');
        });
      });

      test('when only onYearsAgo is supplied, it should invoke onYearsAgo (nearest-coarser precedence)', () {
        withClock(Clock.fixed(fixedNow), () {
          // matched = hours (3), coarser: days(null), months(null), years(supplied)
          final past = fixedNow.subtract(const Duration(hours: 50));
          final result = past.timeAgo(
            onHoursAgo: null, // matched, missing
            onDaysAgo: null,
            onMonthsAgo: null,
            onYearsAgo: (c) => 'y:$c',
            fallback: OmfTimeAgoFallback.coarser,
          );

          expect(result, 'y:0');
        });
      });

      test('when only onNow is supplied (no coarser), it should invoke onMiss', () {
        withClock(Clock.fixed(fixedNow), () {
          // matched = hours (3), coarser: nothing, onNow is not coarser
          final past = fixedNow.subtract(const Duration(hours: 5));
          final result = past.timeAgo(
            onHoursAgo: null,
            onNow: () => 'now',
            onMiss: () => 'miss',
            fallback: OmfTimeAgoFallback.coarser,
          );

          expect(result, 'miss');
        });
      });

      test('when no coarser callback is supplied and onMiss is null, it should throw ArgumentError', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(hours: 5));
          expect(
            () => past.timeAgo(
              onHoursAgo: null,
              onNow: () => 'now',
              // no coarser callbacks, no onMiss
              fallback: OmfTimeAgoFallback.coarser,
            ),
            throwsArgumentError,
          );
        });
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Group F: fallback: bidirectional
    // ─────────────────────────────────────────────────────────────────────────
    group('when fallback is bidirectional and the matched bucket callback is missing', () {
      test('when both finer and coarser count-buckets are supplied, it should prefer finer', () {
        withClock(Clock.fixed(fixedNow), () {
          // matched = hours (3), finer: minutes(supplied), coarser: days(supplied)
          final past = fixedNow.subtract(const Duration(hours: 5));
          final result = past.timeAgo(
            onHoursAgo: null,
            onMinutesAgo: (c) => 'm:$c',
            onDaysAgo: (_) => 'd',
            fallback: OmfTimeAgoFallback.bidirectional,
            onNow: null,
            onSecondsAgo: null,
            onMillisecondsAgo: null,
            onMonthsAgo: null,
            onYearsAgo: null,
          );

          expect(result, 'm:300');
        });
      });

      test('when only a coarser count-bucket is supplied, it should invoke that coarser bucket', () {
        withClock(Clock.fixed(fixedNow), () {
          // matched = hours (3), finer: nothing, coarser: days(supplied)
          final past = fixedNow.subtract(const Duration(hours: 50));
          final result = past.timeAgo(
            onHoursAgo: null,
            onDaysAgo: (c) => 'd:$c',
            fallback: OmfTimeAgoFallback.bidirectional,
            onMinutesAgo: null,
            onSecondsAgo: null,
            onMillisecondsAgo: null,
            onMonthsAgo: null,
            onYearsAgo: null,
            onNow: null,
          );

          expect(result, 'd:2');
        });
      });

      test('when onNow is last resort after no other bucket, it should invoke onNow', () {
        withClock(Clock.fixed(fixedNow), () {
          // matched = hours (3), finer: nothing, coarser: nothing, then onNow
          final past = fixedNow.subtract(const Duration(hours: 5));
          final result = past.timeAgo(
            onHoursAgo: null,
            onNow: () => 'now',
            fallback: OmfTimeAgoFallback.bidirectional,
          );

          expect(result, 'now');
        });
      });

      test('when onNow is available alongside a coarser count-bucket, it should prefer the coarser over onNow', () {
        withClock(Clock.fixed(fixedNow), () {
          // matched = hours (3), finer: nothing, coarser: days(supplied), onNow(supplied)
          // onNow is last resort → days fires
          final past = fixedNow.subtract(const Duration(hours: 50));
          final result = past.timeAgo(
            onHoursAgo: null,
            onDaysAgo: (c) => 'd:$c',
            onNow: () => 'now',
            fallback: OmfTimeAgoFallback.bidirectional,
          );

          expect(result, 'd:2');
        });
      });

      test('when no callback is supplied anywhere and onMiss is supplied, it should invoke onMiss', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(hours: 5));
          final result = past.timeAgo(
            onHoursAgo: null,
            onMiss: () => 'miss',
            fallback: OmfTimeAgoFallback.bidirectional,
          );

          expect(result, 'miss');
        });
      });

      test('when no callback is supplied anywhere and onMiss is null, it should throw ArgumentError', () {
        withClock(Clock.fixed(fixedNow), () {
          final past = fixedNow.subtract(const Duration(hours: 5));
          expect(
            () => past.timeAgo<String>(
              onHoursAgo: null,
              fallback: OmfTimeAgoFallback.bidirectional,
            ),
            throwsArgumentError,
          );
        });
      });
    });
  });
}
