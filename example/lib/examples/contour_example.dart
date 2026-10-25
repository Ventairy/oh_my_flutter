import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'package:oh_my_flutter_example/examples/contour_entrance_example.dart';

/// Demonstrates solid backings behind text and icon artwork.
class ContourExample extends StatefulWidget {
  /// Creates the contour example.
  const new({super.key});

  @override
  State<ContourExample> createState() => _ContourExampleState();
}

class _ContourExampleState extends State<ContourExample> {
  double _amount = 6;
  bool _shadow = true;
  bool _alternate = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Wrap(
            spacing: 36,
            runSpacing: 36,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Contour(
                color: Colors.white,
                amount: _amount,
                shadows: _shadow
                    ? const [Shadow(color: Color(0x33000000), offset: Offset(0, 6), blurRadius: 10)]
                    : const [],
                child: const Icon(Icons.favorite, size: 64, color: Color(0xFFFF4A4B)),
              ),
              Contour(
                color: Colors.white,
                amount: _amount,
                shadows: _shadow
                    ? const [Shadow(color: Color(0x33000000), offset: Offset(0, 6), blurRadius: 10)]
                    : const [],
                child: Text(
                  _alternate ? 'Olá, mundo!' : 'Armando?',
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: Color(0xFF36ADEB)),
                ),
              ),
            ],
          ),
        ),
      ),
      Row(
        children: [
          const Text('Amount'),
          Expanded(
            child: Slider(value: _amount, max: 12, onChanged: (value) => setState(() => _amount = value)),
          ),
          Text(_amount.toStringAsFixed(1)),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Shadow'),
        value: _shadow,
        onChanged: (value) => setState(() => _shadow = value),
      ),
      TextButton(onPressed: () => setState(() => _alternate = !_alternate), child: const Text('Change text')),
      const SizedBox(height: 24),
      const ContourEntranceExample(),
    ],
  );
}
