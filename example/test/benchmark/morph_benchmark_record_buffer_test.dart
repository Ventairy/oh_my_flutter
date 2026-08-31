import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/morph/morph_benchmark_record_buffer.dart';

void main() {
  group('MorphBenchmarkRecordBuffer', () {
    test(
      'when a record is added, it should not emit before flushing',
      () {
        final emitted = <String>[];
        MorphBenchmarkRecordBuffer(emitted.add).add(
          <String, Object>{'path': 'environment'},
        );

        expect(emitted, isEmpty);
      },
    );

    test('when records are flushed, it should preserve their order', () {
      final emitted = <String>[];
      MorphBenchmarkRecordBuffer(emitted.add)
        ..add(<String, Object>{'path': 'first'})
        ..add(<String, Object>{'path': 'second'})
        ..flush();

      expect(emitted, <String>[
        'MORPH_BENCHMARK {"path":"first"}',
        'MORPH_BENCHMARK {"path":"second"}',
      ]);
    });

    test(
      'when records are flushed, it should release the pending batch',
      () {
        final buffer = MorphBenchmarkRecordBuffer((_) {})
          ..add(<String, Object>{'path': 'first'})
          ..flush();

        expect(buffer.pendingCount, 0);
      },
    );

    test(
      'when a record exceeds Android log limits, it should emit bounded chunks',
      () {
        final emitted = <String>[];
        MorphBenchmarkRecordBuffer(emitted.add)
          ..add(<String, Object>{
            'path': 'acceptance',
            'failed_steady_paths': List<String>.generate(
              100,
              (index) => 'scenario.steady.forward.trial_$index',
            ),
          })
          ..flush();

        expect(emitted.length, greaterThan(1));
        expect(
          emitted.every((line) => line.length <= 900),
          isTrue,
        );
        expect(
          emitted.every(
            (line) => line.startsWith('MORPH_BENCHMARK_CHUNK '),
          ),
          isTrue,
        );
      },
    );
  });
}
