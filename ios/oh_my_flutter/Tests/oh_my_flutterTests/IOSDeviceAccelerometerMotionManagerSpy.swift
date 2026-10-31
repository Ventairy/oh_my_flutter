import CoreMotion
@testable import oh_my_flutter

internal final class IOSDeviceAccelerometerMotionManagerSpy: IOSDeviceAccelerometerMotionManager {
  internal var isAccelerometerAvailable = true
  internal var accelerometerUpdateInterval: TimeInterval = 0
  internal var handler: CMAccelerometerHandler?
  internal private(set) var starts = 0
  internal private(set) var stops = 0

  internal func startAccelerometerUpdates(to queue: OperationQueue, withHandler handler: @escaping CMAccelerometerHandler) {
    starts += 1
    self.handler = handler
  }

  internal func stopAccelerometerUpdates() { stops += 1 }
}
