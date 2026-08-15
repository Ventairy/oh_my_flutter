import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows multiple Motion effects applied to the graphemes of a Text widget.
class TextMotionExample extends StatefulWidget {
  /// Creates the TextMotion example.
  const TextMotionExample({super.key});

  @override
  State<TextMotionExample> createState() => _TextMotionExampleState();
}

class _TextMotionExampleState extends State<TextMotionExample> {
  final MotionController _controller = MotionController();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextMotion.list(
          controller: _controller,
          startup: MotionStartup.skip,
          effects: const [
            FadeInMotionEffect(),
            MoveMotionEffect(
              begin: Offset(0, 8),
              end: Offset.zero,
            ),
          ],
          child: const Text(
            'Motion for every letter',
            style: TextStyle(fontSize: 20),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _controller.play,
          child: const Text('Play text motion again'),
        ),
      ],
    );
  }
}
