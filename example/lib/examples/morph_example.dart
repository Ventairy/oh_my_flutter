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
    final alignment = _expanded ? Alignment.centerRight : Alignment.centerLeft;
    var color = const Color(0xFFFF4A4B);
    var text = 'Tap to morph';
    if (_expanded) {
      color = const Color(0xFF3057D5);
      text = 'Morph works across routes and within one screen.';
    }

    return Column(
      children: [
        Align(
          alignment: alignment,
          child: SizedBox(
            width: _expanded ? 300 : 180,
            child: Morph(
              tag: 'example-morph',
              duration: const Duration(milliseconds: 360),
              nonMorphDescendantsTransition: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(_expanded ? 32 : 16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(_expanded ? 24 : 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.white),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _expanded ? 20 : 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: const Text('Transfer Morph ownership'),
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
}
