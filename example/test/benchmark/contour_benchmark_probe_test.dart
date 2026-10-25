import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../../benchmark/contour/contour_benchmark_probe.dart';

void main() {
  late ContourBenchmarkProbe probe;
  setUp(() => probe = ContourBenchmarkProbe());
  tearDown(() => probe.dispose());

  test('when owners repeat shared counters, it should report their global maximum', () {
    final result = probe.summarize([
      {'nativeMaskPictureBuildCount': 7, 'shadowPoolReuseCount': 12, 'workBudgetPeakBytes': 4096},
      {'nativeMaskPictureBuildCount': 7, 'shadowPoolReuseCount': 12, 'workBudgetPeakBytes': 4096},
      {'nativeMaskPictureBuildCount': 8, 'shadowPoolReuseCount': 13, 'workBudgetPeakBytes': 8192},
    ]);

    expect(result['global_max'], {
      'nativeMaskPictureBuildCount': 8,
      'shadowPoolReuseCount': 13,
      'workBudgetPeakBytes': 8192,
    });
  });

  test('when geometry and web work is shared, it should report one global inventory', () {
    final result = probe.summarize([
      {'geometrySources': 2, 'geometrySourceHits': 78, 'webActiveCount': 2, 'webQueuedPayloadBytes': 8192},
      {'geometrySources': 2, 'geometrySourceHits': 78, 'webActiveCount': 2, 'webQueuedPayloadBytes': 8192},
    ]);

    expect(result['global_max'], {
      'geometrySources': 2,
      'geometrySourceHits': 78,
      'webActiveCount': 2,
      'webQueuedPayloadBytes': 8192,
    });
  });

  test('when owners share trace admission and lifecycle values, it should report their sampled maximum once', () {
    final result = probe.summarize([
      {
        'traceSharedScratchBytes': 100,
        'traceScratchPeakBytes': 200,
        'traceSourcePeakBytes': 300,
        'traceSharedPeakSources': 4,
        'traceSharedSources': 2,
        'traceLegacySources': 1,
        'traceConsumptionAcksPending': 2,
        'traceNativeStarts': 3,
        'traceNativeExits': 2,
      },
      {
        'traceSharedScratchBytes': 100,
        'traceScratchPeakBytes': 200,
        'traceSourcePeakBytes': 300,
        'traceSharedPeakSources': 4,
        'traceSharedSources': 2,
        'traceLegacySources': 1,
        'traceConsumptionAcksPending': 2,
        'traceNativeStarts': 3,
        'traceNativeExits': 2,
      },
      {
        'traceSharedScratchBytes': 0,
        'traceScratchPeakBytes': 250,
        'traceSourcePeakBytes': 350,
        'traceSharedPeakSources': 5,
        'traceSharedSources': 0,
        'traceLegacySources': 0,
        'traceConsumptionAcksPending': 0,
        'traceNativeStarts': 4,
        'traceNativeExits': 3,
      },
    ]);

    expect(result['global_max'], {
      'traceSharedScratchBytes': 100,
      'traceScratchPeakBytes': 250,
      'traceSourcePeakBytes': 350,
      'traceSharedPeakSources': 5,
      'traceSharedSources': 2,
      'traceLegacySources': 1,
      'traceConsumptionAcksPending': 2,
      'traceNativeStarts': 4,
      'traceNativeExits': 3,
    });
  });

  testWidgets('when the renderer exposes trace diagnostics, it should preserve them through the property allowlist', (
    tester,
  ) async {
    await tester.pumpWidget(const Contour(color: Color(0x00000000), child: SizedBox(width: 8, height: 8)));

    expect(
      probe.properties(tester.renderObject(find.byType(Contour))).keys,
      containsAll([
        'traceSharedScratchBytes',
        'traceScratchPeakBytes',
        'traceSourcePeakBytes',
        'traceSharedPeakSources',
        'traceSharedSources',
        'traceLegacySources',
        'traceConsumptionAcksPending',
        'traceNativeStarts',
        'traceNativeExits',
      ]),
    );
  });

  test('when work belongs to separate contours, it should sum the owner counters', () {
    final result = probe.summarize([
      {'captureCount': 2, 'shadowCacheBuildCount': 3, 'nativeTextVerificationCount': 1, 'nativeFillLayoutBuilds': 2},
      {'captureCount': 4, 'shadowCacheBuildCount': 5, 'nativeTextVerificationCount': 1, 'nativeFillLayoutBuilds': 3},
    ]);

    expect(result['owner_totals'], {
      'captureCount': 6,
      'nativeTextVerificationCount': 2,
      'nativeFillLayoutBuilds': 5,
      'shadowCacheBuildCount': 8,
    });
  });

  test('when sources use different native text paths, it should count their observed statuses', () {
    final result = probe.summarize([
      {'nativeTextStatus': 'accepted'},
      {'nativeTextStatus': 'accepted'},
      {'nativeTextStatus': 'checking'},
      {'contourReady': false},
    ]);

    expect(result['native_status_counts'], {'accepted': 2, 'checking': 1});
  });

  test('when tracing and proof both capture, it should preserve their split alongside the total', () {
    final result = probe.summarize([
      {'captureCount': 3, 'traceCaptureCount': 2, 'proofCaptureCount': 1},
      {'captureCount': 3, 'traceCaptureCount': 2, 'proofCaptureCount': 1},
    ]);

    expect(result['owner_totals'], {'captureCount': 6, 'traceCaptureCount': 4, 'proofCaptureCount': 2});
  });

  test('when owners repeat the frame fence counters, it should count the shared fence once', () {
    final result = probe.summarize([
      {
        'initialFrameFenceEpoch': 3,
        'initialFrameFenceTargetFrame': 88,
        'initialFrameFenceCount': 2,
        'initialFrameFenceFallbackCount': 1,
      },
      {
        'initialFrameFenceEpoch': 3,
        'initialFrameFenceTargetFrame': 88,
        'initialFrameFenceCount': 2,
        'initialFrameFenceFallbackCount': 1,
      },
      {
        'initialFrameFenceEpoch': 4,
        'initialFrameFenceTargetFrame': 90,
        'initialFrameFenceCount': 3,
        'initialFrameFenceFallbackCount': 2,
      },
    ]);

    expect(result['global_max'], {
      'initialFrameFenceEpoch': 4,
      'initialFrameFenceTargetFrame': 90,
      'initialFrameFenceFallbackCount': 2,
      'initialFrameFenceCount': 3,
    });
  });

  test('when owners share a raster fence result, it should report its actual state without repetition', () {
    final result = probe.summarize([
      {'initialFrameFenceReady': true, 'initialFrameFenceReason': 'raster'},
      {'initialFrameFenceReady': true, 'initialFrameFenceReason': 'raster'},
    ]);

    expect(result['global_values'], {
      'initialFrameFenceReady': [true],
      'initialFrameFenceReason': ['raster'],
    });
  });

  test('when the fence uses a fallback, it should preserve that reason rather than imply a raster match', () {
    final result = probe.summarize([
      {'initialFrameFenceReady': true, 'initialFrameFenceReason': 'timingsUnavailable'},
      {'initialFrameFenceReady': true, 'initialFrameFenceReason': 'timingsUnavailable'},
    ]);

    expect(result['global_values'], {
      'initialFrameFenceReady': [true],
      'initialFrameFenceReason': ['timingsUnavailable'],
    });
  });

  test('when an older renderer has no frame fence, it should leave its shared state absent', () {
    final result = probe.summarize([
      {'captureCount': 1, 'contourReady': true},
    ]);

    expect(result['global_values'], <String, Object?>{});
  });

  test('when source IDs are opaque, it should count reuse without serializing them', () {
    final shared = Object();
    final result = probe.summarize([
      {'nativeMaskSourceId': shared},
      {'nativeMaskSourceId': shared},
      {'nativeMaskSourceId': Object()},
    ]);

    expect((jsonDecode(jsonEncode(result)) as Map<String, Object?>)['unique_native_sources'], 2);
  });

  test('when an old baseline lacks optional counters, it should leave them absent', () {
    final result = probe.summarize([
      {'captureCount': 1, 'contourReady': true},
    ]);

    expect(
      {'global_max': result['global_max'], 'native_instances': result['native_diagnostics_instances']},
      {'global_max': <String, Object?>{}, 'native_instances': 0},
    );
  });

  test('when resources are shared, it should count distinct nonzero resources', () {
    final result = probe.summarize([
      {'shadowResourceId': 0},
      {'shadowResourceId': 12},
      {'shadowResourceId': 12},
      {'shadowResourceId': 13},
    ]);

    expect(result['unique_shadow_resources'], 2);
  });

  test('when thousands of owners repeat diagnostics, it should keep output bounded', () {
    final result = probe.summarize(
      List.generate(
        4000,
        (_) => {'nativeTextActive': true, 'nativeTextStatus': 'accepted', 'nativeTextCacheEntries': 2},
      ),
    );

    expect(jsonEncode(result).length, lessThan(8192));
  });
}
