import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() => runApp(const UtilityExample());

/// A small gallery for the public utility APIs.
class UtilityExample extends StatelessWidget {
  /// Creates the utility example.
  const UtilityExample({super.key});

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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: '#FF4A4B'.hexToColor(),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(label, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
