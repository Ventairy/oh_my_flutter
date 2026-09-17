part of 'snap_list.dart';

class _SnapListItemTransition extends StatefulWidget {
  const _SnapListItemTransition({
    required this.transitions,
    required this.index,
    required this.incomingBuilder,
    required this.outgoingBuilder,
    required this.child,
  });

  final _SnapListTransitions transitions;
  final int index;
  final SnapListTransitionBuilder? incomingBuilder;
  final SnapListTransitionBuilder? outgoingBuilder;
  final Widget child;

  @override
  State<_SnapListItemTransition> createState() => _SnapListItemTransitionState();
}

class _SnapListItemTransitionState extends State<_SnapListItemTransition> {
  final _incoming = _SnapListTransitionAnimation(1);
  final _outgoing = _SnapListTransitionAnimation(0);
  bool _reverse = false;

  @override
  void initState() {
    super.initState();
    _updateAnimations();
    widget.transitions.addListener(widget.index, _changed);
  }

  @override
  void didUpdateWidget(_SnapListItemTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index || oldWidget.transitions != widget.transitions) {
      oldWidget.transitions.removeListener(oldWidget.index, _changed);
      widget.transitions.addListener(widget.index, _changed);
    }
    _updateAnimations();
  }

  bool _updateAnimations() {
    final (incoming, outgoing, reverse) = widget.transitions.values(widget.index);
    final changedDirection = reverse != _reverse;
    _reverse = reverse;
    _incoming.update(incoming, status: widget.transitions.status);
    _outgoing.update(outgoing, status: widget.transitions.status);
    return changedDirection;
  }

  void _changed() {
    if (_updateAnimations()) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.outgoingBuilder?.call(context, _outgoing, _reverse, widget.child) ?? widget.child;
    return widget.incomingBuilder?.call(context, _incoming, _reverse, child) ?? child;
  }

  @override
  void dispose() {
    widget.transitions.removeListener(widget.index, _changed);
    _incoming.dispose();
    _outgoing.dispose();
    super.dispose();
  }
}
