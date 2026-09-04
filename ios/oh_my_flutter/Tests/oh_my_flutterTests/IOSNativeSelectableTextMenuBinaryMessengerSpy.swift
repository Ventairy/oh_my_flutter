import Flutter
import Foundation

/// Records the thread used by native-to-Flutter messages in iOS tests.
internal final class IOSNativeSelectableTextMenuBinaryMessengerSpy: NSObject,
  FlutterBinaryMessenger
{
  internal private(set) var sendsWereOnMainThread: [Bool] = []
  internal private(set) var messageHandlers: [String: FlutterBinaryMessageHandler] = [:]

  internal func send(onChannel _: String, message _: Data?) {
    sendsWereOnMainThread.append(Thread.isMainThread)
  }

  internal func send(
    onChannel _: String,
    message _: Data?,
    binaryReply callback: FlutterBinaryReply? = nil
  ) {
    sendsWereOnMainThread.append(Thread.isMainThread)
    callback?(FlutterStandardMessageCodec.sharedInstance().encode([nil]))
  }

  internal func setMessageHandlerOnChannel(
    _ channel: String,
    binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
  ) -> FlutterBinaryMessengerConnection {
    if let handler {
      messageHandlers[channel] = handler
    } else {
      messageHandlers.removeValue(forKey: channel)
    }
    return 0
  }

  internal func cleanUpConnection(_: FlutterBinaryMessengerConnection) {}
}
