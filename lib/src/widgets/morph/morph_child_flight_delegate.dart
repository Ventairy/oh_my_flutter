part of 'morph.dart';

/// Utilities for transitioning children inside containers and columns.
final class MorphChildFlightDelegate {
  /// Prevents instances of this utility class.
  const MorphChildFlightDelegate._();

  /// Returns the visual values used to transition [widget].
  static MorphChildProperties properties({
    required BuildContext context,
    required Widget widget,
    required Rect rect,
    required Offset axisScale,
    required double switchThreshold,
    RenderBox? renderObject,
  }) {
    return _properties(
      context: context,
      widget: widget,
      rect: rect,
      axisScale: axisScale,
      switchThreshold: switchThreshold,
      capturedEnvironment: _MorphCapturedEnvironment(context),
      renderObject: renderObject,
    );
  }

  static MorphChildProperties _properties({
    required BuildContext context,
    required Widget widget,
    required Rect rect,
    required Offset axisScale,
    required double switchThreshold,
    required _MorphCapturedEnvironment capturedEnvironment,
    RenderBox? renderObject,
    bool specializeDecoratedBox = false,
    bool captureTextConstraintWidth = true,
  }) {
    if (widget is ParentDataWidget<FlexParentData>) {
      throw ArgumentError.value(
        widget,
        'widget',
        'Built-in Column Morph does not support Flex ParentData children such as Expanded or Flexible.',
      );
    }
    var content = widget;
    var padding = EdgeInsets.zero;
    Alignment? alignment;
    double? explicitWidth;
    double? explicitHeight;

    while (true) {
      if (content is Padding) {
        padding += content.padding.resolve(Directionality.of(context));
        content = content.child!;
        continue;
      }
      if (content is Align) {
        alignment = content.alignment.resolve(Directionality.of(context));
        final child = content.child;
        if (child == null) break;
        content = child;
        continue;
      }
      if (content is SizedBox && content.child != null) {
        explicitWidth ??= content.width;
        explicitHeight ??= content.height;
        content = content.child!;
        continue;
      }
      if (content is Motion) {
        content = content.child;
        continue;
      }
      break;
    }

    if (content is Morph) {
      throw ArgumentError.value(
        content,
        'widget',
        'Nested Morph endpoints are not supported inside compound Morph delegates.',
      );
    }

    final scaleX = axisScale.dx;
    final scaleY = axisScale.dy;
    final scaledPadding = EdgeInsets.fromLTRB(
      padding.left * scaleX,
      padding.top * scaleY,
      padding.right * scaleX,
      padding.bottom * scaleY,
    );
    final textSize = Size(
      math.max(0, rect.width - scaledPadding.horizontal),
      math.max(0, rect.height - scaledPadding.vertical),
    );
    final textLayoutWidth = content is Text && captureTextConstraintWidth ? _textLayoutWidth(renderObject) : null;
    final scaledTextLayoutWidth = textLayoutWidth == null ? textSize.width : textLayoutWidth * scaleX;
    final text = content is Text
        ? MorphTextFlightDelegate.captureText(
            context: context,
            text: content,
            size: Size(scaledTextLayoutWidth, textSize.height),
            axisScale: axisScale,
            switchThreshold: switchThreshold,
          )
        : null;
    final container = switch (content) {
      Container() => MorphContainerFlightDelegate._captureContainer(
        context: context,
        container: content,
        size: textSize,
        axisScale: axisScale,
        switchThreshold: switchThreshold,
        capturedEnvironment: capturedEnvironment,
        renderObject: renderObject,
      ),
      DecoratedBox() when specializeDecoratedBox => MorphContainerFlightDelegate._captureDecoratedBox(
        context: context,
        decoratedBox: content,
        size: textSize,
        axisScale: axisScale,
        switchThreshold: switchThreshold,
        capturedEnvironment: capturedEnvironment,
        renderObject: renderObject,
      ),
      _ => null,
    };
    final columnRenderObject = content is Column ? _findRenderBox<RenderFlex>(renderObject) : null;
    final column = content is Column && columnRenderObject != null
        ? MorphColumnFlightDelegate._captureColumn(
            context: context,
            column: content,
            renderObject: columnRenderObject,
            axisScale: axisScale,
            switchThreshold: switchThreshold,
            capturedEnvironment: capturedEnvironment,
          )
        : null;

    return MorphChildProperties(
      widget: content,
      rect: text == null
          ? rect
          : Rect.fromLTWH(
              rect.left,
              rect.top,
              scaledTextLayoutWidth + scaledPadding.horizontal,
              rect.height,
            ),
      padding: scaledPadding,
      alignment: alignment,
      explicitSize: explicitWidth == null && explicitHeight == null
          ? null
          : Size(
              (explicitWidth ?? textSize.width) * scaleX,
              (explicitHeight ?? textSize.height) * scaleY,
            ),
      text: text,
      container: container,
      column: column,
      key: widget.key ?? content.key,
      capturedThemes: text == null && container == null && column == null ? capturedEnvironment.capturedThemes : null,
      mediaQueryData: text == null && container == null && column == null ? capturedEnvironment.mediaQueryData : null,
    );
  }

