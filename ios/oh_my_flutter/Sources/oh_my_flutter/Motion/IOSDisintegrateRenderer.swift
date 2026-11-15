import CoreVideo
import Foundation
import Metal

internal final class IOSDisintegrateRenderer {
  internal let configuration: IOSDisintegrateConfiguration

  private let context: IOSDisintegrateMetalContext
  private let particleCount: Int
  private let maximumCellWidth: Double
  private let maximumCellHeight: Double
  private let vertices: MTLBuffer
  private let pixelBufferPool: CVPixelBufferPool
  private var uniforms: [Float]
  private var image: MTLTexture?

  internal init(configuration: IOSDisintegrateConfiguration, context: IOSDisintegrateMetalContext) throws {
    self.configuration = configuration
    self.context = context
    let geometry = IOSDisintegrateGeometry(configuration: configuration)
    particleCount = geometry.particleCount
    maximumCellWidth = geometry.maximumCellWidth
    maximumCellHeight = geometry.maximumCellHeight
    uniforms = configuration.makeUniforms(frame: configuration.initialFrame)
    guard let vertices = geometry.attributes.withUnsafeBytes({ bytes in
      context.device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
    }) else {
      throw IOSDisintegrateError.unavailable("The particle geometry could not be uploaded.")
    }
    self.vertices = vertices
    let attributes: [String: Any] = [
      kCVPixelBufferWidthKey as String: configuration.viewportWidth,
      kCVPixelBufferHeightKey as String: configuration.viewportHeight,
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferMetalCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:],
    ]
    var pool: CVPixelBufferPool?
    guard CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess, let pool else {
      throw IOSDisintegrateError.unavailable("The output pixel buffer pool could not be created.")
    }
    pixelBufferPool = pool
  }

  internal func uploadImage(_ pixels: Data, frame: [Float]) throws {
    guard pixels.count == configuration.width * configuration.height * 4 else {
      throw IOSDisintegrateError.invalidArguments("Expected RGBA bytes matching the source dimensions.")
    }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
      width: configuration.width, height: configuration.height, mipmapped: false)
    descriptor.usage = .shaderRead
    descriptor.storageMode = .shared
    image = context.device.makeTexture(descriptor: descriptor)
    guard let image else { throw IOSDisintegrateError.unavailable("The source image could not be uploaded.") }
    pixels.withUnsafeBytes { bytes in
      image.replace(region: MTLRegionMake2D(0, 0, configuration.width, configuration.height),
        mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: configuration.width * 4)
    }
    setFrame(frame)
  }

  internal func setFrame(_ frame: [Float]) {
    for index in frame.indices { uniforms[8 + index] = frame[index] }
  }

  internal func render(progress: Float, completion: @escaping (Result<CVPixelBuffer, Error>) -> Void) {
    guard let image else {
      completion(.failure(IOSDisintegrateError.unavailable("The source image was released.")))
      return
    }
    let a = Double(uniforms[9] * uniforms[13] - uniforms[10] * uniforms[14])
    let b = Double(uniforms[10] * uniforms[13] + uniforms[9] * uniforms[14])
    let width = maximumCellWidth * Double(configuration.scaleX)
    let height = maximumCellHeight * Double(configuration.scaleY)
    let pointSize = ceil(max(width * abs(a) + height * abs(b), width * abs(b) + height * abs(a)))
      + Double(configuration.motionParameters[5])
    guard pointSize <= 511 else {
      completion(.failure(IOSDisintegrateError.unavailable("Particles exceed Metal's point-size limit.")))
      return
    }
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pixelBufferPool,
      [kCVPixelBufferPoolAllocationThresholdKey as String: 3] as CFDictionary, &pixelBuffer)
    if status == kCVReturnWouldExceedAllocationThreshold {
      completion(.failure(IOSDisintegrateError.outputBusy))
      return
    }
    guard status == kCVReturnSuccess, let pixelBuffer else {
      completion(.failure(IOSDisintegrateError.unavailable("No output buffer is available (\(status)).")))
      return
    }
    var wrappedTexture: CVMetalTexture?
    let textureAttributes = [kCVMetalTextureUsage as String:
      MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue] as CFDictionary
    guard CVMetalTextureCacheCreateTextureFromImage(nil, context.textureCache, pixelBuffer, textureAttributes, .bgra8Unorm,
      configuration.viewportWidth, configuration.viewportHeight, 0, &wrappedTexture) == kCVReturnSuccess,
      let wrappedTexture, let target = CVMetalTextureGetTexture(wrappedTexture),
      let commands = context.commandQueue.makeCommandBuffer() else {
      completion(.failure(IOSDisintegrateError.unavailable("The output texture could not be created.")))
      return
    }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else {
      completion(.failure(IOSDisintegrateError.unavailable("The render command could not be created.")))
      return
    }
    uniforms[8] = progress
    encoder.setRenderPipelineState(context.pipeline)
    encoder.setVertexBuffer(vertices, offset: 0, index: 0)
    uniforms.withUnsafeBytes { bytes in
      encoder.setVertexBytes(bytes.baseAddress!, length: bytes.count, index: 1)
      encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 1)
    }
    encoder.setFragmentTexture(image, index: 0)
    if progress < 1 { encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount) }
    encoder.endEncoding()
    commands.addCompletedHandler { command in
      withExtendedLifetime(wrappedTexture) {
        if let error = command.error { completion(.failure(error)) }
        else { completion(.success(pixelBuffer)) }
      }
    }
    commands.commit()
  }

  internal func releaseImage() { image = nil }
}
