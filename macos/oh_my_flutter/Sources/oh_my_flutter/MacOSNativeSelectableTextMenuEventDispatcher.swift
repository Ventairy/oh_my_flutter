import Foundation

/// Delivers one macOS selection-menu session's events to Flutter in order.
internal final class MacOSNativeSelectableTextMenuEventDispatcher {
  private enum DeliveryIdentifier: Hashable {
    case menu(ObjectIdentifier)
    case queuedPresentation(Int64)
  }

  private typealias PendingDismissal = (
    sessionIdentifier: Int64,
    actionInvoked: Bool,
    generation: Int
  )

  private let flutterApi: NativeSelectableTextMenuFlutterApiProtocol
  private var actionDeliveryGenerations: [DeliveryIdentifier: Int] = [:]
  private var dismissalDeliveryGenerations: [DeliveryIdentifier: Int] = [:]
  private var pendingDismissals: [DeliveryIdentifier: PendingDismissal] = [:]
  private var nextDeliveryGeneration = 1
  private var isDisposed = false

  internal init(flutterApi: NativeSelectableTextMenuFlutterApiProtocol) {
    self.flutterApi = flutterApi
  }

  internal func sendAction(
    menuIdentifier: ObjectIdentifier,
    sessionIdentifier: Int64,
    actionIdentifier: Int64
  ) {
    sendAction(
      deliveryIdentifier: .menu(menuIdentifier),
      sessionIdentifier: sessionIdentifier,
      actionIdentifier: actionIdentifier
    )
  }

  internal func sendDismissal(
    menuIdentifier: ObjectIdentifier,
    sessionIdentifier: Int64,
    actionInvoked: Bool
  ) {
    sendDismissal(
      deliveryIdentifier: .menu(menuIdentifier),
      sessionIdentifier: sessionIdentifier,
      actionInvoked: actionInvoked
    )
  }

  internal func sendUnavailablePresentationDismissal(sessionIdentifier: Int64) {
    sendDismissal(
      deliveryIdentifier: .queuedPresentation(sessionIdentifier),
      sessionIdentifier: sessionIdentifier,
      actionInvoked: false
    )
  }

  internal func dispose() {
    performOnMain {
      guard !self.isDisposed else {
        return
      }

      self.isDisposed = true
      self.actionDeliveryGenerations.removeAll()
      self.dismissalDeliveryGenerations.removeAll()
      self.pendingDismissals.removeAll()
    }
  }

  private func sendAction(
    deliveryIdentifier: DeliveryIdentifier,
    sessionIdentifier: Int64,
    actionIdentifier: Int64
  ) {
    performOnMain {
      guard !isDisposed else {
        return
      }

      let generation = takeNextDeliveryGeneration()
      actionDeliveryGenerations[deliveryIdentifier] = generation
      DispatchQueue.main.async { [weak self] in
        guard
          let self,
          !self.isDisposed,
          self.actionDeliveryGenerations[deliveryIdentifier] == generation
        else {
          return
        }

        self.flutterApi.onAction(
          sessionIdentifier: sessionIdentifier,
          actionIdentifier: actionIdentifier
        ) { [weak self] _ in
          guard let self else {
            return
          }
          self.performOnMain {
            self.completeAction(
              deliveryIdentifier: deliveryIdentifier,
              generation: generation
            )
          }
        }
      }
    }
  }

  private func sendDismissal(
    deliveryIdentifier: DeliveryIdentifier,
    sessionIdentifier: Int64,
    actionInvoked: Bool
  ) {
    performOnMain {
      guard !isDisposed else {
        return
      }

      let generation = takeNextDeliveryGeneration()
      dismissalDeliveryGenerations[deliveryIdentifier] = generation
      let dismissal: PendingDismissal = (
        sessionIdentifier: sessionIdentifier,
        actionInvoked: actionInvoked,
        generation: generation
      )
      if actionDeliveryGenerations[deliveryIdentifier] != nil {
        pendingDismissals[deliveryIdentifier] = dismissal
        return
      }
      scheduleDismissal(
        deliveryIdentifier: deliveryIdentifier,
        dismissal: dismissal
      )
    }
  }

  private func completeAction(deliveryIdentifier: DeliveryIdentifier, generation: Int) {
    guard
      !isDisposed,
      actionDeliveryGenerations[deliveryIdentifier] == generation
    else {
      return
    }

    actionDeliveryGenerations.removeValue(forKey: deliveryIdentifier)
    guard
      let dismissal = pendingDismissals.removeValue(forKey: deliveryIdentifier),
      dismissalDeliveryGenerations[deliveryIdentifier] == dismissal.generation
    else {
      return
    }
    scheduleDismissal(
      deliveryIdentifier: deliveryIdentifier,
      dismissal: dismissal
    )
  }

  private func scheduleDismissal(
    deliveryIdentifier: DeliveryIdentifier,
    dismissal: PendingDismissal
  ) {
    DispatchQueue.main.async { [weak self] in
      guard
        let self,
        !self.isDisposed,
        self.dismissalDeliveryGenerations[deliveryIdentifier] == dismissal.generation
      else {
        return
      }

      self.flutterApi.onDismissed(
        sessionIdentifier: dismissal.sessionIdentifier,
        actionInvoked: dismissal.actionInvoked
      ) { [weak self] _ in
        guard let self else {
          return
        }
        self.performOnMain {
          guard
            self.dismissalDeliveryGenerations[deliveryIdentifier] == dismissal.generation
          else {
            return
          }
          self.dismissalDeliveryGenerations.removeValue(forKey: deliveryIdentifier)
        }
      }
    }
  }

  private func takeNextDeliveryGeneration() -> Int {
    let generation = nextDeliveryGeneration
    nextDeliveryGeneration += 1
    return generation
  }

  private func performOnMain<Result>(_ operation: () -> Result) -> Result {
    if Thread.isMainThread {
      return operation()
    }
    return DispatchQueue.main.sync(execute: operation)
  }
}
