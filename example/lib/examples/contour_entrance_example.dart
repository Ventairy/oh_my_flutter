import 'package:flutter/material.dart';

import 'package:oh_my_flutter_example/examples/contour_entrance_sample.dart';

/// Shows how preparation and readiness preserve a complete sticker entrance.
class ContourEntranceExample extends StatefulWidget {
  /// Creates the entrance comparison.
  const new({super.key});

  @override
  State<ContourEntranceExample> createState() => _ContourEntranceExampleState();
}

class _ContourEntranceExampleState extends State<ContourEntranceExample> {
  int _replay = 0;
  bool _pop = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Compare entrances', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      const Text(
        'Both sides use a 300 ms entrance, with the second sticker starting no earlier than 200 ms. '
        'The prepared side waits until each complete sticker is ready before starting its full entrance.',
      ),
      const SizedBox(height: 16),
      ColoredBox(
        color: const Color(0xFFF0F1F5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final prepared in [false, true])
                Expanded(
                  child: Column(
                    children: [
                      Text(prepared ? 'Prepare, then enter' : 'Enter on schedule', textAlign: TextAlign.center),
                      for (var index = 0; index < 2; index++)
                        ContourEntranceSample(
                          key: ValueKey('entrance-$_replay-$prepared-$index-$_pop'),
                          waitUntilReady: prepared,
                          delay: Duration(milliseconds: index * 200),
                          pop: _pop,
                          child: Text(
                            index == 0 ? 'Hello!' : 'Ooo',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: index == 0 ? const Color(0xFF36ADEB) : const Color(0xFF8050E8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Pop and fade'),
        subtitle: const Text('Turn off to compare fade only. Reduced motion skips both effects and the stagger.'),
        value: _pop,
        onChanged: (value) => setState(() => _pop = value),
      ),
      TextButton.icon(
        onPressed: () => setState(() => _replay++),
        icon: const Icon(Icons.replay),
        label: const Text('Replay entrances'),
      ),
      const Text(
        'Replay mounts new widgets; shared caches may already be warm. '
        '“Ready” describes readiness, not physical screen presentation. '
        'This comparison does not add an artificial loading delay.',
      ),
    ],
  );
}
