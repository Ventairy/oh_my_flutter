import CoreVideo
import Flutter
import Foundation
import QuartzCore

internal final class IOSDisintegrateScene: NSObject {
  internal let configuration: IOSDisintegrateConfiguration
  internal private(set) var textureId: Int64 = 0

  private let registry: FlutterTextureRegistry
  private let renderQueue: DispatchQueue
  private let makeContext: () throws -> IOSDisintegrateMetalContext
  private let output = IOSDisintegrateTexture()
  private var renderer: IOSDisintegrateRenderer?
  private var imageHandle: Int64 = 0
  private var acquiredHandle: Int64 = 0
  private var isPrepared = false
  private var isClosed = false
  private var isRendering = false
  private var firstFrameResult: FlutterResult?
  private var playbackResult: FlutterResult?
  private var displayLink: CADisplayLink?
  private var playbackStart: CFTimeInterval = 0
  private var playbackDuration: CFTimeInterval = 0
  private var playbackProgress: Float = 0

  internal init(configuration: IOSDisintegrateConfiguration, registry: FlutterTextureRegistry,
    renderQueue: DispatchQueue, makeContext: @escaping () throws -> IOSDisintegrateMetalContext) {
    self.configuration = configuration
    self.registry = registry
    self.renderQueue = renderQueue
    self.makeContext = makeContext
    super.init()
    output.onImageAcquired = { [weak self] handle in self?.imageAcquired(handle) }
    output.onUnregistered = { [weak self] in self?.close() }
    textureId = registry.register(output)
  }

  internal func matches(_ configuration: IOSDisintegrateConfiguration) -> Bool {
    !isClosed && self.configuration.matches(configuration)
  }

  internal func containsImage(textureId: Int64, handle: Int64) -> Bool {
    !isClosed && self.textureId == textureId && imageHandle == handle
  }

  internal func prepareImage(_ pixels: Data, handle: Int64, frame: [Float], result: @escaping FlutterResult) {
    stopPlayback(code: "replaced", message: "The disintegration was replaced.")
    finishFirstFrame(error: FlutterError(code: "replaced", message: "The disintegration was replaced.", details: nil))
    imageHandle = handle
    acquiredHandle = 0
    isPrepared = false
    output.clear()
    renderQueue.async {
      do {
        if self.renderer == nil {
          self.renderer = try IOSDisintegrateRenderer(configuration: self.configuration, context: self.makeContext())
        }
        try self.renderer!.uploadImage(pixels, frame: frame)
        self.renderer!.render(progress: frame[0]) { renderResult in
          DispatchQueue.main.async {
            guard self.containsImage(textureId: self.textureId, handle: handle) else {
              result(FlutterError(code: "replaced", message: "The disintegration was replaced.", details: nil))
              return
            }
            switch renderResult {
            case .success(let image):
              self.isPrepared = true
              self.output.publish(image, handle: handle)
              self.registry.textureFrameAvailable(self.textureId)
              var response: [String: Any] = ["textureId": self.textureId, "handle": handle]
              if self.configuration.nativeGaussian {
                response["nativeGaussian"] = true
                response["textureWidth"] = CVPixelBufferGetWidth(image)
                response["textureHeight"] = CVPixelBufferGetHeight(image)
              }
              result(response)
            case .failure(let error): result(Self.flutterError(error))
            }
          }
        }
      } catch {
        DispatchQueue.main.async { result(Self.flutterError(error)) }
      }
    }
  }

  internal func awaitFirstFrame(result: @escaping FlutterResult) {
    guard isPrepared && !isClosed else {
      result(FlutterError(code: "disposed", message: "The source image was disposed.", details: nil))
      return
    }
    if acquiredHandle == imageHandle { result(nil); return }
    finishFirstFrame(error: FlutterError(code: "replaced", message: "The first image wait was replaced.", details: nil))
    firstFrameResult = result
  }

