import Foundation

/// Delivers one iOS selection-menu session's events to Flutter in order.
internal final class IOSNativeSelectableTextMenuEventDispatcher {
  private let flutterApi: NativeSelectableTextMenuFlutterApiProtocol
  private var actionDeliveryGenerations: [Int64: Int] = [:]
  private var dismissalDeliveryGenerations: [Int64: Int] = [:]
  private var pendingDismissals: [Int64: (actionInvoked: Bool, generation: Int)] = [:]
  private var nextDeliveryGeneration = 1
  private var isDisposed = false

  internal init(flutterApi: NativeSelectableTextMenuFlutterApiProtocol) {
    self.flutterApi = flutterApi
  }

  internal func sendAction(sessionIdentifier: Int64, actionIdentifier: Int64) {
    performOnMain {
      guard !isDisposed else {
        return
      }

      let generation = takeNextDeliveryGeneration()
      actionDeliveryGenerations[sessionIdentifier] = generation
      DispatchQueue.main.async { [weak self] in
        guard
          let self,
          !self.isDisposed,
          self.actionDeliveryGenerations[sessionIdentifier] == generation
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
              sessionIdentifier: sessionIdentifier,
              generation: generation
            )
          }
        }
      }
    }
  }

  internal func sendDismissal(sessionIdentifier: Int64, actionInvoked: Bool) {
    performOnMain {
      guard !isDisposed else {
        return
      }

      let generation = takeNextDeliveryGeneration()
      dismissalDeliveryGenerations[sessionIdentifier] = generation
      if actionDeliveryGenerations[sessionIdentifier] != nil {
        pendingDismissals[sessionIdentifier] = (
          actionInvoked: actionInvoked,
          generation: generation
        )
        return
      }
      scheduleDismissal(
        sessionIdentifier: sessionIdentifier,
        actionInvoked: actionInvoked,
        generation: generation
      )
    }
  }

  internal func dispose() {
    performOnMain {
      guard !isDisposed else {
        return
      }

      isDisposed = true
      actionDeliveryGenerations.removeAll()
      dismissalDeliveryGenerations.removeAll()
      pendingDismissals.removeAll()
    }
  }

  private func completeAction(sessionIdentifier: Int64, generation: Int) {
    guard
      !isDisposed,
      actionDeliveryGenerations[sessionIdentifier] == generation
    else {
      return
    }

    actionDeliveryGenerations.removeValue(forKey: sessionIdentifier)
    guard
      let dismissal = pendingDismissals.removeValue(forKey: sessionIdentifier),
      dismissalDeliveryGenerations[sessionIdentifier] == dismissal.generation
    else {
      return
    }
    scheduleDismissal(
      sessionIdentifier: sessionIdentifier,
      actionInvoked: dismissal.actionInvoked,
      generation: dismissal.generation
    )
  }

  private func scheduleDismissal(
    sessionIdentifier: Int64,
    actionInvoked: Bool,
    generation: Int
  ) {
    DispatchQueue.main.async { [weak self] in
      guard
        let self,
        !self.isDisposed,
        self.dismissalDeliveryGenerations[sessionIdentifier] == generation
      else {
        return
      }

      self.flutterApi.onDismissed(
        sessionIdentifier: sessionIdentifier,
        actionInvoked: actionInvoked
      ) { [weak self] _ in
        guard let self else {
          return
        }
        self.performOnMain {
          guard self.dismissalDeliveryGenerations[sessionIdentifier] == generation else {
            return
          }
          self.dismissalDeliveryGenerations.removeValue(forKey: sessionIdentifier)
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
