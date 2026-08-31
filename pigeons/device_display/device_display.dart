import 'package:pigeon/pigeon.dart';

// Pigeon resolves types only from its input compilation unit, so this schema
// intentionally keeps its related declarations together.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/device/device_display/pigeon/android_device_display.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/dev/ventairy/oh_my_flutter/device_display/AndroidDeviceDisplay.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.ventairy.oh_my_flutter.device_display',
    ),
    dartPackageName: 'oh_my_flutter',
  ),
)
/// Defines the Android host operations used by the display implementation.
@HostApi()
// Pigeon host APIs must be abstract even when they expose a single operation.
// ignore: one_member_abstracts
abstract class AndroidDeviceDisplayApi {
  /// Returns the current display corner radii in physical pixels.
  AndroidDeviceDisplayCornerRadii? getCornerRadii(
    AndroidDeviceDisplayGeometry geometry,
  );
}

/// Identifies the Flutter view geometry requesting Android display evidence.
class AndroidDeviceDisplayGeometry {
  /// Creates a physical-pixel geometry snapshot.
  AndroidDeviceDisplayGeometry({
    required this.displayWidth,
    required this.displayHeight,
    required this.viewWidth,
    required this.viewHeight,
  });

  /// The full Flutter display width in physical pixels.
  final double displayWidth;

  /// The full Flutter display height in physical pixels.
  final double displayHeight;

  /// The requesting Flutter view width in physical pixels.
  final double viewWidth;

  /// The requesting Flutter view height in physical pixels.
  final double viewHeight;
}

/// Carries Android display corner radii across the platform channel.
class AndroidDeviceDisplayCornerRadii {
  /// Creates a message with current-orientation physical-pixel radii.
  AndroidDeviceDisplayCornerRadii({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  /// The top-left corner radius in physical pixels.
  final double topLeft;

  /// The top-right corner radius in physical pixels.
  final double topRight;

  /// The bottom-right corner radius in physical pixels.
  final double bottomRight;

  /// The bottom-left corner radius in physical pixels.
  final double bottomLeft;
}
