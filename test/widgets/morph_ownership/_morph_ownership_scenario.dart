part of '../morph_ownership_test.dart';

final class _MorphOwnershipScenario {
  new({this.curve = Curves.linear}) {
    addTearDown(appearances.dispose);
    addTearDown(revision.dispose);
  }

  final Curve curve;
  final a = MorphTarget(tag: 'surface');
  final b = MorphTarget(tag: 'surface');
  final c = MorphTarget(tag: 'surface');
  late final Map<MorphTarget, String> names = {a: 'A', b: 'B', c: 'C'};
  late final appearances = ValueNotifier<List<MorphTarget>>([a]);
  final ValueNotifier<int> revision = ValueNotifier(0);
  final started = <String>[];
  final received = <String>[];
  final progress = <MorphTarget, (Animation<double>, Animation<double>)>{};

  Widget get app => _MorphOwnershipApp(this);

  Map<String, (double, double)> get values => {
    for (final target in appearances.value)
      if (progress[target] case final animations?) names[target]!: (animations.$1.value, animations.$2.value),
  };

  Future<void> show(WidgetTester tester, List<MorphTarget> targets) async {
    appearances.value = targets;
    await tester.pumpAndSettle();
  }
}
