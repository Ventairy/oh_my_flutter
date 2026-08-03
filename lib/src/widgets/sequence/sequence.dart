import 'dart:async';

import 'package:flutter/widgets.dart';

part 'sequence_controller.dart';
part 'sequence_entry.dart';
part 'sequence_types.dart';

/// Shows one widget at a time from an ordered sequence.
///
/// Use a [SequenceController] to move to the next or previous child, or to
/// select a child by index. Without a transition builder, navigation changes
/// the visible child immediately.
///
/// A directional transition wraps both participating children. Its animation
/// runs from `0` (hidden) to `1` (visible), so the destination runs forward
/// while the source runs in reverse. Paint and compositing transitions such as
/// fades, slides, and scales generally impose less work than transitions that
/// lay out their child on every animation frame.
///
/// ```dart
/// final controller = SequenceController();
///
/// Sequence(
///   controller: controller,
///   nextTransition: (child, animation) => FadeTransition(
///     opacity: animation,
///     child: child,
///   ),
///   children: const [
///     Text('First'),
///     Text('Second'),
///   ],
/// )
/// ```
class Sequence extends StatefulWidget {
  /// Creates a widget that displays one child from [children] at a time.
  const Sequence({
    required this.children,
    this.nextTransition,
    this.previousTransition,
    this.controller,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration = const Duration(milliseconds: 300),
    this.keepMounted = false,
    this.alignment = AlignmentDirectional.topStart,
    super.key,
  }) : assert(children.length > 0, 'Sequence requires at least one child.'),
       assert(duration >= Duration.zero, 'duration must not be negative.'),
       assert(
         reverseDuration >= Duration.zero,
         'reverseDuration must not be negative.',
       );

  /// Widgets displayed by the sequence.
  ///
  /// The list must contain at least one child. The first child is selected
  /// initially. Keys identify child state when this list is reordered.
  final List<Widget> children;

  /// Transition used when navigating to a higher index.
  ///
  /// When `null`, forward navigation is immediate.
  final SequenceTransitionBuilder? nextTransition;

  /// Transition used when navigating to a lower index.
  ///
  /// When `null`, backward navigation is immediate.
  final SequenceTransitionBuilder? previousTransition;

  /// Controller used to navigate and observe the selected [children] index.
  ///
  /// When omitted, [Sequence] creates an internal controller.
  final SequenceController? controller;

  /// Duration used to animate the destination from hidden to visible.
  ///
  /// This value is ignored when the selected direction has no transition,
  /// when it is zero, or when the platform requests reduced motion.
  final Duration duration;

  /// Duration used to animate the source from visible to hidden.
  ///
  /// This value is ignored when the selected direction has no transition,
  /// when it is zero, or when the platform requests reduced motion.
  final Duration reverseDuration;

  /// Whether inactive children remain mounted.
  ///
  /// When `false`, only the current and exiting children are mounted. When
  /// `true`, every child remains mounted offstage so its local state survives.
  /// Retention necessarily keeps every subtree in memory and still lays it out
  /// offstage, so prefer the default for long or expensive sequences.
  final bool keepMounted;

  /// How differently sized children are aligned during a transition.
  ///
  /// At rest, [Sequence] sizes itself to the current child. During a
  /// transition, it sizes itself to the largest participating child and uses
  /// this alignment for the smaller participants. A parent such as [Center]
  /// can still reposition the entire sequence when that outer size changes;
  /// provide stable parent constraints when the sequence itself must remain
  /// anchored.
  final AlignmentGeometry alignment;

  @override
  State<Sequence> createState() => _SequenceState();
}

