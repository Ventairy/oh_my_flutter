import 'package:flutter/widgets.dart';

/// Paints a composite widget whose contour cannot use native glyph rendering.
class ContourBenchmarkGenericArtwork extends StatelessWidget {
  /// Selects a stable or changing rounded composite silhouette.
  const new({required this.variant, super.key});

  /// Varies its rounded edges without changing the benchmark cell size.
  final int variant;

  @override
  Widget build(BuildContext context) {
    final radius = 5.0 + variant % 7;
    return SizedBox(
      width: 32,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 4,
            width: 24 + (variant % 10) * .6,
            height: 20 + (variant ~/ 10 % 4).toDouble(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: variant.isEven ? const Color(0xFF36A9E8) : const Color(0xFF8055E8),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: 13,
            height: 13,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFB833),
                shape: variant.isEven ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: variant.isEven ? null : BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
