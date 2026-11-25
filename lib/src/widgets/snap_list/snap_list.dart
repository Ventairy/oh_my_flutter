import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../transition_preparation/linear_transition_progress.dart';
import '../transition_preparation/prepared_transition.dart';
import 'snap_list_alignment.dart';

part '_render_snap_list_eager_content.dart';
part '_render_snap_list_trailing.dart';
part '_render_snap_list_trailing_sliver.dart';
part '_snap_list_removal.dart';
part '_snap_list_drag.dart';
part '_snap_list_eager_content.dart';
part '_snap_list_item_transition.dart';
part '_snap_list_motion.dart';
part '_snap_list_nested_scroll.dart';
part '_snap_list_parent_data.dart';
part '_snap_list_physics.dart';
part '_snap_list_position.dart';
part '_snap_list_scroll_controller.dart';
part '_snap_list_trailing.dart';
part '_snap_list_trailing_sliver.dart';
part '_snap_list_transition_animation.dart';
part '_snap_list_transitions.dart';
part '_snap_list_viewport_offset.dart';
part 'snap_list_transition_details.dart';
part 'snap_list_controller.dart';
part 'snap_list_types.dart';
part 'snap_list_transient_item.dart';
part '_snap_list_every_transient_item.dart';

/// Presents content that snaps to one item at a time on either axis.
///
/// Use [SnapList] for a small collection whose child state stays mounted,
/// or [SnapList.builder] for lazily created feeds. Nested scrollables hand an
/// outward edge drag to the list automatically. Supply bounded dimensions.
///
/// See the [SnapList guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/snap_list.md).
class SnapList extends StatefulWidget {
  /// Creates a list that keeps every supplied child's state mounted.
  const new({
    required List<Widget> this.children,
    this.axis = Axis.vertical,
    this.spacing = 0,
    this.padding = EdgeInsets.zero,
    this.alignment = SnapListAlignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.commitThreshold = 0.25,
    this.duration = const Duration(milliseconds: 140),
    Duration? reverseDuration,
    this.curve = Curves.linear,
    Curve? reverseCurve,
    this.controller,
    this.trailingBuilder,
    this.transientItem,
    this.onIndexChanged,
    this.incomingTransitionBuilder,
    this.outgoingTransitionBuilder,
    this.removalTransitionBuilder,
    this.removalDuration = const Duration(milliseconds: 300),
    super.key,
  }) : reverseDuration = reverseDuration ?? duration,
       reverseCurve = reverseCurve ?? curve,
       itemBuilder = null,
       itemCount = null,
       itemKeyBuilder = null,
       cacheItemCount = 1,
       assert(spacing >= 0 && spacing < double.infinity, 'spacing must be finite and nonnegative.'),
       assert(commitThreshold > 0 && commitThreshold <= 1, 'commitThreshold must be in (0, 1].');

  /// Creates items lazily as they approach the visible area.
  ///
  /// Children may request Flutter's automatic keep-alive. Existing items
  /// retain their positions when new items are appended.
  const new builder({
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    required LocalKey Function(int) this.itemKeyBuilder,
    this.cacheItemCount = 1,
    this.axis = Axis.vertical,
    this.spacing = 0,
    this.padding = EdgeInsets.zero,
    this.alignment = SnapListAlignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.commitThreshold = 0.25,
    this.duration = const Duration(milliseconds: 260),
    Duration? reverseDuration,
    this.curve = Curves.linear,
    Curve? reverseCurve,
    this.controller,
    this.trailingBuilder,
    this.transientItem,
    this.onIndexChanged,
    this.incomingTransitionBuilder,
    this.outgoingTransitionBuilder,
    this.removalTransitionBuilder,
    this.removalDuration = const Duration(milliseconds: 300),
    super.key,
  }) : reverseDuration = reverseDuration ?? duration,
       reverseCurve = reverseCurve ?? curve,
       children = null,
       assert(itemCount >= 0, 'itemCount must be nonnegative.'),
       assert(cacheItemCount >= 0, 'cacheItemCount must be nonnegative.'),
       assert(spacing >= 0 && spacing < double.infinity, 'spacing must be finite and nonnegative.'),
       assert(commitThreshold > 0 && commitThreshold <= 1, 'commitThreshold must be in (0, 1].');

