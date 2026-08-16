part of 'morph.dart';

/// Defines a text-specific Morph transition.
final class MorphTextFlightDelegate extends MorphFlightDelegate<MorphTextProperties> {
  /// Creates a transition for plain text.
  const MorphTextFlightDelegate({
    this.switchThreshold = 0.5,
    this.switchTransition,
  }) : assert(
         switchThreshold >= 0 && switchThreshold <= 1,
         'switchThreshold must be between 0 and 1.',
       );

  /// Progress at which the visible text and non-interpolated paragraph values
  /// switch to the destination.
  final double switchThreshold;

  /// Transition applied when the visible text changes at [switchThreshold].
  ///
  /// The supplied animation moves from 1 to 0 for the departing text and from
  /// 0 to 1 for the arriving text. It is unused when both endpoints contain
  /// the same text.
  final AnimatedSwitcherTransitionBuilder? switchTransition;

  /// Returns the visual values used to transition [text].
  static MorphTextProperties captureText({
    required BuildContext context,
    required Text text,
    required Size size,
    required Offset axisScale,
    required double switchThreshold,
  }) {
    final data = text.data;
    if (data == null) {
      throw ArgumentError.value(
        text,
        'text',
        'Morph supports Text.data only; Text.rich is not supported.',
      );
    }

    final direction = text.textDirection ?? Directionality.of(context);
    final textScaler = text.textScaler ?? MediaQuery.textScalerOf(context);
    final defaultTextStyle = DefaultTextStyle.of(context);
    final baseStyle = defaultTextStyle.style.merge(text.style);
    final textAlign = text.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start;
    final softWrap = text.softWrap ?? defaultTextStyle.softWrap;
    final overflow = text.overflow ?? defaultTextStyle.overflow;
    final maxLines = text.maxLines ?? defaultTextStyle.maxLines;
    final textWidthBasis = text.textWidthBasis ?? defaultTextStyle.textWidthBasis;
    final textHeightBehavior = text.textHeightBehavior ?? defaultTextStyle.textHeightBehavior;
    final locale = text.locale ?? Localizations.maybeLocaleOf(context);
    final resolvedStyle = axisScale.dy == 1 ? baseStyle : baseStyle.apply(fontSizeFactor: axisScale.dy);
    final resolvedStrutStyle = _scaleStrutStyle(
      text.strutStyle,
      axisScale.dy,
    );
    final horizontalPaintScale = axisScale.dx / axisScale.dy;
    final availableLayoutWidth = size.width.isFinite ? size.width / horizontalPaintScale : double.infinity;
    final painter = TextPainter(
      text: TextSpan(text: data, style: resolvedStyle),
      textAlign: textAlign,
      textDirection: direction,
      textScaler: textScaler,
      locale: locale,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      strutStyle: resolvedStrutStyle,
      maxLines: maxLines,
      ellipsis: overflow == TextOverflow.ellipsis ? '…' : null,
    );
    try {
      final maxWidth = softWrap || overflow == TextOverflow.ellipsis ? availableLayoutWidth : double.infinity;
      painter.layout(
        maxWidth: maxWidth,
      );
      final lineMetrics = painter.computeLineMetrics();
      final firstLine = lineMetrics.firstOrNull;
      final lineHeight = resolvedStrutStyle == null
          ? painter.preferredLineHeight
          : firstLine?.height ?? painter.preferredLineHeight;
      final layoutWidth = availableLayoutWidth.isFinite ? availableLayoutWidth : painter.width;

      return MorphTextProperties(
        text: data,
        style: resolvedStyle,
        textAlign: textAlign,
        textDirection: direction,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: text.semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        strutStyle: resolvedStrutStyle,
        selectionColor: text.selectionColor,
        switchThreshold: switchThreshold,
        measuredLineCount: math.max(1, lineMetrics.length),
        longestLineWidth: lineMetrics.fold<double>(
          0,
          (width, line) => math.max(width, line.width),
        ),
        lineHeight: lineHeight,
        baseline: firstLine?.baseline ?? 0,
        layoutWidth: layoutWidth,
        estimatedHeight: painter.height,
        paintStyle: resolvedStyle,
        paintScaleX: horizontalPaintScale,
        paintScaleY: 1,
        endpointScaleX: axisScale.dx,
        endpointScaleY: axisScale.dy,
        baselineOffset: 0,
        reservedLayoutWidth: null,
      );
    } finally {
      painter.dispose();
    }
  }

