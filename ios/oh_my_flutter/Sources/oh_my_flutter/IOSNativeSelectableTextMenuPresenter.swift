import Flutter
import UIKit

/// Owns UIKit's edit-menu interaction for Flutter-rendered selectable text.
@available(iOS 16.0, *)
internal final class IOSNativeSelectableTextMenuPresenter: NSObject,
  IOSNativeSelectableTextMenuPresenting,
  UIEditMenuInteractionDelegate
{
  private static let geometryCoordinateCount = 6
  private static let nonWhitespaceCharacters = CharacterSet.whitespacesAndNewlines.inverted

  private let viewProvider: () -> UIView?
  private let eventDispatcher: IOSNativeSelectableTextMenuEventDispatcher
  private let interactionFactory: (UIEditMenuInteractionDelegate?) -> UIEditMenuInteraction
  private var interaction: UIEditMenuInteraction?
  private weak var attachedView: UIView?
  private var currentSessionIdentifier: Int64?
  private var requestsBySessionIdentifier: [Int64: NativeSelectableTextMenuRequestMessage] = [:]
  private var actionInvokedSessionIdentifiers = Set<Int64>()
  private var programmaticallyHiddenSessionIdentifiers = Set<Int64>()
  private var isDisposed = false

  internal convenience init(
    viewProvider: @escaping () -> UIView?,
    flutterApi: NativeSelectableTextMenuFlutterApiProtocol
  ) {
    self.init(
      viewProvider: viewProvider,
      flutterApi: flutterApi,
      interactionFactory: { UIEditMenuInteraction(delegate: $0) }
    )
  }

  internal convenience init(
    test viewProvider: @escaping () -> UIView?,
    flutterApi: NativeSelectableTextMenuFlutterApiProtocol,
    interactionFactory: @escaping (UIEditMenuInteractionDelegate?) -> UIEditMenuInteraction
  ) {
    self.init(
      viewProvider: viewProvider,
      flutterApi: flutterApi,
      interactionFactory: interactionFactory
    )
  }

  private init(
    viewProvider: @escaping () -> UIView?,
    flutterApi: NativeSelectableTextMenuFlutterApiProtocol,
    interactionFactory: @escaping (UIEditMenuInteractionDelegate?) -> UIEditMenuInteraction
  ) {
    self.viewProvider = viewProvider
    eventDispatcher = IOSNativeSelectableTextMenuEventDispatcher(flutterApi: flutterApi)
    self.interactionFactory = interactionFactory
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

      let interaction = self.interactionForPresentation()
      self.attach(interaction: interaction, to: view)
      self.requestsBySessionIdentifier[request.sessionIdentifier] = request

      if self.currentSessionIdentifier == request.sessionIdentifier {
        interaction.reloadVisibleMenu()
        interaction.updateVisibleMenuPosition(animated: false)
        return true
      }

      self.currentSessionIdentifier = request.sessionIdentifier
      let configuration = UIEditMenuConfiguration(
        identifier: NSNumber(value: request.sessionIdentifier),
        sourcePoint: self.point(from: request.primaryAnchor, in: view)
      )
      interaction.presentEditMenu(with: configuration)
      return true
    }
  }

  internal func update(request: NativeSelectableTextMenuRequestMessage) -> Bool {
    performOnMain {
      guard
        !self.isDisposed,
        self.currentSessionIdentifier == request.sessionIdentifier
      else {
        return false
      }

      let currentRequest = self.requestsBySessionIdentifier[request.sessionIdentifier]
      let shouldReloadMenu =
        currentRequest.map {
          !self.haveSameItems($0.items, request.items)
        } ?? true
      let shouldUpdatePosition =
        currentRequest.map {
          !self.haveSameCoordinates($0.selectionRectangle, request.selectionRectangle)
        } ?? true
      let anchorChanged =
        currentRequest.map {
          !self.haveSameCoordinates($0.primaryAnchor, request.primaryAnchor)
        } ?? true
      guard
        let interaction = self.interaction,
        let view = self.viewProvider(),
        self.attachedView === view,
        view.window != nil
      else {
        self.abandonCurrentPresentationForAdaptiveFallback()
        return false
      }

      guard shouldReloadMenu || shouldUpdatePosition || anchorChanged else {
        return true
      }
      guard
        self.hasValidGeometry(request),
        !shouldReloadMenu || self.hasValidItems(request.items)
      else {
        self.abandonCurrentPresentationForAdaptiveFallback()
        return false
      }

      self.requestsBySessionIdentifier[request.sessionIdentifier] = request
      if shouldReloadMenu {
        interaction.reloadVisibleMenu()
      }
      if shouldUpdatePosition {
        interaction.updateVisibleMenuPosition(animated: false)
      }
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
        self.currentSessionIdentifier == sessionIdentifier,
        let currentRequest = self.requestsBySessionIdentifier[sessionIdentifier]
      else {
        return false
      }
      guard
        let interaction = self.interaction,
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

      self.requestsBySessionIdentifier[sessionIdentifier] = updatedRequest
      interaction.updateVisibleMenuPosition(animated: false)
      return true
    }
  }

  internal func hide(sessionIdentifier: Int64) {
    performOnMain {
      guard
        !self.isDisposed,
        self.currentSessionIdentifier == sessionIdentifier
      else {
        return
      }

      self.programmaticallyHiddenSessionIdentifiers.insert(sessionIdentifier)
      self.currentSessionIdentifier = nil
      self.requestsBySessionIdentifier.removeValue(forKey: sessionIdentifier)
      self.interaction?.dismissMenu()
    }
  }

  internal func dispose() {
    performOnMain {
      guard !self.isDisposed else {
        return
      }

      self.isDisposed = true
      self.eventDispatcher.dispose()
      if let sessionIdentifier = self.currentSessionIdentifier {
        self.programmaticallyHiddenSessionIdentifiers.insert(sessionIdentifier)
      }
      self.currentSessionIdentifier = nil
      self.requestsBySessionIdentifier.removeAll()
      self.actionInvokedSessionIdentifiers.removeAll()
      self.interaction?.dismissMenu()
      if let interaction = self.interaction {
        self.attachedView?.removeInteraction(interaction)
      }
      self.interaction = nil
      self.attachedView = nil
    }
  }

  internal func editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    menuFor configuration: UIEditMenuConfiguration,
    suggestedActions _: [UIMenuElement]
  ) -> UIMenu? {
    guard
      let sessionIdentifier = sessionIdentifier(from: configuration),
      let request = requestsBySessionIdentifier[sessionIdentifier]
    else {
      return nil
    }

    let actions = request.items.map { item in
      UIAction(title: item.label) { [weak self] _ in
        self?.handleAction(
          sessionIdentifier: sessionIdentifier,
          actionIdentifier: item.identifier
        )
      }
    }
    return UIMenu(options: .displayInline, children: actions)
  }

  internal func editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    targetRectFor configuration: UIEditMenuConfiguration
  ) -> CGRect {
    guard
      let view = interaction.view,
      let sessionIdentifier = sessionIdentifier(from: configuration),
      let request = requestsBySessionIdentifier[sessionIdentifier]
    else {
      return .null
    }

    return rectangle(from: request.selectionRectangle, in: view)
  }

  internal func editMenuInteraction(
    _: UIEditMenuInteraction,
    willDismissMenuFor configuration: UIEditMenuConfiguration,
    animator: UIEditMenuInteractionAnimating
  ) {
    guard let sessionIdentifier = sessionIdentifier(from: configuration) else {
      return
    }

    animator.addCompletion { [weak self] in
      self?.completeDismissal(sessionIdentifier: sessionIdentifier)
    }
  }

  internal func point(
    from message: NativeSelectableTextPointMessage,
    in view: UIView
  ) -> CGPoint {
    CGPoint(
      x: view.bounds.minX + CGFloat(message.dx),
      y: view.bounds.minY + CGFloat(message.dy)
    )
  }

  internal func rectangle(
    from message: NativeSelectableTextRectangleMessage,
    in view: UIView
  ) -> CGRect {
    CGRect(
      x: view.bounds.minX + CGFloat(message.left),
      y: view.bounds.minY + CGFloat(message.top),
      width: CGFloat(message.right - message.left),
      height: CGFloat(message.bottom - message.top)
    )
  }

  internal func handleAction(sessionIdentifier: Int64, actionIdentifier: Int64) {
    guard
      !isDisposed,
      currentSessionIdentifier == sessionIdentifier,
      requestsBySessionIdentifier[sessionIdentifier] != nil
    else {
      return
    }

    actionInvokedSessionIdentifiers.insert(sessionIdentifier)
    eventDispatcher.sendAction(
      sessionIdentifier: sessionIdentifier,
      actionIdentifier: actionIdentifier
    )
  }

  internal func completeDismissal(sessionIdentifier: Int64) {
    guard !isDisposed else {
      return
    }

    let wasProgrammaticallyHidden =
      programmaticallyHiddenSessionIdentifiers.remove(sessionIdentifier) != nil
    let actionInvoked = actionInvokedSessionIdentifiers.remove(sessionIdentifier) != nil
    let hadRequest = requestsBySessionIdentifier.removeValue(forKey: sessionIdentifier) != nil
    if currentSessionIdentifier == sessionIdentifier {
      currentSessionIdentifier = nil
    }

    guard (hadRequest || actionInvoked || wasProgrammaticallyHidden) && !wasProgrammaticallyHidden
    else {
      return
    }

    eventDispatcher.sendDismissal(
      sessionIdentifier: sessionIdentifier,
      actionInvoked: actionInvoked
    )
  }

  private func interactionForPresentation() -> UIEditMenuInteraction {
    if let interaction {
      return interaction
    }
    let interaction = interactionFactory(self)
    self.interaction = interaction
    return interaction
  }

  private func attach(interaction: UIEditMenuInteraction, to view: UIView) {
    guard attachedView !== view else {
      return
    }

    attachedView?.removeInteraction(interaction)
    view.addInteraction(interaction)
    attachedView = view
  }

  private func abandonCurrentPresentationForAdaptiveFallback() {
    guard let sessionIdentifier = currentSessionIdentifier else {
      return
    }

    currentSessionIdentifier = nil
    requestsBySessionIdentifier.removeValue(forKey: sessionIdentifier)
    actionInvokedSessionIdentifiers.remove(sessionIdentifier)
    interaction?.dismissMenu()
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

  private func sessionIdentifier(from configuration: UIEditMenuConfiguration) -> Int64? {
    (configuration.identifier as? NSNumber)?.int64Value
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
