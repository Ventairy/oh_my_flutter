# Debouncer

Use `Debouncer<T>` to wait until repeated calls stop before running the latest
value-producing callback.

Create one debouncer for each independently debounced operation and retain it
for as long as that operation remains active:

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final addressSearchDebouncer = Debouncer<List<String>>(
  delay: const Duration(milliseconds: 300),
);

final suggestions = await addressSearchDebouncer(
  () => searchAddresses(query),
);
```

The callback may return either `T` or `Future<T>`. Errors thrown by the latest
callback are forwarded through the returned future.

## Replace pending calls

Calling the debouncer again before its delay finishes restarts the delay and
replaces the pending callback. Calls in that pending burst share one future, so
all of their awaiters receive the latest callback's value or error.

```dart
final first = addressSearchDebouncer(() => searchAddresses('Avenida'));
final second = addressSearchDebouncer(() => searchAddresses('Avenida Paulista'));

final firstSuggestions = await first;
final secondSuggestions = await second;
```

Only the `Avenida Paulista` callback runs. Both variables receive its result.
Keep any input that must remain associated with a particular result inside the
callback or its returned value.

By default, a later call also cancels the result of a callback that already
started. The earlier future completes with `DebouncerCanceledException`. Its
underlying work continues, but the debouncer consumes and discards its eventual
value or error.

Allow running callbacks to complete independently when every result is still
relevant:

```dart
final saveDebouncer = Debouncer<void>(
  delay: const Duration(milliseconds: 300),
  switchLatest: false,
);
```

Use cancellation supported by the underlying operation when already-running
work must actually stop and release its resources.

## Cancel a pending call

Cancel when the pending work is no longer relevant, such as when a search field
is cleared:

```dart
final pendingSuggestions = addressSearchDebouncer(
  () => searchAddresses(query),
);

addressSearchDebouncer.cancel();

try {
  final suggestions = await pendingSuggestions;
  showSuggestions(suggestions);
} on DebouncerCanceledException {
  // The pending search was intentionally abandoned.
}
```

Cancellation prevents a pending callback from starting and discards results
from callbacks already running. Their futures complete with
`DebouncerCanceledException`. The debouncer remains usable for later calls.

## Dispose with the owner

Dispose the debouncer when its widget, controller, provider, or other owner is
released:

```dart
@override
void dispose() {
  addressSearchDebouncer.dispose();
  super.dispose();
}
```

Disposal cancels pending and running results with
`DebouncerCanceledException` and permanently closes the debouncer. Calling it
afterward throws `StateError`. Repeated `cancel()` and `dispose()` calls are
safe.

See the [generated API reference](../api/oh_my_flutter/Debouncer-class.html)
for the complete member contracts.