  /// Returns the visual values between [source] and [destination].
  static MorphChildProperties lerp({
    required MorphChildProperties source,
    required MorphChildProperties destination,
    required double progress,
    required double switchThreshold,
    required bool transitionEnabled,
  }) {
    final showSource = progress < switchThreshold;
    final selected = showSource ? source : destination;
    final sourceText = source.text;
    final destinationText = destination.text;
    final sourceContainer = source.container;
    final destinationContainer = destination.container;
    final sourceColumn = source.column;
    final destinationColumn = destination.column;
    final text = sourceText != null && destinationText != null
        ? const MorphTextFlightDelegate().lerp(
            sourceText,
            destinationText,
            progress,
          )
        : null;
    final container = sourceContainer != null && destinationContainer != null
        ? const MorphContainerFlightDelegate().lerp(sourceContainer, destinationContainer, progress)
        : null;
    final column = sourceColumn != null && destinationColumn != null
        ? const MorphColumnFlightDelegate().lerp(sourceColumn, destinationColumn, progress)
        : null;

    return MorphChildProperties(
      widget: selected.widget,
      rect: Rect.lerp(source.rect, destination.rect, progress)!,
      padding: EdgeInsets.lerp(source.padding, destination.padding, progress)!,
      alignment: Alignment.lerp(
        source.alignment,
        destination.alignment,
        progress,
      ),
      explicitSize: Size.lerp(
        source.explicitSize,
        destination.explicitSize,
        progress,
      ),
      text: text,
      container: container,
      column: column,
      key: selected.key,
      capturedThemes: selected._capturedThemes,
      mediaQueryData: selected._mediaQueryData,
      transitionProgress: transitionEnabled
          ? _transitionProgress(
              progress: progress,
              threshold: switchThreshold,
              departing: showSource,
            )
          : 1,
    );
  }

  static MorphChildProperties _departing({
    required MorphChildProperties properties,
    required double progress,
    required double threshold,
    required bool transitionEnabled,
  }) {
    if (!transitionEnabled) return properties;
    return properties._withTransitionProgress(
      _transitionProgress(
        progress: progress,
        threshold: threshold,
        departing: true,
      ),
    );
  }

  static MorphChildProperties _arriving({
    required MorphChildProperties properties,
    required double progress,
    required double threshold,
    required bool transitionEnabled,
  }) {
    if (!transitionEnabled) return properties;
    return properties._withTransitionProgress(
      _transitionProgress(
        progress: progress,
        threshold: threshold,
        departing: false,
      ),
    );
  }

