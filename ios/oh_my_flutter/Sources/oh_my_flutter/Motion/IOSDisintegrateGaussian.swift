import Foundation
import Metal

internal final class IOSDisintegrateGaussian {
  // The texture sigma is capped at 8. Impeller's radius is at most sigma times square root of 3.
  private static let maximumRadius = 14
  private let pipeline: MTLRenderPipelineState
  private let scratch: MTLTexture
  private let horizontalStep: SIMD2<Float>
  private let verticalStep: SIMD2<Float>
  private var taps = [SIMD2<Float>](repeating: .zero, count: maximumRadius / 2)
  private var count = 0
  private var center: Float = 1
  private var previousSigma: Float = 0
  private var previousRadius = 0

  internal init(context: IOSDisintegrateMetalContext, width: Int, height: Int) throws {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    descriptor.storageMode = .private
    descriptor.usage = [.renderTarget, .shaderRead]
    guard let pipeline = context.gaussianPipeline, let scratch = context.device.makeTexture(descriptor: descriptor) else {
      throw IOSDisintegrateError.unavailable("The Metal Gaussian filter could not be initialized.")
    }
    self.pipeline = pipeline
    self.scratch = scratch
    horizontalStep = SIMD2(1 / Float(width), 0)
    verticalStep = SIMD2(0, 1 / Float(height))
  }

  internal static func makePipeline(device: MTLDevice, library: MTLLibrary) throws -> MTLRenderPipelineState {
    guard let vertex = library.makeFunction(name: "omf_disintegrate_gaussian_vertex"),
      let fragment = library.makeFunction(name: "omf_disintegrate_gaussian_fragment") else {
      throw IOSDisintegrateError.unavailable("The Metal Gaussian shaders are unavailable.")
    }
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = vertex
    descriptor.fragmentFunction = fragment
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    return try device.makeRenderPipelineState(descriptor: descriptor)
  }

  internal func encode(target: MTLTexture, sigma: Float, displaySigma: Float, commands: MTLCommandBuffer) throws {
    let displayRadius = max(0, Double(displaySigma) - 0.5) * sqrt(3.0)
    let radius = min(Self.maximumRadius, Int((displayRadius * Double(sigma) / Double(displaySigma)).rounded()))
    guard radius > 0 else { return }
    if previousSigma != sigma || previousRadius != radius { updateTaps(sigma: sigma, radius: radius) }

    // The target is held by the producer until all encoders complete.
    try encodePass(input: target, output: scratch, step: horizontalStep, commands: commands)
    try encodePass(input: scratch, output: target, step: verticalStep, commands: commands)
  }

  private func updateTaps(sigma: Float, radius: Int) {
    let inverseVariance = -0.5 / (Double(sigma) * Double(sigma))
    var sum = 1.0
    count = 0
    for tap in stride(from: 1, through: radius, by: 2) {
      let first = exp(Double(tap * tap) * inverseVariance)
      let second = tap < radius ? exp(Double((tap + 1) * (tap + 1)) * inverseVariance) : 0
      let weight = first + second
      if weight == 0 { break }
      taps[count] = SIMD2(Float(Double(tap) + second / weight), Float(weight))
      sum += 2 * weight
      count += 1
    }

    center = Float(1 / sum)
    for index in 0..<count { taps[index].y *= center }
    previousSigma = sigma
    previousRadius = radius
  }

  private func encodePass(input: MTLTexture, output: MTLTexture, step: SIMD2<Float>, commands: MTLCommandBuffer) throws {
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = output
    pass.colorAttachments[0].loadAction = .dontCare
    pass.colorAttachments[0].storeAction = .store
    guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else {
      throw IOSDisintegrateError.unavailable("The Gaussian command could not be created.")
    }
    var uniforms = Uniforms(step: step, center: center, count: UInt32(count))
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
    taps.withUnsafeBytes { bytes in
      encoder.setFragmentBytes(bytes.baseAddress!, length: count * MemoryLayout<SIMD2<Float>>.stride, index: 1)
    }
    encoder.setFragmentTexture(input, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
  }

  private struct Uniforms {
    let step: SIMD2<Float>
    let center: Float
    let count: UInt32
  }
}
