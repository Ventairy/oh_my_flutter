part of 'snap_list.dart';

class _SnapListItemTransition extends StatefulWidget {
  const new({
    required this.transitions,
    required this.index,
    required this.isTrailing,
    required this.incomingBuilder,
    required this.outgoingBuilder,
    required this.child,
  });

  final _SnapListTransitions transitions;
  final int index;
  final bool isTrailing;
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
  bool _involvesTrailing = false;

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
    final values = widget.transitions.values(widget.index);
    final nextInvolvesTrailing = widget.isTrailing || values.involvesTrailing;
    final changedDetails = values.isReverse != _reverse || nextInvolvesTrailing != _involvesTrailing;
    _reverse = values.isReverse;
    _involvesTrailing = nextInvolvesTrailing;
    _incoming.update(values.incoming, status: widget.transitions.status);
    _outgoing.update(values.outgoing, status: widget.transitions.status);
    return changedDetails;
  }

  void _changed() {
    if (_updateAnimations()) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final details = SnapListTransitionDetails(
      isReverse: _reverse,
      isTrailing: widget.isTrailing,
      involvesTrailing: _involvesTrailing,
    );
    final child = widget.outgoingBuilder?.call(context, _outgoing, details, widget.child) ?? widget.child;
    return widget.incomingBuilder?.call(context, _incoming, details, child) ?? child;
  }

  @override
  void dispose() {
    widget.transitions.removeListener(widget.index, _changed);
    _incoming.dispose();
    _outgoing.dispose();
    super.dispose();
  }
}
