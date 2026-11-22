# CountdownBuilder

Use `CountdownBuilder` to show how much time remains before an action becomes
available, an offer ends, or an event begins. Supply the deadline and update
interval. The builder receives the remaining time as a `Duration`.

```dart
import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Widget resendCountdown(DateTime resendAvailableAt) {
  return CountdownBuilder(
    endsAt: resendAvailableAt,
    updateInterval: const Duration(seconds: 1),
    builder: (context, remaining) {
      if (remaining == Duration.zero) return const Text('Ready to resend');
      final seconds = (remaining.inMicroseconds / Duration.microsecondsPerSecond).ceil();
      return Text('Resend in $seconds s');
    },
  );
}
```

The builder receives a value immediately. The interval is measured backward
from the deadline, so separate widgets can show the same countdown even when
they appear at different times. Choose how to display the supplied duration.

An optional `onComplete` callback runs once after the countdown displays zero
for a deadline that was active while mounted. A deadline already reached when
supplied displays zero immediately. When the app resumes, the countdown catches
up and completes if its active deadline passed in the background.
