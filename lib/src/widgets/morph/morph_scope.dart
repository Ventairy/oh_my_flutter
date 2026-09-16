part of 'morph.dart';

/// Provides inherited configuration to Morph widgets in a subtree.
///
/// Wrap content to configure its Morph widgets together without configuring
/// each appearance individually. See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md).
class MorphScope extends StatelessWidget {
  /// Creates inherited Morph configuration for [child].
  const MorphScope({required this.child, this.enabled = true, super.key});

  /// Whether descendants may start new Morph flights.
  ///
  /// Both endpoints must be enabled. A disabled ancestor takes precedence over
  /// an enabled inner scope. Existing flights keep their normal completion,
  /// reversal, retargeting, and handoff behavior.
  ///
  /// Changes take effect when this scope rebuilds. Apply the updated scope before
  /// navigating if that navigation should use the new value. Re-enabling does
  /// not replay changes made while disabled.
  final bool enabled;

  /// The subtree receiving this configuration.
  final Widget child;

  @override
  Widget build(BuildContext context) => _MorphScope(
    enabled: _MorphScope.enabledOf(context) && enabled,
    child: child,
  );
}
