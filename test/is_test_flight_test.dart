import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/gen/test_flight/test_flight.g.dart';
import 'package:oh_my_flutter/src/test_flight/test_flight_lookup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final confirmed in [true, false]) {
    test('when Apple reports $confirmed, it should retain that result', () async {
      var calls = 0;
      final lookup = TestFlightLookup(() async {
        calls++;
        return confirmed;
      });
      expect((await lookup.value, await lookup.value, calls), (confirmed, confirmed, 1));
    });
  }

  test('when reads overlap, it should share the pending lookup', () async {
    final pending = Completer<bool?>();
    final lookup = TestFlightLookup(() => pending.future);
    final first = lookup.value;
    final second = lookup.value;
    pending.complete(true);
    await first;
    expect(second, same(first));
  });

  test('when the source is temporarily unavailable, it should retry on the next read', () async {
    final answers = <bool?>[null, true].iterator;
    final lookup = TestFlightLookup(() async {
      answers.moveNext();
      return answers.current;
    });
    expect([await lookup.value, await lookup.value], [false, true]);
  });

  test('when the platform is unsupported, it should return false without a host call', () async {
    for (final platform in TargetPlatform.values.where((p) => kIsWeb || p != TargetPlatform.iOS)) {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(await isTestFlight, isFalse, reason: platform.name);
    }
  });

  test('when iOS confirms TestFlight, it should expose the result through the public getter', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.oh_my_flutter.TestFlightHostApi.checkTestFlight',
      TestFlightHostApi.pigeonChannelCodec,
    );
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockDecodedMessageHandler(channel, (_) async => [true]);
    addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
    expect(await isTestFlight, isTrue);
  }, skip: kIsWeb);
}
