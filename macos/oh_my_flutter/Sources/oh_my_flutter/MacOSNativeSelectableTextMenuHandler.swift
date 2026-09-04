import AppKit
import FlutterMacOS

/// Presents Flutter selection commands through an AppKit menu.
internal final class MacOSNativeSelectableTextMenuHandler: NSObject,
  NativeSelectableTextMenuHostApi,
  NSMenuDelegate
{
  private static let geometryCoordinateCount = 6
  private static let nonWhitespaceCharacters = CharacterSet.whitespacesAndNewlines.inverted

  private let viewProvider: () -> NSView?
  private let eventDispatcher: MacOSNativeSelectableTextMenuEventDispatcher
  private let presentMenu: @MainActor (NSMenu, NSPoint, NSView) -> Bool
  private var currentRequest: NativeSelectableTextMenuRequestMessage?
  private weak var attachedView: NSView?
  private var sessionMenu: NSMenu?
  private var activeMenu: NSMenu?
  private var presentationGeneration = 0
  private var sessionIdentifiersByMenu: [ObjectIdentifier: Int64] = [:]
  private var actionInvokedMenus = Set<ObjectIdentifier>()
  private var programmaticDismissalCountsByMenu: [ObjectIdentifier: Int] = [:]
  private var isDisposed = false

  internal init(
    viewProvider: @escaping () -> NSView?,
    flutterApi: NativeSelectableTextMenuFlutterApiProtocol,
    presentMenu: @escaping @MainActor (NSMenu, NSPoint, NSView) -> Bool = { menu, point, view in
      menu.popUp(positioning: nil, at: point, in: view)
    }
  ) {
    self.viewProvider = viewProvider
    eventDispatcher = MacOSNativeSelectableTextMenuEventDispatcher(flutterApi: flutterApi)
    self.presentMenu = presentMenu
  }

  internal func show(request: NativeSelectableTextMenuRequestMessage) -> Bool {
    performOnMain {
      guard !self.isDisposed else {
        return false
      }
      guard
        self.isValid(request: request),
        let view = self.viewProvider(),
        view.window != nil
      else {
        self.abandonCurrentPresentationForAdaptiveFallback()
        return false
      }

      self.cancelActiveMenu(programmatically: true)
      self.sessionMenu = nil
      self.attachedView = view
      self.currentRequest = request
      self.schedulePresentation(request: request, in: view)
      return true
    }
  }

  internal func update(request: NativeSelectableTextMenuRequestMessage) -> Bool {
    performOnMain {
      guard
        !self.isDisposed,
        let currentRequest = self.currentRequest,
        currentRequest.sessionIdentifier == request.sessionIdentifier
      else {
        return false
      }
      let itemsChanged = !self.haveSameItems(currentRequest.items, request.items)
      let rectangleChanged = !self.haveSameCoordinates(
        currentRequest.selectionRectangle,
        request.selectionRectangle
      )
      let anchorChanged = !self.haveSameCoordinates(
        currentRequest.primaryAnchor,
        request.primaryAnchor
      )
      guard
        let view = self.viewProvider(),
        self.attachedView === view,
        view.window != nil
      else {
        self.abandonCurrentPresentationForAdaptiveFallback()
        return false
      }

      guard itemsChanged || rectangleChanged || anchorChanged else {
        return true
      }
      guard
        self.hasValidGeometry(request),
        !itemsChanged || self.hasValidItems(request.items)
      else {
        self.abandonCurrentPresentationForAdaptiveFallback()
        return false
      }

      if !itemsChanged && !anchorChanged {
        self.currentRequest = request
        return true
      }

      if !itemsChanged {
        self.cancelActiveMenu(programmatically: true)
      } else {
        self.cancelActiveMenu(programmatically: true)
        self.sessionMenu = nil
      }
      self.currentRequest = request
      self.schedulePresentation(request: request, in: view)
      return true
    }
  }

  internal func updateGeometry(
    sessionIdentifier: Int64,
    geometry: FlutterStandardTypedData
  ) -> Bool {
    performOnMain {
      guard
        !self.isDisposed,
        let currentRequest = self.currentRequest,
        currentRequest.sessionIdentifier == sessionIdentifier
      else {
        return false
      }
      guard
        let view = self.viewProvider(),
        self.attachedView === view,
        view.window != nil
      else {
        self.abandonCurrentPresentationForAdaptiveFallback()
        return false
      }
      guard
        let updatedRequest = self.request(
          currentRequest,
          byUpdatingGeometry: geometry
        ),
        self.hasValidGeometry(updatedRequest)
      else {
        self.abandonCurrentPresentationForAdaptiveFallback()
        return false
      }

      let rectangleChanged = !self.haveSameCoordinates(
        currentRequest.selectionRectangle,
        updatedRequest.selectionRectangle
      )
      let anchorChanged = !self.haveSameCoordinates(
        currentRequest.primaryAnchor,
        updatedRequest.primaryAnchor
      )
      guard rectangleChanged || anchorChanged else {
        return true
      }

      self.currentRequest = updatedRequest
      guard anchorChanged else {
        return true
      }

      self.cancelActiveMenu(programmatically: true)
      self.schedulePresentation(request: updatedRequest, in: view)
      return true
    }
  }

  internal func hide(sessionIdentifier: Int64) {
    performOnMain {
      guard
        !self.isDisposed,
        self.currentRequest?.sessionIdentifier == sessionIdentifier
      else {
        return
      }

      self.presentationGeneration += 1
      self.currentRequest = nil
      self.attachedView = nil
      self.cancelActiveMenu(programmatically: true)
      self.sessionMenu = nil
    }
  }

  internal func dispose() {
    performOnMain {
      guard !self.isDisposed else {
        return
      }

      self.isDisposed = true
      self.eventDispatcher.dispose()
      self.presentationGeneration += 1
      self.currentRequest = nil
      self.attachedView = nil
      self.cancelActiveMenu(programmatically: true)
      self.sessionMenu = nil
      self.sessionIdentifiersByMenu.removeAll()
      self.actionInvokedMenus.removeAll()
      self.programmaticDismissalCountsByMenu.removeAll()
    }
  }

  internal func menuDidClose(_ menu: NSMenu) {
    completeDismissal(of: menu)
  }

  internal func point(
    from message: NativeSelectableTextPointMessage,
    in view: NSView
  ) -> NSPoint {
    let x = view.bounds.minX + CGFloat(message.dx)
    let y: CGFloat
    if view.isFlipped {
      y = view.bounds.minY + CGFloat(message.dy)
    } else {
      y = view.bounds.maxY - CGFloat(message.dy)
    }
    return NSPoint(x: x, y: y)
  }

  internal func makeMenu(for request: NativeSelectableTextMenuRequestMessage) -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false
    menu.delegate = self
    for item in request.items {
      let menuItem = NSMenuItem(
        title: item.label,
        action: #selector(handleMenuItem(_:)),
        keyEquivalent: ""
      )
      menuItem.target = self
      menuItem.representedObject = NSNumber(value: item.identifier)
      menu.addItem(menuItem)
    }
    return menu
  }

  internal func completeDismissal(of menu: NSMenu) {
    guard !isDisposed else {
      return
    }

    let menuIdentifier = ObjectIdentifier(menu)
    let wasProgrammaticallyHidden = consumeProgrammaticDismissal(for: menuIdentifier)
    guard let sessionIdentifier = sessionIdentifiersByMenu[menuIdentifier]
    else {
      return
    }

    let wasActiveMenu = activeMenu === menu
    if wasProgrammaticallyHidden && wasActiveMenu {
      return
    }

    sessionIdentifiersByMenu.removeValue(forKey: menuIdentifier)
    if wasActiveMenu {
      activeMenu = nil
      if sessionMenu === menu {
        sessionMenu = nil
      }
      if currentRequest?.sessionIdentifier == sessionIdentifier {
        currentRequest = nil
        attachedView = nil
      }
    }

    let actionInvoked = actionInvokedMenus.remove(menuIdentifier) != nil
    guard !wasProgrammaticallyHidden else {
      return
    }

    eventDispatcher.sendDismissal(
      menuIdentifier: menuIdentifier,
      sessionIdentifier: sessionIdentifier,
      actionInvoked: actionInvoked
    )
  }

  @objc private func handleMenuItem(_ menuItem: NSMenuItem) {
    guard
      let menu = menuItem.menu,
      let actionIdentifier = (menuItem.representedObject as? NSNumber)?.int64Value
    else {
      return
    }

    let menuIdentifier = ObjectIdentifier(menu)
    guard
      !isDisposed,
      let sessionIdentifier = sessionIdentifiersByMenu[menuIdentifier],
      currentRequest?.sessionIdentifier == sessionIdentifier
    else {
      return
    }

    actionInvokedMenus.insert(menuIdentifier)
    eventDispatcher.sendAction(
      menuIdentifier: menuIdentifier,
      sessionIdentifier: sessionIdentifier,
      actionIdentifier: actionIdentifier
    )
  }

  private func schedulePresentation(
    request: NativeSelectableTextMenuRequestMessage,
    in view: NSView
  ) {
    presentationGeneration += 1
    let generation = presentationGeneration
    DispatchQueue.main.async { [weak self, weak view] in
      guard
        let self,
        !self.isDisposed,
        self.presentationGeneration == generation,
        self.currentRequest?.sessionIdentifier == request.sessionIdentifier
      else {
        return
      }
      guard
        let view,
        self.attachedView === view,
        view.window != nil
      else {
        self.abandonCurrentPresentationForAdaptiveFallback()
        self.eventDispatcher.sendUnavailablePresentationDismissal(
          sessionIdentifier: request.sessionIdentifier
        )
        return
      }

      let menu = self.sessionMenu ?? self.makeMenu(for: request)
      self.sessionMenu = menu
      let menuIdentifier = ObjectIdentifier(menu)
      self.activeMenu = menu
      self.sessionIdentifiersByMenu[menuIdentifier] = request.sessionIdentifier
      let didPresent = self.presentMenu(
        menu,
        self.point(from: request.primaryAnchor, in: view),
        view
      )
      if !didPresent {
        self.completeDismissal(of: menu)
      }
    }
  }

  private func cancelActiveMenu(programmatically: Bool) {
    guard let activeMenu else {
      return
    }
    self.activeMenu = nil
    if programmatically {
      let menuIdentifier = ObjectIdentifier(activeMenu)
      programmaticDismissalCountsByMenu[menuIdentifier, default: 0] += 1
    }
    activeMenu.cancelTrackingWithoutAnimation()
  }

  private func consumeProgrammaticDismissal(for menuIdentifier: ObjectIdentifier) -> Bool {
    guard let count = programmaticDismissalCountsByMenu[menuIdentifier] else {
      return false
    }
    if count == 1 {
      programmaticDismissalCountsByMenu.removeValue(forKey: menuIdentifier)
    } else {
      programmaticDismissalCountsByMenu[menuIdentifier] = count - 1
    }
    return true
  }

  private func abandonCurrentPresentationForAdaptiveFallback() {
    presentationGeneration += 1
    currentRequest = nil
    attachedView = nil
    cancelActiveMenu(programmatically: true)
    sessionMenu = nil
  }

  private func request(
    _ currentRequest: NativeSelectableTextMenuRequestMessage,
    byUpdatingGeometry geometry: FlutterStandardTypedData
  ) -> NativeSelectableTextMenuRequestMessage? {
    let expectedByteCount = Self.geometryCoordinateCount * MemoryLayout<Double>.size
    guard
      geometry.type == .float64,
      geometry.data.count == expectedByteCount
    else {
      return nil
    }

    var coordinates = [Double](repeating: 0, count: Self.geometryCoordinateCount)
    let copiedByteCount = coordinates.withUnsafeMutableBytes { bytes in
      geometry.data.copyBytes(to: bytes)
    }
    guard copiedByteCount == expectedByteCount else {
      return nil
    }

    return NativeSelectableTextMenuRequestMessage(
      sessionIdentifier: currentRequest.sessionIdentifier,
      selectionRectangle: NativeSelectableTextRectangleMessage(
        left: coordinates[0],
        top: coordinates[1],
        right: coordinates[2],
        bottom: coordinates[3]
      ),
      primaryAnchor: NativeSelectableTextPointMessage(
        dx: coordinates[4],
        dy: coordinates[5]
      ),
      items: currentRequest.items
    )
  }

  internal func isValid(request: NativeSelectableTextMenuRequestMessage) -> Bool {
    hasValidItems(request.items) && hasValidGeometry(request)
  }

  private func hasValidItems(_ items: [NativeSelectableTextMenuItemMessage]) -> Bool {
    !items.isEmpty
      && items.allSatisfy {
        $0.label.rangeOfCharacter(from: Self.nonWhitespaceCharacters) != nil
      }
  }

  private func hasValidGeometry(_ request: NativeSelectableTextMenuRequestMessage) -> Bool {
    let rectangle = request.selectionRectangle
    let anchor = request.primaryAnchor
    return rectangle.left.isFinite
      && rectangle.top.isFinite
      && rectangle.right.isFinite
      && rectangle.bottom.isFinite
      && rectangle.right >= rectangle.left
      && rectangle.bottom >= rectangle.top
      && anchor.dx.isFinite
      && anchor.dy.isFinite
  }

  private func haveSameItems(
    _ currentItems: [NativeSelectableTextMenuItemMessage],
    _ nextItems: [NativeSelectableTextMenuItemMessage]
  ) -> Bool {
    guard currentItems.count == nextItems.count else {
      return false
    }
    for index in currentItems.indices {
      let currentItem = currentItems[index]
      let nextItem = nextItems[index]
      if currentItem.identifier != nextItem.identifier || currentItem.label != nextItem.label {
        return false
      }
    }
    return true
  }

  private func haveSameCoordinates(
    _ currentPoint: NativeSelectableTextPointMessage,
    _ nextPoint: NativeSelectableTextPointMessage
  ) -> Bool {
    currentPoint.dx == nextPoint.dx && currentPoint.dy == nextPoint.dy
  }

  private func haveSameCoordinates(
    _ currentRectangle: NativeSelectableTextRectangleMessage,
    _ nextRectangle: NativeSelectableTextRectangleMessage
  ) -> Bool {
    currentRectangle.left == nextRectangle.left
      && currentRectangle.top == nextRectangle.top
      && currentRectangle.right == nextRectangle.right
      && currentRectangle.bottom == nextRectangle.bottom
  }

  private func performOnMain<Result>(_ operation: () -> Result) -> Result {
    if Thread.isMainThread {
      return operation()
    }
    return DispatchQueue.main.sync(execute: operation)
  }
}
