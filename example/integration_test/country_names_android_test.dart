import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'when English fallback has accents, it should preserve its Unicode',
    (_) async {
      expect(
        Country.fromIso2('CI').displayName(const Locale('zzz')),
        'Côte d’Ivoire',
      );
    },
    skip: kIsWeb || defaultTargetPlatform != TargetPlatform.android,
  );
}
