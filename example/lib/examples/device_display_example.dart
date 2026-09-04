import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Demonstrates reading trustworthy display corner radii when available.
class DeviceDisplayExample extends StatefulWidget {
  /// Creates the device display example.
  const DeviceDisplayExample({
    this.cornerRadii,
    super.key,
  });

  /// Overrides the corner-radii operation for deterministic tests.
  final Future<BorderRadius?> Function(BuildContext context)? cornerRadii;

  @override
  State<DeviceDisplayExample> createState() => _DeviceDisplayExampleState();
}

class _DeviceDisplayExampleState extends State<DeviceDisplayExample> {
  static const _device = Device();

  BorderRadius? _radii;
  String _status = 'No display corner radii read yet.';
  bool _working = false;

  Future<void> _readCornerRadii() async {
    if (_working) return;
    setState(() => _working = true);

    final operation = widget.cornerRadii;
    final BorderRadius? radii;
    if (operation == null) {
      radii = await _device.display.cornerRadii(context);
    } else {
      radii = await operation(context);
    }

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
        FilledButton(
          onPressed: _working ? null : _readCornerRadii,
          child: const Text('Read corner radii'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Returns Flutter or native platform data when trustworthy '
          'information is available.',
        ),
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
