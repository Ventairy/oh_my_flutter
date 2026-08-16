import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows same-screen and cross-route Morph ownership transfers.
class MorphExample extends StatefulWidget {
  /// Creates the Morph example.
  const MorphExample({super.key});

  @override
  State<MorphExample> createState() => _MorphExampleState();
}

class _MorphExampleState extends State<MorphExample> {
  bool _expanded = false;

  Future<void> _openRoute() {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 430),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Stack(
                children: [
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Morph(
                        tag: 'example-route-morph',
                        child: Text(
                          'Route destination',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close route',
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildBehaviorExample(
          label: 'Live: content lays out at every flight size',
          tag: 'example-live-morph',
          behavior: MorphDescendantFlightBehavior.live,
        ),
        const SizedBox(height: 16),
        _buildBehaviorExample(
          label: 'Snapshot: captured content keeps its endpoint size',
          tag: 'example-snapshot-morph',
          behavior: MorphDescendantFlightBehavior.snapshot,
        ),
        const SizedBox(height: 16),
        _buildBehaviorExample(
          label: 'Hidden: ordinary content is omitted during the flight',
          tag: 'example-hidden-morph',
          behavior: MorphDescendantFlightBehavior.hide,
        ),
        const SizedBox(height: 16),
        Morph(
          tag: 'example-text-switch',
          duration: const Duration(milliseconds: 900),
          switchTransition: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Text(
            _expanded ? 'Arriving Text fades in' : 'Departing Text fades out',
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Collapse Morphs' : 'Expand Morphs',
          ),
        ),
        FilledButton.tonal(
          onPressed: _openRoute,
          child: const Morph(
            tag: 'example-route-morph',
            child: Text('Open route Morph'),
          ),
        ),
      ],
    );
  }

  Widget _buildBehaviorExample({
    required String label,
    required String tag,
    required MorphDescendantFlightBehavior behavior,
  }) {
    final alignment = _expanded ? Alignment.centerRight : Alignment.centerLeft;
    final color = _expanded ? const Color(0xFF3057D5) : const Color(0xFFFF4A4B);
    final text = _expanded
        ? 'This is different destination content. Watch how it wraps '
              'while the blue surface is still growing.'
        : 'Compact source content';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Align(
          alignment: alignment,
          child: SizedBox(
            width: _expanded ? 330 : 180,
            child: Morph(
              tag: tag,
              duration: const Duration(milliseconds: 900),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(_expanded ? 32 : 16),
                ),
                child: MorphDescendant(
                  flightBehavior: behavior,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth.toStringAsFixed(0);
                        return Text(
                          '$text\nCurrent layout width: $width',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
