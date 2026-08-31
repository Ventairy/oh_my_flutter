part of '../device_display_model.dart';

final class _DeviceDisplayModelTrainer {
  final _algorithms = _DeviceDisplayModelAlgorithms();
  final _disagreementCalibrationCache = <String, Map<String, Object?>>{};
  final _featureSchemaCache = <String, Map<String, Object?>>{};
  final _gateFitCache = <String, Map<String, Object?>>{};
  final _headFitCache = <String, Map<String, Object?>>{};
  final _priorCandidateCache = <String, String>{};
  final _supportCalibrationCache =
      <
        String,
        ({
          double modelBlendWeight,
          double distanceTransitionScale,
          double disagreementTransitionScale,
          List<String> innerPriorCandidates,
        })
      >{};

  Map<String, Object?> train(Map<String, Object?> corpus) {
    final records = (corpus['records']! as List<Object?>).map((value) => value! as Map<String, Object?>).toList();
    return <String, Object?>{
      'schemaVersion': 2,
      'artifactVersion': 'geometry-ensemble-v2',
      'corpusFingerprint': DeviceDisplayModelEncoding.fingerprint(records),
      'targetDefinition': 'two_times_radius_over_shortest_physical_display_side',
      'safeInsetBaseline': <String, Object?>{
        'multiplier': 0.9,
        'provenance': 'https://github.com/flutter/flutter/blob/3.47.1/packages/flutter/lib/src/cupertino/sheet.dart',
      },
      'platforms': <String, Object?>{
        'android': _trainPlatform(
          records.where((record) => record['platform'] == 'android').toList(),
          platform: 'android',
        ),
        'ios': _trainPlatform(
          records.where((record) => record['platform'] == 'ios').toList(),
          platform: 'ios',
        ),
      },
    };
  }

  Map<String, Object?> _trainPlatform(
    List<Map<String, Object?>> records, {
    required String platform,
  }) {
    final logicalScoringRecords = records
        .where(
          (record) => (record['devicePixelRatio'] as num?)?.toDouble().isFinite == true,
        )
        .toList();
    final groups = _groups(records);
    final classification = _classification(records, platform: platform);
    final definitions = _candidateDefinitions();
    if (groups.length < 2 || logicalScoringRecords.isEmpty) {
      return _sparsePlatformResult(
        records: records,
        logicalScoringRecords: logicalScoringRecords,
        groups: groups,
        platform: platform,
        classification: classification,
        definitions: definitions,
      );
    }

    final scores = <Map<String, Object?>>[];
    for (final definition in definitions) {
      final candidate = definition['name']! as String;
      final challengerCandidate = _candidateChallenger(candidate);
      final minimumGroups = definition['minimumGroups']! as int;
      if (groups.length < minimumGroups) {
        scores.add(<String, Object?>{
          'candidate': candidate,
          'eligible': false,
          'role': definition['role'],
          'selectionEligible': definition['selectionEligible'],
          'minimumValidationGroups': minimumGroups,
          'generatedModelBytes': null,
          'inferenceOperationCount': definition['inferenceOperationCount'],
          'ineligibilityReason':
              'Requires at least $minimumGroups independent '
              'leakage groups; ${groups.length} were available.',
        });
        continue;
      }
      scores.add(<String, Object?>{
        ..._crossValidate(
          groups,
          candidate: candidate,
          challengerCandidate: challengerCandidate,
          platform: platform,
        ),
        'eligible': true,
        'role': definition['role'],
        'selectionEligible': definition['selectionEligible'],
        'minimumValidationGroups': minimumGroups,
      });
    }
    final eligibleScores = scores
        .where(
          (score) => score['eligible'] == true && score['selectionEligible'] == true,
        )
        .toList();
    final candidateOrder = <String>[
      for (final definition in definitions) definition['name']! as String,
    ];
    eligibleScores.sort(
      (left, right) => _compareScores(left, right, candidateOrder),
    );
    final winner = eligibleScores.first['candidate']! as String;
    final challenger = eligibleScores.first['challengerCandidate'] as String?;
    final usesSafetyPipeline =
        eligibleScores.first['scoringPipeline'] == 'fold_local_distance_disagreement_gate_prior_v1';
    final selectedScore = eligibleScores.first;
    final rows = groups.values.toList();
    final fittedHeads = _fitHeads(
      rows,
      candidate: winner,
      platform: platform,
      positiveOnly: usesSafetyPipeline,
    );
    final priorCandidate = selectedScore['robustPriorCandidate']! as String;
    final priorHeads = _fitHeads(
      rows,
      candidate: priorCandidate,
      platform: platform,
      positiveOnly: false,
    );
    final schema = _fitFeatureSchema(rows);
    final disagreement = usesSafetyPipeline
        ? _disagreementCalibration(
            groups,
            selectedCandidate: winner,
            challengerCandidate: challenger!,
            platform: platform,
          )
        : <String, Object?>{
            'available': false,
            'reason': 'The selected literal baseline does not use a challenger.',
          };
    final challengerHeads = usesSafetyPipeline && disagreement['available'] == true
        ? _fitHeads(
            rows,
            candidate: challenger!,
            platform: platform,
          )
        : null;
    final legacyTop = fittedHeads[platform == 'ios' ? 'common' : 'top']! as Map<String, Object?>;
    final legacyBottom = fittedHeads[platform == 'ios' ? 'common' : 'bottom']! as Map<String, Object?>;

    return <String, Object?>{
      'labeledRecordCount': records.length,
      'logicalScoringRecordCount': logicalScoringRecords.length,
      'validationGroupCount': groups.length,
      'selectedCandidate': winner,
      'challengerCandidate': challenger,
      'predictionPipeline': usesSafetyPipeline ? 'distance_disagreement_gate_prior_v1' : 'raw_bounded_formula_v1',
      'isFitted': winner != 'zero_baseline' && winner != 'safe_inset_baseline',
      'intercept': _legacyIntercept(legacyTop),
      'aspectSlope': _legacyAspectSlope(legacyTop),
      'topIntercept': _legacyIntercept(legacyTop),
      'topAspectSlope': _legacyAspectSlope(legacyTop),
      'bottomIntercept': _legacyIntercept(legacyBottom),
      'bottomAspectSlope': _legacyAspectSlope(legacyBottom),
      'headModels': fittedHeads,
      'challengerHeadModels': challengerHeads,
      'prior': <String, Object?>{
        'kind': 'grouped_oof_selected_literal_baseline',
        'candidate': priorCandidate,
        'headModels': priorHeads,
      },
      'featureSchema': schema,
      'support': <String, Object?>{
        'distanceInner': schema['distanceInner'],
        'distanceOuter': schema['distanceOuter'],
        'modelBlendWeight': selectedScore['modelBlendWeight'],
        'distanceTransitionScale': selectedScore['distanceTransitionScale'],
        'disagreementTransitionScale': selectedScore['disagreementTransitionScale'],
        'innerPriorCandidates': selectedScore['innerPriorCandidates'],
      },
      'disagreement': disagreement,
      'candidateScores': scores,
      'validation': selectedScore,
      'collisionLowerBound': _collisionLowerBound(records),
      'classification': classification,
      'holdouts': _holdoutResults(
        groups,
        selectedScore: selectedScore,
      ),
      'selectionOrder': const <String>[
        'worstRegimeBootstrapUpperLogicalP95',
        'worstRegimeMacroLogicalPixelMae',
        'logicalPixelMaximumAbsoluteError',
        'generatedModelBytes',
        'inferenceOperationCount',
        'candidateOrder',
      ],
      'limitation': platform == 'android'
          ? 'Independent leakage groups merge anonymized family and complete '
                'runtime-observable geometry collisions.'
          : 'Only exact public-API or excluded tool-only selector labels are accepted.',
    };
  }

