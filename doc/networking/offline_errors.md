# Offline Dio errors

Add `OfflineErrorDioInterceptor` when callers need a conservative offline result
for connection-like Dio failures without scattering connectivity probes through
application code.

## Install the interceptor

```dart
import 'package:dio/dio.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

final dio = Dio()
  ..interceptors.add(OfflineErrorDioInterceptor());
```

Bad-response, connection, connection-timeout, receive-timeout, send-timeout,
and unknown failures trigger an internet-access check with a five-second
limit. If that probe reports online, the original `DioException` continues
unchanged. If the probe reports offline, throws, or times out, the resulting
`DioException.error` contains an `OfflineConnectionDioException`. Treat this as
an offline-safe fallback rather than proof that the network is physically
disconnected.

## Detect an offline result

```dart
try {
  await dio.get('/jobs');
} on DioException catch (error) {
  if (error.isOfflineConnectionDioException) {
    final original =
        (error.error as OfflineConnectionDioException).cause;
    showOfflineState();
    return;
  }

  rethrow;
}
```

The detection extension does not perform a network check itself; it recognizes
the typed result produced by the interceptor. Certificate, cancellation, and
transform-timeout errors are not treated as offline candidates. The original
failure remains available through `OfflineConnectionDioException.cause` when
logging or retry logic needs it.
