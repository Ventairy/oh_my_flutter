import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'marquee_direction.dart';

part '_marquee_parent_data.dart';
part '_marquee_viewport.dart';
part '_render_marquee.dart';

/// Continuously moves an ordered strip of widgets across a clipped viewport.
///
/// During [duration], the source strip advances by one complete strip extent.
/// By default, [infinity] mounts the minimum cyclic child repetitions needed
/// to keep the viewport filled between loops. When infinity is false, the
/// single strip instead travels from fully outside its entry edge to fully
/// outside its exit edge.
///
/// Horizontal marquees fill the available bounded width when [width] is null
/// and use their tallest child when [height] is null. Vertical marquees apply
/// the equivalent behavior to [height] and [width].
///
/// ```dart
/// Marquee(
///   duration: const Duration(seconds: 4),
///   spacing: 24,
///   children: const [
///     Text('Portable'),
///     Text('Strongly typed'),
///     Text('Low allocation'),
///   ],
/// )
/// ```
class Marquee extends StatefulWidget {
  /// Creates a continuously moving strip from [children].
  ///
  /// At least two children are required. [duration] must be positive,
  /// [spacing] must be finite and non-negative, and supplied viewport
  /// dimensions must be finite and non-negative. The children list must not be
  /// mutated after it is passed to this constructor.
  const Marquee({
    required this.children,
    this.direction = MarqueeDirection.right,
    this.duration = const Duration(seconds: 1),
    this.spacing = 0,
    this.width,
    this.height,
    this.interactive = false,
    this.infinity = true,
    super.key,
  }) : assert(spacing >= 0 && spacing < double.infinity, 'spacing must be finite and non-negative.'),
       assert(width == null || (width >= 0 && width < double.infinity), 'width must be finite and non-negative.'),
       assert(height == null || (height >= 0 && height < double.infinity), 'height must be finite and non-negative.');

  /// Widgets placed in the moving strip.
  ///
  /// The list must contain at least two children and must not be mutated after
  /// being passed to the constructor. Each source child is mounted once when
  /// [infinity] is false. When it is true, only the minimum cyclic prefix
  /// needed to cover the viewport is additionally mounted.
  final List<Widget> children;

  /// Physical direction in which the strip moves.
  final MarqueeDirection direction;

  /// Time taken for one complete loop.
  ///
  /// With [infinity], one source strip advances by its complete extent. When
  /// infinity is false, this includes the distance needed for the strip to
  /// begin and finish fully outside the viewport.
  final Duration duration;

  /// Logical pixels inserted between adjacent children.
  final double spacing;

  /// Requested viewport width.
  ///
  /// When null, a horizontal marquee fills its bounded parent width and a
  /// vertical marquee uses its widest child.
  final double? width;

  /// Requested viewport height.
  ///
  /// When null, a vertical marquee fills its bounded parent height and a
  /// horizontal marquee uses its tallest child.
  final double? height;

  /// Whether visible children accept pointer interaction while moving.
  ///
  /// Semantics remain available when this is false.
  final bool interactive;

  /// Whether child sets repeat without a gap between loops.
  ///
  /// When true, the minimum cyclic copies of [children] needed to cover the
  /// viewport are mounted while one complete source strip moves through its
  /// cycle. Do not place a [GlobalKey] anywhere in a child subtree when
  /// enabling this behavior, because Flutter cannot mount the same global key
  /// more than once.
  ///
  /// When false, each child is mounted once and the complete strip travels
  /// from fully outside the entry edge to fully outside the exit edge.
  final bool infinity;

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationsDisabled = false;
  bool _dependenciesReady = false;
  late int _mountedChildCount;
  late List<Widget> _mountedChildren;
  final List<Widget> _cyclicChildCache = <Widget>[];
  late final void Function(int) _requiredChildCountListener = _handleRequiredChildCountChanged;

  @override
  void initState() {
    super.initState();
    _validateConfiguration();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _mountedChildCount = widget.infinity ? widget.children.length * 2 : widget.children.length;
    _mountedChildren = _mountedChildrenForCount(_mountedChildCount);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_dependenciesReady && animationsDisabled == _animationsDisabled) {
      return;
    }

    _dependenciesReady = true;
    _animationsDisabled = animationsDisabled;
    _restartAnimation();
  }

  @override
  void didUpdateWidget(covariant Marquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateConfiguration();
    _controller.duration = widget.duration;
    final childrenChanged = !identical(
      oldWidget.children,
      widget.children,
    );
    if (oldWidget.infinity != widget.infinity || childrenChanged) {
      _mountedChildCount = widget.infinity ? widget.children.length * 2 : widget.children.length;
      if (childrenChanged) _cyclicChildCache.clear();
      _mountedChildren = _mountedChildrenForCount(_mountedChildCount);
    }
    if (oldWidget.duration != widget.duration ||
        oldWidget.infinity != widget.infinity ||
        oldWidget.direction != widget.direction ||
        oldWidget.spacing != widget.spacing ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height ||
        !identical(oldWidget.children, widget.children)) {
      _restartAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _restartAnimation() {
    _controller
      ..stop()
      ..value = 0;
    if (!_animationsDisabled) {
      unawaited(_controller.repeat());
    }
  }

  void _validateConfiguration() {
    if (widget.children.length < 2) {
      throw ArgumentError.value(
        widget.children,
        'children',
        'must contain at least two widgets',
      );
    }
    if (widget.duration <= Duration.zero) {
      throw ArgumentError.value(
        widget.duration,
        'duration',
        'must be positive',
      );
    }
  }

  void _handleRequiredChildCountChanged(int childCount) {
    if (!mounted || !widget.infinity || childCount == _mountedChildCount) {
      return;
    }
    setState(() {
      _mountedChildCount = childCount;
      _mountedChildren = _mountedChildrenForCount(childCount);
    });
  }

  List<Widget> _mountedChildrenForCount(int mountedChildCount) {
    while (_cyclicChildCache.length < mountedChildCount) {
      _cyclicChildCache.add(
        _createCyclicChild(_cyclicChildCache.length),
      );
    }
    return List<Widget>.of(
      _cyclicChildCache.getRange(0, mountedChildCount),
      growable: false,
    );
  }

  Widget _createCyclicChild(int mountedIndex) {
    final sourceChildCount = widget.children.length;
    final childIndex = mountedIndex % sourceChildCount;
    final sourceChild = widget.children[childIndex];
    return KeyedSubtree(
      key: ValueKey<(int, Object)>((
        mountedIndex ~/ sourceChildCount,
        sourceChild.key ?? childIndex,
      )),
      child: mountedIndex < sourceChildCount ? sourceChild : ExcludeSemantics(child: sourceChild),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: _MarqueeViewport(
        animation: _controller,
        direction: widget.direction,
        spacing: widget.spacing,
        width: widget.width,
        height: widget.height,
        staticPosition: _animationsDisabled,
        interactive: widget.interactive,
        infinity: widget.infinity,
        sourceChildCount: widget.children.length,
        onRequiredChildCountChanged: _requiredChildCountListener,
        children: _mountedChildren,
      ),
    );
  }
}