  Map<String, Object?> _sparsePlatformResult({
    required List<Map<String, Object?>> records,
    required List<Map<String, Object?>> logicalScoringRecords,
    required Map<String, Map<String, Object?>> groups,
    required String platform,
    required Map<String, Object?> classification,
    required List<Map<String, Object?>> definitions,
  }) {
    final rows = groups.values.toList();
    final heads = rows.isEmpty
        ? <String, Object?>{}
        : _fitHeads(
            rows,
            candidate: 'safe_inset_baseline',
            platform: platform,
          );
    return <String, Object?>{
      'labeledRecordCount': records.length,
      'logicalScoringRecordCount': logicalScoringRecords.length,
      'validationGroupCount': groups.length,
      'selectedCandidate': 'safe_inset_baseline',
      'challengerCandidate': null,
      'predictionPipeline': 'raw_bounded_formula_v1',
      'isFitted': false,
      'intercept': 0.0,
      'aspectSlope': 0.0,
      'topIntercept': 0.0,
      'topAspectSlope': 0.0,
      'bottomIntercept': 0.0,
      'bottomAspectSlope': 0.0,
      'headModels': heads,
      'challengerHeadModels': null,
      'prior': rows.isEmpty
          ? <String, Object?>{
              'kind': 'safe_inset_baseline',
              'headModels': <String, Object?>{},
            }
          : <String, Object?>{
              'kind': 'median_positive_normalized_diameter',
              'headModels': _fitHeads(
                rows,
                candidate: 'median_normalized_diameter',
                platform: platform,
              ),
            },
      'featureSchema': null,
      'support': null,
      'disagreement': <String, Object?>{
        'available': false,
        'reason': 'Fewer than two independent logical-pixel groups were available.',
      },
      'candidateScores': <Object?>[
        for (final definition in definitions)
          <String, Object?>{
            'candidate': definition['name'],
            'eligible': false,
            'role': definition['role'],
            'selectionEligible': definition['selectionEligible'],
            'minimumValidationGroups': definition['minimumGroups'],
            'generatedModelBytes': null,
            'inferenceOperationCount': definition['inferenceOperationCount'],
            'ineligibilityReason': logicalScoringRecords.isEmpty
                ? 'No DPR-known observation was available for logical-pixel validation.'
                : 'Requires at least '
                      '${definition['minimumGroups']} independent leakage groups; '
                      '${groups.length} were available.',
          },
      ],
      'validation': null,
      'collisionLowerBound': _collisionLowerBound(records),
      'classification': classification,
      'holdouts': _holdoutResults(groups, selectedScore: null),
      'selectionOrder': const <String>[
        'worstRegimeBootstrapUpperLogicalP95',
        'worstRegimeMacroLogicalPixelMae',
        'logicalPixelMaximumAbsoluteError',
        'generatedModelBytes',
        'inferenceOperationCount',
        'candidateOrder',
      ],
      'limitation': logicalScoringRecords.isEmpty
          ? 'No DPR-known observation was available for logical-pixel validation.'
          : 'Fewer than two independent leakage groups were available.',
    };
  }

  List<Map<String, Object?>> _candidateDefinitions() => const [
    <String, Object?>{
      'name': 'zero_baseline',
      'minimumGroups': 2,
      'inferenceOperationCount': 0,
      'role': 'comparison baseline',
      'selectionEligible': false,
    },
    <String, Object?>{
      'name': 'safe_inset_baseline',
      'minimumGroups': 2,
      'inferenceOperationCount': 1,
      'role': 'comparison baseline',
      'selectionEligible': false,
    },
    <String, Object?>{
      'name': 'platform_median_logical_radius',
      'minimumGroups': 2,
      'inferenceOperationCount': 3,
      'role': 'comparison baseline',
      'selectionEligible': false,
    },
    <String, Object?>{
      'name': 'shortest_side_formula',
      'minimumGroups': 2,
      'inferenceOperationCount': 1,
      'role': 'comparison baseline',
      'selectionEligible': false,
    },
    <String, Object?>{
      'name': 'robust_quadratic_regression',
      'minimumGroups': 2,
      'inferenceOperationCount': 72,
      'role': 'structured candidate',
      'selectionEligible': true,
    },
    <String, Object?>{
      'name': 'spline_gam',
      'minimumGroups': 2,
      'inferenceOperationCount': 108,
      'role': 'structured candidate',
      'selectionEligible': true,
    },
    <String, Object?>{
      'name': 'shallow_boosted_tree',
      'minimumGroups': 2,
      'inferenceOperationCount': 48,
      'role': 'structured candidate',
      'selectionEligible': true,
    },
    <String, Object?>{
      'name': 'constrained_blend',
      'minimumGroups': 2,
      'inferenceOperationCount': 159,
      'role': 'structured candidate',
      'selectionEligible': true,
    },
  ];

  Map<String, Map<String, Object?>> _groups(
    List<Map<String, Object?>> records,
  ) {
    final parents = List<int>.generate(records.length, (index) => index);
    for (var left = 0; left < records.length; left += 1) {
      for (var right = left + 1; right < records.length; right += 1) {
        final sameFamily = _sameNonNullHash(
          records[left],
          records[right],
          'familyGroupHash',
        );
        final sameMask = _sameNonNullHash(
          records[left],
          records[right],
          'maskCollisionGroupHash',
        );
        final leftObservable =
            records[left]['observableCollisionGroupHash'] ??
            records[left]['geometryCollisionGroupHash'] ??
            records[left]['validationGroup'];
        final rightObservable =
            records[right]['observableCollisionGroupHash'] ??
            records[right]['geometryCollisionGroupHash'] ??
            records[right]['validationGroup'];
        final sameObservable = leftObservable != null && leftObservable == rightObservable;
        final sameGeometry = _sameNonNullHash(
          records[left],
          records[right],
          'geometryCollisionGroupHash',
        );
        if (sameFamily || sameMask || sameObservable || sameGeometry) {
          _union(parents, left, right);
        }
      }
    }
    final recordsByGroup = <String, List<Map<String, Object?>>>{};
    for (var index = 0; index < records.length; index += 1) {
      final group = _find(parents, index).toString();
      recordsByGroup.putIfAbsent(group, () => []).add(records[index]);
    }
    return <String, Map<String, Object?>>{
      for (final entry in recordsByGroup.entries)
        entry.key: <String, Object?>{
          ..._group(entry.value),
          'groupKey': entry.key,
        },
    };
  }

  bool _sameNonNullHash(
    Map<String, Object?> left,
    Map<String, Object?> right,
    String key,
  ) => left[key] != null && left[key] == right[key];

  int _find(List<int> parents, int index) {
    var root = index;
    while (parents[root] != root) {
      root = parents[root];
    }
    var current = index;
    while (parents[current] != current) {
      final next = parents[current];
      parents[current] = root;
      current = next;
    }
    return root;
  }

  void _union(List<int> parents, int left, int right) {
    final leftRoot = _find(parents, left);
    final rightRoot = _find(parents, right);
    if (leftRoot != rightRoot) {
      parents[rightRoot] = leftRoot;
    }
  }

  Map<String, Object?> _group(List<Map<String, Object?>> records) {
    final topRadii = <double>[];
    final bottomRadii = <double>[];
    final commonInsets = <double>[];
    final topInsets = <double>[];
    final bottomInsets = <double>[];
    final literalCommonInsets = <double>[];
    final literalTopInsets = <double>[];
    final literalBottomInsets = <double>[];
    final logicalScales = <double?>[];
    final featureRows = <List<double>>[];
    final observations = <Map<String, Object?>>[];
    for (final record in records) {
      final shortSide = math.min(
        (record['physicalWidth']! as num).toDouble(),
        (record['physicalHeight']! as num).toDouble(),
      );
      final topDiameter = 2 * (record['topRadiusPhysical']! as num).toDouble() / shortSide;
      final bottomDiameter = 2 * (record['bottomRadiusPhysical']! as num).toDouble() / shortSide;
      if (!topDiameter.isFinite ||
          !bottomDiameter.isFinite ||
          topDiameter < 0 ||
          bottomDiameter < 0 ||
          topDiameter > 1 ||
          bottomDiameter > 1) {
        throw const FormatException(
          'Corner-radius labels must fit within half the shortest display side.',
        );
      }
      topRadii.add(topDiameter);
      bottomRadii.add(bottomDiameter);
      final density = (record['devicePixelRatio'] as num?)?.toDouble();
      logicalScales.add(density == null ? null : shortSide / density / 2);
      final width = (record['physicalWidth']! as num).toDouble();
      final height = (record['physicalHeight']! as num).toDouble();
      final paddingLeft = (record['viewPaddingLeftPhysical'] as num?)?.toDouble() ?? 0;
      final paddingTop = (record['viewPaddingTopPhysical'] as num?)?.toDouble() ?? 0;
      final paddingRight = (record['viewPaddingRightPhysical'] as num?)?.toDouble() ?? 0;
      final paddingBottom = (record['viewPaddingBottomPhysical'] as num?)?.toDouble() ?? 0;
      final isLandscape = width > height;
      final leadingPadding = isLandscape ? paddingLeft : paddingTop;
      final trailingPadding = isLandscape ? paddingRight : paddingBottom;
      final runtimeNaturalTopPadding = record['platform'] == 'ios'
          ? math.max(leadingPadding, trailingPadding)
          : leadingPadding;
      double safeInset(double padding) {
        final logicalRadius = density == null ? 0.0 : padding * 0.9 / density;
        return logicalRadius > 20 ? 2 * padding * 0.9 / shortSide : 0.0;
      }

      final runtimeInset = safeInset(runtimeNaturalTopPadding);
      final literalFlutterSheetInset = safeInset(paddingTop);
      final commonInset = runtimeInset;
      final topInset = runtimeInset;
      final bottomInset = runtimeInset;
      commonInsets.add(commonInset);
      topInsets.add(topInset);
      bottomInsets.add(bottomInset);
      literalCommonInsets.add(literalFlutterSheetInset);
      literalTopInsets.add(literalFlutterSheetInset);
      literalBottomInsets.add(literalFlutterSheetInset);
      final features = _algorithms.features(record);
      featureRows.add(features);
      observations.add(<String, Object?>{
        'features': features,
        'target': _median(<double>[topDiameter, bottomDiameter]),
        'topTarget': topDiameter,
        'bottomTarget': bottomDiameter,
        'roundedTarget': topDiameter > 0 || bottomDiameter > 0 ? 1.0 : 0.0,
        'roundedTopTarget': topDiameter > 0 ? 1.0 : 0.0,
        'roundedBottomTarget': bottomDiameter > 0 ? 1.0 : 0.0,
        'safeInsetPrediction': commonInset,
        'safeInsetTopPrediction': topInset,
        'safeInsetBottomPrediction': bottomInset,
        'literalSafeInsetPrediction': literalFlutterSheetInset,
        'literalSafeInsetTopPrediction': literalFlutterSheetInset,
        'literalSafeInsetBottomPrediction': literalFlutterSheetInset,
        'logicalRadiusScale': density == null ? null : shortSide / density / 2,
        'oemGroupHash': record['oemGroupHash'],
        'generationGroupHash': record['generationGroupHash'],
        'chronologyRank': (record['chronologyRank'] as num?)?.toDouble(),
      });
    }
    final combined = <double>[...topRadii, ...bottomRadii];
    final features = <double>[
      for (var index = 0; index < _DeviceDisplayModelAlgorithms.featureNames.length; index += 1)
        _median(featureRows.map((row) => row[index]).toList()),
    ];
    return <String, Object?>{
      'features': features,
      'target': _median(combined),
      'topTarget': _median(topRadii),
      'bottomTarget': _median(bottomRadii),
      'roundedTarget': combined.any((value) => value > 0) ? 1.0 : 0.0,
      'roundedTopTarget': topRadii.any((value) => value > 0) ? 1.0 : 0.0,
      'roundedBottomTarget': bottomRadii.any((value) => value > 0) ? 1.0 : 0.0,
      'safeInsetPrediction': _median(commonInsets),
      'safeInsetTopPrediction': _median(topInsets),
      'safeInsetBottomPrediction': _median(bottomInsets),
      'literalSafeInsetPrediction': _median(literalCommonInsets),
      'literalSafeInsetTopPrediction': _median(literalTopInsets),
      'literalSafeInsetBottomPrediction': _median(literalBottomInsets),
      'observations': observations,
      'topObservations': topRadii,
      'bottomObservations': bottomRadii,
      'logicalRadiusScales': logicalScales,
      'logicalRadiusScale': logicalScales.whereType<double>().isEmpty
          ? null
          : _median(logicalScales.whereType<double>().toList()),
      'oemGroups': records.map((record) => record['oemGroupHash']).whereType<String>().toSet().toList()..sort(),
      'generationGroups': records.map((record) => record['generationGroupHash']).whereType<String>().toSet().toList()
        ..sort(),
      'chronologyRanks':
          records.map((record) => (record['chronologyRank'] as num?)?.toDouble()).whereType<double>().toSet().toList()
            ..sort(),
      'oemMetadataComplete': records.every(
        (record) => record['oemGroupHash'] is String,
      ),
      'generationMetadataComplete': records.every(
        (record) => record['generationGroupHash'] is String,
      ),
      'chronologyMetadataComplete': records.every(
        (record) => record['chronologyRank'] is num,
      ),
    };
  }

