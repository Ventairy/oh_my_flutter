import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() => runApp(const UtilityExample());

/// A small gallery for the public utility APIs.
class UtilityExample extends StatefulWidget {
  /// Creates the utility example.
  const UtilityExample({super.key});

  @override
  State<UtilityExample> createState() => _UtilityExampleState();
}

class _UtilityExampleState extends State<UtilityExample> {
  final _visibilityController = ControlledVisibilityController();
  bool _detailsVisible = false;

  void _toggleDetails() {
    setState(() => _detailsVisible = !_detailsVisible);
    if (_detailsVisible) {
      _visibilityController.show();
    } else {
      _visibilityController.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = withClock(
      Clock.fixed(DateTime.utc(2026, 1, 1, 12)),
      () => DateTime.utc(2026, 1, 1, 11, 55).timeAgo<String>(
        onMinutesAgo: (minutes) => '$minutes minutes ago',
      ),
    );

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4A4B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _toggleDetails,
                child: Text(_detailsVisible ? 'Hide details' : 'Show details'),
              ),
              const SizedBox(height: 12),
              ControlledVisibility(
                controller: _visibilityController,
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
              const SizedBox(height: 24),
              RouteSettled(
                showTransition: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: const Text('This appears after route motion settles.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
