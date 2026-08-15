import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows built-in Motion effects and their lifecycle callbacks.
class MotionExample extends StatefulWidget {
  /// Creates the Motion example.
  const MotionExample({super.key});

  @override
  State<MotionExample> createState() => _MotionExampleState();
}

class _MotionExampleState extends State<MotionExample> {
  final _controller = MotionController();
  String _status = 'Motion is waiting';

  void _handleStarted() {
    setState(() => _status = 'Motion started');
  }

  void _handleCompleted() {
    setState(() => _status = 'Motion completed');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const PauseAnimations.temporarily(
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
            const SizedBox(width: 24),
            Motion(
              controller: _controller,
              effect: ScaleInMotionEffect(
                scale: 0.4,
                delay: const Duration(milliseconds: 100),
                onStart: _handleStarted,
                onEnd: _handleCompleted,
              ),
              child: const Icon(Icons.check_circle_outline, size: 32),
            ),
            const SizedBox(width: 24),
            const Motion(
              effect: MoveMotionEffect(
                begin: Offset(-24, 0),
                end: Offset.zero,
                duration: Duration(milliseconds: 500),
                delay: Duration(milliseconds: 150),
              ),
              child: Icon(Icons.arrow_forward, size: 32),
            ),
            const SizedBox(width: 24),
            const Motion(
              effect: FloatingMotionEffect(
                delay: Duration(milliseconds: 300),
              ),
              child: Icon(Icons.cloud_outlined, size: 40),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(_status),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _controller.play,
          icon: const Icon(Icons.replay),
          label: const Text('Play motion again'),
        ),
      ],
    );
  }
}
