part of 'morph.dart';

final class _MorphTextRasterPoolEntry {
  _MorphTextRasterPoolEntry({
    required this.key,
    required this.image,
  });

  final _MorphTextRasterPoolKey key;
  final ui.Image image;
  int leases = 0;
  bool evicted = false;

  void dispose() {
    image.dispose();
  }
}