  /// Eager children, or null when using the builder constructor.
  final List<Widget>? children;

  /// Builds a lazy item by index, or null for eager children.
  final IndexedWidgetBuilder? itemBuilder;

  /// Number of lazy items; eager lists use the length of [children].
  final int? itemCount;

  /// Identifies a lazy item across insertions, removals, and changes of order.
  ///
  /// Return a unique stable key for each item, such as a value key of its ID.
  final LocalKey Function(int index)? itemKeyBuilder;

  /// Wraps a removed visible item while its successor is displayed beneath it.
  ///
  /// Progress advances from zero to one. Eager items need stable widget keys.
  final Widget Function(BuildContext, Animation<double>, Widget)? removalTransitionBuilder;

  /// Time a visible item takes to exit after its transition is ready.
  final Duration removalDuration;

  /// Axis along which items move.
  final Axis axis;

  /// Gap between items, in logical pixels.
  final double spacing;

  /// Space outside the list's viewport. No safe area is added automatically.
  final EdgeInsetsGeometry padding;

  /// Where the selected item rests within the viewport.
  final SnapListAlignment alignment;

  /// Clipping applied at the viewport boundary.
  final Clip clipBehavior;

  /// Fraction of the distance between item anchors required to commit a drag.
  ///
  /// At the last item, this fraction applies to the trailing content's size.
  final double commitThreshold;

  /// Duration of forward movement, including next-item navigation.
  ///
  /// Must be nonnegative. Trailing reveals and automatic advances also use it.
  final Duration duration;

  /// Duration of previous-item navigation and cancelled drag returns.
  ///
  /// Defaults to [duration]. Must be nonnegative.
  final Duration reverseDuration;

  /// Curve of forward movement, including next-item navigation.
  final Curve curve;

  /// Curve of previous-item navigation and cancelled drag returns.
  ///
  /// Defaults to [curve].
  final Curve reverseCurve;

  /// Optional controller for observing position and moving to items.
  final SnapListController? controller;

  /// Offers optional swipeable pages that share their preceding item’s index and position.
  final SnapListTransientItem? transientItem;

  /// Builds content revealed after the last item, outside the item indexes.
  ///
  /// The child receives loose main-axis constraints bounded by the viewport.
  /// Its measured size determines the reveal distance. Use SizedBox.expand
  /// to fill the viewport, or a naturally sized child for a smaller reveal.
  /// It uses the same incoming and outgoing transition builders as the items.
  ///
  /// Appending items while this slot is committed or settled advances to the
  /// first appended item. Returning to an item cancels that automatic advance.
  /// Fetching, errors, and retry actions belong to the caller.
  final WidgetBuilder? trailingBuilder;

  /// Called when a different real item finishes settling, not on first mount.
  final ValueChanged<int>? onIndexChanged;

  /// Animates arriving items and trailing content with an effect that follows scrolling.
  ///
  /// Progress moves from zero to one as the item arrives, and rewinds when
  /// the swipe is cancelled. The settled item receives one. Both navigation
  /// directions use this builder; `details.isReverse` identifies previous-item travel.
  /// Omit it for normal appearance. See [SnapListTransitionBuilder] for usage.
  final SnapListTransitionBuilder? incomingTransitionBuilder;

  /// Animates departing items and trailing content independently of their incoming effect.
  ///
  /// Progress moves from zero to one as the item leaves, and rewinds when
  /// the swipe is cancelled. The settled item receives zero. For a fade-out,
  /// drive a tween from one to zero. See [SnapListTransitionBuilder] for usage.
  final SnapListTransitionBuilder? outgoingTransitionBuilder;

  /// Extra items to prepare on each side of the visible lazy range.
  final int cacheItemCount;

  @override
  State<SnapList> createState() => _SnapListState();
}

