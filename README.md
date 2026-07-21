# oh_my_flutter

[![CI](https://github.com/Cataqui/oh_my_flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/Cataqui/oh_my_flutter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Cataqui/oh_my_flutter/blob/main/LICENSE)
[![pub package](https://img.shields.io/pub/v/oh_my_flutter.svg)](https://pub.dev/packages/oh_my_flutter)

Focused, strongly typed utilities for everyday Flutter applications: relative
time, colors and OKLCH, gesture velocity, offline Dio failures, phone calls, and
WhatsApp links.

## Install

Until the first pub.dev release, use the immutable GitHub tag:

```yaml
dependencies:
  oh_my_flutter:
    git:
      url: https://github.com/Cataqui/oh_my_flutter.git
      ref: v0.1.0
```

After publication, use `oh_my_flutter: ^0.1.0`.

## Quick start

```dart
import 'package:clock/clock.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

final label = withClock(
  Clock.fixed(DateTime.utc(2026, 1, 1, 12)),
  () => DateTime.utc(2026, 1, 1, 11, 55).timeAgo<String>(
    onMinutesAgo: (minutes) => '$minutes minutes ago',
  ),
);

final accent = '#FF4A4B'.hexToColor();
```

See the runnable [example](https://github.com/Cataqui/oh_my_flutter/blob/main/example/lib/main.dart), the generated
[API reference](https://pub.dev/documentation/oh_my_flutter/latest/), and the
[usage guide](https://github.com/Cataqui/oh_my_flutter/blob/main/doc/usage.md).

## Scope

- Deterministic relative-time bucketing through `package:clock`.
- Flutter `Color` conversion, luminance helpers, and OKLCH interpolation.
- Gesture velocity thresholds.
- Typed offline Dio interception.
- `tel:` and WhatsApp URI launching.

The package does not include application state, routing, localization, design
components, or Cataquí-specific domain logic.

## Contributing and security

Read [CONTRIBUTING.md](https://github.com/Cataqui/oh_my_flutter/blob/main/CONTRIBUTING.md) before opening a pull
request. Report vulnerabilities privately as described in the
[security policy](https://github.com/Cataqui/oh_my_flutter/blob/main/SECURITY.md).
