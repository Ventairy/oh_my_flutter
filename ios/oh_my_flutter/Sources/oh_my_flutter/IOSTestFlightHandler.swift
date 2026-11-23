import MarketplaceKit

final class IOSTestFlightHandler: TestFlightHostApi {
  func checkTestFlight() async -> Bool? {
    #if targetEnvironment(simulator)
    return false
    #else
    guard #available(iOS 17.4, *) else { return false }
    return await Self.resolve { try await AppDistributor.current }
    #endif
  }

  @available(iOS 17.4, *)
  static func resolve(_ distributor: () async throws -> AppDistributor) async -> Bool? {
    do {
      if case .testFlight = try await distributor() { return true }
      return false
    } catch {
      return nil
    }
  }
}