class _SnapListState extends State<SnapList> {
  late final _motion = _SnapListMotion(
    commitThreshold: widget.commitThreshold,
    duration: widget.duration,
    reverseDuration: widget.reverseDuration,
    curve: widget.curve,
    reverseCurve: widget.reverseCurve,
    reducedMotion: false,
  )..addListener(_changed);
  late final _scrollController = _SnapListScrollController(_motion);
  late final _nested = _SnapListNestedScroll(_motion);
  final _transitions = _SnapListTransitions();
  final _focusNode = FocusNode(debugLabel: 'SnapList');
  final _visible = ValueNotifier<(int, int)>((0, 0));
  _SnapListViewportOffset? _viewportOffset;
  SnapListController? _controller;
  AxisDirection? _direction;
  int? _reportedIndex;
  bool _scheduled = false;
  double _extent = 0;
  double _itemExtent = 0;
  double _leading = 0;

  late List<Key?> _itemKeys;
  late Map<Key, int> _itemIndices;
  final _surfaceKeys = <Key, GlobalKey>{};
  List<Positioned> _outgoing = const [];

  void _readItemKeys() {
    _itemKeys = List.generate(_mainCount, (index) => widget.itemKeyBuilder?.call(index) ?? widget.children![index].key);
    _itemIndices = {
      for (var i = 0; i < _itemKeys.length; i++) ?_itemKeys[i]: i,
    };
    assert(_itemIndices.length == _itemKeys.whereType<Key>().length, 'SnapList item keys must be unique.');
  }

