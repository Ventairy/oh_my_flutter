import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows a mounted details surface returning to its card when removed.
class MorphLocalExample extends StatefulWidget {
  /// Creates the local appearance example.
  const new({super.key});

  @override
  State<MorphLocalExample> createState() => _MorphLocalExampleState();
}

class _MorphLocalExampleState extends State<MorphLocalExample> {
  final _card = MorphTarget(tag: 'local-example');
  final _details = MorphTarget(tag: 'local-example');
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Mount details to move the surface; remove them to return.'),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: Stack(
            children: [
              Positioned(top: 0, left: 0, child: _header(_card, 'Card header')),
              Positioned(
                top: 36,
                left: 0,
                child: Morph(
                  animateChildChanges: true,
                  target: _card,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    width: 150,
                    height: 100,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFE8F1FF), borderRadius: BorderRadius.circular(16)),
                    child: const Text('A compact card'),
                  ),
                ),
              ),
              if (_showDetails) ...[
                Positioned(top: 0, right: 0, child: _header(_details, 'Details header')),
                Positioned(
                  top: 36,
                  right: 0,
                  child: Morph(
                    animateChildChanges: true,
                    target: _details,
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      width: 230,
                      height: 230,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E6),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Text('More room for the details'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _showDetails = !_showDetails),
          child: Text(_showDetails ? 'Remove details' : 'Mount details'),
        ),
      ],
    );
  }

  Widget _header(MorphTarget target, String label) {
    return MorphSibling(
      target: target,
      transitionBuilder: (child, curved, uncurved) {
        return FadeTransition(opacity: uncurved, child: child);
      },
      child: Text(label),
    );
  }
}
