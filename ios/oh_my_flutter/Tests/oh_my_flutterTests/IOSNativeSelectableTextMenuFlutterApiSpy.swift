import Foundation

@testable import oh_my_flutter

internal final class IOSNativeSelectableTextMenuFlutterApiSpy:
  NativeSelectableTextMenuFlutterApiProtocol
{
  internal private(set) var actions: [(sessionIdentifier: Int64, actionIdentifier: Int64)] = []
  internal private(set) var dismissals: [(sessionIdentifier: Int64, actionInvoked: Bool)] = []
  internal private(set) var events: [String] = []
  internal private(set) var actionDeliveriesWereOnMainThread: [Bool] = []
  internal private(set) var dismissalDeliveriesWereOnMainThread: [Bool] = []
  internal var suspendsActionDelivery = false
  internal var suspendsDismissalDelivery = false
  private var actionDeliveryCompletion: (() -> Void)?
  private var dismissalDeliveryCompletion: (() -> Void)?

  internal func onAction(
    sessionIdentifier: Int64,
    actionIdentifier: Int64,
    completion: @escaping (Result<Void, NativeSelectableTextPigeonError>) -> Void
  ) {
    actionDeliveriesWereOnMainThread.append(Thread.isMainThread)
    actions.append((sessionIdentifier, actionIdentifier))
    events.append("action:\(sessionIdentifier):\(actionIdentifier)")
    if suspendsActionDelivery {
      actionDeliveryCompletion = {
        completion(.success(()))
      }
    } else {
      completion(.success(()))
    }
  }

  internal func onDismissed(
    sessionIdentifier: Int64,
    actionInvoked: Bool,
    completion: @escaping (Result<Void, NativeSelectableTextPigeonError>) -> Void
  ) {
    dismissalDeliveriesWereOnMainThread.append(Thread.isMainThread)
    dismissals.append((sessionIdentifier, actionInvoked))
    events.append("dismissal:\(sessionIdentifier):\(actionInvoked)")
    if suspendsDismissalDelivery {
      dismissalDeliveryCompletion = {
        completion(.success(()))
      }
    } else {
      completion(.success(()))
    }
  }

  internal func resumeActionDelivery() {
    actionDeliveryCompletion?()
    actionDeliveryCompletion = nil
  }

  internal func resumeDismissalDelivery() {
    dismissalDeliveryCompletion?()
    dismissalDeliveryCompletion = nil
  }
}
