import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows a relative time label evaluated against a deterministic clock.
class RelativeTimeExample extends StatelessWidget {
  /// Creates the relative time example.
  const RelativeTimeExample({super.key});

  @override
  Widget build(BuildContext context) {
    final label = withClock(
      Clock.fixed(DateTime.utc(2026, 1, 1, 12)),
      () => DateTime.utc(2026, 1, 1, 11, 55).timeAgo<String>(
        onMinutesAgo: (minutes) => '$minutes minutes ago',
      ),
    );

    return DecoratedBox(
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
    );
  }
}
