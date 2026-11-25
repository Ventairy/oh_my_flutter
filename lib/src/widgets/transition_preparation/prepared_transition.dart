import 'dart:async';

import 'package:flutter/widgets.dart';

import 'transition_preparation_scope.dart';

/// Shows the first frame while descendants prepare a transition.
class PreparedTransition extends StatefulWidget {
  /// Calls [onReady] once after the initial frame and all preparation completes.
  const new({required this.onReady, required this.child, super.key});

  /// Receives false if preparation failed.
  final ValueChanged<bool> onReady;

  /// The transition subtree to prepare.
  final Widget child;

  @override
  State<PreparedTransition> createState() => _PreparedTransitionState();
}

class _PreparedTransitionState extends State<PreparedTransition> {
  int _pending = 0;
  bool _painted = false;
  bool _scheduled = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _painted = true;
      _notifyWhenReady();
    });
  }

  void Function(bool) _register() {
    if (_scheduled) return (_) {};
    _pending++;
    var released = false;
    return (ready) {
      if (released) return;
      released = true;
      _failed |= !ready;
      _pending--;
      _notifyWhenReady();
    };
  }

  void _notifyWhenReady() {
    if (!_painted || _scheduled || _pending != 0) return;
    _scheduled = true;
    scheduleMicrotask(() {
      if (mounted) widget.onReady(!_failed);
    });
  }

  @override
  Widget build(BuildContext context) => TransitionPreparationScope(register: _register, child: widget.child);
}