  internal func play(from progress: Float, duration: CFTimeInterval, result: @escaping FlutterResult) {
    guard isPrepared && !isClosed else {
      result(FlutterError(code: "disposed", message: "The source image was disposed.", details: nil))
      return
    }
    stopPlayback(code: "replaced", message: "The disintegration playback was replaced.")
    playbackResult = result
    playbackProgress = progress
    playbackDuration = duration
    playbackStart = CACurrentMediaTime()
    let displayLink = CADisplayLink(target: self, selector: #selector(displayFrame(_:)))
    displayLink.preferredFrameRateRange = .default
    self.displayLink = displayLink
    displayLink.add(to: .main, forMode: .common)
  }

  internal func setFrame(_ frame: [Float], result: @escaping FlutterResult) {
    render(progress: frame[0], frame: frame, result: result)
  }

  internal func pause() {
    stopPlayback(code: "paused", message: "The disintegration was paused.")
  }

  internal func releaseImage(result: @escaping FlutterResult) {
    isPrepared = false
    imageHandle = 0
    stopPlayback(code: "disposed", message: "The source image was disposed.")
    finishFirstFrame(error: FlutterError(code: "disposed", message: "The source image was disposed.", details: nil))
    output.clear()
    renderQueue.async {
      self.renderer?.releaseImage()
      DispatchQueue.main.async { result(nil) }
    }
  }

  internal func close() {
    guard !isClosed else { return }
    isClosed = true
    isPrepared = false
    stopPlayback(code: "disposed", message: "The renderer was released.")
    finishFirstFrame(error: FlutterError(code: "disposed", message: "The renderer was released.", details: nil))
    output.clear()
    registry.unregisterTexture(textureId)
    renderQueue.async { self.renderer = nil }
  }

  private static func flutterError(_ error: Error) -> FlutterError {
    FlutterError(code: "render_failed", message: String(describing: error), details: nil)
  }

  private func imageAcquired(_ handle: Int64) {
    guard !isClosed && handle == imageHandle else { return }
    acquiredHandle = handle
    finishFirstFrame(error: nil)
  }

  private func finishFirstFrame(error: FlutterError?) {
    let result = firstFrameResult
    firstFrameResult = nil
    result?(error)
  }

  private func stopPlayback(code: String?, message: String? = nil) {
    displayLink?.invalidate()
    displayLink = nil
    let result = playbackResult
    playbackResult = nil
    if let code { result?(FlutterError(code: code, message: message, details: nil)) }
    else { result?(nil) }
  }

  @objc private func displayFrame(_ displayLink: CADisplayLink) {
    let elapsed = min(1, max(0, (displayLink.targetTimestamp - playbackStart) / playbackDuration))
    let progress = playbackProgress + (1 - playbackProgress) * Float(elapsed)
    let handle = imageHandle
    render(progress: progress, frame: nil) { [weak self] value in
      guard let self, self.containsImage(textureId: self.textureId, handle: handle),
        let error = value as? FlutterError else { return }
      self.stopPlayback(code: error.code, message: error.message)
    }
    if elapsed >= 1 { stopPlayback(code: nil) }
  }

  private func render(progress: Float, frame: [Float]?, result: @escaping FlutterResult) {
    guard !isClosed else {
      result(FlutterError(code: "disposed", message: "The renderer was released.", details: nil))
      return
    }
    if isRendering { result(nil); return }
    isRendering = true
    let handle = imageHandle
    renderQueue.async {
      if let frame { self.renderer?.setFrame(frame) }
      guard let renderer = self.renderer else {
        DispatchQueue.main.async {
          self.isRendering = false
          result(FlutterError(code: "disposed", message: "The renderer was released.", details: nil))
        }
        return
      }
      renderer.render(progress: progress) { renderResult in
        DispatchQueue.main.async {
          self.isRendering = false
          guard self.containsImage(textureId: self.textureId, handle: handle) else {
            result(FlutterError(code: "replaced", message: "The disintegration was replaced.", details: nil))
            return
          }
          switch renderResult {
          case .success(let image):
            self.output.publish(image, handle: handle)
            self.registry.textureFrameAvailable(self.textureId)
            result(nil)
          case .failure(IOSDisintegrateError.outputBusy): result(nil)
          case .failure(let error): result(Self.flutterError(error))
          }
        }
      }
    }
  }
}