  static StrutStyle? _scaleStrutStyle(
    StrutStyle? style,
    double scale,
  ) {
    if (style == null || scale == 1) return style;
    return StrutStyle(
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      fontSize: (style.fontSize ?? kDefaultFontSize) * scale,
      height: style.height,
      leadingDistribution: style.leadingDistribution,
      leading: style.leading,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      forceStrutHeight: style.forceStrutHeight,
      debugLabel: style.debugLabel,
    );
  }

  @override
  MorphTextProperties properties(MorphEndpointContext endpoint) {
    if (!endpoint._hasSupportedBuiltInTransform) {
      throw ArgumentError.value(
        endpoint.transform,
        'endpoint.transform',
        'Built-in Text Morph supports axis-aligned translation and positive scale only.',
      );
    }
    final child = endpoint.child;
    if (child is! Text) {
      throw ArgumentError.value(
        child,
        'endpoint.child',
        'MorphTextFlightDelegate requires a Text child.',
      );
    }
    return captureText(
      context: endpoint.context,
      text: child,
      size: endpoint.overlayBounds.size,
      axisScale: endpoint.axisScale,
      switchThreshold: switchThreshold,
    );
  }

  @override
  MorphTextProperties lerp(
    MorphTextProperties source,
    MorphTextProperties destination,
    double progress,
  ) => _lerp(
    source,
    destination,
    progress,
    estimateHeight: true,
  );

  MorphTextProperties _lerpForPaint(
    MorphTextProperties source,
    MorphTextProperties destination,
    double progress,
  ) => _lerp(
    source,
    destination,
    progress,
    estimateHeight: false,
  );

  MorphTextProperties _lerp(
    MorphTextProperties source,
    MorphTextProperties destination,
    double progress, {
    required bool estimateHeight,
  }) {
    if (progress <= 0) return source;
    if (progress >= 1) return destination;

    final threshold = source.switchThreshold;
    final showSource = progress < threshold;
    final selected = showSource ? source : destination;
    final style = TextStyle.lerp(source.style, destination.style, progress)!;
    final lineHeight = _lerpDouble(
      source.lineHeight,
      destination.lineHeight,
      progress,
    );
    final baseline = _lerpDouble(
      source.baseline,
      destination.baseline,
      progress,
    );
    final layoutWidth = _lerpDouble(
      source.layoutWidth,
      destination.layoutWidth,
      progress,
    );
    var paintStyle = style;
    final endpointScaleX = _lerpDouble(
      source.endpointScaleX,
      destination.endpointScaleX,
      progress,
    );
    final endpointScaleY = _lerpDouble(
      source.endpointScaleY,
      destination.endpointScaleY,
      progress,
    );
    var paintScaleX = endpointScaleX / endpointScaleY;
    var paintScaleY = 1.0;
    var baselineOffset = 0.0;
    double? reservedLayoutWidth;
    ({double baseline, double height, double lineHeight})? paintMetrics;
    final sourceFontSize = source.style.fontSize;
    final interpolatedFontSize = style.fontSize;
    final destinationFontSize = destination.style.fontSize;
    if (sourceFontSize != null && sourceFontSize > 0 && destinationFontSize != null && destinationFontSize > 0) {
      reservedLayoutWidth = _reservedLayoutWidth(
        source: source,
        destination: destination,
        showSource: showSource,
      );
    }
    if (sourceFontSize != null &&
        destinationFontSize != null &&
        sourceFontSize != destinationFontSize &&
        interpolatedFontSize != null &&
        interpolatedFontSize > 0 &&
        destinationFontSize > 0 &&
        destination.lineHeight > 0) {
      paintStyle = style.copyWith(fontSize: destinationFontSize);
      paintScaleX *= interpolatedFontSize / destinationFontSize;
      if (selected.strutStyle != null) {
        paintMetrics = _measurePaintMetrics(
          selected: selected,
          paintStyle: paintStyle,
          layoutWidth: reservedLayoutWidth ?? layoutWidth,
          maxLines: selected.maxLines,
        );
      }
      final anchorLineHeight = paintMetrics?.lineHeight ?? destination.lineHeight;
      final anchorBaseline = paintMetrics?.baseline ?? destination.baseline;
      paintScaleY = lineHeight / anchorLineHeight;
      baselineOffset = baseline - anchorBaseline * paintScaleY;
    }
    final estimatedHeight = paintMetrics != null
        ? paintMetrics.height * paintScaleY
        : !estimateHeight
        ? selected.estimatedHeight
        : _estimatedHeight(
            selected: selected,
            paintStyle: paintStyle,
            paintScaleY: paintScaleY,
            layoutWidth: reservedLayoutWidth ?? layoutWidth,
            maxLines: selected.maxLines,
          );
    return MorphTextProperties(
      text: selected.text,
      style: style,
      textAlign: selected.textAlign,
      textDirection: selected.textDirection,
      locale: selected.locale,
      softWrap: selected.softWrap,
      overflow: selected.overflow,
      textScaler: selected.textScaler,
      maxLines: selected.maxLines,
      semanticsLabel: selected.semanticsLabel,
      textWidthBasis: selected.textWidthBasis,
      textHeightBehavior: selected.textHeightBehavior,
      strutStyle: selected.strutStyle,
      selectionColor: Color.lerp(
        source.selectionColor,
        destination.selectionColor,
        progress,
      ),
      switchThreshold: threshold,
      measuredLineCount: selected.measuredLineCount,
      longestLineWidth: selected.longestLineWidth,
      lineHeight: lineHeight,
      baseline: baseline,
      layoutWidth: layoutWidth,
      estimatedHeight: estimatedHeight,
      paintStyle: paintStyle,
      paintScaleX: paintScaleX,
      paintScaleY: paintScaleY,
      endpointScaleX: endpointScaleX,
      endpointScaleY: endpointScaleY,
      baselineOffset: baselineOffset,
      reservedLayoutWidth: reservedLayoutWidth,
    );
  }

