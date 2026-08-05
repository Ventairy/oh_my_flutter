part of '../motion.dart';

/// Builds the text paragraph after every effect application is collected.
class _TextMotionTransition extends StatelessWidget {
  factory _TextMotionTransition.initial(Text text) {
    final graphemes = text.data!.characters.toList(growable: false);
    var animatedCharacterCount = 0;
    for (final grapheme in graphemes) {
      if (isVisible(grapheme)) {
        animatedCharacterCount += 1;
      }
    }
    return _TextMotionTransition._(
      text: text,
      graphemes: graphemes,
      animatedCharacterCount: animatedCharacterCount,
      applications: const <_TextMotionApplication>[],
    );
  }

  const _TextMotionTransition._({
    required this.text,
    required this.graphemes,
    required this.animatedCharacterCount,
    required this.applications,
  });

  final Text text;

  final List<String> graphemes;

  final List<_TextMotionApplication> applications;

  final int animatedCharacterCount;

  _TextMotionTransition withText(Text nextText) {
    return _TextMotionTransition._(
      text: nextText,
      graphemes: graphemes,
      animatedCharacterCount: animatedCharacterCount,
      applications: const <_TextMotionApplication>[],
    );
  }

  _TextMotionTransition withApplications(
    List<_TextMotionApplication> nextApplications,
  ) {
    return _TextMotionTransition._(
      text: text,
      graphemes: graphemes,
      animatedCharacterCount: animatedCharacterCount,
      applications: nextApplications,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (animatedCharacterCount == 0) {
      return text;
    }

    final textScaler = _resolveTextScaler(context);
    final effectiveStyle = _resolveTextStyle(context);
    final defaultTextStyle = DefaultTextStyle.of(context);
    final textDirection = text.textDirection ?? Directionality.of(context);
    final locale = text.locale ?? Localizations.maybeLocaleOf(context);
    final textAlign = text.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start;
    final softWrap = text.softWrap ?? defaultTextStyle.softWrap;
    final overflow = text.overflow ?? effectiveStyle.overflow ?? defaultTextStyle.overflow;
    final maxLines = text.maxLines ?? defaultTextStyle.maxLines;
    final textWidthBasis = text.textWidthBasis ?? defaultTextStyle.textWidthBasis;
    final textHeightBehavior =
        text.textHeightBehavior ?? defaultTextStyle.textHeightBehavior ?? DefaultTextHeightBehavior.maybeOf(context);
    final strutStyle = _resolveStrutStyle(context);
    final baseline = effectiveStyle.textBaseline ?? TextBaseline.alphabetic;
    return _OptimizedTextMotion(
      key: text.key,
      graphemes: graphemes,
      applications: applications,
      style: effectiveStyle,
      strutStyle: strutStyle,
      textAlign: textAlign,
      attributedLabel: _semanticsLabel,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      baseline: baseline,
      devicePixelRatio: View.of(context).devicePixelRatio,
      semanticsIdentifier: text.semanticsIdentifier,
    );
  }

  AttributedString get _semanticsLabel {
    final label = text.semanticsLabel ?? text.data!;
    final locale = text.locale;
    if (label.isEmpty || locale == null) {
      return AttributedString(label);
    }
    return AttributedString(
      label,
      attributes: <StringAttribute>[
        LocaleStringAttribute(
          range: TextRange(start: 0, end: label.length),
          locale: locale,
        ),
      ],
    );
  }

  TextScaler _resolveTextScaler(BuildContext context) {
    final textScaler = text.textScaler;
    if (textScaler != null) {
      return textScaler;
    }
    // This preserves the complete Text.new contract while Flutter retains the
    // deprecated argument.
    // ignore: deprecated_member_use
    final textScaleFactor = text.textScaleFactor;
    if (textScaleFactor != null) {
      return TextScaler.linear(textScaleFactor);
    }
    return MediaQuery.textScalerOf(context);
  }

  TextStyle _resolveTextStyle(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final configuredStyle = text.style;
    final effectiveStyle = configuredStyle == null || configuredStyle.inherit
        ? defaultStyle.merge(configuredStyle)
        : configuredStyle;
    var resolvedStyle = effectiveStyle;
    if (MediaQuery.boldTextOf(context)) {
      resolvedStyle = resolvedStyle.merge(
        const TextStyle(fontWeight: FontWeight.bold),
      );
    }
    return resolvedStyle.merge(
      TextStyle(
        height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
        letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
        wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
      ),
    );
  }

  StrutStyle? _resolveStrutStyle(BuildContext? context) {
    final strutStyle = text.strutStyle;
    if (strutStyle == null || context == null) {
      return strutStyle;
    }
    return strutStyle.merge(
      StrutStyle(
        height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
      ),
    );
  }

  static bool isVisible(String grapheme) {
    if (grapheme.trim().isEmpty) {
      return false;
    }
    for (final codePoint in grapheme.runes) {
      if (!_isFormatControl(codePoint)) {
        return true;
      }
    }
    return false;
  }

  static bool _isFormatControl(int codePoint) {
    return codePoint == 0x00AD ||
        codePoint == 0x061C ||
        codePoint == 0x070F ||
        codePoint == 0x180E ||
        codePoint == 0x200B ||
        (codePoint >= 0x200C && codePoint <= 0x200F) ||
        (codePoint >= 0x202A && codePoint <= 0x202E) ||
        (codePoint >= 0x2060 && codePoint <= 0x206F) ||
        codePoint == 0xFEFF ||
        (codePoint >= 0xFFF9 && codePoint <= 0xFFFB) ||
        (codePoint >= 0x1BCA0 && codePoint <= 0x1BCA3) ||
        (codePoint >= 0x1D173 && codePoint <= 0x1D17A) ||
        codePoint == 0xE0001 ||
        (codePoint >= 0xE0020 && codePoint <= 0xE007F);
  }
}
