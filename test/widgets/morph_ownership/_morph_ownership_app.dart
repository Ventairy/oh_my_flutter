part of '../morph_ownership_test.dart';

class _MorphOwnershipApp extends StatefulWidget {
  const _MorphOwnershipApp(this.scenario);

  final _MorphOwnershipScenario scenario;

  @override
  State<_MorphOwnershipApp> createState() => _MorphOwnershipAppState();
}

class _MorphOwnershipAppState extends State<_MorphOwnershipApp> {
  late final entry = OverlayEntry(builder: _buildAppearances);

  Widget _buildAppearances(BuildContext context) {
    final scenario = widget.scenario;
    return ValueListenableBuilder(
      valueListenable: scenario.appearances,
      builder: (context, targets, _) => ValueListenableBuilder(
        valueListenable: scenario.revision,
        builder: (context, revision, _) => Stack(
          children: [
            for (final target in targets)
              Positioned(
                key: ObjectKey(target),
                left: scenario.names[target]!.codeUnitAt(0) * 2,
                top: 100,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MorphSibling(
                      target: target,
                      transitionBuilder: (child, curved, uncurved) {
                        scenario.progress[target] = (curved, uncurved);
                        return FadeTransition(opacity: uncurved, child: child);
                      },
                      child: Text('Header ${scenario.names[target]}'),
                    ),
                    Morph(
                      animateChildChanges: true,
                      target: target,
                      duration: const Duration(milliseconds: 400),
                      curve: scenario.curve,
                      onStart: () => scenario.started.add(scenario.names[target]!),
                      onReceived: () => scenario.received.add(scenario.names[target]!),
                      child: SizedBox(
                        key: ValueKey((target, revision)),
                        width: 100,
                        height: 100,
                        child: Text('${scenario.names[target]} $revision'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: .ltr,
    child: Overlay(initialEntries: [entry]),
  );
}
