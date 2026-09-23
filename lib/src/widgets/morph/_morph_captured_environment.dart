part of 'morph.dart';

final class _MorphCapturedEnvironment {
  factory of(BuildContext context) {
    if (context case StatefulElement(:final _MorphState state)) {
      return state._capturedEnvironment ?? _MorphCapturedEnvironment._(context);
    }
    return _MorphCapturedEnvironment._(context);
  }

  new _(this._context);

  final BuildContext _context;

  late final CapturedThemes capturedThemes = InheritedTheme.capture(
    from: _context,
    to: null,
  );

  late final MediaQueryData? mediaQueryData = MediaQuery.maybeOf(_context);
}
