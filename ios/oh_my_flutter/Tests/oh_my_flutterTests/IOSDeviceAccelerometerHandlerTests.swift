import CoreMotion
import Flutter
import XCTest
@testable import oh_my_flutter

final class IOSDeviceAccelerometerHandlerTests: XCTestCase {
  func testWhenOnlyConfiguredItShouldNotStartHardware() throws {
    let manager = IOSDeviceAccelerometerMotionManagerSpy()
    let handler = IOSDeviceAccelerometerHandler(manager: manager)
    try handler.configure(samplingIntervalMicroseconds: 200000)
    XCTAssertEqual(manager.starts, 0)
  }

  func testWhenListeningItShouldStartAtTheConfiguredInterval() throws {
    let manager = IOSDeviceAccelerometerMotionManagerSpy()
    let handler = IOSDeviceAccelerometerHandler(manager: manager)
    try handler.configure(samplingIntervalMicroseconds: 200000)
    handler.onListen(withArguments: nil, sink: PigeonEventSink { _ in })
    XCTAssertEqual([Double(manager.starts), manager.accelerometerUpdateInterval], [1, 0.2])
  }

  func testWhenTheIntervalChangesItShouldUpdateNativeSampling() throws {
    let manager = IOSDeviceAccelerometerMotionManagerSpy()
    let handler = IOSDeviceAccelerometerHandler(manager: manager)
    try handler.configure(samplingIntervalMicroseconds: 200000)
    handler.onListen(withArguments: nil, sink: PigeonEventSink { _ in })
    try handler.configure(samplingIntervalMicroseconds: 20000)
    XCTAssertEqual(manager.accelerometerUpdateInterval, 0.02)
  }

  func testWhenConfigurationIsClearedItShouldStopSampling() throws {
    let manager = IOSDeviceAccelerometerMotionManagerSpy()
    let handler = IOSDeviceAccelerometerHandler(manager: manager)
    try handler.configure(samplingIntervalMicroseconds: 200000)
    handler.onListen(withArguments: nil, sink: PigeonEventSink { _ in })
    let previousStops = manager.stops
    try handler.configure(samplingIntervalMicroseconds: nil)
    XCTAssertEqual(manager.stops, previousStops + 1)
  }

  func testWhenCanceledItShouldStopSampling() throws {
    let manager = IOSDeviceAccelerometerMotionManagerSpy()
    let handler = IOSDeviceAccelerometerHandler(manager: manager)
    try handler.configure(samplingIntervalMicroseconds: 200000)
    handler.onListen(withArguments: nil, sink: PigeonEventSink { _ in })
    let previousStops = manager.stops
    handler.onCancel(withArguments: nil)
    XCTAssertEqual(manager.stops, previousStops + 1)
  }

  func testWhenDisposedItShouldStopSampling() throws {
    let manager = IOSDeviceAccelerometerMotionManagerSpy()
    let handler = IOSDeviceAccelerometerHandler(manager: manager)
    try handler.configure(samplingIntervalMicroseconds: 200000)
    handler.onListen(withArguments: nil, sink: PigeonEventSink { _ in })
    let previousStops = manager.stops
    handler.dispose()
    XCTAssertEqual(manager.stops, previousStops + 1)
  }

  func testWhenHardwareIsMissingItShouldReportUnavailable() throws {
    let manager = IOSDeviceAccelerometerMotionManagerSpy()
    manager.isAccelerometerAvailable = false
    XCTAssertFalse(try IOSDeviceAccelerometerHandler(manager: manager).isAvailable())
  }

  func testWhenMissingHardwareIsConfiguredItShouldReportSensorUnavailable() {
    let manager = IOSDeviceAccelerometerMotionManagerSpy()
    manager.isAccelerometerAvailable = false
    XCTAssertThrowsError(try IOSDeviceAccelerometerHandler(manager: manager).configure(samplingIntervalMicroseconds: 200000)) { error in
      XCTAssertEqual((error as? DeviceAccelerometerPigeonError)?.code, "sensorUnavailable")
    }
  }

  func testWhenConvertingNativeAccelerationItShouldUseAndroidSignsAndSIUnits() {
    let sample = IOSDeviceAccelerometerHandler.sample(acceleration: CMAcceleration(x: 1, y: 0, z: -1), timestamp: 1.25)
    XCTAssertEqual([sample.x, sample.y, sample.z], [-9.80665, 0, 9.80665])
  }

  func testWhenConvertingMeasurementTimeItShouldRetainMonotonicMicroseconds() {
    let sample = IOSDeviceAccelerometerHandler.sample(acceleration: CMAcceleration(x: 0, y: 0, z: 0), timestamp: 1.25)
    XCTAssertEqual(sample.timestampMicroseconds, 1250000)
  }

  func testWhenAnOldCallbackArrivesAfterDisposalItShouldNotSendAnError() async throws {
    let manager = IOSDeviceAccelerometerMotionManagerSpy()
    let handler = IOSDeviceAccelerometerHandler(manager: manager)
    var events = 0
    try handler.configure(samplingIntervalMicroseconds: 200000)
    handler.onListen(withArguments: nil, sink: PigeonEventSink { _ in events += 1 })
    let callback = manager.handler
    handler.dispose()
    callback?(nil, NSError(domain: "test", code: 1))
    await MainActor.run {}
    XCTAssertEqual(events, 0)
  }

  func testWhenCoreMotionFailsItShouldDeliverTheFailureOnThePlatformThread() async throws {
    let manager = IOSDeviceAccelerometerMotionManagerSpy()
    let handler = IOSDeviceAccelerometerHandler(manager: manager)
    let delivered = expectation(description: "sensor failure")
    var result: [String] = []
    try handler.configure(samplingIntervalMicroseconds: 200000)
    handler.onListen(withArguments: nil, sink: PigeonEventSink { value in
      result = [(value as? FlutterError)?.code ?? "unexpected", String(Thread.isMainThread)]
      delivered.fulfill()
    })
    manager.handler?(nil, NSError(domain: "test", code: 1))
    await fulfillment(of: [delivered], timeout: 2)
    XCTAssertEqual(result, ["operationUnavailable", "true"])
  }
}
