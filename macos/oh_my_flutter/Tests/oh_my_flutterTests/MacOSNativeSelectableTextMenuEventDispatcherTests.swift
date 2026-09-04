import AppKit
import XCTest

@testable import oh_my_flutter

final class MacOSNativeSelectableTextMenuEventDispatcherTests: XCTestCase {
  func testWhenAnActionIsSentItShouldEnterTheFlutterApiOnThePlatformThread() async {
    let flutterApi = MacOSNativeSelectableTextMenuFlutterApiSpy()
    let dispatcher = MacOSNativeSelectableTextMenuEventDispatcher(flutterApi: flutterApi)
    let menuIdentifier = ObjectIdentifier(NSMenu())

    await MainActor.run {
      dispatcher.sendAction(
        menuIdentifier: menuIdentifier,
        sessionIdentifier: 10,
        actionIdentifier: 1
      )
    }
    await waitForEventCount(1, in: flutterApi)

    let deliveries = await MainActor.run { flutterApi.actionDeliveriesWereOnMainThread }
    XCTAssertEqual(deliveries, [true])
  }

  func testWhenDismissalIsSentItShouldEnterTheFlutterApiOnThePlatformThread() async {
    let flutterApi = MacOSNativeSelectableTextMenuFlutterApiSpy()
    let dispatcher = MacOSNativeSelectableTextMenuEventDispatcher(flutterApi: flutterApi)
    let menuIdentifier = ObjectIdentifier(NSMenu())

    await MainActor.run {
      dispatcher.sendDismissal(
        menuIdentifier: menuIdentifier,
        sessionIdentifier: 10,
        actionInvoked: false
      )
    }
    await waitForEventCount(1, in: flutterApi)

    let deliveries = await MainActor.run { flutterApi.dismissalDeliveriesWereOnMainThread }
    XCTAssertEqual(deliveries, [true])
  }

  func testWhenAnActionClosesTheMenuItShouldDeliverTheActionBeforeDismissal() async {
    let flutterApi = MacOSNativeSelectableTextMenuFlutterApiSpy()
    flutterApi.suspendsActionDelivery = true
    let dispatcher = MacOSNativeSelectableTextMenuEventDispatcher(flutterApi: flutterApi)
    let menuIdentifier = ObjectIdentifier(NSMenu())

    await MainActor.run {
      dispatcher.sendAction(
        menuIdentifier: menuIdentifier,
        sessionIdentifier: 11,
        actionIdentifier: 2
      )
      dispatcher.sendDismissal(
        menuIdentifier: menuIdentifier,
        sessionIdentifier: 11,
        actionInvoked: true
      )
    }
    await waitForEventCount(1, in: flutterApi)
    await MainActor.run {
      flutterApi.resumeActionDelivery()
    }
    await waitForEventCount(2, in: flutterApi)

    let events = await MainActor.run { flutterApi.events }
    XCTAssertEqual(events, ["action:11:2", "dismissal:11:true"])
  }

  func testWhenTheMenuClosesExternallyItShouldReportNoInvokedAction() async {
    let flutterApi = MacOSNativeSelectableTextMenuFlutterApiSpy()
    let dispatcher = MacOSNativeSelectableTextMenuEventDispatcher(flutterApi: flutterApi)
    let menuIdentifier = ObjectIdentifier(NSMenu())

    await MainActor.run {
      dispatcher.sendDismissal(
        menuIdentifier: menuIdentifier,
        sessionIdentifier: 12,
        actionInvoked: false
      )
    }
    await waitForEventCount(1, in: flutterApi)

    let events = await MainActor.run { flutterApi.events }
    XCTAssertEqual(events, ["dismissal:12:false"])
  }