  double _lerpDouble(double source, double destination, double progress) {
    return source + (destination - source) * progress;
  }

  double? _reservedLayoutWidth({
    required MorphTextProperties source,
    required MorphTextProperties destination,
    required bool showSource,
  }) {
    final sourceFontSize = source.style.fontSize;
    final destinationFontSize = destination.style.fontSize;
    if (sourceFontSize == null || sourceFontSize <= 0) return null;
    if (destinationFontSize == null || destinationFontSize <= 0) return null;
    if (source.layoutWidth <= 0 || destination.layoutWidth <= 0) return null;
    if (!showSource) return destination.layoutWidth;

    final fontScale = destinationFontSize / sourceFontSize;
    final sourceWidthAtDestinationFont = source.layoutWidth * fontScale;
    final previouslyReservedWidth = math.min(
      sourceWidthAtDestinationFont,
      destination.layoutWidth,
    );
    if (source.softWrap == false) return previouslyReservedWidth;
    if (source.measuredLineCount != 1) {
      return sourceWidthAtDestinationFont;
    }

    final singleLineWidth = source.longestLineWidth * fontScale;
    return math.max(
      previouslyReservedWidth,
      singleLineWidth + precisionErrorTolerance,
    );
  }

  double _estimatedHeight({
    required MorphTextProperties selected,
    required TextStyle paintStyle,
    required double paintScaleY,
    required double layoutWidth,
    required int? maxLines,
  }) {
    if (!layoutWidth.isFinite || layoutWidth <= 0) {
      return selected.estimatedHeight;
    }
    final painter = TextPainter(
      text: TextSpan(text: selected.text, style: paintStyle),
      textAlign: selected.textAlign ?? TextAlign.start,
      textDirection: selected.textDirection,
      textScaler: selected.textScaler,
      locale: selected.locale,
      textWidthBasis: selected.textWidthBasis ?? TextWidthBasis.parent,
      textHeightBehavior: selected.textHeightBehavior,
      strutStyle: selected.strutStyle,
      maxLines: maxLines,
      ellipsis: selected.overflow == TextOverflow.ellipsis ? '…' : null,
    );
    try {
      painter.layout(
        maxWidth: (selected.softWrap ?? true) || selected.overflow == TextOverflow.ellipsis
            ? layoutWidth
            : double.infinity,
      );
      return painter.height * paintScaleY;
    } finally {
      painter.dispose();
    }
  }

