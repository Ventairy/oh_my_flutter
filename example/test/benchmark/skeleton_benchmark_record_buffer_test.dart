import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/skeleton/skeleton_benchmark_record_buffer.dart';

void main() {
  group('SkeletonBenchmarkRecordBuffer', () {
    test(
      'when a record is added, it should not emit before flushing',
      () {
        final emitted = <String>[];
        SkeletonBenchmarkRecordBuffer(emitted.add).add(
          <String, Object>{'path': 'environment'},
        );

        expect(emitted, isEmpty);
      },
    );

    test('when records are flushed, it should preserve their order', () {
      final emitted = <String>[];
      SkeletonBenchmarkRecordBuffer(emitted.add)
        ..add(<String, Object>{'path': 'first'})
        ..add(<String, Object>{'path': 'second'})
        ..flush();

      expect(emitted, <String>[
        'SKELETON_BENCHMARK {"path":"first"}',
        'SKELETON_BENCHMARK {"path":"second"}',
      ]);
    });

    test(
      'when a flushed buffer is flushed again, '
      'it should not emit a duplicate record',
      () {
        final emitted = <String>[];
        SkeletonBenchmarkRecordBuffer(emitted.add)
          ..add(<String, Object>{'path': 'environment'})
          ..flush()
          ..flush();

        expect(emitted, <String>[
          'SKELETON_BENCHMARK {"path":"environment"}',
        ]);
      },
    );

    test(
      'when a record exceeds Android log limits, '
      'it should emit bounded Skeleton chunks',
      () {
        final emitted = <String>[];
        SkeletonBenchmarkRecordBuffer(emitted.add)
          ..add(<String, Object>{
            'path': 'acceptance',
            'details': List<String>.filled(6000, 'x').join(),
          })
          ..flush();

        expect(
          emitted,
          everyElement(
            allOf(
              hasLength(lessThanOrEqualTo(3000)),
              startsWith('SKELETON_BENCHMARK_CHUNK '),
            ),
          ),
        );
      },
    );

    test(
      'when a record is chunked, '
      'it should emit the exact sequential chunk schema',
      () {
        final record = <String, Object>{
          'path': 'acceptance',
          'details': List<String>.filled(6000, 'x').join(),
        };
        final emitted = <String>[];
        SkeletonBenchmarkRecordBuffer(emitted.add)
          ..add(record)
          ..flush();
        const marker = 'SKELETON_BENCHMARK_CHUNK ';
        final chunks = emitted
            .map((line) {
              final Object? decoded = jsonDecode(
                line.substring(marker.length),
              );
              return decoded! as Map<String, Object?>;
            })
            .toList(growable: false);
        final count = chunks.length;
        final payloadParts = chunks.map((chunk) {
          return chunk['payload'];
        }).whereType<String>();
        final encodedPayload = payloadParts.join();
        final chunkKeys = chunks
            .map((chunk) {
              return chunk.keys.toList(growable: false);
            })
            .toList(growable: false);
        final recordIdentifiers = <Object?>[
          for (final chunk in chunks) chunk['record'],
        ];
        final indexes = <Object?>[
          for (final chunk in chunks) chunk['index'],
        ];
        final counts = <Object?>[
          for (final chunk in chunks) chunk['count'],
        ];

        expect(
          <String, Object?>{
            'keys': chunkKeys,
            'records': recordIdentifiers,
            'indexes': indexes,
            'counts': counts,
            'decoded': jsonDecode(
              utf8.decode(base64Decode(encodedPayload)),
            ),
          },
          <String, Object?>{
            'keys': List<List<String>>.generate(
              count,
              (_) => <String>['record', 'index', 'count', 'payload'],
            ),
            'records': List<int>.filled(count, 0),
            'indexes': List<int>.generate(count, (index) => index),
            'counts': List<int>.filled(count, count),
            'decoded': record,
          },
        );
      },
    );

    test(
      'when separate oversized records are flushed, '
      'it should assign distinct chunk record identifiers',
      () {
        final emitted = <String>[];
        final buffer = SkeletonBenchmarkRecordBuffer(emitted.add);
        for (final path in const <String>['first', 'second']) {
          buffer
            ..add(<String, Object>{
              'path': path,
              'details': List<String>.filled(6000, path).join(),
            })
            ..flush();
        }
        const marker = 'SKELETON_BENCHMARK_CHUNK ';
        final recordIdentifiers = emitted.map((line) {
          final Object? decoded = jsonDecode(
            line.substring(marker.length),
          );
          final chunk = decoded! as Map<String, Object?>;
          return chunk['record'];
        }).toSet();

        expect(recordIdentifiers, <Object?>{0, 1});
      },
    );
  });
}
