# Double validation

`DoubleExtension` adds convenient operations to Flutter doubles.

## Positive finite values

Use `isPositiveFinite` when a value must be both finite and strictly greater
than zero:

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final width = 320.0;

if (width.isPositiveFinite) {
  useWidth(width);
}
```

The getter returns `false` for positive and negative infinity, `NaN`, zero,
negative zero, and every negative value.

See the
[generated API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/DoubleExtension.html)
for the complete member contract.
