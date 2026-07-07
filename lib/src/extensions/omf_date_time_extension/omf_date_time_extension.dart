import 'package:clock/clock.dart';

part 'omf_date_time_extension_enums.dart';

/// Shared helpers for [DateTime] values.
extension OmfDateTimeExtension on DateTime {
  /// Returns a "time ago" value for this [DateTime] relative to now.
  ///
  /// The result type `T` is inferred from the callbacks you pass — pass
  /// callbacks returning [String] to get a localized string, callbacks
  /// returning `int` to get a raw count, and so on.
  ///
  /// The current time is read via `clock.now` from `package:clock` (NOT
  /// `DateTime.now()`), so the result is deterministic and fakeable in tests.
  /// Wrap the call in `withClock(Clock.fixed(fixedTime), () { ... })` to pin
  /// time; for advancing time (timers/delays) use `package:fake_async`.
  ///
  /// The elapsed time is classified into a bucket (now / milliseconds / seconds
  /// / minutes / hours / days / months / years). If that bucket's callback is
  /// supplied, it is invoked with the recomputed count and its return value is
  /// returned.
  ///
  /// If the matched bucket's callback is null, [fallback] decides what happens:
  /// - [OmfTimeAgoFallback.none] (default) → no walk; go to the terminal case.
  /// - [OmfTimeAgoFallback.finer] → walks toward finer count-buckets, then
  ///   [onNow] as a last resort; first supplied callback fires.
  /// - [OmfTimeAgoFallback.coarser] → walks toward coarser count-buckets only;
  ///   [onNow] is not reachable in this mode.
  /// - [OmfTimeAgoFallback.bidirectional] → finer count-buckets first, then
  ///   coarser count-buckets, then [onNow] last.
  ///
  /// Terminal case (matched missing under `none`, OR a non-`none` walk
  /// exhausted with no callback found): if [onMiss] is supplied, its return
  /// value is returned; otherwise an [ArgumentError] is thrown.
  ///
  /// All callbacks are optional. The count passed to a count-bearing callback
  /// is recomputed for that callback's unit (not the matched bucket's unit).
  /// [onNow] and [onMiss] take no count.
  ///
  /// **Nullable callback trick:** since a callback is `T Function(...)?`, its
  /// return type carries the nullability of `T`. A callback that returns `null`
  /// (for example, `onDaysAgo: (d) => d > 7 ? null : '\$d days'`) is treated
  /// the same as an omitted callback — the fallback walk continues to the next
  /// bucket. This lets you express conditional formatting declaratively:
  /// skip a bucket for large values, delegate to a coarser unit, or provide a
  /// default only when a finer unit is a better fit.
  T timeAgo<T>({
    T Function()? onNow,
    T Function(int count)? onMillisecondsAgo,
    T Function(int count)? onSecondsAgo,
    T Function(int count)? onMinutesAgo,
    T Function(int count)? onHoursAgo,
    T Function(int count)? onDaysAgo,
    T Function(int count)? onMonthsAgo,
    T Function(int count)? onYearsAgo,
    T Function()? onMiss,
    OmfTimeAgoFallback fallback = OmfTimeAgoFallback.none,
  }) {
    final now = clock.now();
    final elapsed = now.difference(this);

    _TimeAgoBucket matchedBucket;

    if (elapsed.inMilliseconds <= 0) {
      matchedBucket = _TimeAgoBucket.now;
    } else if (elapsed.inMilliseconds < 1000) {
      matchedBucket = _TimeAgoBucket.milliseconds;
    } else if (elapsed.inSeconds < 60) {
      matchedBucket = _TimeAgoBucket.seconds;
    } else if (elapsed.inMinutes < 60) {
      matchedBucket = _TimeAgoBucket.minutes;
    } else if (elapsed.inHours < 24) {
      matchedBucket = _TimeAgoBucket.hours;
    } else if (elapsed.inDays < 30) {
      matchedBucket = _TimeAgoBucket.days;
    } else {
      final months = _elapsedMonths(now, this);
      matchedBucket = months < 12 ? _TimeAgoBucket.months : _TimeAgoBucket.years;
    }

    T? invoke(_TimeAgoBucket bucket) => switch (bucket) {
      _TimeAgoBucket.years => onYearsAgo?.call(_elapsedYears(now, this)),
      _TimeAgoBucket.months => onMonthsAgo?.call(_elapsedMonths(now, this)),
      _TimeAgoBucket.days => onDaysAgo?.call(elapsed.inDays),
      _TimeAgoBucket.hours => onHoursAgo?.call(elapsed.inHours),
      _TimeAgoBucket.minutes => onMinutesAgo?.call(elapsed.inMinutes),
      _TimeAgoBucket.seconds => onSecondsAgo?.call(elapsed.inSeconds),
      _TimeAgoBucket.milliseconds => onMillisecondsAgo?.call(elapsed.inMilliseconds),
      _TimeAgoBucket.now => onNow?.call(),
    };

    final matchedResult = invoke(matchedBucket);
    if (matchedResult != null) return matchedResult;

    final candidates = switch (fallback) {
      OmfTimeAgoFallback.none => <_TimeAgoBucket>[],
      OmfTimeAgoFallback.finer => [
        for (var i = matchedBucket.index + 1; i <= _TimeAgoBucket.now.index; i++)
          _TimeAgoBucket.values[i],
      ],
      OmfTimeAgoFallback.coarser => [
        for (var i = matchedBucket.index - 1; i >= 0; i--)
          _TimeAgoBucket.values[i],
      ],
      OmfTimeAgoFallback.bidirectional => [
        for (var i = matchedBucket.index + 1; i <= _TimeAgoBucket.milliseconds.index; i++)
          _TimeAgoBucket.values[i],
        for (var i = matchedBucket.index - 1; i >= 0; i--)
          _TimeAgoBucket.values[i],
        _TimeAgoBucket.now,
      ],
    };

    for (final bucket in candidates) {
      final r = invoke(bucket);
      if (r != null) return r;
    }

    if (onMiss != null) return onMiss();

    throw ArgumentError(
      'No timeAgo callback supplied for any reachable bucket. '
      'Provide at least one unit callback or onMiss.',
    );
  }

  int _elapsedMonths(DateTime now, DateTime then) {
    var months = (now.year - then.year) * 12 + (now.month - then.month);
    if (now.day < then.day) months -= 1;
    if (months < 0) months = 0;
    return months;
  }

  int _elapsedYears(DateTime now, DateTime then) {
    return _elapsedMonths(now, then) ~/ 12;
  }
}
