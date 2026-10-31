import CoreMotion

/// Allows native sensor lifecycle tests without real accelerometer hardware.
internal protocol IOSDeviceAccelerometerMotionManager: AnyObject {
  var isAccelerometerAvailable: Bool { get }
  var accelerometerUpdateInterval: TimeInterval { get set }
  func startAccelerometerUpdates(to queue: OperationQueue, withHandler handler: @escaping CMAccelerometerHandler)
  func stopAccelerometerUpdates()
}

extension CMMotionManager: IOSDeviceAccelerometerMotionManager {}
