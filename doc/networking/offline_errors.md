# Offline Dio errors

Add `OfflineErrorDioInterceptor` when callers need to distinguish confirmed
offline failures from other Dio errors without scattering connectivity probes
through application code.

## Install the interceptor

```dart
final dio = Dio()
  ..interceptors.add(OfflineErrorDioInterceptor());
```

Connection-related failures trigger an internet-access check. If the device is
offline, the resulting `DioException.error` contains an
`OfflineConnectionDioException`. The original failure remains available as its
cause.

## Detect an offline result

```dart
try {
  await dio.get('/jobs');
} on DioException catch (error) {
  if (error.isOfflineConnectionDioException) {
    showOfflineState();
    return;
  }

  rethrow;
}
```

The detection extension does not perform a network check itself; it recognizes
the typed result produced by the interceptor. Certificate, cancellation, and
transform-timeout errors are not treated as offline candidates. See the
[API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/OfflineErrorDioInterceptor-class.html)
for the complete error classification.
