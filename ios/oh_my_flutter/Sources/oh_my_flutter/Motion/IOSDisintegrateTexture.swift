import CoreVideo
import Flutter
import Foundation

internal final class IOSDisintegrateTexture: NSObject, FlutterTexture {
  internal var onImageAcquired: ((Int64) -> Void)?
  internal var onUnregistered: (() -> Void)?

  private let imageLock = NSLock()
  private var image: CVPixelBuffer?
  private var imageHandle: Int64 = 0
  private var acquiredHandle: Int64 = 0

  internal func publish(_ image: CVPixelBuffer, handle: Int64) {
    imageLock.lock()
    self.image = image
    imageHandle = handle
    imageLock.unlock()
  }

  internal func clear() {
    imageLock.lock()
    image = nil
    imageHandle = 0
    acquiredHandle = 0
    imageLock.unlock()
  }

  internal func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    imageLock.lock()
    let currentImage = image
    let handle = imageHandle
    let isFirstAcquisition = currentImage != nil && acquiredHandle != handle
    if isFirstAcquisition { acquiredHandle = handle }
    let retainedImage = currentImage.map(Unmanaged.passRetained)
    imageLock.unlock()
    if isFirstAcquisition {
      DispatchQueue.main.async { [weak self] in self?.onImageAcquired?(handle) }
    }
    return retainedImage
  }

  internal func onTextureUnregistered(_ texture: any FlutterTexture) {
    DispatchQueue.main.async { [weak self] in self?.onUnregistered?() }
  }
}
