part of 'morph.dart';

final class _MorphTextRasterPoolLease {
  _MorphTextRasterPoolLease(this._pool, this._entry);

  _MorphTextRasterPool? _pool;
  final _MorphTextRasterPoolEntry _entry;

  ui.Image get image => _entry.image;

  void release() {
    final pool = _pool;
    if (pool == null) return;
    _pool = null;
    pool.release(_entry);
  }
}
