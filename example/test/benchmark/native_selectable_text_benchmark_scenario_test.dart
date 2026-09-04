import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/native_selectable_text/scenario.dart';

void main() {
  group('NativeSelectableTextBenchmarkScenario', () {
    test(
      'when menu_idle is selected, it should open the menu without updates',
      () {
        final scenario = NativeSelectableTextBenchmarkScenario.parse(
          'menu_idle',
        );

        expect(
          (
            id: scenario.id,
            opensMenu: scenario.opensMenu,
            updatesSelection: scenario.updatesSelection,
          ),
          (id: 'menu_idle', opensMenu: true, updatesSelection: false),
        );
      },
    );

    test(
      'when existing CLI values are parsed, it should preserve their meaning',
      () {
        expect(
          <String, String>{
            for (final id in const <String>['scroll', 'selection'])
              id: NativeSelectableTextBenchmarkScenario.parse(id).id,
          },
          <String, String>{'scroll': 'scroll', 'selection': 'selection'},
        );
      },
    );
  });
}
