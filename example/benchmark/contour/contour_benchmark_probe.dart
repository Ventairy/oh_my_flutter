import 'package:flutter/rendering.dart';

import 'contour_benchmark_properties_builder.dart';

/// Reads optional render diagnostics without adding production observability.
class ContourBenchmarkProbe extends RenderProxyBox {
  static const _globalCounters = {
    'geometrySources',
    'geometrySourceBytes',
    'geometrySourceHits',
    'geometrySourceBuilds',
    'webActiveCount',
    'webQueuedPayloadBytes',
    'nativeTextCacheEntries',
    'nativeTextCacheBytes',
    'nativeMaskPictureEntries',
    'nativeMaskPictureBytes',
    'nativeMaskPictureBuildCount',
    'initialFrameFenceEpoch',
    'initialFrameFenceTargetFrame',
    'initialFrameFenceFallbackCount',
    'initialFrameFenceCount',
    'shadowPoolEntries',
    'shadowPoolPending',
    'shadowPoolPixels',
    'shadowPoolBuildCount',
    'shadowPoolReuseCount',
    'workBudgetActiveBytes',
    'workBudgetPeakBytes',
    'workBudgetPendingCount',
    'traceSharedScratchBytes',
    'traceScratchPeakBytes',
    'traceSourcePeakBytes',
    'traceSharedPeakSources',
    'traceSharedSources',
    'traceLegacySources',
    'traceConsumptionAcksPending',
    'traceNativeStarts',
    'traceNativeExits',
    'shadowAtlasQueuedJobs',
    'shadowAtlasActiveJobs',
    'shadowAtlasTransientPixels',
    'shadowAtlasSnapshotBytes',
  };
  static const _ownerCounters = {
    'captureCount',
    'traceCaptureCount',
    'proofCaptureCount',
    'geometryCapacityExceededCount',
    'nativeFillPainterCreations',
    'nativeFillLayoutBuilds',
    'nativeFillPaintUpdates',
    'nativeTextVerificationCount',
    'shadowCacheBuildCount',
    'shadowAtlasBuildCount',
    'shadowAtlasPaintCount',
  };
  static const _booleanStates = {
    'contourReady',
    'geometryCapacityExceeded',
    'generating',
    'nativeTextActive',
    'shadowCacheReady',
    'shadowAtlasActive',
    'shadowAtlasReady',
  };
  static const _globalValues = {'initialFrameFenceReady', 'initialFrameFenceReason'};

  /// Samples a contour's existing fields in profile mode as well as debug mode.
  Map<String, Object?> properties(RenderObject render) {
    final builder = ContourBenchmarkPropertiesBuilder();
    render.debugFillProperties(builder);
    return {
      for (final property in builder.properties)
        if (_globalCounters.contains(property.name) ||
            _globalValues.contains(property.name) ||
            _ownerCounters.contains(property.name) ||
            _booleanStates.contains(property.name) ||
            const {
              'firstPresentationFrameNumber',
              'firstPresentationHasContour',
              'lastMainCompositionFrameNumber',
              'lastMainCompositionHasContent',
              'lastMainCompositionHasContour',
              'nativeTextStatus',
              'geometryIdentity',
              'nativeMaskSourceId',
              'nativeMaskSourceBytes',
              'shadowResourceId',
              'shadowAtlasResourceId',
              'shadowAtlasMinimumAmount',
              'shadowAtlasMaximumAmount',
            }.contains(property.name))
          property.name!: property.value,
    };
  }

  /// Summarizes visible owners without repeating shared counters or source IDs.
  ///
  /// Missing optional properties stay absent. Process-wide counters use their
  /// maximum across sampled owners, while each contour's own work is summed.
  /// Current values do not become lifetime peaks through this aggregation.
  /// Shared nonnumeric states retain their distinct observed values once.
  Map<String, Object?> summarize(List<Map<String, Object?>> samples) => {
    'probe_version': 3,
    'observed_instances': samples.where((sample) => sample.containsKey('contourReady')).length,
    'ready_instances': samples.where((sample) => sample['contourReady'] == true).length,
    'captured_instances': samples.where((sample) => ((sample['captureCount'] as int?) ?? 0) > 0).length,
    'captures': _sum(samples, 'captureCount') ?? 0,
    'native_diagnostics_instances': samples.where((sample) => sample.containsKey('nativeTextActive')).length,
    'native_active_instances': samples.where((sample) => sample['nativeTextActive'] == true).length,
    'native_status_counts': _histogram(samples, 'nativeTextStatus'),
    'shadow_cache_ready_instances': samples.where((sample) => sample['shadowCacheReady'] == true).length,
    'shadow_cache_builds': _sum(samples, 'shadowCacheBuildCount') ?? 0,
    'unique_geometry_sources': samples
        .map((sample) => sample['geometryIdentity'])
        .whereType<int>()
        .where((id) => id != 0)
        .toSet()
        .length,
    'unique_native_sources': samples.map((sample) => sample['nativeMaskSourceId']).whereType<Object>().toSet().length,
    'unique_shadow_resources': samples
        .map((sample) => sample['shadowResourceId'])
        .whereType<int>()
        .where((id) => id != 0)
        .toSet()
        .length,
    'unique_atlas_resources': samples
        .map((sample) => sample['shadowAtlasResourceId'])
        .whereType<int>()
        .where((id) => id != 0)
        .toSet()
        .length,
    'global_max': {
      for (final field in _globalCounters)
        if (_maximum(samples, field) case final int value) field: value,
    },
    'global_values': {
      for (final field in _globalValues)
        if (samples.map((sample) => sample[field]).where((value) => value is bool || value is String).toSet()
            case final values when values.isNotEmpty)
          field: values.toList(),
    },
    'owner_totals': {
      for (final field in _ownerCounters)
        if (_sum(samples, field) case final int value) field: value,
    },
    'boolean_states': {
      for (final field in _booleanStates)
        if (samples.any((sample) => sample[field] is bool))
          field: {
            'true': samples.where((sample) => sample[field] == true).length,
            'false': samples.where((sample) => sample[field] == false).length,
          },
    },
  };

  int? _maximum(List<Map<String, Object?>> samples, String field) {
    int? maximum;
    for (final sample in samples) {
      if (sample[field] case final int value) {
        if (maximum == null || value > maximum) maximum = value;
      }
    }
    return maximum;
  }

  int? _sum(List<Map<String, Object?>> samples, String field) {
    int? sum;
    for (final sample in samples) {
      if (sample[field] case final int value) sum = (sum ?? 0) + value;
    }
    return sum;
  }

  Map<String, int> _histogram(List<Map<String, Object?>> samples, String field) {
    final counts = <String, int>{};
    for (final sample in samples) {
      if (sample[field] case final String value) {
        counts.update(value, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }
}
