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
  final _card = MorphTarget(tag: 'local-example', duration: const Duration(milliseconds: 500));

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
              const Positioned(top: 0, left: 0, child: Text('Card')),
              Positioned(
                top: 36,
                left: 0,
                child: Morph(
                  targets: [_card],

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
                const Positioned(top: 0, right: 0, child: Text('Details')),
                Positioned(
                  top: 36,
                  right: 0,
                  child: Morph(
                    targets: [_card],

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
}
