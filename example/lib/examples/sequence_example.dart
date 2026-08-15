import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows controller-driven navigation through a Sequence.
class SequenceExample extends StatefulWidget {
  /// Creates the Sequence example.
  const SequenceExample({super.key});

  @override
  State<SequenceExample> createState() => _SequenceExampleState();
}

class _SequenceExampleState extends State<SequenceExample> {
  final _controller = SequenceController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Sequence(
          controller: _controller,
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
          animation: _controller,
          builder: (context, child) {
            final index = _controller.index;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: index == 0 ? null : _controller.previous,
                  tooltip: 'Previous step',
                  icon: const Icon(Icons.arrow_back),
                ),
                Text('Step ${index + 1} of 3'),
                IconButton(
                  onPressed: index == 2 ? null : _controller.next,
                  tooltip: 'Next step',
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
