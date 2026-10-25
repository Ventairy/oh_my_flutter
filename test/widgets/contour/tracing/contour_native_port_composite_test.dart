@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session.dart';

import 'contour_native_port_composite_test_support.dart';

void main() {
  final supported = ContourNativePortSession.isSupported;

  test(
    'when a decoration packet has transparent styling, it should omit every foreground pixel',
    () async {
      final session = ContourNativePortSession.create()!;
      addTearDown(session.close);
      final result = await ContourNativePortCompositeTestSupport.submit(session);
      expect((result.status, result.rgba.isNotEmpty, result.rgba.every((byte) => byte == 0)), (0, true, true));
    },
    skip: !supported,
  );

  for (final obsolete in [false, true]) {
    test(
      'when a packet appends the obsolete foreground flag $obsolete, it should reject it and retire safely',
      () async {
        final session = ContourNativePortSession.create()!;
        addTearDown(session.close);
        final invalid = await ContourNativePortCompositeTestSupport.submit(
          session,
          obsoleteForegroundField: obsolete,
        );
        final valid = await ContourNativePortCompositeTestSupport.submit(session);
        final stats = session.stats;
        expect(
          (invalid.status, invalid.rgba.isEmpty, valid.status, stats['jobs'], stats['active'], stats['heldBytes']),
          (2, true, 0, 0, 0, 0),
        );
      },
      skip: !supported,
    );
  }

  test('when a packet omits its worker count, it should reject it and retire safely', () async {
    final session = ContourNativePortSession.create()!;
    addTearDown(session.close);
    final invalid = await ContourNativePortCompositeTestSupport.submit(session, missingWorkers: true);
    final valid = await ContourNativePortCompositeTestSupport.submit(session);
    final stats = session.stats;
    expect(
      (invalid.status, invalid.rgba.isEmpty, valid.status, stats['jobs'], stats['active'], stats['heldBytes']),
      (2, true, 0, 0, 0, 0),
    );
  }, skip: !supported);

  test('when a composite descriptor is malformed, it should retire safely and admit a subsequent request', () async {
    final session = ContourNativePortSession.create()!;
    addTearDown(session.close);
    final invalid = await ContourNativePortCompositeTestSupport.submit(
      session,
      malformedDescriptor: true,
    );
    final valid = await ContourNativePortCompositeTestSupport.submit(session);
    final stats = session.stats;
    expect(
      (invalid.status, invalid.rgba.isEmpty, valid.status, stats['jobs'], stats['active'], stats['heldBytes']),
      (2, true, 0, 0, 0, 0),
    );
  }, skip: !supported);
  test(
    'when decoration sources differ only in RGB, it should share one placement without mutating or retaining input',
    () async {
      final session = ContourNativePortSession.create()!;
      addTearDown(session.close);
      final batch = ContourNativePortCompositeTestSupport.coloredBatch();
      final originalRgba = Uint8List.fromList(batch.rgba);
      final originalTiles = Float64List.fromList(batch.tiles);
      final result = await ContourNativePortCompositeTestSupport.submit(
        session,
        rgba: batch.rgba,
        width: batch.width,
        height: batch.height,
        tiles: batch.tiles,
      );
      await session.close();
      final stats = session.stats;
      expect(
        <Object?>[
          result.status,
          result.placements.length,
          ContourNativePortCompositeTestSupport.uniquePlacementCount(
            result.placements,
          ),
          batch.rgba,
          batch.tiles,
          stats['owners'],
          stats['jobs'],
          stats['active'],
          stats['heldBytes'],
        ],
        <Object?>[0, 40 * 6, 1, originalRgba, originalTiles, 0, 0, 0, 0],
      );
    },
    skip: !supported,
  );

  test(
    'when decoration alpha or style differs, it should allocate independent placements for each difference',
    () async {
      final session = ContourNativePortSession.create()!;
      addTearDown(session.close);
      final batch = ContourNativePortCompositeTestSupport.coloredBatch(
        differingAlphaAndStyle: true,
      );
      final result = await ContourNativePortCompositeTestSupport.submit(
        session,
        rgba: batch.rgba,
        width: batch.width,
        height: batch.height,
        tiles: batch.tiles,
      );
      expect(
        (
          result.status,
          result.placements.length,
          ContourNativePortCompositeTestSupport.uniquePlacementCount(
            result.placements,
          ),
        ),
        (0, 40 * 6, 3),
      );
    },
    skip: !supported,
  );

  test('when two workers prepare decorations, it should match the serial pixels and placements', () async {
    final session = ContourNativePortSession.create()!;
    addTearDown(session.close);
    final batch = ContourNativePortCompositeTestSupport.coloredBatch(differingAlphaAndStyle: true);
    final serial = await ContourNativePortCompositeTestSupport.submit(
      session,
      workers: 1,
      rgba: batch.rgba,
      width: batch.width,
      height: batch.height,
      tiles: batch.tiles,
    );
    final parallel = await ContourNativePortCompositeTestSupport.submit(
      session,
      rgba: batch.rgba,
      width: batch.width,
      height: batch.height,
      tiles: batch.tiles,
    );
    expect(
      <Object>[parallel.status, parallel.width, parallel.height, parallel.rgba, parallel.placements],
      <Object>[serial.status, serial.width, serial.height, serial.rgba, serial.placements],
    );
  }, skip: !supported);

  test(
    'when forty sources have equal alpha with different RGB, it should contain only the shared decoration colors',
    () async {
      final session = ContourNativePortSession.create()!;
      addTearDown(session.close);
      final batch = ContourNativePortCompositeTestSupport.coloredBatch();
      final result = await ContourNativePortCompositeTestSupport.submit(
        session,
        rgba: batch.rgba,
        width: batch.width,
        height: batch.height,
        tiles: batch.tiles,
      );
      final counts = ContourNativePortCompositeTestSupport.opaquePixelCounts(
        result.rgba,
      );
      expect(
        <Object>[
          result.status,
          result.placements.length,
          ContourNativePortCompositeTestSupport.uniquePlacementCount(
            result.placements,
          ),
          [for (final color in batch.colors) counts[color] ?? 0],
        ],
        <Object>[
          0,
          40 * 6,
          1,
          List<int>.filled(40, 0),
        ],
      );
    },
    skip: !supported,
  );
}