class _SequenceState extends State<Sequence> with TickerProviderStateMixin {
  final Map<Object, _SequenceEntry> _entries = {};
  late SequenceController _controller;
  late bool _ownsController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? SequenceController();
    _attachController();
    _ensureEntryAt(_index);
    if (widget.keepMounted) _ensureAllEntries();
  }

  @override
  void didUpdateWidget(covariant Sequence oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldIndex = _index;
    final oldIdentity = oldIndex < oldWidget.children.length ? _identityAt(oldWidget.children, oldIndex) : null;

    if (_index >= widget.children.length) {
      _index = widget.children.length - 1;
    }

    _updateExternalController(oldWidget);
    _controller._setIndex(_index);
    _updateActiveDurations();
    _reconcileEntries();

    final currentEntry = _ensureEntryAt(_index);
    final selectedChildChanged = oldIdentity != currentEntry.identity;
    if (oldIndex != _index || selectedChildChanged) {
      _showImmediately(currentEntry);
      return;
    }

    if (widget.keepMounted) {
      _ensureAllEntries();
    } else if (oldWidget.keepMounted) {
      _removeInactiveEntries();
    }
  }

  @override
  void dispose() {
    _controller._detach(this);
    if (_ownsController) _controller.dispose();
    for (final entry in _entries.values) {
      entry.animationController?.dispose();
    }
    super.dispose();
  }

  void _updateExternalController(Sequence oldWidget) {
    if (oldWidget.controller == widget.controller) return;

    _controller._detach(this);
    if (_ownsController) _controller.dispose();

    _ownsController = widget.controller == null;
    _controller = widget.controller ?? SequenceController();
    _attachController();
  }

  void _attachController() {
    _controller._attach(
      owner: this,
      index: _index,
      onNext: _next,
      onPrevious: _previous,
      onGoTo: _goTo,
    );
  }

  void _next() {
    if (_index == widget.children.length - 1) return;
    _navigateTo(_index + 1);
  }

  void _previous() {
    if (_index == 0) return;
    _navigateTo(_index - 1);
  }

  void _goTo(int index) {
    RangeError.checkValidIndex(index, widget.children, 'index');
    if (index == _index) return;
    _navigateTo(index);
  }

  void _navigateTo(int targetIndex) {
    final transition = targetIndex > _index ? widget.nextTransition : widget.previousTransition;
    final source = _ensureEntryAt(_index);
    final target = _ensureEntryAt(targetIndex);

    _index = targetIndex;
    _controller._setIndex(targetIndex);

    final animationsDisabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (transition == null ||
        animationsDisabled ||
        (widget.duration == Duration.zero && widget.reverseDuration == Duration.zero)) {
      setState(() => _showImmediately(target));
      return;
    }

    _animateTo(
      source: source,
      target: target,
      transition: transition,
    );
  }

  void _animateTo({
    required _SequenceEntry source,
    required _SequenceEntry target,
    required SequenceTransitionBuilder transition,
  }) {
    AnimationController? sourceController;
    AnimationController? targetController;

    setState(() {
      if (widget.reverseDuration == Duration.zero) {
        _hideImmediately(source);
      } else {
        sourceController = _ensureAnimationController(source, initialValue: 1)
          ..stop()
          ..reverseDuration = widget.reverseDuration;
        source.transition = transition;
      }

      if (widget.duration == Duration.zero) {
        _disposeAnimation(target);
      } else {
        targetController = _ensureAnimationController(target, initialValue: 0)
          ..stop()
          ..duration = widget.duration;
        target.transition = transition;
      }
    });

    if (sourceController != null) unawaited(sourceController!.reverse());
    if (targetController != null) unawaited(targetController!.forward());
  }

  AnimationController _ensureAnimationController(
    _SequenceEntry entry, {
    required double initialValue,
  }) {
    final existing = entry.animationController;
    if (existing != null) {
      existing
        ..duration = widget.duration
        ..reverseDuration = widget.reverseDuration;
      return existing;
    }

    final controller = AnimationController(
      value: initialValue,
      duration: widget.duration,
      reverseDuration: widget.reverseDuration,
      vsync: this,
    );
    entry.animationController = controller;
    controller.addStatusListener(
      (status) => _handleAnimationStatus(entry, status),
    );
    return controller;
  }

  void _handleAnimationStatus(
    _SequenceEntry entry,
    AnimationStatus status,
  ) {
    if (!mounted || entry.animationController == null) return;

    if (status.isCompleted && _isCurrent(entry)) {
      if (entry.transition == null) return;
      setState(() => entry.transition = null);
      return;
    }

    if (!status.isDismissed || _isCurrent(entry)) return;
    setState(() => _hideImmediately(entry));
  }

  void _showImmediately(_SequenceEntry target) {
    if (widget.keepMounted) {
      _entries.values.forEach(_disposeAnimation);
      _ensureAllEntries();
      return;
    }

    _entries.removeWhere((identity, entry) {
      _disposeAnimation(entry);
      return !identical(entry, target);
    });
  }

  void _hideImmediately(_SequenceEntry entry) {
    _disposeAnimation(entry);
    if (!widget.keepMounted && !_isCurrent(entry)) {
      _entries.remove(entry.identity);
    }
  }

  void _disposeAnimation(_SequenceEntry entry) {
    entry.transition = null;
    entry.animationController?.dispose();
    entry.animationController = null;
  }

  void _updateActiveDurations() {
    for (final entry in _entries.values) {
      entry.animationController
        ?..duration = widget.duration
        ..reverseDuration = widget.reverseDuration;
    }
  }

  void _reconcileEntries() {
    final currentIdentities = <Object>{};
    for (var index = 0; index < widget.children.length; index += 1) {
      final identity = _identityAt(widget.children, index);
      currentIdentities.add(identity);
      final entry = _entries[identity];
      if (entry != null) {
        entry
          ..index = index
          ..child = widget.children[index];
      }
    }

    _entries.removeWhere((identity, entry) {
      if (currentIdentities.contains(identity)) return false;
      _disposeAnimation(entry);
      return true;
    });
  }

  void _ensureAllEntries() {
    for (var index = 0; index < widget.children.length; index += 1) {
      _ensureEntryAt(index);
    }
  }

  void _removeInactiveEntries() {
    final currentIdentity = _identityAt(widget.children, _index);
    _entries.removeWhere((identity, entry) {
      return identity != currentIdentity && entry.animationController == null;
    });
  }

  _SequenceEntry _ensureEntryAt(int index) {
    final child = widget.children[index];
    final identity = _identityAt(widget.children, index);
    final entry =
        _entries.putIfAbsent(
            identity,
            () => _SequenceEntry(
              identity: identity,
              index: index,
              child: child,
            ),
          )
          ..index = index
          ..child = child;
    return entry;
  }

  Object _identityAt(List<Widget> children, int index) {
    return children[index].key ?? index;
  }

  bool _isCurrent(_SequenceEntry entry) {
    return entry.identity == _identityAt(widget.children, _index);
  }

  Widget _buildEntry(_SequenceEntry entry, {required bool current}) {
    final controller = entry.animationController;
    final hidden = !current && controller == null;
    final child = KeyedSubtree(
      key: entry.subtreeKey,
      child: entry.child,
    );

    if (hidden) {
      return Positioned(
        key: entry.stackKey,
        child: Offstage(
          offstage: true,
          child: TickerMode(enabled: false, child: child),
        ),
      );
    }

    Widget result = IgnorePointer(
      ignoring: !current,
      child: current ? child : ExcludeSemantics(excluding: true, child: child),
    );
    final transition = entry.transition;
    if (transition != null && controller != null) {
      result = transition(result, controller);
    }
    return KeyedSubtree(key: entry.stackKey, child: result);
  }

  @override
  Widget build(BuildContext context) {
    final currentIdentity = _identityAt(widget.children, _index);
    final currentEntry = _entries[currentIdentity]!;
    final entries = <Widget>[];

    for (final entry in _entries.values) {
      if (identical(entry, currentEntry)) continue;
      entries.add(_buildEntry(entry, current: false));
    }
    entries.add(_buildEntry(currentEntry, current: true));

    return Stack(
      alignment: widget.alignment,
      children: entries,
    );
  }
}
