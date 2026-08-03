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
  final _sequenceController = SequenceController();
  bool _detailsVisible = false;

  @override
  void dispose() {
    _sequenceController.dispose();
    super.dispose();
  }

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
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PauseAnimations.temporarily(
                    duration: Duration(milliseconds: 300),
                    child: Motion.list(
                      effects: [
                        FadeInMotionEffect(),
                        ScaleInMotionEffect(
                          scale: 0.7,
                          delay: Duration(milliseconds: 80),
                        ),
                      ],
                      child: Icon(Icons.visibility_outlined, size: 32),
                    ),
                  ),
                  SizedBox(width: 24),
                  Motion(
                    effect: ScaleInMotionEffect(
                      scale: 0.4,
                      delay: Duration(milliseconds: 100),
                    ),
                    child: Icon(Icons.check_circle_outline, size: 32),
                  ),
                  SizedBox(width: 24),
                  Motion(
                    effect: MoveMotionEffect(
                      begin: Offset(-24, 0),
                      end: Offset.zero,
                      duration: Duration(milliseconds: 500),
                      delay: Duration(milliseconds: 150),
                    ),
                    child: Icon(Icons.arrow_forward, size: 32),
                  ),
                  SizedBox(width: 24),
                  Motion(
                    effect: FloatingMotionEffect(
                      delay: Duration(milliseconds: 300),
                    ),
                    child: Icon(Icons.cloud_outlined, size: 40),
                  ),
                ],
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
              Sequence(
                controller: _sequenceController,
                nextTransition: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                previousTransition: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                children: const [
                  Text('Sequence step one'),
                  Text('Sequence step two'),
                  Text('Sequence step three'),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _sequenceController,
                builder: (context, child) {
                  final sequence = _sequenceController;
                  final index = sequence.index;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: index == 0 ? null : sequence.previous,
                        tooltip: 'Previous step',
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Text('Step ${index + 1} of 3'),
                      IconButton(
                        onPressed: index == 2 ? null : sequence.next,
                        tooltip: 'Next step',
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  );
                },
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
