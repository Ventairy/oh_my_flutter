part of 'morph.dart';

final class _MorphHybridColumnFlightPlan extends ChangeNotifier {
  _MorphHybridColumnFlightPlan._({
    required this.children,
    required this.rawSlots,
  }) : rawSlotCount = rawSlots.length,
       requiresFrameLayout = rawSlots.any(
         (child) => child.rawSizeChangesContinuously,
       ) {
    for (final child in children) {
      child.retained?.addListener(notifyListeners);
    }
  }

  final List<_MorphHybridColumnChildPlan> children;
  final List<_MorphHybridColumnChildPlan> rawSlots;
  final int rawSlotCount;
  final bool requiresFrameLayout;

  bool rawSelectionChangesBetween(double previous, double next) {
    if (previous == next) return false;
    for (final child in rawSlots) {
      if (!identical(
        child.rawPropertiesAt(previous),
        child.rawPropertiesAt(next),
      )) {
        return true;
      }
    }
    return false;
  }

  _MorphTextRasterPool? _rasterPool;
  int? _viewId;

  static _MorphHybridColumnFlightPlan? tryCreate({
    required MorphColumnProperties source,
    required MorphColumnProperties destination,
    required TextDirection textDirection,
  }) {
    final matching = _MorphColumnChildMatching(
      source: source.children,
      destination: destination.children,
    );
    final children = <_MorphHybridColumnChildPlan>[];
    var rawSlotCount = 0;

    for (var sourceIndex = 0; sourceIndex < source.children.length; sourceIndex += 1) {
      final destinationIndex = matching.destinationIndexForSource(sourceIndex);
      final child = _createChild(
        source: source.children[sourceIndex],
        destination: destinationIndex == null ? null : destination.children[destinationIndex],
        textDirection: textDirection,
        switchThreshold: source.switchThreshold,
        rawSlotIndex: rawSlotCount,
      );
      if (child == null) {
        _disposeChildren(children);
        return null;
      }
      children.add(child);
      if (child.isRaw) rawSlotCount += 1;
    }

    for (var destinationIndex = 0; destinationIndex < destination.children.length; destinationIndex += 1) {
      if (matching.isDestinationMatched(destinationIndex)) continue;
      final child = _createChild(
        source: null,
        destination: destination.children[destinationIndex],
        textDirection: textDirection,
        switchThreshold: source.switchThreshold,
        rawSlotIndex: rawSlotCount,
      );
      if (child == null) {
        _disposeChildren(children);
        return null;
      }
      children.add(child);
      if (child.isRaw) rawSlotCount += 1;
    }

    if (rawSlotCount == 0) {
      _disposeChildren(children);
      return null;
    }
    return _MorphHybridColumnFlightPlan._(
      children: List<_MorphHybridColumnChildPlan>.unmodifiable(children),
      rawSlots: List<_MorphHybridColumnChildPlan>.unmodifiable(
        children.where((child) => child.isRaw),
      ),
    );
  }

  _MorphTextRasterPool? get rasterPool => _rasterPool;

  int? get viewId => _viewId;

  set rasterPool(_MorphTextRasterPool? value) {
    if (identical(value, _rasterPool)) return;
    _rasterPool = value;
    for (final child in children) {
      child.retained?.rasterPool = value;
    }
  }

  set viewId(int value) {
    if (value == _viewId) return;
    _viewId = value;
    for (final child in children) {
      child.retained?.viewId = value;
    }
  }

  List<Map<String, Object?>> get debugTextLayouts {
    final result = <Map<String, Object?>>[];
    for (final child in children) {
      final retained = child.retained;
      if (retained != null) result.addAll(retained.debugTextLayouts);
    }
    return result;
  }

  _MorphHybridColumnChildPlan rawSlot(int index) {
    return rawSlots[index];
  }

  void layoutRawChildren(
    List<RenderBox> rawChildren,
    Rect bounds,
    double progress,
  ) {
    assert(
      rawChildren.length == rawSlotCount,
      'Every hybrid raw plan must have one stable render child.',
    );
    for (final childPlan in children) {
      final rawSlotIndex = childPlan.rawSlotIndex;
      if (rawSlotIndex == null) continue;
      final rawChild = rawChildren[rawSlotIndex];
      final childSize = childPlan.isVisible(progress) ? childPlan.rectAt(progress).size : Size.zero;
      rawChild.layout(BoxConstraints.tight(childSize));
      (rawChild.parentData! as ContainerBoxParentData<RenderBox>).offset = Offset.zero;
    }

    Rect? previousLayoutRect;
    var previousPaintBottom = 0.0;
    for (final childPlan in children) {
      if (!childPlan.isVisible(progress)) continue;
      final layoutRect = childPlan.rectAt(progress);
      final previousRect = previousLayoutRect;
      final gap = previousRect == null ? 0.0 : layoutRect.top - previousRect.bottom;
      final top = previousRect == null ? layoutRect.top : math.max(layoutRect.top, previousPaintBottom + gap);
      final childRect = Rect.fromLTWH(
        bounds.left + layoutRect.left,
        bounds.top + top,
        layoutRect.width,
        layoutRect.height,
      );
      final rawSlotIndex = childPlan.rawSlotIndex;
      if (rawSlotIndex != null) {
        final rawChild = rawChildren[rawSlotIndex];
        (rawChild.parentData! as ContainerBoxParentData<RenderBox>).offset = childRect.topLeft;
      }
      previousLayoutRect = layoutRect;
      previousPaintBottom = top + childPlan.estimatedPaintHeight(childRect, progress);
    }
  }

