part of 'morph.dart';

final class _MorphCapturedEnvironment {
  _MorphCapturedEnvironment(this._context);

  final BuildContext _context;

  late final CapturedThemes capturedThemes = InheritedTheme.capture(
    from: _context,
    to: null,
  );

  late final MediaQueryData? mediaQueryData = MediaQuery.maybeOf(_context);
}
