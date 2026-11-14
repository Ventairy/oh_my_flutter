import Flutter
import Foundation

internal struct IOSDisintegrateConfiguration {
  internal let width: Int
  internal let height: Int
  internal let viewportWidth: Int
  internal let viewportHeight: Int
  internal let originX: Float
  internal let originY: Float
  internal let scaleX: Float
  internal let scaleY: Float
  internal let maximumParticleCount: Int
  internal let minimumCellSize: Double
  internal let seed: UInt32
  internal let geometryParameters: [Double]
  internal let motionParameters: [Float]
  internal let initialFrame: [Float]

  internal init(arguments: [String: Any]) throws {
    width = try Self.positiveInteger(arguments["width"])
    height = try Self.positiveInteger(arguments["height"])
    viewportWidth = try Self.positiveInteger(arguments["viewportWidth"])
    viewportHeight = try Self.positiveInteger(arguments["viewportHeight"])
    originX = try Self.finiteFloat(arguments["originX"])
    originY = try Self.finiteFloat(arguments["originY"])
    scaleX = try Self.finiteFloat(arguments["scaleX"])
    scaleY = try Self.finiteFloat(arguments["scaleY"])
    maximumParticleCount = try Self.positiveInteger(arguments["maximumParticleCount"])
    guard let cellSize = arguments["minimumCellSize"] as? NSNumber,
      cellSize.doubleValue.isFinite, cellSize.doubleValue > 0,
      let seedValue = arguments["seed"] as? NSNumber,
      let seed = UInt32(exactly: seedValue.int64Value), seed != 0,
      scaleX > 0, scaleY > 0
    else {
      throw IOSDisintegrateError.invalidArguments("Expected a positive particle size, positive scales, and nonzero seed.")
    }
    minimumCellSize = cellSize.doubleValue
    self.seed = seed
    geometryParameters = try Self.values(from: arguments["geometryParameters"], count: 10)
    motionParameters = try Self.values(from: arguments["motionParameters"], count: 6).map(Float.init)
    initialFrame = try Self.frame(from: arguments["frame"])
    guard motionParameters.allSatisfy({ $0.isFinite }), motionParameters[0] > 0,
      motionParameters[4] >= 0, motionParameters[4] < 1, motionParameters[5] >= 0
    else {
      throw IOSDisintegrateError.invalidArguments("Expected finite motion parameters and valid fade and padding values.")
    }
  }

  internal static func frame(from value: Any?) throws -> [Float] {
    let frame = try values(from: value, count: 14).map(Float.init)
    guard frame.allSatisfy({ $0.isFinite }) else {
      throw IOSDisintegrateError.invalidArguments("Expected fourteen finite frame parameters.")
    }
    return frame
  }

  internal func makeUniforms(frame: [Float]) -> [Float] {
    [
      Float(width), Float(height), Float(viewportWidth), Float(viewportHeight),
      originX, originY, scaleX, scaleY,
    ] + frame + motionParameters
  }

  internal func matches(_ other: IOSDisintegrateConfiguration) -> Bool {
    width == other.width && height == other.height
      && viewportWidth == other.viewportWidth && viewportHeight == other.viewportHeight
      && originX == other.originX && originY == other.originY
      && scaleX == other.scaleX && scaleY == other.scaleY
      && maximumParticleCount == other.maximumParticleCount
      && minimumCellSize == other.minimumCellSize && seed == other.seed
      && geometryParameters == other.geometryParameters
      && motionParameters == other.motionParameters
  }

  private static func positiveInteger(_ value: Any?) throws -> Int {
    guard let number = value as? NSNumber, number.doubleValue.isFinite,
      let integer = Int(exactly: number.doubleValue), integer > 0
    else {
      throw IOSDisintegrateError.invalidArguments("Expected positive image dimensions and particle counts.")
    }
    return integer
  }

  private static func finiteFloat(_ value: Any?) throws -> Float {
    guard let number = value as? NSNumber, number.doubleValue.isFinite,
      number.floatValue.isFinite
    else {
      throw IOSDisintegrateError.invalidArguments("Expected finite geometry values.")
    }
    return number.floatValue
  }

  private static func values(from value: Any?, count: Int) throws -> [Double] {
    guard let typedData = value as? FlutterStandardTypedData,
      typedData.type == .float64, typedData.data.count == count * MemoryLayout<Double>.size
    else {
      throw IOSDisintegrateError.invalidArguments("Expected \(count) Float64 parameters.")
    }
    let values = typedData.data.withUnsafeBytes { bytes in
      (0..<count).map { index in
        bytes.loadUnaligned(fromByteOffset: index * MemoryLayout<Double>.stride, as: Double.self)
      }
    }
    guard values.allSatisfy({ $0.isFinite }) else {
      throw IOSDisintegrateError.invalidArguments("Expected finite parameters.")
    }
    return values
  }

}