  List<Map<String, Object?>> _featureRows(
    List<Map<String, Object?>> groups,
  ) {
    final rows = <Map<String, Object?>>[];
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex += 1) {
      final observations = (groups[groupIndex]['observations']! as List<Object?>).cast<Map<String, Object?>>();
      final weight = 1 / observations.length;
      for (final observation in observations) {
        rows.add(<String, Object?>{
          ...observation,
          'fitWeight': weight,
          'fitGroupId': groupIndex,
        });
      }
    }
    return rows;
  }

  List<Map<String, Object?>> _headRows(
    List<Map<String, Object?>> groups, {
    required String platform,
    required String head,
    required bool positiveOnly,
  }) {
    final rows = <Map<String, Object?>>[];
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex += 1) {
      final observations = (groups[groupIndex]['observations']! as List<Object?>).cast<Map<String, Object?>>();
      final groupRows = <Map<String, Object?>>[];
      for (final observation in observations) {
        void addEdge(String targetKey, String roundedKey, String safeInsetKey) {
          final target = observation[targetKey]! as double;
          if (positiveOnly && target <= 0) {
            return;
          }
          groupRows.add(<String, Object?>{
            ...observation,
            'fitTarget': target,
            'fitRoundedTarget': observation[roundedKey],
            'safeInsetPrediction': observation[safeInsetKey],
            'fitGroupId': groupIndex,
          });
        }

        if (platform == 'ios') {
          addEdge(
            'topTarget',
            'roundedTopTarget',
            'safeInsetPrediction',
          );
          addEdge(
            'bottomTarget',
            'roundedBottomTarget',
            'safeInsetPrediction',
          );
        } else if (head == 'top') {
          addEdge(
            'topTarget',
            'roundedTopTarget',
            'safeInsetTopPrediction',
          );
        } else {
          addEdge(
            'bottomTarget',
            'roundedBottomTarget',
            'safeInsetBottomPrediction',
          );
        }
      }
      if (groupRows.isEmpty) {
        continue;
      }
      final weight = 1 / groupRows.length;
      rows.addAll(<Map<String, Object?>>[
        for (final row in groupRows)
          <String, Object?>{
            ...row,
            'fitWeight': weight,
          },
      ]);
    }
    return rows;
  }

  Map<String, Object?> _crossValidate(
    Map<String, Map<String, Object?>> groups, {
    required String candidate,
    required String challengerCandidate,
    required String platform,
  }) {
    final applySafetyPipeline = !_isComparisonBaseline(candidate);
    final family = _evaluateFolds(
      groups,
      folds: <Set<String>>[
        for (final key in groups.keys) <String>{key},
      ],
      candidate: candidate,
      challengerCandidate: challengerCandidate,
      platform: platform,
      applySafetyPipeline: applySafetyPipeline,
    );
    if (family == null) {
      throw const FormatException(
        'At least one DPR-known held-out observation is required.',
      );
    }
    final regimes = <String, Map<String, Object?>>{
      'family': family,
    };
    final oemFolds = _metadataFolds(
      groups,
      key: 'oemGroups',
      minimumDistinctValues: 2,
    );
    if (oemFolds != null) {
      final metrics = _evaluateFolds(
        groups,
        folds: <Set<String>>[
          for (final fold in oemFolds.folds) fold.heldOut,
        ],
        heldOutObservationFilters: <({String key, Object value})?>[
          for (final fold in oemFolds.folds) (key: 'oemGroupHash', value: fold.targetValue),
        ],
        eligibleObservationMetadataKey: 'oemGroupHash',
        eligibleGroupKeys: oemFolds.eligibleGroupKeys,
        candidate: candidate,
        challengerCandidate: challengerCandidate,
        platform: platform,
        applySafetyPipeline: applySafetyPipeline,
      );
      if (metrics != null) {
        regimes['leaveOemOut'] = <String, Object?>{
          ...metrics,
          'metadataEligibleGroupCount': oemFolds.eligibleGroupKeys.length,
          'metadataExcludedGroupCount': oemFolds.excludedGroupCount,
        };
      }
    }
    final generationFolds = _metadataFolds(
      groups,
      key: 'generationGroups',
      minimumDistinctValues: 2,
    );
    if (generationFolds != null) {
      final metrics = _evaluateFolds(
        groups,
        folds: <Set<String>>[
          for (final fold in generationFolds.folds) fold.heldOut,
        ],
        heldOutObservationFilters: <({String key, Object value})?>[
          for (final fold in generationFolds.folds) (key: 'generationGroupHash', value: fold.targetValue),
        ],
        eligibleObservationMetadataKey: 'generationGroupHash',
        eligibleGroupKeys: generationFolds.eligibleGroupKeys,
        candidate: candidate,
        challengerCandidate: challengerCandidate,
        platform: platform,
        applySafetyPipeline: applySafetyPipeline,
      );
      if (metrics != null) {
        regimes['leaveGenerationOut'] = <String, Object?>{
          ...metrics,
          'metadataEligibleGroupCount': generationFolds.eligibleGroupKeys.length,
          'metadataExcludedGroupCount': generationFolds.excludedGroupCount,
        };
      }
    }
    final newest = _newestFold(groups);
    if (newest != null) {
      final metrics = _evaluateFolds(
        groups,
        folds: <Set<String>>[newest.heldOut],
        heldOutObservationFilters: <({String key, Object value})?>[
          (key: 'chronologyRank', value: newest.targetRank),
        ],
        eligibleObservationMetadataKey: 'chronologyRank',
        eligibleGroupKeys: newest.eligibleGroupKeys,
        candidate: candidate,
        challengerCandidate: challengerCandidate,
        platform: platform,
        applySafetyPipeline: applySafetyPipeline,
      );
      if (metrics != null) {
        regimes['newestGeneration'] = <String, Object?>{
          ...metrics,
          'metadataEligibleGroupCount': newest.eligibleGroupKeys.length,
          'metadataExcludedGroupCount': newest.excludedGroupCount,
        };
      }
    }
    final payload = _fitHeads(
      groups.values.toList(),
      candidate: candidate,
      platform: platform,
      positiveOnly: applySafetyPipeline,
    );
    final challengerPayload = applySafetyPipeline
        ? _fitHeads(
            groups.values.toList(),
            candidate: challengerCandidate,
            platform: platform,
          )
        : null;
    final robustPrior = applySafetyPipeline ? _fitRobustPrior(groups, platform: platform) : null;
    final priorPayload = robustPrior?.headModels;
    final gates = applySafetyPipeline
        ? _fitGateHeads(
            groups.values.toList(),
            platform: platform,
          )
        : null;
    final schema = applySafetyPipeline ? _fitFeatureSchema(groups.values.toList()) : null;
    final disagreement = applySafetyPipeline
        ? _disagreementCalibration(
            groups,
            selectedCandidate: candidate,
            challengerCandidate: challengerCandidate,
            platform: platform,
          )
        : <String, Object?>{
            'available': false,
            'reason': 'Literal baseline alternatives do not use a challenger.',
          };
    final supportCalibration = applySafetyPipeline
        ? _calibrateSafetySupport(
            groups,
            selectedCandidate: candidate,
            challengerCandidate: challengerCandidate,
            platform: platform,
          )
        : (
            modelBlendWeight: 1.0,
            distanceTransitionScale: 1.0,
            disagreementTransitionScale: 1.0,
            innerPriorCandidates: const <String>[],
          );
    final serializedPipeline = applySafetyPipeline
        ? <String, Object?>{
            'predictionPipeline': 'distance_disagreement_gate_prior_v1',
            'heads': payload,
            'challengerHeads': disagreement['available'] == true ? challengerPayload : null,
            'priorHeads': priorPayload,
            'priorCandidate': robustPrior!.candidate,
            'gates': gates,
            'featureSchema': schema,
            'modelBlendWeight': supportCalibration.modelBlendWeight,
            'distanceTransitionScale': supportCalibration.distanceTransitionScale,
            'disagreementTransitionScale': supportCalibration.disagreementTransitionScale,
            'disagreement': <String, Object?>{
              'available': disagreement['available'],
              if (disagreement['logicalPixelP50'] != null) 'logicalPixelP50': disagreement['logicalPixelP50'],
              if (disagreement['logicalPixelP95'] != null) 'logicalPixelP95': disagreement['logicalPixelP95'],
            },
          }
        : <String, Object?>{
            'predictionPipeline': 'raw_bounded_formula_v1',
            'heads': payload,
          };
    final standaloneComparator = _isComparisonBaseline(candidate)
        ? _standaloneComparator(
            groups,
            candidate: candidate,
            platform: platform,
          )
        : null;
    return <String, Object?>{
      'candidate': candidate,
      'challengerCandidate': applySafetyPipeline ? challengerCandidate : null,
      'scoringPipeline': applySafetyPipeline
          ? 'fold_local_distance_disagreement_gate_prior_v1'
          : 'fold_local_raw_bounded_formula_v1',
      'standaloneComparator': standaloneComparator,
      if (applySafetyPipeline) ...<String, Object?>{
        'robustPriorCandidate': robustPrior!.candidate,
        'modelBlendWeight': supportCalibration.modelBlendWeight,
        'distanceTransitionScale': supportCalibration.distanceTransitionScale,
        'disagreementTransitionScale': supportCalibration.disagreementTransitionScale,
        'innerPriorCandidates': supportCalibration.innerPriorCandidates,
      },
      ...family,
      'validationRegimes': regimes,
      'worstRegimeBootstrapUpperLogicalP95': regimes.values
          .map(
            (metrics) => (metrics['familyBootstrapUpperLogicalP95']! as num).toDouble(),
          )
          .reduce(math.max),
      'worstRegimeMacroLogicalPixelMae': regimes.values
          .map(
            (metrics) => (metrics['macroLogicalPixelMae']! as num).toDouble(),
          )
          .reduce(math.max),
      'logicalPixelMaximumAbsoluteError': regimes.values
          .map(
            (metrics) => (metrics['logicalPixelMaximumAbsoluteError']! as num).toDouble(),
          )
          .reduce(math.max),
      'generatedModelBytes': _DeviceDisplayModelGenerator().modelPayloadByteCount(serializedPipeline),
      'inferenceOperationCount': _pipelineOperationCount(
        selectedHeads: payload,
        challengerHeads: applySafetyPipeline && disagreement['available'] == true ? challengerPayload : null,
        priorHeads: priorPayload ?? const <String, Object?>{},
        gates: gates ?? const <String, Object?>{},
        usesSafetyPipeline: applySafetyPipeline,
      ),
    };
  }

  Map<String, Object?>? _evaluateFolds(
    Map<String, Map<String, Object?>> groups, {
    required List<Set<String>> folds,
    required String candidate,
    required String challengerCandidate,
    required String platform,
    bool applySafetyPipeline = true,
    bool useRuntimeSafeInset = false,
    Set<String>? eligibleGroupKeys,
    List<({String key, Object value})?>? heldOutObservationFilters,
    String? eligibleObservationMetadataKey,
  }) {
    assert(
      heldOutObservationFilters == null || heldOutObservationFilters.length == folds.length,
      'Each held-out fold needs a matching observation filter.',
    );
    final diameterErrors = <double>[];
    final squaredDiameterErrors = <double>[];
    final logicalErrors = <double>[];
    final diameterErrorsByGroup = <String, List<double>>{};
    final logicalErrorsByGroup = <String, List<double>>{};
    var withinTwo = 0;
    var withinFour = 0;
    var withinEight = 0;
    for (var foldIndex = 0; foldIndex < folds.length; foldIndex += 1) {
      final heldOutKeys = folds[foldIndex];
      final observationFilter = heldOutObservationFilters?[foldIndex];
      final trainingGroups =
          <String, Map<String, Object?>>{
            for (final entry in groups.entries)
              if ((eligibleGroupKeys == null || eligibleGroupKeys.contains(entry.key)) &&
                  !heldOutKeys.contains(entry.key))
                entry.key: eligibleObservationMetadataKey == null
                    ? entry.value
                    : <String, Object?>{
                        ...entry.value,
                        'observations': (entry.value['observations']! as List<Object?>)
                            .cast<Map<String, Object?>>()
                            .where(
                              (observation) => observation[eligibleObservationMetadataKey] != null,
                            )
                            .toList(),
                      },
          }..removeWhere(
            (_, group) => (group['observations']! as List<Object?>).isEmpty,
          );
      final training = trainingGroups.values.toList();
      if (training.isEmpty) {
        continue;
      }
      final heads = _fitHeads(
        training,
        candidate: candidate,
        platform: platform,
        positiveOnly: applySafetyPipeline,
      );
      final challengerHeads = applySafetyPipeline
          ? _fitHeads(
              training,
              candidate: challengerCandidate,
              platform: platform,
            )
          : null;
      final robustPrior = applySafetyPipeline ? _fitRobustPrior(trainingGroups, platform: platform) : null;
      final priorHeads = robustPrior?.headModels;
      final gates = applySafetyPipeline ? _fitGateHeads(training, platform: platform) : null;
      final schema = applySafetyPipeline ? _fitFeatureSchema(training) : null;
      final disagreement = applySafetyPipeline
          ? _disagreementCalibration(
              trainingGroups,
              selectedCandidate: candidate,
              challengerCandidate: challengerCandidate,
              platform: platform,
            )
          : null;
      final supportCalibration = applySafetyPipeline
          ? _calibrateSafetySupport(
              trainingGroups,
              selectedCandidate: candidate,
              challengerCandidate: challengerCandidate,
              platform: platform,
            )
          : (
              modelBlendWeight: 1.0,
              distanceTransitionScale: 1.0,
              disagreementTransitionScale: 1.0,
              innerPriorCandidates: const <String>[],
            );
      for (final key in heldOutKeys) {
        final heldOut = groups[key];
        if (heldOut == null) {
          continue;
        }
        final topModel = heads[platform == 'ios' ? 'common' : 'top']! as Map<String, Object?>;
        final bottomModel = heads[platform == 'ios' ? 'common' : 'bottom']! as Map<String, Object?>;
        final topChallenger = challengerHeads?[platform == 'ios' ? 'common' : 'top'] as Map<String, Object?>?;
        final bottomChallenger = challengerHeads?[platform == 'ios' ? 'common' : 'bottom'] as Map<String, Object?>?;
        final topPrior = priorHeads?[platform == 'ios' ? 'common' : 'top'] as Map<String, Object?>?;
        final bottomPrior = priorHeads?[platform == 'ios' ? 'common' : 'bottom'] as Map<String, Object?>?;
        final groupDiameterErrors = <double>[];
        final groupLogicalErrors = <double>[];
        final observations = (heldOut['observations']! as List<Object?>).cast<Map<String, Object?>>();
        for (final observation in observations) {
          if (observationFilter != null && observation[observationFilter.key] != observationFilter.value) {
            continue;
          }
          final scale = observation['logicalRadiusScale'] as double?;
          if (scale == null) {
            continue;
          }
          final features = observation['features']! as List<double>;
          final runtimeInset = applySafetyPipeline || useRuntimeSafeInset;
          final topSafeInset =
              observation[platform == 'ios'
                      ? runtimeInset
                            ? 'safeInsetPrediction'
                            : 'literalSafeInsetPrediction'
                      : runtimeInset
                      ? 'safeInsetTopPrediction'
                      : 'literalSafeInsetTopPrediction']!
                  as double;
          final bottomSafeInset =
              observation[platform == 'ios'
                      ? runtimeInset
                            ? 'safeInsetPrediction'
                            : 'literalSafeInsetPrediction'
                      : runtimeInset
                      ? 'safeInsetBottomPrediction'
                      : 'literalSafeInsetBottomPrediction']!
                  as double;
          final topPrediction = applySafetyPipeline
              ? _pipelinePrediction(
                  selectedModel: topModel,
                  challengerModel: topChallenger!,
                  priorModel: topPrior!,
                  gate: gates![platform == 'ios' ? 'common' : 'top']! as Map<String, Object?>,
                  schema: schema!,
                  disagreement: disagreement!,
                  features: features,
                  safeInsetPrediction: topSafeInset,
                  logicalRadiusScale: scale,
                  modelBlendWeight: supportCalibration.modelBlendWeight,
                  distanceTransitionScale: supportCalibration.distanceTransitionScale,
                  disagreementTransitionScale: supportCalibration.disagreementTransitionScale,
                )
              : _predictCandidate(
                  topModel,
                  features,
                  safeInsetPrediction: topSafeInset,
                );
          final bottomPrediction = applySafetyPipeline
              ? _pipelinePrediction(
                  selectedModel: bottomModel,
                  challengerModel: bottomChallenger!,
                  priorModel: bottomPrior!,
                  gate: gates![platform == 'ios' ? 'common' : 'bottom']! as Map<String, Object?>,
                  schema: schema!,
                  disagreement: disagreement!,
                  features: features,
                  safeInsetPrediction: bottomSafeInset,
                  logicalRadiusScale: scale,
                  modelBlendWeight: supportCalibration.modelBlendWeight,
                  distanceTransitionScale: supportCalibration.distanceTransitionScale,
                  disagreementTransitionScale: supportCalibration.disagreementTransitionScale,
                )
              : _predictCandidate(
                  bottomModel,
                  features,
                  safeInsetPrediction: bottomSafeInset,
                );
          for (final pair in <(double, double)>[
            (topPrediction, observation['topTarget']! as double),
            (bottomPrediction, observation['bottomTarget']! as double),
          ]) {
            final diameterError = (pair.$1.clamp(0, 1) - pair.$2).abs();
            final logicalError = diameterError * scale;
            diameterErrors.add(diameterError);
            squaredDiameterErrors.add(diameterError * diameterError);
            logicalErrors.add(logicalError);
            groupDiameterErrors.add(diameterError);
            groupLogicalErrors.add(logicalError);
            if (logicalError <= 2) {
              withinTwo += 1;
            }
            if (logicalError <= 4) {
              withinFour += 1;
            }
            if (logicalError <= 8) {
              withinEight += 1;
            }
          }
        }
        if (groupLogicalErrors.isNotEmpty) {
          diameterErrorsByGroup.putIfAbsent(key, () => <double>[]).addAll(groupDiameterErrors);
          logicalErrorsByGroup.putIfAbsent(key, () => <double>[]).addAll(groupLogicalErrors);
        }
      }
    }
    if (logicalErrors.isEmpty) {
      return null;
    }
    diameterErrors.sort();
    logicalErrors.sort();
    return <String, Object?>{
      'diameterMae': _mean(diameterErrors),
      'diameterMedianAbsoluteError': _median(diameterErrors),
      'macroDiameterMae': _mean(
        diameterErrorsByGroup.values.map(_mean).toList(),
      ),
      'diameterRmse': math.sqrt(_mean(squaredDiameterErrors)),
      'diameterP95AbsoluteError': _percentile(diameterErrors, 0.95),
      'diameterMaximumAbsoluteError': diameterErrors.last,
      'familyBootstrapUpperDiameterP95': _bootstrapUpperP95(
        diameterErrorsByGroup.values.toList(),
      ),
      'familyBootstrapUpperLogicalP95': _bootstrapUpperP95(
        logicalErrorsByGroup.values.toList(),
      ),
      'logicalPixelObservationCount': logicalErrors.length,
      'logicalPixelLeakageGroupCount': logicalErrorsByGroup.length,
      'logicalPixelMae': _mean(logicalErrors),
      'macroLogicalPixelMae': _mean(
        logicalErrorsByGroup.values.map(_mean).toList(),
      ),
      'logicalPixelMedianAbsoluteError': _median(logicalErrors),
      'logicalPixelP95AbsoluteError': _percentile(logicalErrors, 0.95),
      'logicalPixelMaximumAbsoluteError': logicalErrors.last,
      'withinTwoLogicalPixels': withinTwo / logicalErrors.length,
      'withinFourLogicalPixels': withinFour / logicalErrors.length,
      'withinEightLogicalPixels': withinEight / logicalErrors.length,
    };
  }

  Map<String, Object?> _standaloneComparator(
    Map<String, Map<String, Object?>> groups, {
    required String candidate,
    required String platform,
  }) {
    final metrics = _evaluateFolds(
      groups,
      folds: <Set<String>>[
        for (final key in groups.keys) <String>{key},
      ],
      candidate: candidate,
      challengerCandidate: _candidateChallenger(candidate),
      platform: platform,
      applySafetyPipeline: false,
    );
    final fitted = _fitHeads(
      groups.values.toList(),
      candidate: candidate,
      platform: platform,
      positiveOnly: false,
    );
    return <String, Object?>{
      'scoringPipeline': 'standalone_raw_formula_grouped_oof_v1',
      'headKinds': <String, Object?>{
        for (final entry in fitted.entries) entry.key: (entry.value! as Map<String, Object?>)['kind'],
      },
      'metrics': metrics,
    };
  }

  ({String candidate, Map<String, Object?> headModels}) _fitRobustPrior(
    Map<String, Map<String, Object?>> groups, {
    required String platform,
  }) {
    final candidate = _selectRobustPriorCandidate(
      groups,
      platform: platform,
    );
    return (
      candidate: candidate,
      headModels: _fitHeads(
        groups.values.toList(),
        candidate: candidate,
        platform: platform,
        positiveOnly: false,
      ),
    );
  }

  String _selectRobustPriorCandidate(
    Map<String, Map<String, Object?>> groups, {
    required String platform,
  }) {
    final cacheKey = 'prior|$platform|${_trainingSetFingerprint(groups)}';
    final cached = _priorCandidateCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    const candidates = <String>[
      'zero_baseline',
      'safe_inset_baseline',
      'platform_median_logical_radius',
      'shortest_side_formula',
    ];
    if (groups.length < 2) {
      _priorCandidateCache[cacheKey] = 'safe_inset_baseline';
      return 'safe_inset_baseline';
    }
    final scores = <Map<String, Object?>>[];
    for (final candidate in candidates) {
      final metrics = _evaluateFolds(
        groups,
        folds: <Set<String>>[
          for (final key in groups.keys) <String>{key},
        ],
        candidate: candidate,
        challengerCandidate: _candidateChallenger(candidate),
        platform: platform,
        applySafetyPipeline: false,
        useRuntimeSafeInset: true,
      );
      if (metrics == null) {
        continue;
      }
      final heads = _fitHeads(
        groups.values.toList(),
        candidate: candidate,
        platform: platform,
        positiveOnly: false,
      );
      scores.add(<String, Object?>{
        'candidate': candidate,
        'worstRegimeBootstrapUpperLogicalP95': metrics['familyBootstrapUpperLogicalP95'],
        'worstRegimeMacroLogicalPixelMae': metrics['macroLogicalPixelMae'],
        'logicalPixelMaximumAbsoluteError': metrics['logicalPixelMaximumAbsoluteError'],
        'generatedModelBytes': _DeviceDisplayModelGenerator().modelPayloadByteCount(heads),
        'inferenceOperationCount': _pipelineOperationCount(
          selectedHeads: heads,
          challengerHeads: null,
          priorHeads: const <String, Object?>{},
          gates: const <String, Object?>{},
          usesSafetyPipeline: false,
        ),
      });
    }
    scores.sort(
      (left, right) => _compareScores(left, right, candidates),
    );
    final selected = scores.isEmpty ? 'safe_inset_baseline' : scores.first['candidate']! as String;
    _priorCandidateCache[cacheKey] = selected;
    return selected;
  }

  ({
    double modelBlendWeight,
    double distanceTransitionScale,
    double disagreementTransitionScale,
    List<String> innerPriorCandidates,
  })
  _calibrateSafetySupport(
    Map<String, Map<String, Object?>> groups, {
    required String selectedCandidate,
    required String challengerCandidate,
    required String platform,
  }) {
    final cacheKey =
        'support|$platform|$selectedCandidate|$challengerCandidate|'
        '${_trainingSetFingerprint(groups)}';
    final cached = _supportCalibrationCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    if (groups.length < 2) {
      const fallback = (
        modelBlendWeight: 0.0,
        distanceTransitionScale: 0.25,
        disagreementTransitionScale: 0.25,
        innerPriorCandidates: <String>[],
      );
      _supportCalibrationCache[cacheKey] = fallback;
      return fallback;
    }
    final configurations =
        <
          ({
            double modelBlendWeight,
            double distanceTransitionScale,
            double disagreementTransitionScale,
            Map<String, List<double>> logicalErrorsByGroup,
          })
        >[
          for (var weightIndex = 0; weightIndex <= 20; weightIndex += 1)
            for (final distanceScale in const <double>[0.25, 0.5, 1])
              for (final disagreementScale in const <double>[0.25, 0.5, 1])
                (
                  modelBlendWeight: weightIndex / 20,
                  distanceTransitionScale: distanceScale,
                  disagreementTransitionScale: disagreementScale,
                  logicalErrorsByGroup: <String, List<double>>{},
                ),
        ];
    final innerPriorCandidates = <String>{};
    for (final heldOut in groups.entries) {
      final trainingGroups = <String, Map<String, Object?>>{
        for (final entry in groups.entries)
          if (entry.key != heldOut.key) entry.key: entry.value,
      };
      if (trainingGroups.isEmpty) {
        continue;
      }
      final training = trainingGroups.values.toList();
      final selectedHeads = _fitHeads(
        training,
        candidate: selectedCandidate,
        platform: platform,
      );
      final challengerHeads = _fitHeads(
        training,
        candidate: challengerCandidate,
        platform: platform,
      );
      final prior = _fitRobustPrior(trainingGroups, platform: platform);
      innerPriorCandidates.add(prior.candidate);
      final gates = _fitGateHeads(training, platform: platform);
      final calibrationSchema = _fitFeatureSchema(training);
      final calibrationDisagreement = _disagreementCalibration(
        trainingGroups,
        selectedCandidate: selectedCandidate,
        challengerCandidate: challengerCandidate,
        platform: platform,
      );
      final observations = (heldOut.value['observations']! as List<Object?>).cast<Map<String, Object?>>();
      for (final observation in observations) {
        final logicalRadiusScale = observation['logicalRadiusScale'] as double?;
        if (logicalRadiusScale == null) {
          continue;
        }
        final features = observation['features']! as List<double>;
        final heads = platform == 'ios'
            ? const <({String name, String target, String inset})>[
                (
                  name: 'common',
                  target: 'topTarget',
                  inset: 'safeInsetPrediction',
                ),
                (
                  name: 'common',
                  target: 'bottomTarget',
                  inset: 'safeInsetPrediction',
                ),
              ]
            : const <({String name, String target, String inset})>[
                (
                  name: 'top',
                  target: 'topTarget',
                  inset: 'safeInsetTopPrediction',
                ),
                (
                  name: 'bottom',
                  target: 'bottomTarget',
                  inset: 'safeInsetBottomPrediction',
                ),
              ];
        for (final head in heads) {
          final safeInset = observation[head.inset]! as double;
          final target = observation[head.target]! as double;
          for (final configuration in configurations) {
            final prediction = _pipelinePrediction(
              selectedModel: selectedHeads[head.name]! as Map<String, Object?>,
              challengerModel: challengerHeads[head.name]! as Map<String, Object?>,
              priorModel: prior.headModels[head.name]! as Map<String, Object?>,
              gate: gates[head.name]! as Map<String, Object?>,
              schema: calibrationSchema,
              disagreement: calibrationDisagreement,
              features: features,
              safeInsetPrediction: safeInset,
              logicalRadiusScale: logicalRadiusScale,
              modelBlendWeight: configuration.modelBlendWeight,
              distanceTransitionScale: configuration.distanceTransitionScale,
              disagreementTransitionScale: configuration.disagreementTransitionScale,
            );
            configuration.logicalErrorsByGroup
                .putIfAbsent(heldOut.key, () => <double>[])
                .add((prediction - target).abs() * logicalRadiusScale);
          }
        }
      }
    }
    final scored =
        <
          ({
            double modelBlendWeight,
            double distanceTransitionScale,
            double disagreementTransitionScale,
            double bootstrapUpperP95,
            double macroMae,
            double maximum,
          })
        >[];
    for (final configuration in configurations) {
      final groupedErrors = configuration.logicalErrorsByGroup.values.where((errors) => errors.isNotEmpty).toList();
      if (groupedErrors.isEmpty) {
        continue;
      }
      scored.add((
        modelBlendWeight: configuration.modelBlendWeight,
        distanceTransitionScale: configuration.distanceTransitionScale,
        disagreementTransitionScale: configuration.disagreementTransitionScale,
        bootstrapUpperP95: _bootstrapUpperP95(groupedErrors),
        macroMae: _mean(groupedErrors.map(_mean).toList()),
        maximum: groupedErrors.expand((errors) => errors).reduce(math.max),
      ));
    }
    scored.sort((left, right) {
      for (final comparison in <int>[
        left.bootstrapUpperP95.compareTo(right.bootstrapUpperP95),
        left.macroMae.compareTo(right.macroMae),
        left.maximum.compareTo(right.maximum),
        left.modelBlendWeight.compareTo(right.modelBlendWeight),
        left.distanceTransitionScale.compareTo(
          right.distanceTransitionScale,
        ),
        left.disagreementTransitionScale.compareTo(
          right.disagreementTransitionScale,
        ),
      ]) {
        if (comparison != 0) {
          return comparison;
        }
      }
      return 0;
    });
    final best = scored.first;
    final result = (
      modelBlendWeight: best.modelBlendWeight,
      distanceTransitionScale: best.distanceTransitionScale,
      disagreementTransitionScale: best.disagreementTransitionScale,
      innerPriorCandidates: innerPriorCandidates.toList()..sort(),
    );
    _supportCalibrationCache[cacheKey] = result;
    return result;
  }

  String _trainingSetFingerprint(
    Map<String, Map<String, Object?>> groups,
  ) => DeviceDisplayModelEncoding.fingerprint(groups);

  Map<String, Object?> _fitHeads(
    List<Map<String, Object?>> groups, {
    required String candidate,
    required String platform,
    bool positiveOnly = true,
  }) {
    final cacheKey =
        'heads|$platform|$candidate|$positiveOnly|'
        '${DeviceDisplayModelEncoding.fingerprint(groups)}';
    final cached = _headFitCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final fitted = platform == 'ios'
        ? <String, Object?>{
            'common': _fitPositiveCandidate(
              candidate,
              _headRows(
                groups,
                platform: platform,
                head: 'common',
                positiveOnly: positiveOnly,
              ),
            ),
          }
        : <String, Object?>{
            'top': _fitPositiveCandidate(
              candidate,
              _headRows(
                groups,
                platform: platform,
                head: 'top',
                positiveOnly: positiveOnly,
              ),
            ),
            'bottom': _fitPositiveCandidate(
              candidate,
              _headRows(
                groups,
                platform: platform,
                head: 'bottom',
                positiveOnly: positiveOnly,
              ),
            ),
          };
    final immutable = Map<String, Object?>.unmodifiable(fitted);
    _headFitCache[cacheKey] = immutable;
    return immutable;
  }

  Map<String, Object?> _fitGateHeads(
    List<Map<String, Object?>> groups, {
    required String platform,
  }) {
    final cacheKey = 'gates|$platform|${DeviceDisplayModelEncoding.fingerprint(groups)}';
    final cached = _gateFitCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final fitted = platform == 'ios'
        ? <String, Object?>{
            'common': _algorithms.fitGate(
              _headRows(
                groups,
                platform: platform,
                head: 'common',
                positiveOnly: false,
              ),
              targetKey: 'fitRoundedTarget',
            ),
          }
        : <String, Object?>{
            'top': _algorithms.fitGate(
              _headRows(
                groups,
                platform: platform,
                head: 'top',
                positiveOnly: false,
              ),
              targetKey: 'fitRoundedTarget',
            ),
            'bottom': _algorithms.fitGate(
              _headRows(
                groups,
                platform: platform,
                head: 'bottom',
                positiveOnly: false,
              ),
              targetKey: 'fitRoundedTarget',
            ),
          };
    final immutable = Map<String, Object?>.unmodifiable(fitted);
    _gateFitCache[cacheKey] = immutable;
    return immutable;
  }

  Map<String, Object?> _fitFeatureSchema(
    List<Map<String, Object?>> groups,
  ) {
    final cacheKey = DeviceDisplayModelEncoding.fingerprint(groups);
    final cached = _featureSchemaCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final schema = Map<String, Object?>.unmodifiable(
      _algorithms.featureSchema(_featureRows(groups)),
    );
    _featureSchemaCache[cacheKey] = schema;
    return schema;
  }

  double _pipelinePrediction({
    required Map<String, Object?> selectedModel,
    required Map<String, Object?> challengerModel,
    required Map<String, Object?> priorModel,
    required Map<String, Object?> gate,
    required Map<String, Object?> schema,
    required Map<String, Object?> disagreement,
    required List<double> features,
    required double safeInsetPrediction,
    required double logicalRadiusScale,
    required double modelBlendWeight,
    required double distanceTransitionScale,
    required double disagreementTransitionScale,
  }) => DeviceDisplayModelPipeline.predict(
    selectedModel: selectedModel,
    challengerModel: challengerModel,
    priorModel: priorModel,
    gate: gate,
    featureSchema: schema,
    disagreement: disagreement,
    features: features,
    safeInsetDiameter: safeInsetPrediction,
    logicalRadiusScale: logicalRadiusScale,
    modelBlendWeight: modelBlendWeight,
    distanceTransitionScale: distanceTransitionScale,
    disagreementTransitionScale: disagreementTransitionScale,
  );

  Map<String, Object?> _fitPositiveCandidate(
    String candidate,
    List<Map<String, Object?>> rows,
  ) {
    if (rows.isEmpty) {
      return <String, Object?>{'kind': 'zero'};
    }
    return _fitCandidate(candidate, rows);
  }

  Map<String, Object?> _fitCandidate(
    String candidate,
    List<Map<String, Object?>> rows,
  ) {
    if (_isRichCandidate(candidate)) {
      return DeviceDisplayModelCandidateEngine.fit(
        candidate: candidate,
        features: rows.map((row) => row['features']! as List<double>).toList(),
        targets: rows.map((row) => row['fitTarget']! as double).toList(),
        weights: rows.map((row) => row['fitWeight']! as double).toList(),
        logicalRadiusScales: rows.map((row) => row['logicalRadiusScale'] as double?).toList(),
        groupIds: rows.map((row) => row['fitGroupId']! as int).toList(),
      );
    }
    return _algorithms.fitModel(candidate, rows, targetKey: 'fitTarget');
  }

  double _predictCandidate(
    Map<String, Object?> model,
    List<double> features, {
    required double safeInsetPrediction,
  }) {
    if (_isRichKind(model['kind']! as String)) {
      return DeviceDisplayModelCandidateEngine.predict(
        model: model,
        features: features,
      );
    }
    return _algorithms.predictModel(
      model,
      features,
      safeInsetPrediction: safeInsetPrediction,
    );
  }

  bool _isRichCandidate(String candidate) => const {
    'robust_quadratic_regression',
    'spline_gam',
    'shallow_boosted_tree',
    'constrained_blend',
  }.contains(candidate);

  bool _isComparisonBaseline(String candidate) => const {
    'zero_baseline',
    'safe_inset_baseline',
    'platform_median_logical_radius',
    'shortest_side_formula',
  }.contains(candidate);

  String _candidateChallenger(String candidate) => switch (candidate) {
    'zero_baseline' || 'safe_inset_baseline' || 'platform_median_logical_radius' => 'shallow_boosted_tree',
    'shortest_side_formula' => 'platform_median_logical_radius',
    'robust_quadratic_regression' => 'shallow_boosted_tree',
    'spline_gam' => 'shallow_boosted_tree',
    'shallow_boosted_tree' => 'spline_gam',
    'constrained_blend' => 'robust_quadratic_regression',
    _ => throw FormatException('No structural challenger for $candidate.'),
  };

  bool _isRichKind(String kind) => const {
    'robust_quadratic_regression',
    'spline_gam',
    'shallow_boosted_tree',
    'constrained_blend',
  }.contains(kind);

  int _modelOperationCount(Map<String, Object?> model) {
    if (_isRichKind(model['kind']! as String)) {
      return DeviceDisplayModelCandidateEngine.inferenceOperationCount(model);
    }
    return _algorithms.inferenceOperationCount(model);
  }

  int _pipelineOperationCount({
    required Map<String, Object?> selectedHeads,
    required Map<String, Object?>? challengerHeads,
    required Map<String, Object?> priorHeads,
    required Map<String, Object?> gates,
    required bool usesSafetyPipeline,
  }) {
    int headOperations(Map<String, Object?> heads) => heads.values
        .whereType<Map<String, Object?>>()
        .map(_modelOperationCount)
        .fold(0, (total, count) => total + count);
    if (!usesSafetyPipeline) {
      return headOperations(selectedHeads);
    }
    final headCount = selectedHeads.values.whereType<Map<String, Object?>>().length;
    final gateOperations = gates.values
        .whereType<Map<String, Object?>>()
        .map(
          (gate) => gate['fitted'] == true ? 3 * (gate['coefficients']! as List<Object?>).length + 10 : 1,
        )
        .fold(0, (total, count) => total + count);
    return headOperations(selectedHeads) +
        (challengerHeads == null ? 0 : headOperations(challengerHeads)) +
        headOperations(priorHeads) +
        gateOperations +
        headCount * (5 * _DeviceDisplayModelAlgorithms.featureNames.length + 12);
  }

  Map<String, Object?> _classification(
    List<Map<String, Object?>> records, {
    required String platform,
  }) {
    final roundedCount = records.where((record) => record['cornerClassification'] == 'rounded').length;
    final squareCount = records.where((record) => record['cornerClassification'] == 'square').length;
    final groups = _groups(records).values.toList();
    final headGates = _fitGateHeads(groups, platform: platform);
    final commonGate = platform == 'ios'
        ? headGates['common']! as Map<String, Object?>
        : _algorithms.fitGate(
            _featureRows(groups),
            targetKey: 'roundedTarget',
          );
    final topGate = platform == 'ios' ? commonGate : headGates['top']! as Map<String, Object?>;
    final bottomGate = platform == 'ios' ? commonGate : headGates['bottom']! as Map<String, Object?>;
    return <String, Object?>{
      'roundedRecordCount': roundedCount,
      'squareRecordCount': squareCount,
      'roundedIndependentGroupCount': groups.where((group) => group['roundedTarget'] == 1.0).length,
      'squareIndependentGroupCount': groups.where((group) => group['roundedTarget'] == 0.0).length,
      'independentGroupCount': groups.length,
      'selectedCandidate': commonGate['fitted'] == true
          ? 'quadratic_logistic_hurdle'
          : 'laplace_smoothed_constant_hurdle',
      'isFitted': commonGate['fitted'],
      'roundedProbability': commonGate['priorProbability'],
      'commonGate': commonGate,
      'topGate': topGate,
      'bottomGate': bottomGate,
      'limitation': commonGate['fitted'] == true
          ? 'The hurdle was fitted with group-equal deterministic logistic loss.'
          : 'Both classes across at least two independent groups are required; '
                'the Laplace-smoothed prior is not a calibrated classifier.',
    };
  }

  Map<String, Object?> _disagreementCalibration(
    Map<String, Map<String, Object?>> groups, {
    required String selectedCandidate,
    required String challengerCandidate,
    required String platform,
  }) {
    final cacheKey =
        'disagreement|$platform|$selectedCandidate|$challengerCandidate|'
        '${_trainingSetFingerprint(groups)}';
    final cached = _disagreementCalibrationCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    if (groups.length < 2) {
      final unavailable = <String, Object?>{
        'available': false,
        'reason':
            'At least two independent leakage groups are required for '
            'out-of-fold disagreement calibration.',
      };
      _disagreementCalibrationCache[cacheKey] = unavailable;
      return unavailable;
    }
    final logicalSpreads = <double>[];
    for (final heldOut in groups.entries) {
      final training = <Map<String, Object?>>[
        for (final entry in groups.entries)
          if (entry.key != heldOut.key) entry.value,
      ];
      final selectedHeads = _fitHeads(
        training,
        candidate: selectedCandidate,
        platform: platform,
      );
      final challengerHeads = _fitHeads(
        training,
        candidate: challengerCandidate,
        platform: platform,
      );
      final observations = (heldOut.value['observations']! as List<Object?>).cast<Map<String, Object?>>();
      for (final observation in observations) {
        final features = observation['features']! as List<double>;
        final scale = observation['logicalRadiusScale'] as double?;
        if (scale == null) {
          continue;
        }
        for (final head in platform == 'ios' ? const <String>['common'] : const <String>['top', 'bottom']) {
          final safeInsetKey = platform == 'ios'
              ? 'safeInsetPrediction'
              : head == 'bottom'
              ? 'safeInsetBottomPrediction'
              : 'safeInsetTopPrediction';
          final safeInset = observation[safeInsetKey]! as double;
          final selected = _predictCandidate(
            selectedHeads[head]! as Map<String, Object?>,
            features,
            safeInsetPrediction: safeInset,
          );
          final challenger = _predictCandidate(
            challengerHeads[head]! as Map<String, Object?>,
            features,
            safeInsetPrediction: safeInset,
          );
          logicalSpreads.add((selected - challenger).abs() * scale);
        }
      }
    }
    logicalSpreads.sort();
    if (logicalSpreads.isEmpty) {
      final unavailable = <String, Object?>{
        'available': false,
        'reason': 'No DPR-known held-out observation supported disagreement calibration.',
      };
      _disagreementCalibrationCache[cacheKey] = unavailable;
      return unavailable;
    }
    final calibration = <String, Object?>{
      'available': true,
      'selectedCandidate': selectedCandidate,
      'challengerCandidate': challengerCandidate,
      'logicalPixelP50': _percentile(logicalSpreads, 0.5),
      'logicalPixelP95': _percentile(logicalSpreads, 0.95),
      'observationCount': logicalSpreads.length,
    };
    _disagreementCalibrationCache[cacheKey] = calibration;
    return calibration;
  }

  ({
    List<({Set<String> heldOut, String targetValue})> folds,
    Set<String> eligibleGroupKeys,
    int excludedGroupCount,
  })?
  _metadataFolds(
    Map<String, Map<String, Object?>> groups, {
    required String key,
    required int minimumDistinctValues,
  }) {
    if (key != 'oemGroups' && key != 'generationGroups') {
      throw FormatException('Unknown metadata fold key: $key');
    }
    final eligible = <String, Map<String, Object?>>{
      for (final entry in groups.entries)
        if ((entry.value[key]! as List<String>).isNotEmpty) entry.key: entry.value,
    };
    final values = eligible.values.expand((group) => group[key]! as List<String>).toSet().toList()..sort();
    if (values.length < minimumDistinctValues) {
      return null;
    }
    final folds = <({Set<String> heldOut, String targetValue})>[];
    for (final value in values) {
      final heldOut = <String>{
        for (final entry in eligible.entries)
          if ((entry.value[key]! as List<String>).contains(value)) entry.key,
      };
      if (heldOut.isNotEmpty && heldOut.length < eligible.length) {
        folds.add((heldOut: heldOut, targetValue: value));
      }
    }
    return folds.isEmpty
        ? null
        : (
            folds: folds,
            eligibleGroupKeys: eligible.keys.toSet(),
            excludedGroupCount: groups.length - eligible.length,
          );
  }

  ({
    Set<String> heldOut,
    Set<String> eligibleGroupKeys,
    int excludedGroupCount,
    double targetRank,
  })?
  _newestFold(Map<String, Map<String, Object?>> groups) {
    final eligible = <String, Map<String, Object?>>{
      for (final entry in groups.entries)
        if ((entry.value['chronologyRanks']! as List<double>).isNotEmpty) entry.key: entry.value,
    };
    final ranks = eligible.values.expand((group) => group['chronologyRanks']! as List<double>).toSet().toList()..sort();
    if (ranks.length < 2) {
      return null;
    }
    final newest = ranks.last;
    final heldOut = <String>{
      for (final entry in eligible.entries)
        if ((entry.value['chronologyRanks']! as List<double>).contains(newest)) entry.key,
    };
    return heldOut.isEmpty || heldOut.length == eligible.length
        ? null
        : (
            heldOut: heldOut,
            eligibleGroupKeys: eligible.keys.toSet(),
            excludedGroupCount: groups.length - eligible.length,
            targetRank: newest,
          );
  }

  Map<String, Object?> _holdoutResults(
    Map<String, Map<String, Object?>> groups, {
    required Map<String, Object?>? selectedScore,
  }) {
    final regimes = selectedScore?['validationRegimes'] as Map<String, Object?>?;
    Map<String, Object?> result(
      String regime, {
      required int groupCount,
      required int minimumGroupCount,
      required int eligibleLeakageGroupCount,
      required int excludedLeakageGroupCount,
      required String unavailableReason,
    }) {
      final metrics = regimes?[regime] as Map<String, Object?>?;
      return metrics == null
          ? <String, Object?>{
              'status': 'unavailable',
              'groupCount': groupCount,
              'minimumGroupCount': minimumGroupCount,
              'eligibleLeakageGroupCount': eligibleLeakageGroupCount,
              'excludedLeakageGroupCount': excludedLeakageGroupCount,
              'reason': groupCount < minimumGroupCount
                  ? unavailableReason
                  : 'No DPR-known held-out observation was available for this split.',
            }
          : <String, Object?>{
              'status': 'executed',
              'groupCount': groupCount,
              'minimumGroupCount': minimumGroupCount,
              'eligibleLeakageGroupCount': metrics['metadataEligibleGroupCount'] ?? eligibleLeakageGroupCount,
              'excludedLeakageGroupCount': metrics['metadataExcludedGroupCount'] ?? excludedLeakageGroupCount,
              'metrics': metrics,
            };
    }

    final oemEligible = groups.values
        .where(
          (group) => (group['oemGroups']! as List<String>).isNotEmpty,
        )
        .toList();
    final generationEligible = groups.values
        .where(
          (group) => (group['generationGroups']! as List<String>).isNotEmpty,
        )
        .toList();
    final chronologyEligible = groups.values
        .where(
          (group) => (group['chronologyRanks']! as List<double>).isNotEmpty,
        )
        .toList();
    final oemCount = oemEligible.expand((group) => group['oemGroups']! as List<String>).toSet().length;
    final generationCount = generationEligible
        .expand((group) => group['generationGroups']! as List<String>)
        .toSet()
        .length;
    final chronologyCount = chronologyEligible
        .expand((group) => group['chronologyRanks']! as List<double>)
        .toSet()
        .length;
    return <String, Object?>{
      'leaveOemOut': result(
        'leaveOemOut',
        groupCount: oemCount,
        minimumGroupCount: 2,
        eligibleLeakageGroupCount: oemEligible.length,
        excludedLeakageGroupCount: groups.length - oemEligible.length,
        unavailableReason: 'Fewer than two anonymized OEM groups were available.',
      ),
      'leaveGenerationOut': result(
        'leaveGenerationOut',
        groupCount: generationCount,
        minimumGroupCount: 2,
        eligibleLeakageGroupCount: generationEligible.length,
        excludedLeakageGroupCount: groups.length - generationEligible.length,
        unavailableReason: 'Fewer than two anonymized generation groups were available.',
      ),
      'newestGeneration': result(
        'newestGeneration',
        groupCount: chronologyCount,
        minimumGroupCount: 2,
        eligibleLeakageGroupCount: chronologyEligible.length,
        excludedLeakageGroupCount: groups.length - chronologyEligible.length,
        unavailableReason: 'Fewer than two distinct anonymous chronology ranks were available.',
      ),
    };
  }

  Map<String, Object?> _collisionLowerBound(
    List<Map<String, Object?>> records,
  ) {
    final diameterErrors = <double>[];
    final logicalErrors = <double>[];
    var collisionGroupCount = 0;
    final recordsByGeometry = <String, List<Map<String, Object?>>>{};
    for (final record in records) {
      final geometry =
          record['observableCollisionGroupHash'] ?? record['geometryCollisionGroupHash'] ?? record['validationGroup'];
      if (geometry is! String) {
        continue;
      }
      recordsByGeometry.putIfAbsent(geometry, () => []).add(record);
    }
    for (final collisionRecords in recordsByGeometry.values) {
      if (collisionRecords.length < 2) {
        continue;
      }
      collisionGroupCount += 1;
      final topTargets = <double>[];
      final bottomTargets = <double>[];
      for (final record in collisionRecords) {
        final shortSide = math.min(
          (record['physicalWidth']! as num).toDouble(),
          (record['physicalHeight']! as num).toDouble(),
        );
        topTargets.add(
          2 * (record['topRadiusPhysical']! as num).toDouble() / shortSide,
        );
        bottomTargets.add(
          2 * (record['bottomRadiusPhysical']! as num).toDouble() / shortSide,
        );
      }
      final topPrediction = _median(topTargets);
      final bottomPrediction = _median(bottomTargets);
      for (var index = 0; index < collisionRecords.length; index += 1) {
        final record = collisionRecords[index];
        final shortSide = math.min(
          (record['physicalWidth']! as num).toDouble(),
          (record['physicalHeight']! as num).toDouble(),
        );
        final errors = <double>[
          (topPrediction - topTargets[index]).abs(),
          (bottomPrediction - bottomTargets[index]).abs(),
        ];
        diameterErrors.addAll(errors);
        final density = (record['devicePixelRatio'] as num?)?.toDouble();
        if (density != null) {
          final logicalScale = shortSide / density / 2;
          logicalErrors.addAll(
            errors.map((error) => error * logicalScale),
          );
        }
      }
    }
    return <String, Object?>{
      'collisionGroupCount': collisionGroupCount,
      'diameterMae': _meanOrNull(diameterErrors),
      'logicalPixelMae': _meanOrNull(logicalErrors),
      'logicalPixelObservationCount': logicalErrors.length,
    };
  }

  int _compareScores(
    Map<String, Object?> left,
    Map<String, Object?> right,
    List<String> candidateOrder,
  ) {
    for (final key in const [
      'worstRegimeBootstrapUpperLogicalP95',
      'worstRegimeMacroLogicalPixelMae',
      'logicalPixelMaximumAbsoluteError',
      'generatedModelBytes',
      'inferenceOperationCount',
    ]) {
      final comparison = (left[key]! as num).compareTo(right[key]! as num);
      if (comparison != 0) {
        return comparison;
      }
    }
    return candidateOrder
        .indexOf(left['candidate']! as String)
        .compareTo(candidateOrder.indexOf(right['candidate']! as String));
  }

  double _bootstrapUpperP95(List<List<double>> errorsByGroup) {
    var state = 0x5eed1234;
    final bootstrapP95 = <double>[];
    for (var repetition = 0; repetition < 1000; repetition += 1) {
      final sampledErrors = <double>[];
      for (var index = 0; index < errorsByGroup.length; index += 1) {
        state = ((1664525 * state) + 1013904223) & 0xffffffff;
        sampledErrors.addAll(errorsByGroup[state % errorsByGroup.length]);
      }
      sampledErrors.sort();
      bootstrapP95.add(_percentile(sampledErrors, 0.95));
    }
    bootstrapP95.sort();
    return _percentile(bootstrapP95, 0.95);
  }

  double _legacyIntercept(Map<String, Object?> model) => (model['intercept'] as num?)?.toDouble() ?? 0;

  double _legacyAspectSlope(Map<String, Object?> model) {
    if (model['kind'] != 'linear') {
      return 0;
    }
    return ((model['coefficients']! as List<Object?>).first! as num).toDouble();
  }

  double _mean(List<double> values) => values.reduce((left, right) => left + right) / values.length;

  double? _meanOrNull(List<double> values) => values.isEmpty ? null : _mean(values);

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _percentile(List<double> sortedValues, double percentile) =>
      sortedValues[((sortedValues.length - 1) * percentile).ceil()];
}
