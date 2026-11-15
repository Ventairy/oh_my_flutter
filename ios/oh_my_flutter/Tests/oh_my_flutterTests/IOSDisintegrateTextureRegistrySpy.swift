import Flutter
import Foundation

internal final class IOSDisintegrateTextureRegistrySpy: NSObject, FlutterTextureRegistry {
  internal private(set) var textures: [Int64: FlutterTexture] = [:]
  internal private(set) var notifications: [Int64] = []
  private var nextId: Int64 = 0

  internal func register(_ texture: FlutterTexture) -> Int64 {
    nextId += 1
    textures[nextId] = texture
    return nextId
  }

  internal func textureFrameAvailable(_ textureId: Int64) {
    notifications.append(textureId)
  }

  internal func unregisterTexture(_ textureId: Int64) {
    textures.removeValue(forKey: textureId)
  }
}
