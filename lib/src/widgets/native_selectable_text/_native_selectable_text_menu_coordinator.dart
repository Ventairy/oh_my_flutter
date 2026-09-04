part of 'native_selectable_text.dart';

final class _NativeSelectableTextMenuCoordinator implements NativeSelectableTextMenuFlutterApi {
  _NativeSelectableTextMenuCoordinator._();

  static final instance = _NativeSelectableTextMenuCoordinator._();
  final NativeSelectableTextMenuHostApi _hostApi = NativeSelectableTextMenuHostApi();
  bool _initialized = false;
  int _nextSessionIdentifier = 1;
  int? _activeSessionIdentifier;
  Map<int, VoidCallback> _presentedActions = const <int, VoidCallback>{};
  Map<int, VoidCallback>? _inFlightActions;
  VoidCallback? _onExternalDismissed;
  VoidCallback? _onActionDismissed;

  int createSessionIdentifier() {
    _ensureInitialized();
    return _nextSessionIdentifier++;
  }

  Future<bool> show({
    required NativeSelectableTextMenuRequestMessage request,
    required Map<int, VoidCallback> actions,
    required VoidCallback onExternalDismissed,
    required VoidCallback onActionDismissed,
  }) async {
    final previousDismissed = _onExternalDismissed;
    if (_activeSessionIdentifier != null && _activeSessionIdentifier != request.sessionIdentifier) {
      previousDismissed?.call();
    }
    _activeSessionIdentifier = request.sessionIdentifier;
    _presentedActions = actions;
    _inFlightActions = null;
    _onExternalDismissed = onExternalDismissed;
    _onActionDismissed = onActionDismissed;
    try {
      final shown = await _hostApi.show(request);
      if (!shown && _activeSessionIdentifier == request.sessionIdentifier) {
        _clearActiveSession();
      }
      return shown;
    } on MissingPluginException {
      _clearSession(request.sessionIdentifier);
      return false;
    } on PlatformException {
      _clearSession(request.sessionIdentifier);
      return false;
    }
  }

  Future<bool> update({
    required NativeSelectableTextMenuRequestMessage request,
    required Map<int, VoidCallback> actions,
  }) async {
    if (_activeSessionIdentifier != request.sessionIdentifier) {
      return false;
    }
    _inFlightActions = actions;
    try {
      final updated = await _hostApi.update(request);
      if (!updated) {
        _clearSession(request.sessionIdentifier);
      } else if (_activeSessionIdentifier == request.sessionIdentifier && identical(_inFlightActions, actions)) {
        _presentedActions = actions;
        _inFlightActions = null;
      }
      return updated;
    } on MissingPluginException {
      _clearSession(request.sessionIdentifier);
      return false;
    } on PlatformException {
      _clearSession(request.sessionIdentifier);
      return false;
    }
  }

  Future<bool> updateGeometry({
    required int sessionIdentifier,
    required Float64List geometry,
  }) async {
    if (_activeSessionIdentifier != sessionIdentifier) {
      return false;
    }
    try {
      final updated = await _hostApi.updateGeometry(sessionIdentifier, geometry);
      if (!updated) {
        _clearSession(sessionIdentifier);
      }
      return updated;
    } on MissingPluginException {
      _clearSession(sessionIdentifier);
      return false;
    } on PlatformException {
      _clearSession(sessionIdentifier);
      return false;
    }
  }

  void hide(int sessionIdentifier) {
    if (_activeSessionIdentifier != sessionIdentifier) {
      return;
    }
    _clearActiveSession();
    unawaited(_hostApi.hide(sessionIdentifier).catchError((Object _) {}));
  }

  @override
  Future<void> onAction(int sessionIdentifier, int actionIdentifier) {
    if (_activeSessionIdentifier != sessionIdentifier) {
      return Future<void>.value();
    }
    (_inFlightActions?[actionIdentifier] ?? _presentedActions[actionIdentifier])?.call();
    return Future<void>.value();
  }

  @override
  Future<void> onDismissed(int sessionIdentifier, bool actionInvoked) {
    if (_activeSessionIdentifier != sessionIdentifier) {
      return Future<void>.value();
    }
    final onExternalDismissed = _onExternalDismissed;
    final onActionDismissed = _onActionDismissed;
    _clearActiveSession();
    if (actionInvoked) {
      onActionDismissed?.call();
    } else {
      onExternalDismissed?.call();
    }
    return Future<void>.value();
  }

  void _ensureInitialized() {
    if (_initialized) {
      return;
    }
    NativeSelectableTextMenuFlutterApi.setUp(this);
    _initialized = true;
  }

  void _clearSession(int sessionIdentifier) {
    if (_activeSessionIdentifier == sessionIdentifier) {
      _clearActiveSession();
    }
  }

  void _clearActiveSession() {
    _activeSessionIdentifier = null;
    _presentedActions = const <int, VoidCallback>{};
    _inFlightActions = null;
    _onExternalDismissed = null;
    _onActionDismissed = null;
  }
}