  void _retainRemovedSurfaces(List<Key?> previousKeys) {
    if (widget.removalTransitionBuilder == null ||
        widget.removalDuration == Duration.zero ||
        _motion.reducedMotion ||
        !_motion._tickerEnabled ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    final viewport = context.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final surfaces = <Positioned>[];
    late final snapshot = _SnapListTransitions.snapshot(_transitions);
    final (first, last) = _visible.value;
    for (var page = first; page <= last; page++) {
      final (index, transient) = _address(page);
      if (transient || index >= previousKeys.length) continue;
      final key = previousKeys[index];
      if (key == null || _itemIndices.containsKey(key)) continue;
      final surface = _surfaceKeys.remove(key);
      final box = surface?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final bounds = box.localToGlobal(Offset.zero, ancestor: viewport) & box.size;
      if (bounds.overlaps(Offset.zero & viewport.size)) {
        final captured = surface!.currentWidget! as IndexedSemantics;
        final child = captured.child!;
        surfaces.add(
          Positioned.fromRect(
            rect: bounds,
            child: IndexedSemantics(
              key: surface,
              index: captured.index,
              child: child is _SnapListItemTransition ? child.freeze(snapshot) : child,
            ),
          ),
        );
      }
    }
    if (surfaces.isNotEmpty) _outgoing = surfaces;
  }

  int get _mainCount => widget.children?.length ?? widget.itemCount!;
  int get _count => _mainCount + _transients.length;

  Map<int, Widget> _transients = const {};
  int? _resolvedAt;
  bool _deferredSlots = false;

  int _pageOf(int mainIndex) {
    var page = mainIndex;
    for (final preceding in _transients.keys) {
      if (preceding >= mainIndex) break;
      page++;
    }
    return page;
  }

  (int, bool) _address(int page) {
    var mainIndex = page;
    for (final preceding in _transients.keys) {
      if (mainIndex <= preceding) break;
      mainIndex--;
      if (mainIndex == preceding) return (mainIndex, true);
    }
    return (mainIndex, false);
  }

  int? get _index => _motion.index == null ? null : _address(_motion.index!).$1;

  double? get _position {
    final position = _motion.itemPosition;
    if (position == null || _transients.isEmpty) return position;
    final page = position.floor();
    final from = _address(page).$1;
    final to = _address(page + 1).$1;
    return from + (position - page) * (to - from);
  }

  void _resolveSlots() {
    final rule = widget.transientItem;
    if (rule == null && _transients.isEmpty) {
      _deferredSlots = false;
      return;
    }
    if (_motion.dragging || _motion.moving) {
      _deferredSlots = true;
      return;
    }
    _deferredSlots = false;
    final (anchor, wasTransient) = _address(_motion.index ?? 0);
    _resolvedAt = anchor;
    final slots = <int, Widget>{};
    if (rule != null) {
      final radius = math.max(1, widget.cacheItemCount + 1);
      final first = widget.children == null ? math.max(0, anchor - radius) : 0;
      final last = widget.children == null ? math.min(_mainCount, anchor + radius + 1) : _mainCount;
      for (var i = first; i < last; i++) {
        if (!rule._matches(i)) continue;
        final child = rule.builder(context, i);
        if (child != null) slots[i] = child;
      }
    }
    final appendPage = _motion._appendTarget;
    final appendedMainIndex = appendPage == null ? null : _address(appendPage).$1;
    final changed = slots.length != _transients.length || !slots.keys.every(_transients.containsKey);
    _transients = slots;
    if (!changed) return;
    final retained = _pageOf(anchor) + (wasTransient ? 1 : 0);
    final useTrailing =
        wasTransient && retained >= _count && widget.trailingBuilder != null && _motion.revealExtent > 0;
    _motion.reconcilePages(
      pageCount: _count,
      anchor: retained,
      revealTrailing: useTrailing,
      appendedPage: appendedMainIndex == null ? null : _pageOf(appendedMainIndex),
    );
  }

  @override
  void initState() {
    super.initState();
    _readItemKeys();
    _controller = widget.controller?.._attach(this);
    _motion.configure(itemCount: _count, itemStride: 1);
    _reportedIndex = _motion.index;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion.updateTickerMode(enabled: TickerMode.valuesOf(context).enabled);
  }

  @override
  void didUpdateWidget(SnapList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _controller?._detach(this);
      _controller = widget.controller?.._attach(this);
    }
    final oldCount = _motion.count;
    final oldIndex = _index;
    final wasTransient = _address(_motion.index ?? 0).$2;
    final wasTrailing = _motion.trailingCommitted;
    final previousKeys = _itemKeys;
    final oldKey = oldIndex == null ? null : previousKeys[oldIndex];
    _readItemKeys();
    _retainRemovedSurfaces(previousKeys);
    _surfaceKeys.removeWhere((key, surface) => !_itemIndices.containsKey(key) || surface.currentContext == null);
    if (_transients.isNotEmpty) {
      final slots = <int, Widget>{};
      for (final entry in _transients.entries) {
        final index = _itemIndices[previousKeys[entry.key]];
        if (index != null && (widget.transientItem?._matches(index) ?? false)) slots[index] = entry.value;
      }
      _transients = slots;
    }
    final retained = _itemIndices[oldKey];
    final removedCurrent = oldKey != null && retained == null;
    final successor = removedCurrent
        ? previousKeys.skip(oldIndex! + 1).map((key) => _itemIndices[key]).nonNulls.firstOrNull
        : retained;
    final settleOnTrailing = removedCurrent && successor == null && widget.trailingBuilder != null;
    final target = removedCurrent && successor == null && !settleOnTrailing
        ? previousKeys.take(oldIndex!).toList().reversed.map((key) => _itemIndices[key]).nonNulls.firstOrNull
        : successor;
    final geometryChanged =
        oldWidget.axis != widget.axis ||
        oldWidget.spacing != widget.spacing ||
        oldWidget.padding != widget.padding ||
        oldWidget.alignment != widget.alignment;
    final identityChanged = oldKey != null && retained != oldIndex;
    final reset = geometryChanged || identityChanged || _count < oldCount;
    _motion
      ..commitThreshold = widget.commitThreshold
      ..duration = widget.duration
      ..reverseDuration = widget.reverseDuration
      ..curve = widget.curve
      ..reverseCurve = widget.reverseCurve;
    _motion.configure(
      itemCount: _count,
      itemStride: _motion.stride,
      retainIndex: target == null
          ? null
          : _pageOf(target) + (!removedCurrent && wasTransient && _transients.containsKey(target) ? 1 : 0),
    );
    if (reset) {
      _nested.clear();
      _motion.reset();
    }
    if (settleOnTrailing || (reset && wasTrailing && widget.trailingBuilder != null)) {
      _motion.reconcilePages(
        pageCount: _count,
        anchor: math.max(0, _count - 1),
        revealTrailing: true,
        appendedPage: null,
      );
    }
    _scheduleChanged();
    if (widget.trailingBuilder == null) _trailingMeasured(0);
  }

