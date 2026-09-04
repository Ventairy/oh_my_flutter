# String classification

`StringExtension` adds convenient operations to Dart strings.

## Values containing only digits

Use `isDigitsOnly` when a non-empty value must contain only the ASCII digits
from `0` to `9`:

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final isNumericIdentifier = '12345'.isDigitsOnly;
// true
```

The getter returns `false` for an empty string and for values containing
letters, whitespace, signs, decimal separators, or other characters.

See the
[generated API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/StringExtension.html)
for the complete member contract.
