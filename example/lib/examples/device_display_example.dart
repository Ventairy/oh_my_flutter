import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Demonstrates exact display corner radii with an optional estimate fallback.
class DeviceDisplayExample extends StatefulWidget {
  /// Creates the device display example.
  const DeviceDisplayExample({
    this.cornerRadii,
    super.key,
  });

  /// Overrides the corner-radii operation for deterministic tests.
  final Future<BorderRadius?> Function(
    BuildContext context, {
    required bool estimate,
  })?
  cornerRadii;

  @override
  State<DeviceDisplayExample> createState() => _DeviceDisplayExampleState();
}

class _DeviceDisplayExampleState extends State<DeviceDisplayExample> {
  static const _device = Device();

  BorderRadius? _radii;
  String _status = 'No display corner radii read yet.';
  bool _working = false;

  Future<void> _readCornerRadii({required bool estimate}) async {
    if (_working) return;
    setState(() => _working = true);

    final operation = widget.cornerRadii;
    final radii = operation == null
        ? await _device.display.cornerRadii(context, estimate: estimate)
        : await operation(context, estimate: estimate);

    if (!mounted) return;
    setState(() {
      _radii = radii;
      if (radii == null) {
        _status = 'Display corner radii are unavailable.';
      } else {
        _status = _describe(radii);
      }
      _working = false;
    });
  }

  Future<void> _readExactCornerRadii() {
    return _readCornerRadii(estimate: false);
  }

  Future<void> _readEstimatedCornerRadii() {
    return _readCornerRadii(estimate: true);
  }

  String _describe(BorderRadius radii) {
    return 'Top-left ${_format(radii.topLeft)}, '
        'top-right ${_format(radii.topRight)}, '
        'bottom-right ${_format(radii.bottomRight)}, '
        'bottom-left ${_format(radii.bottomLeft)} logical pixels.';
  }

  String _format(Radius radius) {
    final horizontal = radius.x.toStringAsFixed(1);
    if (radius.x == radius.y) return horizontal;
    return '$horizontal×${radius.y.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _working ? null : _readExactCornerRadii,
              child: const Text('Read exact data'),
            ),
            OutlinedButton(
              onPressed: _working ? null : _readEstimatedCornerRadii,
              child: const Text('Allow estimate'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Allowing an estimate still prefers exact Flutter data.'),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: _radii ?? BorderRadius.zero,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_working ? 'Reading…' : _status),
            ),
          ),
        ),
      ],
    );
  }
}