  static double _transitionProgress({
    required double progress,
    required double threshold,
    required bool departing,
  }) {
    if (departing) {
      if (progress <= 0) return 1;
      if (threshold <= 0 || progress >= threshold) return 0;
      return 1 - progress / threshold;
    }
    if (progress >= 1) return 1;
    if (threshold >= 1 || progress <= threshold) return 0;
    return (progress - threshold) / (1 - threshold);
  }

  static MorphChildProperties _rawProperties({
    required Widget widget,
    required Rect rect,
    required _MorphCapturedEnvironment capturedEnvironment,
  }) {
    return MorphChildProperties(
      widget: widget,
      rect: rect,
      padding: EdgeInsets.zero,
      alignment: null,
      explicitSize: null,
      text: null,
      container: null,
      column: null,
      key: widget.key,
      capturedThemes: capturedEnvironment.capturedThemes,
      mediaQueryData: capturedEnvironment.mediaQueryData,
    );
  }

  static bool _containsNestedMorphOrFlexParentData(Widget widget) {
    if (widget is Morph || widget is ParentDataWidget<FlexParentData>) {
      return true;
    }
    return switch (widget) {
      Padding(:final child?) => _containsNestedMorphOrFlexParentData(child),
      Align(:final child?) => _containsNestedMorphOrFlexParentData(child),
      SizedBox(:final child?) => _containsNestedMorphOrFlexParentData(child),
      Container(:final child?) => _containsNestedMorphOrFlexParentData(child),
      DecoratedBox(:final child?) => _containsNestedMorphOrFlexParentData(child),
      Column(:final children) => children.any(_containsNestedMorphOrFlexParentData),
      _ => false,
    };
  }

  /// Builds a child with the supplied transition [properties].
  static Widget build(
    BuildContext context,
    MorphChildProperties properties, {
    AnimatedSwitcherTransitionBuilder? nonMorphDescendantsTransition,
  }) {
    Widget child;
    final text = properties.text;
    final container = properties.container;
    final column = properties.column;
    final isRaw = text == null && container == null && column == null;
    if (text != null) {
      child = const MorphTextFlightDelegate()._buildProperties(context, text);
    } else if (container != null) {
      child = const MorphContainerFlightDelegate()._buildProperties(
        context,
        container,
        nonMorphDescendantsTransition: nonMorphDescendantsTransition,
      );
    } else if (column != null) {
      child = const MorphColumnFlightDelegate()._buildProperties(
        context,
        column,
        nonMorphDescendantsTransition: nonMorphDescendantsTransition,
      );
    } else {
      child = _MorphNonMorphDescendantsTransition(
        progress: properties._transitionProgress,
        transitionBuilder: nonMorphDescendantsTransition,
        capturedThemes: properties._capturedThemes,
        mediaQueryData: properties._mediaQueryData,
        child: properties.widget,
      );
    }

    final alignment = properties.alignment;
    final explicitSize = properties.explicitSize;
    if (explicitSize != null) {
      child = SizedBox.fromSize(size: explicitSize, child: child);
    }
    if (alignment != null) child = Align(alignment: alignment, child: child);
    if (properties.padding != EdgeInsets.zero) {
      child = Padding(padding: properties.padding, child: child);
    }
    if (!isRaw) {
      child = properties._capturedThemes?.wrap(child) ?? child;
      final mediaQueryData = properties._mediaQueryData;
      if (mediaQueryData != null) {
        child = MediaQuery(data: mediaQueryData, child: child);
      }
    }
    return child;
  }

  static T? _findRenderBox<T extends RenderBox>(RenderObject? root) {
    if (root is T) return root;

    T? result;
    root?.visitChildren((child) {
      result ??= _findRenderBox<T>(child);
    });
    return result;
  }

  static double? _textLayoutWidth(RenderObject? root) {
    final paragraph = _findRenderBox<RenderParagraph>(root);
    if (paragraph == null || !paragraph.constraints.hasBoundedWidth) {
      return null;
    }
    return paragraph.constraints.maxWidth;
  }
}
