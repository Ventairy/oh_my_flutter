part of 'omf_date_time_extension.dart';

/// Selects how [OmfDateTimeExtension.timeAgo] walks when the matched bucket's
/// callback is missing.
///
/// - [OmfTimeAgoFallback.none] (default): no walk; the terminal case fires
///   (onMiss if supplied, else an [ArgumentError]).
/// - [OmfTimeAgoFallback.finer]: walk toward finer units, then onNow last.
/// - [OmfTimeAgoFallback.coarser]: walk toward coarser units only.
/// - [OmfTimeAgoFallback.bidirectional]: finer first, then coarser, then onNow.
enum OmfTimeAgoFallback {
  /// No walk is performed. When the matched bucket's callback is missing, the
  /// terminal case fires immediately — `onMiss` if supplied, else an
  /// [ArgumentError].
  ///
  /// This is the default and the most explicit option. Every time bucket you
  /// care about must have its own callback, or you must supply `onMiss`.
  none,

  /// Walk toward finer (smaller) time units, then `onNow` as a last resort.
  ///
  /// The walk order from the matched bucket is: finer count-buckets in
  /// increasing precision (hours → minutes → seconds → milliseconds), then
  /// `onNow`. The first callback whose value is non-null fires. Coarser
  /// (larger) units are never consulted.
  ///
  /// Example: matched = hours (missing), `onMinutesAgo` supplied, `onDaysAgo`
  /// supplied → walks to minutes (finer, preferred) and fires it. Days is
  /// coarser and is never reached.
  ///
  /// If the entire finer walk (including `onNow`) finds nothing, the terminal
  /// case fires (`onMiss` or throw).
  finer,

  /// Walk toward coarser (larger) time units only.
  ///
  /// The walk order from the matched bucket is: coarser count-buckets in
  /// decreasing precision (hours → days → months → years). `onNow` is NOT
  /// reachable in this mode — it is the finest unit and lives in the opposite
  /// direction.
  ///
  /// Example: matched = hours (missing), `onYearsAgo` supplied, `onMinutesAgo`
  /// supplied → walks to days, months, then years (coarser). Minutes is finer
  /// and is never consulted. `onNow` is also never consulted.
  ///
  /// If the entire coarser walk finds nothing, the terminal case fires
  /// (`onMiss` or throw). A common pitfall: supplying only `onNow` in this
  /// mode means no count-bucket can fire; you must also supply `onMiss` or
  /// an explicit coarser callback.
  coarser,

  /// Walk finer first, then coarser, then `onNow` as an absolute last resort.
  ///
  /// The walk order is: finer count-buckets (hours → minutes → seconds →
  /// milliseconds), then coarser count-buckets (hours → days → months →
  /// years), then `onNow`. The first non-null callback fires. Finer
  /// count-buckets are always preferred over coarser ones, and `onNow` is
  /// deferred until everything else is exhausted.
  ///
  /// Example: matched = hours (missing), `onMillisecondsAgo` supplied (finer),
  /// `onDaysAgo` supplied (coarser) → fires milliseconds (finer preferred).
  /// Only if no finer count-bucket exists at all does it consult coarser ones;
  /// only if neither finer nor coarser exist does it fire `onNow`.
  ///
  /// If no callback is found anywhere, the terminal case fires (`onMiss` or
  /// throw).
  bidirectional,
}

enum _TimeAgoBucket { years, months, days, hours, minutes, seconds, milliseconds, now }
