import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows a continuously looping horizontal Marquee.
class MarqueeExample extends StatelessWidget {
  /// Creates the Marquee example.
  const MarqueeExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 320,
      child: Marquee(
        direction: MarqueeDirection.left,
        duration: Duration(seconds: 4),
        spacing: 24,
        children: [
          Text('Portable'),
          Text('Strongly typed'),
          Text('Low allocation'),
        ],
      ),
    );
  }
}
