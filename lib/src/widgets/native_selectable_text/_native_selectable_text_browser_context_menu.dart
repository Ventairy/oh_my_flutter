part of 'native_selectable_text.dart';

final class _NativeSelectableTextBrowserContextMenu {
  _NativeSelectableTextBrowserContextMenu._();

  static final instance = _NativeSelectableTextBrowserContextMenu._();

  final Set<Object> _leases = Set<Object>.identity();
  Future<void> _operation = Future<void>.value();
  bool _restoreWhenIdle = false;

  void acquire(Object lease) {
    if (!kIsWeb || !_leases.add(lease) || _leases.length != 1) {
      return;
    }
    if (BrowserContextMenu.enabled) {
      _restoreWhenIdle = true;
    }
    _queueOperation(() async {
      if (_leases.isNotEmpty && BrowserContextMenu.enabled) {
        await BrowserContextMenu.disableContextMenu();
      }
    });
  }

  void release(Object lease) {
    if (!kIsWeb || !_leases.remove(lease) || _leases.isNotEmpty) {
      return;
    }
    _queueOperation(() async {
      if (_leases.isEmpty && _restoreWhenIdle) {
        if (!BrowserContextMenu.enabled) {
          await BrowserContextMenu.enableContextMenu();
        }
        if (_leases.isEmpty) {
          _restoreWhenIdle = false;
        }
      }
    });
  }

  void _queueOperation(Future<void> Function() operation) {
    _operation = _operation.then((_) => operation()).catchError((Object _) {});
  }
}
