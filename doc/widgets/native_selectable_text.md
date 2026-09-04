# Native selectable text

`NativeSelectableText` displays text with Flutter's layout, selection
highlight, handles, magnifier, and accessibility behavior while presenting the
selection commands with the operating system's native menu when available.
Use it for text that people should be able to copy or select without giving up
Flutter's text rendering.

## Select plain text

```dart
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

const NativeSelectableText(
  'Long-press or right-click to select and copy this text.',
  style: TextStyle(fontSize: 16),
)
```

The widget follows the same wrapping, scaling, direction, locale, emoji
fallback, and selection rendering as Flutter's `SelectableText`.

## Select styled text

Use `NativeSelectableText.rich` when parts of the text need different styles:

```dart
const NativeSelectableText.rich(
  TextSpan(
    text: 'Native menu, ',
    children: [
      TextSpan(
        text: 'Flutter-rendered text.',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ],
  ),
)
```

As with Flutter's `SelectableText.rich`, every entry in `TextSpan.children`
must also be a `TextSpan`.

## Platform behavior

Android 24 and later, iOS 16 and later, macOS, Windows, and Linux use a menu
rendered by their native UI toolkit. The operating system chooses the menu's
final placement and handles screen-edge avoidance and dismissal.

Flutter's adaptive selection toolbar is used on iOS 15 and earlier, web,
Fuchsia, and whenever a supported native host cannot present the menu. Text
selection remains usable when this fallback occurs.

Available commands and their localized labels come from Flutter's current
selection state. Choosing a command therefore preserves Flutter's ordinary
Copy and Select All behavior. Tapping outside the text or menu clears its
focus and selection; choosing a menu command is not treated as an outside tap.

`NativeSelectableText` owns menu presentation and does not expose
`contextMenuBuilder`. Supply `selectionControls` only when the controls
implement Flutter's handle-only `TextSelectionHandleControls` contract.
Legacy controls that also build a toolbar are rejected in debug builds. Use
Flutter's `SelectableText` instead when the application needs a custom or
Flutter-rendered menu.

See the [API reference][api] for the complete set of text, cursor, scrolling,
magnifier, and selection options. When selectable text is inside nested
scrollables without a `Scaffold`, follow Flutter's
[`SelectableText` scrolling guidance][selectable-text].

[api]: https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/NativeSelectableText-class.html
[selectable-text]: https://api.flutter.dev/flutter/material/SelectableText-class.html
