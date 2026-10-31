import 'package:meta/meta.dart';

/// Provides a timed acceleration reading for responding to device movement.
///
/// Values include gravity and use meters per second squared. Axes remain fixed
/// to the device's reference orientation, regardless of app rotation.
@immutable
final class DeviceAccelerometerSample {
  /// Creates a reading with finite acceleration values and a nonnegative time.
  new({required this.x, required this.y, required this.z, required this.timestamp})
    : assert(x > double.negativeInfinity && x < double.infinity, 'x must be finite'),
      assert(y > double.negativeInfinity && y < double.infinity, 'y must be finite'),
      assert(z > double.negativeInfinity && z < double.infinity, 'z must be finite'),
      assert(!timestamp.isNegative, 'timestamp must not be negative');

  /// Acceleration along the device's left-to-right axis, including gravity.
  final double x;

  /// Acceleration along the device's bottom-to-top axis, including gravity.
  final double y;

  /// Acceleration perpendicular to the screen, positive outward from it.
  ///
  /// A stationary, face-up device normally reports approximately +9.81 m/s².
  final double z;

  /// When the reading was measured, on the device's monotonic uptime clock.
  ///
  /// Subtract timestamps to find elapsed measurement time. This is not a
  /// calendar date, and its origin must not be compared across devices or boots.
  /// Subscriptions resumed after background suspension can have a time gap.
  final Duration timestamp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceAccelerometerSample &&
          other.x == x &&
          other.y == y &&
          other.z == z &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(x, y, z, timestamp);

  @override
  String toString() => 'DeviceAccelerometerSample(x: $x, y: $y, z: $z, timestamp: $timestamp)';
}
