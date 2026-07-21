# Usage guide

## Relative time

`DateTimeExtension.timeAgo` classifies elapsed time and invokes only the
callback for the selected unit. Use `TimeAgoFallback` when callers intentionally
omit some units. Time is read from `clock.now`, which makes tests deterministic.

## Color and OKLCH

Use `StringExtension.hexToColor` for CSS-style hex values. `ColorExtension` and
`OklchExtension` expose perceptual color operations without leaking mutable state.

## Connectivity

`OfflineErrorDioInterceptor` converts requests that fail while the device is
offline into `OfflineConnectionDioException`. Configure it on the same Dio
instance as the rest of the application's error handling.

## External applications

`Telephony` and `Whatsapp` build and launch platform URIs. Their futures report
whether the target application accepted the launch request; consumers should
still provide a visible fallback when no handler is installed.
