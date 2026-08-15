import 'package:flutter/material.dart';

/// Displays the benchmark result only after all timed work has finished.
class MorphBenchmarkStatus extends StatelessWidget {
  /// Creates the benchmark result status.
  const MorphBenchmarkStatus({
    required this.complete,
    required this.status,
    super.key,
  });

  /// Whether all timed benchmark work has finished.
  final bool complete;

  /// Result message displayed after completion.
  final String status;

  @override
  Widget build(BuildContext context) {
    if (!complete) return const SizedBox.shrink();
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Text(status, maxLines: 2),
    );
  }
}
