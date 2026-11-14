import CoreVideo
import Foundation
import Metal

internal final class IOSDisintegrateMetalContext {
  internal let device: MTLDevice
  internal let commandQueue: MTLCommandQueue
  internal let pipeline: MTLRenderPipelineState
  internal let textureCache: CVMetalTextureCache

  internal init() throws {
    guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else {
      throw IOSDisintegrateError.unavailable("Metal is unavailable.")
    }
    self.device = device
    self.commandQueue = commandQueue
    let library = try Self.loadLibrary(device: device)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "omf_disintegrate_vertex")
    descriptor.fragmentFunction = library.makeFunction(name: "omf_disintegrate_fragment")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    descriptor.colorAttachments[0].isBlendingEnabled = true
    descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
    descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
    descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    var textureCache: CVMetalTextureCache?
    guard CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) == kCVReturnSuccess,
      let textureCache else {
      throw IOSDisintegrateError.unavailable("A Metal texture cache could not be created.")
    }
    self.textureCache = textureCache
  }

  private static func loadLibrary(device: MTLDevice) throws -> MTLLibrary {
    if let library = try? device.makeDefaultLibrary(bundle: .module) { return library }
    guard let url = Bundle.module.url(forResource: "Disintegrate", withExtension: "metal", subdirectory: "Motion")
      ?? Bundle.module.url(forResource: "Disintegrate", withExtension: "metal") else {
      throw IOSDisintegrateError.unavailable("The disintegration shader is unavailable.")
    }
    return try device.makeLibrary(source: String(contentsOf: url), options: nil)
  }
}
