import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_endpoint_context/_registration_delegate.dart';

void main() {
  late ValueNotifier<bool> expanded;
  late List<({MorphEndpointContext endpoint, Widget registered})> captures;

  setUp(() {
    expanded = ValueNotifier(false);
    captures = [];
  });

  tearDown(() => expanded.dispose());

  Future<void> startFlight(WidgetTester tester) async {
    final morphTarget1 = MorphTarget(tag: 'registration-api');
    final morphObserver1 = MorphNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [morphObserver1],
        home: ValueListenableBuilder<bool>(
          valueListenable: expanded,
          builder: (context, value, _) => Align(
            child: Morph(
              animateChildChanges: true,
              target: morphTarget1,
              duration: const Duration(seconds: 1),
              flightConfig: .custom(
                _RegistrationDelegate(
                  onRegister: (endpoint, registered) => captures.add((endpoint: endpoint, registered: registered)),
                ),
              ),
              child: SizedBox(
                key: ValueKey(value),
                width: value ? 120 : 80,
                height: 60,
                child: const Text('Live content'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expanded.value = true;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'when an endpoint registers live content, it should return a Widget that renders normally in the flight',
    (tester) async {
      await startFlight(tester);

      expect(
        (captures.isNotEmpty, find.text('Live content').evaluate().length, tester.takeException()),
        (true, 2, null),
      );
    },
  );

  testWidgets(
    'when registration is attempted after properties returns, it should explain the required capture phase',
    (tester) async {
      await startFlight(tester);

      expect(
        () => captures.last.endpoint.descendantWidget(const SizedBox.shrink()),
        throwsA(
          isA<AssertionError>().having(
            (error) => error.message.toString(),
            'message',
            contains('properties is running'),
          ),
        ),
      );
    },
  );

  testWidgets(
    'when a registered widget is rendered outside its flight, it should explain its associated flight requirement',
    (tester) async {
      final morphObserver1 = MorphNavigatorObserver();

      await startFlight(tester);
      await tester.pumpWidget(MaterialApp(navigatorObservers: [morphObserver1], home: captures.last.registered));

      expect(tester.takeException().toString(), contains('associated Morph flight'));
    },
  );
}
