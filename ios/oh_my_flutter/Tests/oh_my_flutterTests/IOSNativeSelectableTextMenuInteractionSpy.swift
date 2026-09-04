import UIKit

@available(iOS 16.0, *)
internal final class IOSNativeSelectableTextMenuInteractionSpy: UIEditMenuInteraction {
  internal private(set) var reloadVisibleMenuCallCount = 0
  internal private(set) var updateVisibleMenuPositionCallCount = 0
  internal private(set) var positionUpdatesWereOnMainThread: [Bool] = []

  override internal func reloadVisibleMenu() {
    reloadVisibleMenuCallCount += 1
  }

  override internal func updateVisibleMenuPosition(animated: Bool) {
    updateVisibleMenuPositionCallCount += 1
    positionUpdatesWereOnMainThread.append(Thread.isMainThread)
  }
}
