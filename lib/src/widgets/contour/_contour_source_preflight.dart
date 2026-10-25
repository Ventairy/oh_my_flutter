part of 'contour.dart';

class _ContourSourcePreflight {
  static final _builders = Expando<ui.SceneBuilder>();
  static int _observationDepth = 0;

  static bool get observing => _observationDepth != 0;

  static T observe<T>(T Function() action) {
    _observationDepth++;
    try {
      return action();
    } finally {
      _observationDepth--;
    }
  }

  static ui.SceneBuilder forScene(ui.SceneBuilder scene) {
    final existing = _builders[scene];
    if (existing != null) return existing;
    final builder = ui.SceneBuilder();
    _builders[scene] = builder;
    // A snapshot may be built while no application frame is pending. Release
    // its observation scene after synchronous scene construction, including
    // exports, instead of retaining it until a future frame happens to run.
    scheduleMicrotask(() {
      _builders[scene] = null;
      builder.build().dispose();
    });
    return builder;
  }
}
