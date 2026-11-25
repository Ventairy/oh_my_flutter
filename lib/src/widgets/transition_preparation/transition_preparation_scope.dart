import 'package:flutter/widgets.dart';

/// Package-internal rendezvous for transitions that need a painted source.
class TransitionPreparationScope extends InheritedWidget {
  /// Lets preparing descendants delay playback in this subtree.
  const new({required this.register, required super.child, super.key});

  /// Acquires a hold and returns its one-shot completion callback.
  final void Function(bool ready) Function() register;

  /// Registers with the enclosing transition, if present.
  static void Function(bool ready)? hold(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TransitionPreparationScope>()?.register();

  @override
  bool updateShouldNotify(TransitionPreparationScope oldWidget) => false;
}
