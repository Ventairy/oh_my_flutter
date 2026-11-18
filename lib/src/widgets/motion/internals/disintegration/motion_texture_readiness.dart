part of '../../motion.dart';

class _MotionTextureReadiness {
  new({
    required this.texture,
    required this.handle,
    required this.size,
    required this.probeWidth,
    required this.contentTop,
  });

  // Must match the probe row emitted by Android's ParticleRenderer.
  static const androidProbeWidth = 22;

  final int texture;
  final int handle;
  final Size size;
  final int probeWidth;
  final double contentTop;
  bool _disposed = false;

  static Future<void> acquire({required int texture, required Size size}) async {
    final image = await _renderProbe(texture: texture, size: size, width: 1);
    image.dispose();
  }

  static Future<ui.Image> _renderProbe({required int texture, required Size size, required int width}) async {
    final scene = (ui.SceneBuilder()..addTexture(texture, width: size.width, height: size.height, filterQuality: .none))
        .build();
    try {
      return await scene.toImage(width, 1);
    } finally {
      scene.dispose();
    }
  }

  Future<bool> waitForImage() async {
    final elapsed = Stopwatch()..start();
    while (!_disposed && elapsed.elapsed < const Duration(seconds: 1)) {
      final image = await _renderProbe(texture: texture, size: size, width: probeWidth);
      try {
        final pixels = await image.toByteData();
        if (_disposed) return false;
        if (pixels != null && _matchesHandle(pixels)) return true;
      } finally {
        image.dispose();
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    return false;
  }

  void dispose() => _disposed = true;

  bool _matchesHandle(ByteData pixels) {
    for (var pixel = 0; pixel < probeWidth; pixel++) {
      if (pixels.getUint8(pixel * 4 + 3) != 255) return false;
      for (var channel = 0; channel < 3; channel++) {
        final bit = pixel * 3 + channel;
        final expected = bit < 64 && ((handle >> bit) & 1) != 0;
        if ((pixels.getUint8(pixel * 4 + channel) >= 128) != expected) return false;
      }
    }
    return true;
  }
}
