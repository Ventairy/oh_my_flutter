import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows application-controlled visibility with independent transitions.
class ControlledVisibilityExample extends StatefulWidget {
  /// Creates the ControlledVisibility example.
  const ControlledVisibilityExample({super.key});

  @override
  State<ControlledVisibilityExample> createState() {
    return _VisibilityExampleState();
  }
}

class _VisibilityExampleState extends State<ControlledVisibilityExample> {
  final _controller = ControlledVisibilityController();
  bool _detailsVisible = false;

  void _toggleDetails() {
    setState(() => _detailsVisible = !_detailsVisible);
    if (_detailsVisible) {
      _controller.show();
    } else {
      _controller.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton(
          onPressed: _toggleDetails,
          child: Text(_detailsVisible ? 'Hide details' : 'Show details'),
        ),
        const SizedBox(height: 12),
        ControlledVisibility(
          controller: _controller,
          showDuration: const Duration(milliseconds: 240),
          hideDuration: const Duration(milliseconds: 120),
          showTransition: (child, animation) => FadeTransition(
            opacity: CurveTween(
              curve: Curves.easeOutCubic,
            ).animate(animation),
            child: child,
          ),
          hideTransition: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: const Text('Visibility remains application-controlled.'),
        ),
      ],
    );
  }
}