  ({double baseline, double height, double lineHeight}) _measurePaintMetrics({
    required MorphTextProperties selected,
    required TextStyle paintStyle,
    required double layoutWidth,
    required int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: selected.text, style: paintStyle),
      textAlign: selected.textAlign ?? TextAlign.start,
      textDirection: selected.textDirection,
      textScaler: selected.textScaler,
      locale: selected.locale,
      textWidthBasis: selected.textWidthBasis ?? TextWidthBasis.parent,
      textHeightBehavior: selected.textHeightBehavior,
      strutStyle: selected.strutStyle,
      maxLines: maxLines,
      ellipsis: selected.overflow == TextOverflow.ellipsis ? '…' : null,
    );
    try {
      painter.layout(
        maxWidth: (selected.softWrap ?? true) || selected.overflow == TextOverflow.ellipsis
            ? layoutWidth
            : double.infinity,
      );
      final firstLine = painter.computeLineMetrics().firstOrNull;
      return (
        baseline: firstLine?.baseline ?? 0,
        height: painter.height,
        lineHeight: firstLine?.height ?? painter.preferredLineHeight,
      );
    } finally {
      painter.dispose();
    }
  }

  Widget _buildProperties(BuildContext context, MorphTextProperties properties) {
    final text = Text(
      properties.text,
      style: properties.paintStyle,
      textAlign: properties.textAlign,
      textDirection: properties.textDirection,
      locale: properties.locale,
      softWrap: properties.softWrap,
      overflow: properties.overflow,
      textScaler: properties.textScaler,
      maxLines: properties.maxLines,
      semanticsLabel: properties.semanticsLabel,
      textWidthBasis: properties.textWidthBasis,
      textHeightBehavior: properties.textHeightBehavior,
      strutStyle: properties.strutStyle,
      selectionColor: properties.selectionColor,
    );
    if (properties.paintScaleX == 1 &&
        properties.paintScaleY == 1 &&
        properties.baselineOffset == 0 &&
        properties.reservedLayoutWidth == null) {
      return text;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final alignment = properties.textDirection == TextDirection.ltr ? Alignment.topLeft : Alignment.topRight;
        final layoutWidth = _paintLayoutWidth(
          properties: properties,
          availableWidth: constraints.hasBoundedWidth ? constraints.maxWidth : null,
        );
        Widget result = text;
        if (layoutWidth != null) {
          result = OverflowBox(
            alignment: alignment,
            fit: OverflowBoxFit.deferToChild,
            minWidth: layoutWidth,
            maxWidth: layoutWidth,
            child: SizedBox(width: layoutWidth, child: result),
          );
        }
        result = Align(
          alignment: alignment,
          widthFactor: properties.paintScaleX,
          heightFactor: properties.paintScaleY,
          child: Transform.scale(
            scaleX: properties.paintScaleX,
            scaleY: properties.paintScaleY,
            alignment: alignment,
            child: result,
          ),
        );
        if (properties.baselineOffset == 0) return result;
        return Transform.translate(
          offset: Offset(0, properties.baselineOffset),
          child: result,
        );
      },
    );
  }

  bool _supportsRetainedFlight(
    MorphTextProperties source,
    MorphTextProperties destination,
  ) {
    return _supportsRetainedProperties(source) && _supportsRetainedProperties(destination);
  }

  static bool _supportsRetainedProperties(MorphTextProperties properties) {
    return switch (properties.overflow ?? TextOverflow.clip) {
      TextOverflow.clip || TextOverflow.ellipsis || TextOverflow.visible => true,
      TextOverflow.fade => false,
    };
  }

  double? _paintLayoutWidth({
    required MorphTextProperties properties,
    required double? availableWidth,
  }) {
    final reservedLayoutWidth = properties.reservedLayoutWidth;
    if (availableWidth == null) return reservedLayoutWidth;
    if (reservedLayoutWidth == null) {
      return availableWidth / properties.paintScaleX;
    }
    return reservedLayoutWidth;
  }

  @override
  Widget buildFlight(
    BuildContext context,
    MorphFlight<MorphTextProperties> flight,
  ) {
    Widget result;
    if (!_supportsRetainedFlight(
      flight.source.properties,
      flight.destination.properties,
    )) {
      result = AnimatedBuilder(
        animation: flight.animation,
        builder: (context, child) => _buildProperties(context, flight.properties),
      );
    } else {
      result = _MorphTextFlight(delegate: this, flight: flight);
    }

    if (!_usesSwitchTransition(
      flight.source.properties,
      flight.destination.properties,
    )) {
      return result;
    }

    return AnimatedBuilder(
      animation: flight.animation,
      child: result,
      builder: (context, child) {
        final progress = flight.animation.value;
        final threshold = flight.source.properties.switchThreshold;

        return _MorphSwitchTransition(
          progress: MorphChildFlightDelegate._transitionProgress(
            progress: progress,
            threshold: threshold,
            departing: progress < threshold,
          ),
          transitionBuilder: switchTransition,
          capturedThemes: null,
          mediaQueryData: null,
          child: child!,
        );
      },
    );
  }

  bool _usesSwitchTransition(
    MorphTextProperties source,
    MorphTextProperties destination,
  ) {
    return switchTransition != null && source.text != destination.text;
  }
}
