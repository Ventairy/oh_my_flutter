// dart format width=80
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'group_morph/_group_morph_delegate.dart';

/// Moves a card and attached header together while its title has its own Morph.
class GroupMorphExample extends StatefulWidget {
  /// Creates the grouped Morph example.
  const new({super.key});

  @override
  State<GroupMorphExample> createState() => _GroupMorphExampleState();
}

class _GroupMorphExampleState extends State<GroupMorphExample> {
  final _source = MorphTarget(tag: 'group-example-surface');
  final _destination = MorphTarget(tag: 'group-example-surface');
  final _sourceTitle = MorphTarget(tag: 'group-example-title');
  final _destinationTitle = MorphTarget(tag: 'group-example-title');
  final _sourceGroup = GroupLink();
  final _destinationGroup = GroupLink();
  bool _expanded = false;

  Widget _appearance(bool expanded) {
    final group = expanded ? _destinationGroup : _sourceGroup;
    return SizedBox(
      width: expanded ? 240 : 140,
      height: expanded ? 180 : 110,
      child: Stack(
        children: [
          Positioned.fill(
            child: Morph(
              target: expanded ? _destination : _source,
              animateChildChanges: true,
              duration: const Duration(milliseconds: 800),
              flightConfig: MorphFlightConfig.custom(
                _GroupMorphDelegate(group),
              ),
              child: Group(
                link: group,
                child: ColoredBox(
                  color: expanded
                      ? const Color(0xffffe1c4)
                      : const Color(0xffdce9ff),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Group(
              link: group,
              zIndex: 1,
              child: Morph(
                target: expanded ? _destinationTitle : _sourceTitle,
                animateChildChanges: true,
                duration: const Duration(milliseconds: 800),
                child: Text(
                  'One title',
                  style: TextStyle(
                    fontSize: expanded ? 26 : 18,
                    color: const Color(0xff172038),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Group(
              link: group,
              zIndex: 2,
              child: Text(expanded ? 'Expanded details' : 'Compact card'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('The title travels independently; the footer stays attached.'),
      const SizedBox(height: 12),
      SizedBox(
        height: 300,
        child: Stack(
          children: [
            Positioned(left: 0, top: 0, child: _appearance(false)),
            if (_expanded)
              Positioned(right: 0, bottom: 0, child: _appearance(true)),
          ],
        ),
      ),
      TextButton(
        onPressed: () => setState(() => _expanded = !_expanded),
        child: Text(_expanded ? 'Return card' : 'Expand card'),
      ),
    ],
  );
}