  void paint(
    PaintingContext context,
    Offset offset,
    Rect bounds,
    double progress,
    List<RenderBox> rawChildren, {
    required double devicePixelRatio,
  }) {
    for (final child in children) {
      final retained = child.retained;
      if (retained == null) continue;
      retained._updateDevicePixelRatio(devicePixelRatio);
      assert(() {
        retained._clearDebugTextLayouts();
        return true;
      }(), 'Hybrid retained-text diagnostics should reset before painting.');
    }

    Rect? previousLayoutRect;
    var previousPaintBottom = 0.0;
    for (final childPlan in children) {
      if (!childPlan.isVisible(progress)) continue;
      final layoutRect = childPlan.rectAt(progress);
      final previousRect = previousLayoutRect;
      final gap = previousRect == null ? 0.0 : layoutRect.top - previousRect.bottom;
      final top = previousRect == null ? layoutRect.top : math.max(layoutRect.top, previousPaintBottom + gap);
      final childRect = Rect.fromLTWH(
        bounds.left + layoutRect.left,
        bounds.top + top,
        layoutRect.width,
        layoutRect.height,
      );
      final rawSlotIndex = childPlan.rawSlotIndex;
      final double paintedHeight;
      if (rawSlotIndex == null) {
        paintedHeight = childPlan.retainedPaintHeight(
          context.canvas,
          childRect.shift(offset),
          progress,
        );
      } else {
        final rawChild = rawChildren[rawSlotIndex];
        (rawChild.parentData! as ContainerBoxParentData<RenderBox>).offset = childRect.topLeft;
        context.paintChild(rawChild, offset + childRect.topLeft);
        paintedHeight = childRect.height;
      }
      previousLayoutRect = layoutRect;
      previousPaintBottom = top + paintedHeight;
    }
  }

  Rect paintBounds(Rect bounds, double progress) {
    var result = bounds;
    Rect? previousLayoutRect;
    var previousPaintBottom = 0.0;
    for (final childPlan in children) {
      if (!childPlan.isVisible(progress)) continue;
      final layoutRect = childPlan.rectAt(progress);
      final previousRect = previousLayoutRect;
      final gap = previousRect == null ? 0.0 : layoutRect.top - previousRect.bottom;
      final top = previousRect == null ? layoutRect.top : math.max(layoutRect.top, previousPaintBottom + gap);
      final childRect = Rect.fromLTWH(
        bounds.left + layoutRect.left,
        bounds.top + top,
        layoutRect.width,
        layoutRect.height,
      );
      if (childPlan.isRaw) {
        result = result.expandToInclude(childRect);
      } else {
        result = result.expandToInclude(
          childPlan.retainedPaintBounds(childRect, progress),
        );
      }
      previousLayoutRect = layoutRect;
      previousPaintBottom = top + childPlan.estimatedPaintHeight(childRect, progress);
    }
    return result;
  }

  @override
  void dispose() {
    for (final child in children) {
      final retained = child.retained;
      if (retained == null) continue;
      retained
        ..removeListener(notifyListeners)
        ..dispose();
    }
    super.dispose();
  }

  static _MorphHybridColumnChildPlan? _createChild({
    required MorphChildProperties? source,
    required MorphChildProperties? destination,
    required TextDirection textDirection,
    required double switchThreshold,
    required int rawSlotIndex,
  }) {
    final retained = _MorphCompoundFlightPlan._forChild(
      source: source,
      destination: destination,
      textDirection: textDirection,
      switchThreshold: switchThreshold,
      departureThresholdIsInclusive: true,
    );
    if (retained != null) {
      return _MorphHybridColumnChildPlan(
        source: source,
        destination: destination,
        retained: retained,
        rawSlotIndex: null,
        switchThreshold: switchThreshold,
      );
    }
    if (!_hasCompatibleRawWrappers(source, destination)) return null;
    if (!_supportsRawIsland(source) || !_supportsRawIsland(destination)) {
      return null;
    }
    return _MorphHybridColumnChildPlan(
      source: source,
      destination: destination,
      retained: null,
      rawSlotIndex: rawSlotIndex,
      switchThreshold: switchThreshold,
    );
  }

  static bool _hasCompatibleRawWrappers(
    MorphChildProperties? source,
    MorphChildProperties? destination,
  ) {
    if (source == null || destination == null) return true;
    return source.padding == destination.padding && source.explicitSize == destination.explicitSize;
  }

  static bool _supportsRawIsland(MorphChildProperties? child) {
    if (child == null) return true;
    if (child.text != null || child.container != null || child.column != null) {
      return false;
    }
    if (child.alignment != null || child.widget.key is GlobalKey) return false;
    return _supportsRawWidget(child.widget);
  }

  static bool _supportsRawWidget(Widget widget) {
    return switch (widget) {
      DecoratedBox(:final decoration, :final child) =>
        _supportsRawDecoration(decoration) && (child == null || _supportsRawWidget(child)),
      Container(
        :final decoration,
        :final foregroundDecoration,
        :final transform,
        :final child,
      ) =>
        transform == null &&
            _supportsRawDecoration(decoration) &&
            _supportsRawDecoration(foregroundDecoration) &&
            (child == null || _supportsRawWidget(child)),
      Padding(:final child?) => _supportsRawWidget(child),
      Align(:final child?) => _supportsRawWidget(child),
      SizedBox(:final child?) => _supportsRawWidget(child),
      Row(:final children) || Column(:final children) => children.every(_supportsRawWidget),
      _ => true,
    };
  }

  static bool _supportsRawDecoration(Decoration? decoration) {
    if (decoration == null) return true;
    if (decoration is! BoxDecoration) return false;
    return decoration.image == null && decoration.border == null;
  }

  static void _disposeChildren(
    List<_MorphHybridColumnChildPlan> children,
  ) {
    for (final child in children) {
      child.retained?.dispose();
    }
  }
}
