import Flutter
import Foundation

@testable import oh_my_flutter

internal enum IOSDisintegrateTestFixture {
  internal static func configuration(overrides: [String: Any] = [:]) throws -> IOSDisintegrateConfiguration {
    return try IOSDisintegrateConfiguration(arguments: arguments(overrides: overrides))
  }

  internal static func arguments(overrides: [String: Any] = [:]) -> [String: Any] {
    var arguments: [String: Any] = [
      "width": 12, "height": 8, "viewportWidth": 12, "viewportHeight": 8,
      "originX": 0, "originY": 0, "scaleX": 1, "scaleY": 1,
      "maximumParticleCount": 6, "minimumCellSize": 4, "seed": 42,
      "geometryParameters": typedData([0.16, 0.04, 0.55, 0.45, 0.02, 0.08, 0.015, 0.075, 0.003, 0.01]),
      "motionParameters": typedData([5, 0.4, 0.7, 3, 0.1, 2]),
      "frame": typedData([0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0]),
    ]
    arguments.merge(overrides) { _, replacement in replacement }
    return arguments
  }

  internal static func typedData(_ values: [Double]) -> FlutterStandardTypedData {
    FlutterStandardTypedData(float64: values.withUnsafeBytes { Data($0) })
  }

  internal static func pixels(width: Int = 12, height: Int = 8, rgba: [UInt8] = [255, 0, 0, 255]) -> Data {
    Data((0..<(width * height)).flatMap { _ in rgba })
  }
}
