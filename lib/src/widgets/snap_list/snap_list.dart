import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'snap_list_alignment.dart';

part '_render_snap_list_eager_content.dart';
part '_render_snap_list_trailing.dart';
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
part '_snap_list_transition_animation.dart';
part '_snap_list_transitions.dart';
part '_snap_list_viewport_offset.dart';
part 'snap_list_controller.dart';
part 'snap_list_types.dart';

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
    this.onIndexChanged,
    this.incomingTransitionBuilder,
    this.outgoingTransitionBuilder,
    super.key,
  }) : reverseDuration = reverseDuration ?? duration,
       reverseCurve = reverseCurve ?? curve,
       itemBuilder = null,
       itemCount = null,
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
    this.onIndexChanged,
    this.incomingTransitionBuilder,
    this.outgoingTransitionBuilder,
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

  /// Optional controller for observing position and moving between items.
  final SnapListController? controller;

  /// Builds content revealed after the last item, outside the item indexes.
  ///
  /// The child receives loose main-axis constraints bounded by the viewport.
  /// Its measured size determines the reveal distance. Use SizedBox.expand
  /// to fill the viewport, or a naturally sized child for a smaller reveal.
  ///
  /// Appending items while this slot is committed or settled advances to the
  /// first appended item. Returning to an item cancels that automatic advance.
  /// Fetching, errors, and retry actions belong to the caller.
  final WidgetBuilder? trailingBuilder;

  /// Called when a different real item finishes settling, not on first mount.
  final ValueChanged<int>? onIndexChanged;

  /// Animates each arriving item with an effect that follows scrolling.
  ///
  /// Progress moves from zero to one as the item arrives, and rewinds when
  /// the swipe is cancelled. The settled item receives one. Both navigation
  /// directions use this builder; `isReverse` identifies previous-item travel.
  /// Omit it for normal appearance. See [SnapListTransitionBuilder] for usage.
  final SnapListTransitionBuilder? incomingTransitionBuilder;

  /// Animates each departing item independently of its incoming effect.
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

  int get _count => widget.children?.length ?? widget.itemCount!;

  @override
  void initState() {
    super.initState();
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
    final oldIndex = _motion.index;
    final oldKey = oldWidget.children != null && oldIndex != null && oldIndex < oldWidget.children!.length
        ? oldWidget.children![oldIndex].key
        : null;
    int? retained;
    if (oldKey != null) {
      retained = widget.children?.indexWhere((child) => child.key == oldKey);
      if (retained != null && retained < 0) retained = null;
    }
    final geometryChanged =
        oldWidget.axis != widget.axis ||
        oldWidget.spacing != widget.spacing ||
        oldWidget.padding != widget.padding ||
        oldWidget.alignment != widget.alignment;
    final identityChanged = oldKey != null && widget.children != null && retained != oldIndex;
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
      retainIndex: retained,
    );
    if (reset) {
      _nested.clear();
      _motion.reset();
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

  Future<bool> _navigate(int direction) => _motion.navigate(direction);

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
    final index = _motion.index;
    if (index != _reportedIndex) {
      _reportedIndex = index;
      if (index != null) widget.onIndexChanged?.call(index);
    }
    final pixels = _motion.displayPixels;
    _updateTransitions();
    final first = ((pixels - _leading - _itemExtent) / _motion.stride).floor() + 1;
    final last = ((pixels + _extent - _leading) / _motion.stride).ceil() - 1;
    _visible.value = (math.max(0, first), math.min(_count - 1, last));
    _controller?._changed();
  }

  void _updateTransitions() {
    if (widget.incomingTransitionBuilder == null && widget.outgoingTransitionBuilder == null) return;
    _transitions.update(
      _motion.displayPixels / _motion.stride,
      _count,
      reducedMotion: _motion.reducedMotion,
    );
  }

  Widget _item(BuildContext context, int index) {
    final child = widget.children?[index] ?? widget.itemBuilder!(context, index);
    return KeyedSubtree(
      key: ValueKey(child.key ?? index),
      child: ValueListenableBuilder<(int, int)>(
        valueListenable: _visible,
        child: widget.incomingTransitionBuilder == null && widget.outgoingTransitionBuilder == null
            ? child
            : _SnapListItemTransition(
                transitions: _transitions,
                index: index,
                incomingBuilder: widget.incomingTransitionBuilder,
                outgoingBuilder: widget.outgoingTransitionBuilder,
                child: child,
              ),
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
                (index) =>
                    RepaintBoundary(key: ValueKey(widget.children![index].key ?? index), child: _item(context, index)),
              ),
            ),
          )
        else
          SliverFixedExtentList(
            itemExtent: _motion.stride,
            delegate: SliverChildBuilderDelegate(
              _item,
              childCount: _count,
            ),
          ),
        SliverToBoxAdapter(
          child: _spacer(
            _count == 0 ? 0 : math.max(0, _extent - _leading - _itemExtent),
          ),
        ),
        if (widget.trailingBuilder != null)
          SliverToBoxAdapter(
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
                child: Builder(builder: widget.trailingBuilder!),
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
    _motion.reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final direction = getAxisDirectionFromAxisReverseAndDirectionality(context, widget.axis, false);
    if (_direction != null && _direction != direction) _motion.reset();
    _direction = direction;
    _nested.direction = direction;
    return Padding(
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
