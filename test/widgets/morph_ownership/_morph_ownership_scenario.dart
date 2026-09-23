part of '../morph_ownership_test.dart';

final class _MorphOwnershipScenario {
  new() {
    addTearDown(appearances.dispose);
    addTearDown(revision.dispose);
  }

  final a = Object();
  final b = Object();
  final c = Object();
  late final target = MorphTarget(tag: 'surface', duration: const Duration(milliseconds: 400), curve: Curves.linear);

  late final Map<Object, String> names = {a: 'A', b: 'B', c: 'C'};
  late final appearances = ValueNotifier<List<Object>>([a]);
  final ValueNotifier<int> revision = ValueNotifier(0);
  final started = <String>[];
  final received = <String>[];
  final progress = <MorphTarget, (Animation<double>, Animation<double>)>{};

  Widget get app => _MorphOwnershipApp(this);

  Map<String, (double, double)> get values => {
    for (final target in appearances.value)
      if (progress[target] case final animations?) names[target]!: (animations.$1.value, animations.$2.value),
  };

  Future<void> show(WidgetTester tester, List<Object> targets) async {
    appearances.value = targets;
    await tester.pumpAndSettle();
  }
}