  func testWhenDisposedBeforeQueuedEventsRunItShouldSuppressEveryCallback() async {
    let flutterApi = MacOSNativeSelectableTextMenuFlutterApiSpy()
    let dispatcher = MacOSNativeSelectableTextMenuEventDispatcher(flutterApi: flutterApi)
    let menuIdentifier = ObjectIdentifier(NSMenu())

    await MainActor.run {
      dispatcher.sendAction(
        menuIdentifier: menuIdentifier,
        sessionIdentifier: 13,
        actionIdentifier: 3
      )
      dispatcher.sendDismissal(
        menuIdentifier: menuIdentifier,
        sessionIdentifier: 13,
        actionInvoked: true
      )
      dispatcher.dispose()
    }
    await yieldToMainActor()

    let events = await MainActor.run { flutterApi.events }
    XCTAssertTrue(events.isEmpty)
  }

  func testWhenDisposedDuringActionDeliveryItShouldSuppressThePendingDismissal() async {
    let flutterApi = MacOSNativeSelectableTextMenuFlutterApiSpy()
    flutterApi.suspendsActionDelivery = true
    let dispatcher = MacOSNativeSelectableTextMenuEventDispatcher(flutterApi: flutterApi)
    let menuIdentifier = ObjectIdentifier(NSMenu())

    await MainActor.run {
      dispatcher.sendAction(
        menuIdentifier: menuIdentifier,
        sessionIdentifier: 14,
        actionIdentifier: 4
      )
      dispatcher.sendDismissal(
        menuIdentifier: menuIdentifier,
        sessionIdentifier: 14,
        actionInvoked: true
      )
    }
    await waitForEventCount(1, in: flutterApi)
    await MainActor.run {
      dispatcher.dispose()
      flutterApi.resumeActionDelivery()
    }
    await yieldToMainActor()

    let events = await MainActor.run { flutterApi.events }
    XCTAssertEqual(events, ["action:14:4"])
  }

  func testWhenDisposedDuringUnansweredActionItShouldReleaseTheDispatcher() async {
    let flutterApi = MacOSNativeSelectableTextMenuFlutterApiSpy()
    flutterApi.suspendsActionDelivery = true
    var dispatcher: MacOSNativeSelectableTextMenuEventDispatcher? =
      MacOSNativeSelectableTextMenuEventDispatcher(flutterApi: flutterApi)
    weak let weakDispatcher = dispatcher
    let menu = NSMenu()
    let menuIdentifier = ObjectIdentifier(menu)

    await MainActor.run { [dispatcher] in
      dispatcher?.sendAction(
        menuIdentifier: menuIdentifier,
        sessionIdentifier: 15,
        actionIdentifier: 5
      )
    }
    await waitForEventCount(1, in: flutterApi)
    await MainActor.run { [dispatcher] in
      dispatcher?.dispose()
    }
    dispatcher = nil
    await yieldToMainActor()

    XCTAssertNil(weakDispatcher)
  }

  func testWhenDisposedDuringUnansweredDismissalItShouldReleaseTheDispatcher() async {
    let flutterApi = MacOSNativeSelectableTextMenuFlutterApiSpy()
    flutterApi.suspendsDismissalDelivery = true
    var dispatcher: MacOSNativeSelectableTextMenuEventDispatcher? =
      MacOSNativeSelectableTextMenuEventDispatcher(flutterApi: flutterApi)
    weak let weakDispatcher = dispatcher
    let menu = NSMenu()
    let menuIdentifier = ObjectIdentifier(menu)

    await MainActor.run { [dispatcher] in
      dispatcher?.sendDismissal(
        menuIdentifier: menuIdentifier,
        sessionIdentifier: 16,
        actionInvoked: false
      )
    }
    await waitForEventCount(1, in: flutterApi)
    await MainActor.run { [dispatcher] in
      dispatcher?.dispose()
    }
    dispatcher = nil
    await yieldToMainActor()

    XCTAssertNil(weakDispatcher)
  }

  private func waitForEventCount(
    _ expectedCount: Int,
    in flutterApi: MacOSNativeSelectableTextMenuFlutterApiSpy
  ) async {
    for _ in 0..<100 {
      let count = await MainActor.run { flutterApi.events.count }
      if count >= expectedCount {
        return
      }
      await Task.yield()
    }
  }

  private func yieldToMainActor() async {
    for _ in 0..<10 {
      await Task.yield()
    }
  }
}
