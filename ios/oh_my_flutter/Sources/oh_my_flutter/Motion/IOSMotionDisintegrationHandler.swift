import CoreVideo
import Flutter
import Foundation

internal final class IOSMotionDisintegrationHandler {
  private let channel: FlutterMethodChannel
  private let registry: FlutterTextureRegistry
  private let renderQueue = DispatchQueue(label: "dev.ventairy.oh_my_flutter.disintegrate", qos: .userInteractive, autoreleaseFrequency: .workItem)
  private var context: IOSDisintegrateMetalContext?
  private var rendererReadiness = RendererReadiness.cold
  private var scenes: [Int64: IOSDisintegrateScene] = [:]
  private var nextHandle: Int64 = 0

  internal init(binaryMessenger: FlutterBinaryMessenger, registry: FlutterTextureRegistry) {
    self.registry = registry
    channel = FlutterMethodChannel(name: "dev.ventairy.oh_my_flutter.motion", binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  internal func dispose() {
    channel.setMethodCallHandler(nil)
    rendererReadiness = .unavailable
    for scene in scenes.values { scene.close() }
    scenes.removeAll()
    renderQueue.async {
      if let context = self.context { CVMetalTextureCacheFlush(context.textureCache, 0) }
      self.context = nil
    }
  }

  internal func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "prepareRenderer" {
      prepareRenderer(result: result)
      return
    }
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_arguments", message: "Expected named arguments.", details: nil))
      return
    }
    if call.method == "releaseRenderer" {
      if let instance = (arguments["instanceId"] as? NSNumber)?.int64Value {
        scenes.removeValue(forKey: instance)?.close()
      } else {
        for scene in scenes.values { scene.close() }
        scenes.removeAll()
      }
      if scenes.isEmpty {
        renderQueue.async {
          if let context = self.context { CVMetalTextureCacheFlush(context.textureCache, 0) }
        }
      }
      result(nil)
      return
    }
    do {
      if call.method == "prepare" {
        try prepare(arguments, result: result)
        return
      }
      guard let instance = (arguments["instanceId"] as? NSNumber)?.int64Value,
        let texture = (arguments["textureId"] as? NSNumber)?.int64Value,
        let handle = (arguments["handle"] as? NSNumber)?.int64Value,
        let scene = scenes[instance], scene.containsImage(textureId: texture, handle: handle) else {
        result(call.method == "dispose" ? nil : FlutterError(code: "replaced", message: "The disintegration was replaced.", details: nil))
        return
      }
      switch call.method {
      case "awaitFirstFrame": scene.awaitFirstFrame(result: result)
      case "play":
        guard let progress = (arguments["fromProgress"] as? NSNumber)?.doubleValue,
          progress.isFinite && progress >= 0 && progress <= 1,
          let milliseconds = (arguments["durationMillis"] as? NSNumber)?.doubleValue,
          milliseconds.isFinite && milliseconds > 0 else {
          throw IOSDisintegrateError.invalidArguments("Expected finite progress and a positive duration.")
        }
        scene.play(from: Float(progress), duration: milliseconds / 1000, result: result)
      case "setFrame":
        let frame = try IOSDisintegrateConfiguration.frame(from: arguments["frame"], nativeGaussian: scene.configuration.nativeGaussian)
        scene.setFrame(frame, result: result)
      case "pause": scene.pause(); result(nil)
      case "dispose": scene.releaseImage(result: result)
      default: result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "invalid_arguments", message: String(describing: error), details: nil))
    }
  }

  private func prepareRenderer(result: @escaping FlutterResult) {
    switch rendererReadiness {
    case .ready:
      result(true)
    case .warming, .unavailable:
      result(false)
    case .cold:
      rendererReadiness = .warming
      renderQueue.async {
        let readiness: RendererReadiness
        do {
          _ = try self.getOrCreateContext()
          readiness = .ready
        } catch {
          readiness = .unavailable
        }
        DispatchQueue.main.async {
          guard self.rendererReadiness == .warming else { return }
          self.rendererReadiness = readiness
        }
      }
      result(false)
    }
  }

  private func getOrCreateContext() throws -> IOSDisintegrateMetalContext {
    if let context { return context }
    let context = try IOSDisintegrateMetalContext()
    self.context = context
    return context
  }

  private func prepare(_ arguments: [String: Any], result: @escaping FlutterResult) throws {
    let configuration = try IOSDisintegrateConfiguration(arguments: arguments)
    guard let instance = (arguments["instanceId"] as? NSNumber)?.int64Value,
      let pixels = arguments["image"] as? FlutterStandardTypedData else {
      throw IOSDisintegrateError.invalidArguments("Expected source pixels and an instance identifier.")
    }
    let scene: IOSDisintegrateScene
    if let current = scenes[instance], current.matches(configuration) {
      scene = current
    } else {
      scenes.removeValue(forKey: instance)?.close()
      scene = IOSDisintegrateScene(configuration: configuration, registry: registry, renderQueue: renderQueue,
        makeContext: { [weak self] in
          guard let self else { throw IOSDisintegrateError.unavailable("The engine was detached.") }
          return try self.getOrCreateContext()
        })
      scenes[instance] = scene
    }
    nextHandle += 1
    let handle = nextHandle
    scene.prepareImage(pixels.data, handle: handle, frame: configuration.initialFrame) { value in
      if value is FlutterError && scene.containsImage(textureId: scene.textureId, handle: handle) {
        self.scenes.removeValue(forKey: instance)?.close()
      }
      result(value)
    }
  }
  private enum RendererReadiness {
    case cold
    case warming
    case ready
    case unavailable
  }
}
