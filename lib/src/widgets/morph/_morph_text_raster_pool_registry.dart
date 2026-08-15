part of 'morph.dart';

final class _MorphTextRasterPoolRegistry with WidgetsBindingObserver {
  _MorphTextRasterPoolRegistry._() {
    WidgetsBinding.instance.addObserver(this);
    PaintingBinding.instance.systemFonts.addListener(_clearPools);
  }

  static _MorphTextRasterPoolRegistry? _instance;

  static void register(_MorphTextRasterPool pool) {
    final registry = _instance ??= _MorphTextRasterPoolRegistry._();
    registry._pools
      ..removeWhere((reference) => reference.target == null)
      ..add(WeakReference<_MorphTextRasterPool>(pool));
  }

  static void unregister(_MorphTextRasterPool pool) {
    _instance?._pools.removeWhere((reference) {
      final target = reference.target;
      return target == null || identical(target, pool);
    });
  }

  static void prune() {
    _instance?._removeDeadPools();
  }

  static int get debugPoolCount => _instance?._pools.length ?? 0;

  final List<WeakReference<_MorphTextRasterPool>> _pools = <WeakReference<_MorphTextRasterPool>>[];

  @override
  void didHaveMemoryPressure() {
    _clearPools();
  }

  void _clearPools() {
    _pools.removeWhere((reference) {
      final pool = reference.target;
      if (pool == null) return true;
      pool.clear();
      return false;
    });
  }

  void _removeDeadPools() {
    _pools.removeWhere((reference) => reference.target == null);
  }
}
