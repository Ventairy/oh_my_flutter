# Detect TestFlight installations

Use `isTestFlight` to offer beta testers a feedback button or another
preview feature. Read it after Flutter binding initialization, for example
from a button handler.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

Future<String> feedbackLabel() async {
  if (await isTestFlight) return 'Send beta feedback';
  return 'Send feedback';
}
```

The result is true when Apple confirms a TestFlight installation on an iPhone
or iPad running 17.4 or later. App Store and local development installations,
simulators, earlier OS versions, and all other platforms (including macOS
TestFlight) return false. If Apple temporarily cannot determine the source,
the check returns false and a later call tries again.
