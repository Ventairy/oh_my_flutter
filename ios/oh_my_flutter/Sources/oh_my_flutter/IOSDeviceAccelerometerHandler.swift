import CoreMotion
import Flutter

/// Owns one engine's accelerometer updates and platform-thread delivery.
internal final class IOSDeviceAccelerometerHandler: DeviceAccelerometerSamplesStreamHandler, DeviceAccelerometerHostApi {
  private let manager: IOSDeviceAccelerometerMotionManager
  private let queue: OperationQueue
  private var sink: PigeonEventSink<DeviceAccelerometerPlatformSample>?
  private var interval: Int64?
  private var generation = 0
  private var disposed = false

  internal init(manager: IOSDeviceAccelerometerMotionManager = CMMotionManager()) {
    self.manager = manager
    queue = OperationQueue()
    queue.name = "dev.ventairy.oh_my_flutter.accelerometer"
    queue.maxConcurrentOperationCount = 1
    super.init()
  }

  internal func isAvailable() throws -> Bool {
    !disposed && manager.isAccelerometerAvailable
  }

  internal func configure(samplingIntervalMicroseconds: Int64?) throws {
    guard !disposed else {
      throw DeviceAccelerometerPigeonError(code: "operationUnavailable", message: "Accelerometer handler is detached", details: nil)
    }
    stop()
    interval = samplingIntervalMicroseconds
    if samplingIntervalMicroseconds != nil && !manager.isAccelerometerAvailable {
      interval = nil
      throw DeviceAccelerometerPigeonError(code: "sensorUnavailable", message: "No accelerometer is available", details: nil)
    }
    start()
  }

  internal override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<DeviceAccelerometerPlatformSample>) {
    stop()
    self.sink = sink
    start()
  }

  internal override func onCancel(withArguments arguments: Any?) {
    stop()
    sink = nil
  }

  private func start() {
    guard let interval, sink != nil, !disposed else { return }
    guard manager.isAccelerometerAvailable else {
      sink?.error(code: "sensorUnavailable", message: "No accelerometer is available", details: nil)
      return
    }
    manager.accelerometerUpdateInterval = Double(interval) / 1_000_000
    let currentGeneration = generation
    manager.startAccelerometerUpdates(to: queue) { [weak self] data, error in
      // Read Core Motion's sample on its serial queue before crossing threads.
      let sample = data.map {
        Self.sample(acceleration: $0.acceleration, timestamp: $0.timestamp)
      }
      DispatchQueue.main.async { [weak self] in
        guard let self, !self.disposed, self.generation == currentGeneration else { return }
        if let error {
          self.sink?.error(code: "operationUnavailable", message: error.localizedDescription, details: nil)
          self.stop()
        } else if let sample {
          self.sink?.success(sample)
        }
      }
    }
  }

  internal static func sample(acceleration: CMAcceleration, timestamp: TimeInterval) -> DeviceAccelerometerPlatformSample {
    DeviceAccelerometerPlatformSample(
      x: -acceleration.x * 9.80665,
      y: -acceleration.y * 9.80665,
      z: -acceleration.z * 9.80665,
      timestampMicroseconds: Int64(timestamp * 1_000_000)
    )
  }

  private func stop() {
    generation += 1
    manager.stopAccelerometerUpdates()
  }

  internal func dispose() {
    stop()
    interval = nil
    sink = nil
    disposed = true
  }

  deinit {
    manager.stopAccelerometerUpdates()
    queue.cancelAllOperations()
  }
}
