import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows multiple Motion effects applied to the graphemes of a Text widget.
class TextMotionExample extends StatelessWidget {
  /// Creates the TextMotion example.
  const TextMotionExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const TextMotion.list(
      effects: [
        FadeInMotionEffect(),
        MoveMotionEffect(
          begin: Offset(0, 8),
          end: Offset.zero,
        ),
      ],
      child: Text(
        'Motion for every letter',
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}
