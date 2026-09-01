import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/interactive_swipe_dismiss/interactive_swipe_dismiss_benchmark_record_buffer.dart';

void main() {
  group('InteractiveSwipeDismissBenchmarkRecordBuffer', () {
    test(
      'when a record is added, it should not emit before flushing',
      () {
        final emitted = <String>[];
        InteractiveSwipeDismissBenchmarkRecordBuffer(emitted.add).add(
          <String, Object>{'path': 'environment'},
        );

        expect(emitted, isEmpty);
      },
    );

    test('when records are flushed, it should preserve their order', () {
      final emitted = <String>[];
      InteractiveSwipeDismissBenchmarkRecordBuffer(emitted.add)
        ..add(<String, Object>{'path': 'first'})
        ..add(<String, Object>{'path': 'second'})
        ..flush();
      const marker = InteractiveSwipeDismissBenchmarkRecordBuffer.recordMarker;

      expect(emitted, <String>[
        '$marker{"path":"first"}',
        '$marker{"path":"second"}',
      ]);
    });

    test(
      'when a flushed buffer is flushed again, '
      'it should not duplicate records',
      () {
        final emitted = <String>[];
        InteractiveSwipeDismissBenchmarkRecordBuffer(emitted.add)
          ..add(<String, Object>{'path': 'environment'})
          ..flush()
          ..flush();

        expect(emitted, hasLength(1));
      },
    );

    test(
      'when a record exceeds Android log limits, '
      'it should emit lines no longer than 900 characters',
      () {
        final emitted = <String>[];
        InteractiveSwipeDismissBenchmarkRecordBuffer(emitted.add)
          ..add(<String, Object>{
            'path': 'steady.trial_1',
            'details': List<String>.filled(6000, 'x').join(),
          })
          ..flush();

        expect(
          emitted,
          everyElement(
            allOf(
              hasLength(lessThanOrEqualTo(900)),
              startsWith(
                InteractiveSwipeDismissBenchmarkRecordBuffer.chunkMarker,
              ),
            ),
          ),
        );
      },
    );

    test(
      'when a record is chunked, it should preserve its exact JSON payload',
      () {
        final record = <String, Object>{
          'path': 'steady.trial_1',
          'details': List<String>.filled(6000, 'x').join(),
        };
        final emitted = <String>[];
        InteractiveSwipeDismissBenchmarkRecordBuffer(emitted.add)
          ..add(record)
          ..flush();
        final chunks = emitted
            .map((line) {
              final payload = line.substring(
                InteractiveSwipeDismissBenchmarkRecordBuffer.chunkMarker.length,
              );
              final Object? decoded = jsonDecode(payload);
              return decoded! as Map<String, Object?>;
            })
            .toList(growable: false);
        final payloads = chunks.map((chunk) => chunk['payload']);
        final encodedPayload = payloads.whereType<String>().join();

        expect(
          jsonDecode(utf8.decode(base64Decode(encodedPayload))),
          record,
        );
      },
    );

    test(
      'when separate oversized records flush, '
      'it should assign distinct chunk identifiers',
      () {
        final emitted = <String>[];
        final buffer = InteractiveSwipeDismissBenchmarkRecordBuffer(
          emitted.add,
        );
        for (final path in const <String>['first', 'second']) {
          buffer
            ..add(<String, Object>{
              'path': path,
              'details': List<String>.filled(6000, path).join(),
            })
            ..flush();
        }
        final recordIdentifiers = emitted.map((line) {
          final payload = line.substring(
            InteractiveSwipeDismissBenchmarkRecordBuffer.chunkMarker.length,
          );
          final Object? decoded = jsonDecode(payload);
          return (decoded! as Map<String, Object?>)['record'];
        }).toSet();

        expect(recordIdentifiers, <Object?>{0, 1});
      },
    );
  });
}
