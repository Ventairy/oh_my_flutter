import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows content after its route motion has settled.
class RouteSettledExample extends StatelessWidget {
  /// Creates the RouteSettled example.
  const RouteSettledExample({super.key});

  @override
  Widget build(BuildContext context) {
    return RouteSettled(
      showTransition: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: const Text('This appears after route motion settles.'),
    );
  }
}
