import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/widgets/native_selectable_text/pigeon/native_selectable_text.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/dev/ventairy/oh_my_flutter/NativeSelectableText.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.ventairy.oh_my_flutter',
      errorClassName: 'NativeSelectableTextPigeonError',
    ),
    swiftOut: 'ios/oh_my_flutter/Sources/oh_my_flutter/NativeSelectableText.g.swift',
    swiftOptions: SwiftOptions(
      errorClassName: 'NativeSelectableTextPigeonError',
    ),
    cppHeaderOut: 'windows/native_selectable_text.g.h',
    cppSourceOut: 'windows/native_selectable_text.g.cpp',
    cppOptions: CppOptions(namespace: 'oh_my_flutter'),
    gobjectHeaderOut: 'linux/native_selectable_text.g.h',
    gobjectSourceOut: 'linux/native_selectable_text.g.cc',
    gobjectOptions: GObjectOptions(module: 'OhMyFlutter'),
    dartPackageName: 'oh_my_flutter',
  ),
)
/// Carries a Flutter logical-pixel rectangle to a native menu host.
class NativeSelectableTextRectangleMessage {
  /// Creates a rectangle message.
  NativeSelectableTextRectangleMessage({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// The horizontal coordinate of the leading edge.
  final double left;

  /// The vertical coordinate of the upper edge.
  final double top;

  /// The horizontal coordinate of the trailing edge.
  final double right;

  /// The vertical coordinate of the lower edge.
  final double bottom;
}

/// Carries a Flutter logical-pixel point to a native menu host.
class NativeSelectableTextPointMessage {
  /// Creates a point message.
  NativeSelectableTextPointMessage({required this.dx, required this.dy});

  /// The horizontal coordinate.
  final double dx;

  /// The vertical coordinate.
  final double dy;
}

/// Describes one labeled native selection-menu command.
class NativeSelectableTextMenuItemMessage {
  /// Creates a menu item whose identifier routes its callback to Flutter.
  NativeSelectableTextMenuItemMessage({
    required this.identifier,
    required this.label,
  });

  /// The identifier returned when the person chooses this item.
  final int identifier;

  /// The localized label displayed by the platform menu.
  final String label;
}

/// Describes one native selection-menu presentation.
class NativeSelectableTextMenuRequestMessage {
  /// Creates a presentation request.
  NativeSelectableTextMenuRequestMessage({
    required this.sessionIdentifier,
    required this.selectionRectangle,
    required this.primaryAnchor,
    required this.items,
  });

  /// Identifies this presentation and rejects callbacks from older menus.
  final int sessionIdentifier;

  /// The selected glyph bounds in Flutter global logical pixels.
  final NativeSelectableTextRectangleMessage selectionRectangle;

  /// The preferred pointer or keyboard anchor in global logical pixels.
  final NativeSelectableTextPointMessage primaryAnchor;

  /// The ordered commands shown by the menu.
  final List<NativeSelectableTextMenuItemMessage> items;
}

/// Presents selection commands through the current native host.
@HostApi()
abstract class NativeSelectableTextMenuHostApi {
  /// Shows a native menu and reports whether presentation was accepted.
  bool show(NativeSelectableTextMenuRequestMessage request);

  /// Updates an already visible native menu.
  bool update(NativeSelectableTextMenuRequestMessage request);

  /// Updates only the current selection rectangle and primary anchor.
  ///
  /// [geometry] contains left, top, right, bottom, anchor dx, and anchor dy in
  /// Flutter global logical pixels, in that order.
  bool updateGeometry(int sessionIdentifier, Float64List geometry);

  /// Hides the menu for [sessionIdentifier] when it is still current.
  void hide(int sessionIdentifier);
}

/// Delivers native selection-menu events to Flutter.
@FlutterApi()
abstract class NativeSelectableTextMenuFlutterApi {
  /// Invokes a command previously sent for [sessionIdentifier].
  @asyncCallback
  void onAction(int sessionIdentifier, int actionIdentifier);

  /// Reports that a menu closed and whether a command caused the dismissal.
  @asyncCallback
  // Pigeon APIs support positional parameters only.
  // ignore: avoid_positional_boolean_parameters
  void onDismissed(int sessionIdentifier, bool actionInvoked);
}
