import Flutter
import Foundation

/// Records the thread used by native-to-Flutter messages in iOS tests.
internal final class IOSNativeSelectableTextMenuBinaryMessengerSpy: NSObject,
  FlutterBinaryMessenger
{
  internal private(set) var sendsWereOnMainThread: [Bool] = []

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
    _: String,
    binaryMessageHandler _: FlutterBinaryMessageHandler? = nil
  ) -> FlutterBinaryMessengerConnection {
    0
  }

  internal func cleanUpConnection(_: FlutterBinaryMessengerConnection) {}
}