  void _trailingMeasured(double extent) {
    _motion.measureTrailing(extent);
    _scheduleChanged();
  }

  void _detachController(SnapListController controller) {
    if (identical(_controller, controller)) _controller = null;
  }

  Future<bool> _navigate(int direction) async {
    if (widget.transientItem != null && _index != _resolvedAt) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
    }
    return await _motion.navigate(direction);
  }

  void _jumpTo(int index) {
    assert(_motion.scroll?.hasContentDimensions ?? false, 'SnapList must be laid out before jumping to an item.');
    assert(index >= 0 && index < _mainCount, 'The jump index must identify an item.');
    _nested.clear();
    _motion.jumpToItem(_pageOf(index));
  }

  void _scheduleChanged() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) {
        _motion.resolveTrailing();
        _changed();
      }
    });
  }

  void _changed() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _scheduleChanged();
      return;
    }
    if (!mounted) return;
    if (!_motion.moving) _surfaceKeys.removeWhere((_, surface) => surface.currentContext == null);
    final index = _index;
    if (widget.transientItem != null || _deferredSlots) {
      if (!_motion.moving && !_motion.dragging && (_deferredSlots || (index ?? 0) != _resolvedAt)) setState(() {});
    }
    if (index != _reportedIndex) {
      _reportedIndex = index;
      if (index != null) widget.onIndexChanged?.call(index);
    }
    final pixels = _motion.displayPixels;
    _updateTransitions();
    final first = ((pixels - _leading - _itemExtent) / _motion.stride).floor() + 1;
    final last = ((pixels + _extent - _leading) / _motion.stride).ceil() - 1;
    final trailerVisible =
        widget.trailingBuilder != null && _motion.revealExtent > 0 && (_count == 0 || pixels > _motion.lastAnchor);
    _visible.value = (math.max(0, first), trailerVisible ? _count : math.min(_count - 1, last));
    _controller?._changed();
  }

  void _updateTransitions() {
    if (widget.incomingTransitionBuilder == null && widget.outgoingTransitionBuilder == null) return;
    final hasTrailing = widget.trailingBuilder != null && _count > 0;
    final pixels = _motion.displayPixels;
    _transitions.update(
      hasTrailing && _motion.revealExtent > 0 && pixels > _motion.lastAnchor
          ? _count - 1 + ((pixels - _motion.lastAnchor) / _motion.revealExtent).clamp(0.0, 1.0)
          : pixels / _motion.stride,
      _count + (hasTrailing ? 1 : 0),
      pixels: pixels,
      trailing: hasTrailing ? (index: _count, anchor: _motion.lastAnchor, extent: _motion.revealExtent) : null,
      reducedMotion: _motion.reducedMotion,
    );
  }

  Widget _transition(int index, Widget child) =>
      widget.incomingTransitionBuilder == null && widget.outgoingTransitionBuilder == null
      ? child
      : _SnapListItemTransition(
          transitions: _transitions,
          index: index,
          isTrailing: index == _count,
          incomingBuilder: widget.incomingTransitionBuilder,
          outgoingBuilder: widget.outgoingTransitionBuilder,
          child: child,
        );

  Widget _item(BuildContext context, int index) {
    final (mainIndex, transient) = _address(index);
    var child = transient
        ? _transients[mainIndex]!
        : widget.children?[mainIndex] ?? widget.itemBuilder!(context, mainIndex);
    child = _transition(index, child);
    final key = _itemKeys[mainIndex];
    if (!transient && widget.removalTransitionBuilder != null && key != null) {
      child = IndexedSemantics(key: _surfaceKeys.putIfAbsent(key, GlobalKey.new), index: index, child: child);
    } else if (widget.removalTransitionBuilder != null && widget.children == null) {
      child = IndexedSemantics(index: index, child: child);
    }

    return KeyedSubtree(
      key: _pageKey(index),
      child: ValueListenableBuilder<(int, int)>(
        valueListenable: _visible,
        child: child,
        builder: (context, range, child) {
          final visible = index >= range.$1 && index <= range.$2;
          return TickerMode(
            enabled: visible,
            child: ExcludeFocus(
              excluding: !visible,
              child: ExcludeSemantics(
                excluding: !visible,
                child: IgnorePointer(
                  ignoring: !visible,
                  child: SizedBox(
                    width: widget.axis == Axis.horizontal ? _motion.stride : null,
                    height: widget.axis == Axis.vertical ? _motion.stride : null,
                    child: Align(
                      alignment: switch (_direction!) {
                        AxisDirection.down => Alignment.topCenter,
                        AxisDirection.up => Alignment.bottomCenter,
                        AxisDirection.right => Alignment.centerLeft,
                        AxisDirection.left => Alignment.centerRight,
                      },
                      child: SizedBox(
                        width: widget.axis == Axis.horizontal ? _itemExtent : double.infinity,
                        height: widget.axis == Axis.vertical ? _itemExtent : double.infinity,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Key _pageKey(int page) {
    final (index, transient) = _address(page);
    return ValueKey((_itemKeys[index] ?? index, transient));
  }

  Widget _spacer(double extent, {Widget? child}) => SizedBox(
    width: widget.axis == Axis.horizontal ? extent : null,
    height: widget.axis == Axis.vertical ? extent : null,
    child: child,
  );

  Widget _viewport(BuildContext context, ViewportOffset offset) {
    if (!identical(_viewportOffset?.position, offset)) {
      _viewportOffset?.dispose();
      _viewportOffset = _SnapListViewportOffset(_motion, offset);
    }
    return Viewport(
      axisDirection: _direction!,
      offset: _viewportOffset!,
      clipBehavior: widget.clipBehavior,
      scrollCacheExtent: ScrollCacheExtent.pixels(widget.cacheItemCount * _motion.stride),
      slivers: [
        SliverToBoxAdapter(child: _spacer(_count == 0 ? 0 : _leading)),
        if (widget.children != null)
          SliverToBoxAdapter(
            child: _SnapListEagerContent(
              motion: _motion,
              direction: _direction!,
              extent: _extent,
              leading: _leading,
              children: List.generate(
                _count,
                (index) => RepaintBoundary(key: _pageKey(index), child: _item(context, index)),
              ),
            ),
          )
        else
          SliverFixedExtentList(
            itemExtent: _motion.stride,
            delegate: SliverChildBuilderDelegate(
              _item,
              addSemanticIndexes: widget.removalTransitionBuilder == null,
              childCount: _count,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<(Object, bool)>) return null;
                final (itemKey, transient) = key.value;
                final index = _itemIndices[itemKey];
                if (index == null || (transient && !_transients.containsKey(index))) return null;
                return _pageOf(index) + (transient ? 1 : 0);
              },
            ),
          ),
        SliverToBoxAdapter(
          child: _spacer(
            _count == 0 ? 0 : math.max(0, _extent - _leading - _itemExtent),
          ),
        ),
        if (widget.trailingBuilder != null)
          _SnapListTrailingSliver(
            viewportOffset: _viewportOffset!,
            paintOutsideViewport: widget.clipBehavior == Clip.none,
            child: _SnapListTrailing(
              axis: widget.axis,
              extent: _extent,
              onExtentChanged: _trailingMeasured,
              child: Transform.translate(
                offset: _count == 0
                    ? Offset.zero
                    : switch (_direction!) {
                        AxisDirection.down => Offset(0, -widget.spacing),
                        AxisDirection.up => Offset(0, widget.spacing),
                        AxisDirection.right => Offset(-widget.spacing, 0),
                        AxisDirection.left => Offset(widget.spacing, 0),
                      },
                child: RepaintBoundary(
                  child: ValueListenableBuilder<(int, int)>(
                    valueListenable: _visible,
                    child: Builder(builder: (context) => _transition(_count, widget.trailingBuilder!(context))),
                    builder: (context, range, child) => TickerMode(enabled: range.$2 == _count, child: child!),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final forward = switch (_direction!) {
      AxisDirection.down => LogicalKeyboardKey.arrowDown,
      AxisDirection.up => LogicalKeyboardKey.arrowUp,
      AxisDirection.right => LogicalKeyboardKey.arrowRight,
      AxisDirection.left => LogicalKeyboardKey.arrowLeft,
    };
    final backward = switch (_direction!) {
      AxisDirection.down => LogicalKeyboardKey.arrowUp,
      AxisDirection.up => LogicalKeyboardKey.arrowDown,
      AxisDirection.right => LogicalKeyboardKey.arrowLeft,
      AxisDirection.left => LogicalKeyboardKey.arrowRight,
    };
    if (key != forward && key != backward && key != LogicalKeyboardKey.pageDown && key != LogicalKeyboardKey.pageUp) {
      return KeyEventResult.ignored;
    }
    unawaited(_navigate(key == forward || key == LogicalKeyboardKey.pageDown ? 1 : -1));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    assert(
      !widget.duration.isNegative && !widget.reverseDuration.isNegative,
      'Durations must be nonnegative.',
    );
    _motion.reducedMotion =
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) || (MediaQuery.maybeReduceMotionOf(context) ?? false);
    _resolveSlots();
    final direction = getAxisDirectionFromAxisReverseAndDirectionality(context, widget.axis, false);
    if (_direction != null && _direction != direction) _motion.reset();
    _direction = direction;
    _nested.direction = direction;
    final content = Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          assert(
            constraints.hasBoundedWidth && constraints.hasBoundedHeight,
            'SnapList requires bounded width and height.',
          );
          final extent = widget.axis == Axis.vertical ? constraints.maxHeight : constraints.maxWidth;
          final itemExtent = extent;
          _leading =
              (extent - itemExtent) *
              switch (widget.alignment) {
                SnapListAlignment.start => 0,
                SnapListAlignment.center => 0.5,
                SnapListAlignment.end => 1,
              };
          if (_extent != extent || _itemExtent != itemExtent || _motion.stride != itemExtent + widget.spacing) {
            _extent = extent;
            _itemExtent = itemExtent;
            _motion.configure(
              itemCount: _count,
              itemStride: math.max(precisionErrorTolerance, itemExtent + widget.spacing),
            );
            _motion.reset();
          }
          _updateTransitions();
          _scheduleChanged();
          return Focus(
            focusNode: _focusNode,
            onKeyEvent: _key,
            child: Listener(
              onPointerDown: (event) {
                _focusNode.requestFocus();
                _nested.down(event);
              },
              onPointerMove: _nested.move,
              onPointerUp: _nested.up,
              onPointerCancel: _nested.up,
              onPointerPanZoomStart: _nested.panStart,
              onPointerPanZoomUpdate: _nested.panUpdate,
              onPointerPanZoomEnd: _nested.up,
              child: NotificationListener<ScrollNotification>(
                onNotification: _nested.notification,
                child: Scrollable(
                  controller: _scrollController,
                  axisDirection: direction,
                  physics: const _SnapListPhysics(),
                  semanticChildCount: _count,
                  incrementCalculator: (_) => _motion.stride,
                  viewportBuilder: _viewport,
                ),
              ),
            ),
          );
        },
      ),
    );
    assert(!widget.removalDuration.isNegative, 'Removal duration must be nonnegative.');
    if (_motion.reducedMotion || widget.removalTransitionBuilder == null) {
      _outgoing = const [];
    }
    return Stack(
      fit: StackFit.expand,
      clipBehavior: widget.clipBehavior,
      children: [
        content,
        if (_outgoing.isNotEmpty)
          _SnapListRemoval(
            key: ObjectKey(_outgoing),
            surfaces: _outgoing,
            duration: widget.removalDuration,
            builder: widget.removalTransitionBuilder!,
            onDone: () => setState(() => _outgoing = const []),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?._detach(this);
    _nested.clear();
    _viewportOffset?.dispose();
    _scrollController.dispose();
    _motion.removeListener(_changed);
    _motion.dispose();
    _visible.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
