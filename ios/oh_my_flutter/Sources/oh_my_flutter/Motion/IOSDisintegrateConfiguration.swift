import Flutter
import Foundation

internal struct IOSDisintegrateConfiguration {
  internal static let particleFrameCount = 14
  private static let maximumGaussianDimension = 2048
  private static let maximumGaussianPixels = 640 * 1024
  private static let maximumTextureSigma = 8.0

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
  internal let nativeGaussian: Bool

  internal init(arguments: [String: Any]) throws {
    width = try Self.positiveInteger(arguments["width"])
    height = try Self.positiveInteger(arguments["height"])
    viewportWidth = try Self.positiveInteger(arguments["viewportWidth"])
    viewportHeight = try Self.positiveInteger(arguments["viewportHeight"])
    nativeGaussian = arguments["nativeGaussian"] as? Bool == true
    if nativeGaussian &&
      (viewportWidth > Self.maximumGaussianDimension || viewportHeight > Self.maximumGaussianDimension ||
        viewportWidth * viewportHeight > Self.maximumGaussianPixels) {
      throw IOSDisintegrateError.unavailable("The Gaussian viewport exceeds the native texture budget.")
    }
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
    initialFrame = try Self.frame(from: arguments["frame"], nativeGaussian: nativeGaussian)
    guard motionParameters.allSatisfy({ $0.isFinite }), motionParameters[0] > 0,
      motionParameters[4] >= 0, motionParameters[4] < 1, motionParameters[5] >= 0
    else {
      throw IOSDisintegrateError.invalidArguments("Expected finite motion parameters and valid fade and padding values.")
    }
  }

  internal static func frame(from value: Any?, nativeGaussian: Bool = false) throws -> [Float] {
    let count = particleFrameCount + (nativeGaussian ? 2 : 0)
    let parameters = try values(from: value, count: count)
    let frame = parameters.map(Float.init)
    guard frame.allSatisfy({ $0.isFinite }) else {
      throw IOSDisintegrateError.invalidArguments("Expected \(count) finite frame parameters.")
    }
    if nativeGaussian {
      let textureSigma = parameters[particleFrameCount]
      let displaySigma = parameters[particleFrameCount + 1]
      if textureSigma < 0 || textureSigma > maximumTextureSigma || displaySigma < 0 ||
        (textureSigma == 0) != (displaySigma == 0) ||
        (frame[particleFrameCount] == 0) != (frame[particleFrameCount + 1] == 0) {
        throw IOSDisintegrateError.invalidArguments("Expected consistent Gaussian sigmas within the native texture limit.")
      }
    }
    return frame
  }

  internal func makeUniforms(frame: [Float]) -> [Float] {
    [
      Float(width), Float(height), Float(viewportWidth), Float(viewportHeight),
      originX, originY, scaleX, scaleY,
    ] + frame.prefix(Self.particleFrameCount) + motionParameters
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
      && nativeGaussian == other.nativeGaussian
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
