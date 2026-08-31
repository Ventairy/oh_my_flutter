part of '../device_display_model.dart';

/// Fits and evaluates compact display-radius model candidates offline.
///
/// This tooling API operates only on anonymous numeric features. Returned maps
/// contain the complete numeric model state needed by the generated runtime
/// predictor; training rows are never embedded in them.
abstract final class DeviceDisplayModelCandidateEngine {
  /// The robust additive-quadratic elastic-net candidate.
  static const robustQuadratic = 'robust_quadratic_regression';

  /// The natural-cubic-spline generalized additive candidate.
  static const naturalSplineGam = 'spline_gam';

  /// The depth-two gradient-boosted-tree candidate.
  static const shallowBoostedTrees = 'shallow_boosted_tree';

  /// The constrained convex GAM and tree blend candidate.
  static const constrainedBlend = 'constrained_blend';

  static const _candidateKinds = <String>{
    robustQuadratic,
    naturalSplineGam,
    shallowBoostedTrees,
    constrainedBlend,
  };

  static const _treeCount = 8;
  static const _treeLearningRate = 0.1;
  static const _elasticL1 = 0.0005;
  static const _elasticL2 = 0.0005;
  static const _gamL2 = 0.001;
  static const _solverIterations = 1200;

  /// Fits [candidate] to normalized-diameter [targets].
  ///
  /// Every row in [features] must have the same non-zero length. [weights]
  /// defaults to equal observation weights and may contain zeroes, provided at
  /// least one observation has positive weight. Rows sharing a [groupIds]
  /// value remain together in inner validation folds; omitted IDs default to
  /// one independent group per row.
  static Map<String, Object?> fit({
    required String candidate,
    required List<List<double>> features,
    required List<double> targets,
    List<double>? weights,
    List<double?>? logicalRadiusScales,
    List<int>? groupIds,
  }) {
    final effectiveWeights = _validatedWeights(
      candidate: candidate,
      features: features,
      targets: targets,
      weights: weights,
    );
    final effectiveLogicalScales = _validatedLogicalScales(
      logicalRadiusScales,
      rowCount: features.length,
    );
    final effectiveGroupIds = _validatedGroupIds(
      groupIds,
      rowCount: features.length,
    );
    final normalization = _normalizeTrainingFeatures(
      features,
      effectiveWeights,
    );
    final fitted = _fitNormalized(
      candidate,
      normalization.rows,
      targets,
      effectiveWeights,
      effectiveLogicalScales,
      effectiveGroupIds,
    );
    return <String, Object?>{
      ...fitted,
      'featureCenters': normalization.centers,
      'featureScales': normalization.scales,
    };
  }

  /// Predicts a bounded normalized diameter from a serialized [model].
  static double predict({
    required Map<String, Object?> model,
    required List<double> features,
  }) {
    final centers = _doubleList(model['featureCenters']);
    final scales = _doubleList(model['featureScales']);
    if (features.length != centers.length || scales.length != centers.length) {
      throw const FormatException(
        'Candidate features must match the fitted feature schema.',
      );
    }
    if (features.any((value) => !value.isFinite)) {
      throw const FormatException('Candidate features must be finite.');
    }
    final standardized = <double>[
      for (var index = 0; index < features.length; index += 1) (features[index] - centers[index]) / scales[index],
    ];
    return _predictNormalized(model, standardized).clamp(0, 1);
  }

  /// Returns a deterministic relative inference-cost estimate for [model].
  ///
  /// The value is intended only as a final model-selection tie breaker.
  static int inferenceOperationCount(Map<String, Object?> model) {
    return switch (model['kind']) {
      robustQuadratic => 3 * _doubleList(model['coefficients']).length + 2,
      naturalSplineGam => 5 * _doubleList(model['coefficients']).length + 2,
      shallowBoostedTrees =>
        1 + 8 * (model['trees']! as List<Object?>).map((tree) => _numericList(tree).length ~/ 5).fold(0, math.max),
      constrainedBlend =>
        inferenceOperationCount(
              model['gam']! as Map<String, Object?>,
            ) +
            inferenceOperationCount(
              model['trees']! as Map<String, Object?>,
            ) +
            3,
      _ => throw FormatException(
        'Unknown serialized candidate kind: ${model['kind']}',
      ),
    };
  }

  static List<double> _validatedWeights({
    required String candidate,
    required List<List<double>> features,
    required List<double> targets,
    required List<double>? weights,
  }) {
    if (!_candidateKinds.contains(candidate)) {
      throw FormatException('Unknown model candidate: $candidate');
    }
    if (features.isEmpty || targets.length != features.length) {
      throw const FormatException(
        'Candidate features and targets must have the same non-zero length.',
      );
    }
    final featureCount = features.first.length;
    if (featureCount == 0 ||
        features.any(
          (row) => row.length != featureCount || row.any((value) => !value.isFinite),
        )) {
      throw const FormatException(
        'Candidate feature rows must be finite and equally sized.',
      );
    }
    if (targets.any(
      (target) => !target.isFinite || target < 0 || target > 1,
    )) {
      throw const FormatException(
        'Candidate targets must be finite normalized diameters in [0, 1].',
      );
    }
    final result = weights == null ? List<double>.filled(features.length, 1) : List<double>.of(weights);
    if (result.length != features.length ||
        result.any((weight) => !weight.isFinite || weight < 0) ||
        result.every((weight) => weight == 0)) {
      throw const FormatException(
        'Candidate weights must be finite, non-negative, and contain a '
        'positive value.',
      );
    }
    return result;
  }

  static ({
    List<double> centers,
    List<double> scales,
    List<List<double>> rows,
  })
  _normalizeTrainingFeatures(
    List<List<double>> features,
    List<double> weights,
  ) {
    final centers = <double>[];
    final scales = <double>[];
    for (var feature = 0; feature < features.first.length; feature += 1) {
      final values = <double>[
        for (final row in features) row[feature],
      ];
      final center = _weightedQuantile(values, weights, 0.5);
      final deviations = <double>[
        for (final value in values) (value - center).abs(),
      ];
      final scaledMad = 1.4826 * _weightedQuantile(deviations, weights, 0.5);
      centers.add(center);
      scales.add(scaledMad < 1e-6 ? 1 : scaledMad);
    }
    return (
      centers: centers,
      scales: scales,
      rows: <List<double>>[
        for (final row in features)
          <double>[
            for (var feature = 0; feature < row.length; feature += 1)
              (row[feature] - centers[feature]) / scales[feature],
          ],
      ],
    );
  }

  static Map<String, Object?> _fitNormalized(
    String candidate,
    List<List<double>> features,
    List<double> targets,
    List<double> weights,
    List<double?> logicalRadiusScales,
    List<int> groupIds,
  ) {
    return switch (candidate) {
      robustQuadratic => _fitQuadratic(features, targets, weights),
      naturalSplineGam => _fitGam(features, targets, weights),
      shallowBoostedTrees => _fitTrees(features, targets, weights, groupIds),
      constrainedBlend => _fitBlend(
        features,
        targets,
        weights,
        logicalRadiusScales,
        groupIds,
      ),
      _ => throw FormatException('Unknown model candidate: $candidate'),
    };
  }

  static Map<String, Object?> _fitQuadratic(
    List<List<double>> features,
    List<double> targets,
    List<double> weights,
  ) {
    final fitted = _fitHuber(
      <List<double>>[
        for (final row in features) _quadraticBasis(row),
      ],
      targets,
      weights,
      l1: _elasticL1,
      l2: _elasticL2,
    );
    return <String, Object?>{
      'kind': robustQuadratic,
      'intercept': fitted.intercept,
      'coefficients': fitted.coefficients,
    };
  }

  static Map<String, Object?> _fitGam(
    List<List<double>> features,
    List<double> targets,
    List<double> weights,
  ) {
    final knots = <List<double>>[];
    for (var feature = 0; feature < features.first.length; feature += 1) {
      final values = <double>[
        for (final row in features) row[feature],
      ];
      final featureKnots = <double>[
        for (final quantile in const <double>[0.05, 0.35, 0.65, 0.95]) _weightedQuantile(values, weights, quantile),
      ];
      knots.add(
        featureKnots.toSet().length == 4 ? featureKnots : const <double>[],
      );
    }
    final fitted = _fitHuber(
      <List<double>>[
        for (final row in features) _gamBasis(row, knots),
      ],
      targets,
      weights,
      l1: 0,
      l2: _gamL2,
    );
    return <String, Object?>{
      'kind': naturalSplineGam,
      'intercept': fitted.intercept,
      'coefficients': fitted.coefficients,
      'knots': knots,
    };
  }

  static Map<String, Object?> _fitTrees(
    List<List<double>> features,
    List<double> targets,
    List<double> weights,
    List<int> groupIds,
  ) {
    final bias = _weightedQuantile(targets, weights, 0.5);
    final predictions = List<double>.filled(targets.length, bias);
    final trees = <Object?>[];
    final delta =
        1.345 *
        math.max(
          _weightedMedianAbsoluteDeviation(targets, weights),
          0.001,
        );
    final groupCount = groupIds.toSet().length;
    final minimumLeafGroups = groupCount < 6 ? 1 : math.max(2, (groupCount * 0.1).ceil());
    final minimumLeafWeight = weights.reduce((left, right) => left + right) * 0.1;
    for (var round = 0; round < _treeCount; round += 1) {
      final residuals = <double>[
        for (var index = 0; index < targets.length; index += 1)
          (targets[index] - predictions[index]).clamp(-delta, delta),
      ];
      final tree = <num>[];
      _appendTreeNode(
        tree: tree,
        features: features,
        targets: residuals,
        weights: weights,
        groupIds: groupIds,
        indices: List<int>.generate(features.length, (index) => index),
        depth: 0,
        minimumLeafGroups: minimumLeafGroups,
        minimumLeafWeight: minimumLeafWeight,
      );
      trees.add(tree);
      for (var index = 0; index < features.length; index += 1) {
        predictions[index] += _treeLearningRate * _predictTree(tree, features[index]);
      }
    }
    return <String, Object?>{
      'kind': shallowBoostedTrees,
      'bias': bias,
      'learningRate': _treeLearningRate,
      'trees': trees,
    };
  }

  static Map<String, Object?> _fitBlend(
    List<List<double>> features,
    List<double> targets,
    List<double> weights,
    List<double?> logicalRadiusScales,
    List<int> groupIds,
  ) {
    final gam = _fitGam(features, targets, weights);
    final trees = _fitTrees(features, targets, weights, groupIds);
    if (groupIds.toSet().length < 2) {
      return <String, Object?>{
        'kind': constrainedBlend,
        'weight': 0.5,
        'gam': gam,
        'trees': trees,
      };
    }
    final outOfFold = _blendOutOfFoldPredictions(
      features,
      targets,
      weights,
      groupIds,
    );
    final scoredRows = <int>[
      for (var index = 0; index < logicalRadiusScales.length; index += 1)
        if (logicalRadiusScales[index] != null) index,
    ];
    if (scoredRows.isEmpty) {
      return <String, Object?>{
        'kind': constrainedBlend,
        'weight': 0.5,
        'gam': gam,
        'trees': trees,
      };
    }
    var bestWeight = 0.2;
    var bestUpperP95 = double.infinity;
    var bestMacroMae = double.infinity;
    for (var index = 0; index <= 12; index += 1) {
      final weight = 0.2 + 0.05 * index;
      final logicalErrorsByGroup = <int, List<double>>{};
      for (final row in scoredRows) {
        final prediction = weight * outOfFold.gam[row] + (1 - weight) * outOfFold.trees[row];
        logicalErrorsByGroup
            .putIfAbsent(groupIds[row], () => <double>[])
            .add(
              (prediction.clamp(0, 1) - targets[row]).abs() * logicalRadiusScales[row]!,
            );
      }
      final groupedErrors = logicalErrorsByGroup.entries.toList()..sort((left, right) => left.key.compareTo(right.key));
      final upperP95 = _bootstrapUpperP95(
        groupedErrors.map((entry) => entry.value).toList(),
      );
      final macroMae =
          groupedErrors
              .map(
                (entry) => entry.value.reduce((left, right) => left + right) / entry.value.length,
              )
              .reduce((left, right) => left + right) /
          groupedErrors.length;
      if (upperP95 < bestUpperP95 - 1e-12 ||
          ((upperP95 - bestUpperP95).abs() <= 1e-12 && macroMae < bestMacroMae - 1e-12)) {
        bestUpperP95 = upperP95;
        bestMacroMae = macroMae;
        bestWeight = weight;
      }
    }
    return <String, Object?>{
      'kind': constrainedBlend,
      'weight': bestWeight,
      'gam': gam,
      'trees': trees,
    };
  }

  static ({List<double> gam, List<double> trees}) _blendOutOfFoldPredictions(
    List<List<double>> features,
    List<double> targets,
    List<double> weights,
    List<int> groupIds,
  ) {
    final uniqueGroupIds = groupIds.toSet().toList()..sort();
    final foldCount = math.min(5, uniqueGroupIds.length);
    final gamPredictions = List<double>.filled(features.length, 0);
    final treePredictions = List<double>.filled(features.length, 0);
    for (var fold = 0; fold < foldCount; fold += 1) {
      final heldOutGroupIds = <int>{
        for (var index = 0; index < uniqueGroupIds.length; index += 1)
          if (index % foldCount == fold) uniqueGroupIds[index],
      };
      final trainingIndices = <int>[
        for (var index = 0; index < features.length; index += 1)
          if (!heldOutGroupIds.contains(groupIds[index])) index,
      ];
      final heldOutIndices = <int>[
        for (var index = 0; index < features.length; index += 1)
          if (heldOutGroupIds.contains(groupIds[index])) index,
      ];
      final trainingFeatures = <List<double>>[
        for (final index in trainingIndices) features[index],
      ];
      final trainingTargets = <double>[
        for (final index in trainingIndices) targets[index],
      ];
      final trainingWeights = <double>[
        for (final index in trainingIndices) weights[index],
      ];
      final trainingGroupIds = <int>[
        for (final index in trainingIndices) groupIds[index],
      ];
      final normalization = _normalizeTrainingFeatures(
        trainingFeatures,
        trainingWeights,
      );
      final gam = _fitGam(
        normalization.rows,
        trainingTargets,
        trainingWeights,
      );
      final trees = _fitTrees(
        normalization.rows,
        trainingTargets,
        trainingWeights,
        trainingGroupIds,
      );
      for (final index in heldOutIndices) {
        final heldOut = <double>[
          for (var feature = 0; feature < features[index].length; feature += 1)
            (features[index][feature] - normalization.centers[feature]) / normalization.scales[feature],
        ];
        gamPredictions[index] = _predictNormalized(gam, heldOut);
        treePredictions[index] = _predictNormalized(
          trees,
          heldOut,
        );
      }
    }
    return (gam: gamPredictions, trees: treePredictions);
  }

  static double _predictNormalized(
    Map<String, Object?> model,
    List<double> features,
  ) {
    final prediction = switch (model['kind']) {
      robustQuadratic => _linearCombination(
        model,
        _quadraticBasis(features),
      ),
      naturalSplineGam => _linearCombination(
        model,
        _gamBasis(features, _knots(model['knots'])),
      ),
      shallowBoostedTrees => _predictTrees(model, features),
      constrainedBlend =>
        (model['weight']! as num).toDouble() *
                _predictNormalized(
                  model['gam']! as Map<String, Object?>,
                  features,
                ) +
            (1 - (model['weight']! as num).toDouble()) *
                _predictNormalized(
                  model['trees']! as Map<String, Object?>,
                  features,
                ),
      _ => throw FormatException(
        'Unknown serialized candidate kind: ${model['kind']}',
      ),
    };
    return prediction.clamp(0, 1);
  }

  static double _linearCombination(
    Map<String, Object?> model,
    List<double> basis,
  ) {
    final coefficients = _doubleList(model['coefficients']);
    if (basis.length != coefficients.length) {
      throw const FormatException(
        'Serialized candidate coefficients do not match its basis.',
      );
    }
    var result = (model['intercept']! as num).toDouble();
    for (var index = 0; index < basis.length; index += 1) {
      result += coefficients[index] * basis[index];
    }
    return result;
  }

  static double _predictTrees(
    Map<String, Object?> model,
    List<double> features,
  ) {
    var prediction = (model['bias']! as num).toDouble();
    final learningRate = (model['learningRate']! as num).toDouble();
    for (final treeValue in model['trees']! as List<Object?>) {
      prediction += learningRate * _predictTree(_numericList(treeValue), features);
    }
    return prediction;
  }

  static List<double> _quadraticBasis(List<double> features) => <double>[
    ...features,
    for (final feature in features) feature * feature,
  ];

  static List<double> _gamBasis(
    List<double> features,
    List<List<double>> knots,
  ) {
    final result = <double>[];
    for (var feature = 0; feature < features.length; feature += 1) {
      final value = features[feature];
      result.add(value);
      final featureKnots = knots[feature];
      if (featureKnots.length != 4) {
        continue;
      }
      final first = featureKnots.first;
      final secondLast = featureKnots[2];
      final last = featureKnots.last;
      final rangeSquared = (last - first) * (last - first);
      final tailDistance = last - secondLast;
      for (var knot = 0; knot < 2; knot += 1) {
        final current = featureKnots[knot];
        final currentCubic = math.pow(math.max(value - current, 0), 3).toDouble() / rangeSquared;
        final secondLastCubic = math.pow(math.max(value - secondLast, 0), 3).toDouble() / rangeSquared;
        final lastCubic = math.pow(math.max(value - last, 0), 3).toDouble() / rangeSquared;
        result.add(
          currentCubic -
              secondLastCubic * (last - current) / tailDistance +
              lastCubic * (secondLast - current) / tailDistance,
        );
      }
    }
    return result;
  }

  static ({double intercept, List<double> coefficients}) _fitHuber(
    List<List<double>> rows,
    List<double> targets,
    List<double> weights, {
    required double l1,
    required double l2,
  }) {
    var intercept = _weightedQuantile(targets, weights, 0.5);
    final coefficients = List<double>.filled(rows.first.length, 0);
    final totalWeight = weights.reduce((left, right) => left + right);
    final delta =
        1.345 *
        math.max(
          _weightedMedianAbsoluteDeviation(targets, weights),
          0.001,
        );
    var maximumSquaredNorm = 1.0;
    for (final row in rows) {
      var squaredNorm = 0.0;
      for (final value in row) {
        squaredNorm += value * value;
      }
      maximumSquaredNorm = math.max(maximumSquaredNorm, squaredNorm);
    }
    final step = 0.5 / (1 + maximumSquaredNorm + l2);
    for (var iteration = 0; iteration < _solverIterations; iteration += 1) {
      var interceptGradient = 0.0;
      final gradients = List<double>.filled(coefficients.length, 0);
      for (var row = 0; row < rows.length; row += 1) {
        var prediction = intercept;
        for (var coefficient = 0; coefficient < coefficients.length; coefficient += 1) {
          prediction += coefficients[coefficient] * rows[row][coefficient];
        }
        final residual = prediction - targets[row];
        final huberGradient = residual.abs() <= delta ? residual : delta * residual.sign;
        final weightedGradient = weights[row] * huberGradient;
        interceptGradient += weightedGradient;
        for (var coefficient = 0; coefficient < coefficients.length; coefficient += 1) {
          gradients[coefficient] += weightedGradient * rows[row][coefficient];
        }
      }
      final nextIntercept = intercept - step * interceptGradient / totalWeight;
      var maximumChange = (nextIntercept - intercept).abs();
      intercept = nextIntercept;
      for (var coefficient = 0; coefficient < coefficients.length; coefficient += 1) {
        final gradient = gradients[coefficient] / totalWeight + l2 * coefficients[coefficient];
        final next = _softThreshold(
          coefficients[coefficient] - step * gradient,
          step * l1,
        );
        maximumChange = math.max(
          maximumChange,
          (next - coefficients[coefficient]).abs(),
        );
        coefficients[coefficient] = next;
      }
      if (maximumChange < 1e-10) {
        break;
      }
    }
    return (intercept: intercept, coefficients: coefficients);
  }

  static int _appendTreeNode({
    required List<num> tree,
    required List<List<double>> features,
    required List<double> targets,
    required List<double> weights,
    required List<int> groupIds,
    required List<int> indices,
    required int depth,
    required int minimumLeafGroups,
    required double minimumLeafWeight,
  }) {
    final nodeIndex = tree.length ~/ 5;
    final leafValue = _weightedMean(targets, weights, indices);
    final split =
        depth >= 2 ||
            _distinctGroupCount(groupIds, indices) < minimumLeafGroups * 2 ||
            _weightSum(weights, indices) < minimumLeafWeight * 2
        ? null
        : _bestSplit(
            features: features,
            targets: targets,
            weights: weights,
            groupIds: groupIds,
            indices: indices,
            minimumLeafGroups: minimumLeafGroups,
            minimumLeafWeight: minimumLeafWeight,
          );
    if (split == null) {
      tree.addAll(<num>[-1, 0, -1, -1, leafValue]);
      return nodeIndex;
    }
    tree.addAll(<num>[split.feature, split.threshold, -1, -1, leafValue]);
    final left = _appendTreeNode(
      tree: tree,
      features: features,
      targets: targets,
      weights: weights,
      groupIds: groupIds,
      indices: split.left,
      depth: depth + 1,
      minimumLeafGroups: minimumLeafGroups,
      minimumLeafWeight: minimumLeafWeight,
    );
    final right = _appendTreeNode(
      tree: tree,
      features: features,
      targets: targets,
      weights: weights,
      groupIds: groupIds,
      indices: split.right,
      depth: depth + 1,
      minimumLeafGroups: minimumLeafGroups,
      minimumLeafWeight: minimumLeafWeight,
    );
    tree[nodeIndex * 5 + 2] = left;
    tree[nodeIndex * 5 + 3] = right;
    return nodeIndex;
  }

  static ({
    int feature,
    double threshold,
    List<int> left,
    List<int> right,
  })?
  _bestSplit({
    required List<List<double>> features,
    required List<double> targets,
    required List<double> weights,
    required List<int> groupIds,
    required List<int> indices,
    required int minimumLeafGroups,
    required double minimumLeafWeight,
  }) {
    final parentLoss = _weightedSquaredError(
      targets,
      weights,
      indices,
    );
    var bestGain = 1e-12;
    ({
      int feature,
      double threshold,
      List<int> left,
      List<int> right,
    })?
    best;
    for (var feature = 0; feature < features.first.length; feature += 1) {
      final values = indices.map((index) => features[index][feature]).toSet().toList()..sort();
      for (var value = 0; value < values.length - 1; value += 1) {
        final threshold = (values[value] + values[value + 1]) / 2;
        final left = <int>[];
        final right = <int>[];
        for (final index in indices) {
          (features[index][feature] <= threshold ? left : right).add(index);
        }
        if (_distinctGroupCount(groupIds, left) < minimumLeafGroups ||
            _distinctGroupCount(groupIds, right) < minimumLeafGroups ||
            _weightSum(weights, left) < minimumLeafWeight ||
            _weightSum(weights, right) < minimumLeafWeight) {
          continue;
        }
        final gain =
            parentLoss - _weightedSquaredError(targets, weights, left) - _weightedSquaredError(targets, weights, right);
        if (gain > bestGain + 1e-12) {
          bestGain = gain;
          best = (
            feature: feature,
            threshold: threshold,
            left: left,
            right: right,
          );
        }
      }
    }
    return best;
  }

  static double _predictTree(List<num> tree, List<double> features) {
    var node = 0;
    while (true) {
      final offset = node * 5;
      final feature = tree[offset].toInt();
      if (feature == -1) {
        return tree[offset + 4].toDouble();
      }
      final threshold = tree[offset + 1].toDouble();
      node = features[feature] <= threshold ? tree[offset + 2].toInt() : tree[offset + 3].toInt();
    }
  }

  static double _weightedSquaredError(
    List<double> targets,
    List<double> weights,
    List<int> indices,
  ) {
    final mean = _weightedMean(targets, weights, indices);
    var result = 0.0;
    for (final index in indices) {
      final residual = targets[index] - mean;
      result += weights[index] * residual * residual;
    }
    return result;
  }

  static int _distinctGroupCount(
    List<int> groupIds,
    List<int> indices,
  ) => indices.map((index) => groupIds[index]).toSet().length;

  static double _weightSum(List<double> weights, List<int> indices) {
    var result = 0.0;
    for (final index in indices) {
      result += weights[index];
    }
    return result;
  }

  static double _weightedMean(
    List<double> values,
    List<double> weights,
    List<int> indices,
  ) {
    var weightedSum = 0.0;
    var totalWeight = 0.0;
    for (final index in indices) {
      weightedSum += values[index] * weights[index];
      totalWeight += weights[index];
    }
    if (totalWeight > 0) {
      return weightedSum / totalWeight;
    }
    return indices.map((index) => values[index]).reduce((left, right) => left + right) / indices.length;
  }

  static double _weightedMedianAbsoluteDeviation(
    List<double> values,
    List<double> weights,
  ) {
    final median = _weightedQuantile(values, weights, 0.5);
    return _weightedQuantile(
      <double>[
        for (final value in values) (value - median).abs(),
      ],
      weights,
      0.5,
    );
  }

  static double _weightedQuantile(
    List<double> values,
    List<double> weights,
    double quantile,
  ) {
    final indices = List<int>.generate(values.length, (index) => index)
      ..sort((left, right) {
        final comparison = values[left].compareTo(values[right]);
        return comparison == 0 ? left.compareTo(right) : comparison;
      });
    final totalWeight = weights.reduce((left, right) => left + right);
    final threshold = quantile * totalWeight;
    var cumulativeWeight = 0.0;
    for (final index in indices) {
      cumulativeWeight += weights[index];
      if (cumulativeWeight >= threshold) {
        return values[index];
      }
    }
    return values[indices.last];
  }

  static double _softThreshold(double value, double threshold) {
    if (value > threshold) {
      return value - threshold;
    }
    if (value < -threshold) {
      return value + threshold;
    }
    return 0;
  }

  static List<double?> _validatedLogicalScales(
    List<double?>? values, {
    required int rowCount,
  }) {
    final result = values ?? List<double?>.filled(rowCount, 1);
    if (result.length != rowCount ||
        result.whereType<double>().any(
          (value) => !value.isFinite || value <= 0,
        )) {
      throw const FormatException(
        'Logical-radius scales must be positive finite values or null.',
      );
    }
    return List<double?>.of(result);
  }

  static List<int> _validatedGroupIds(
    List<int>? values, {
    required int rowCount,
  }) {
    final result = values ?? List<int>.generate(rowCount, (index) => index);
    if (result.length != rowCount) {
      throw const FormatException(
        'Candidate group IDs must match the training row count.',
      );
    }
    return List<int>.of(result);
  }

  static double _bootstrapUpperP95(List<List<double>> errorsByGroup) {
    var state = 0x5eed1234;
    final p95Values = <double>[];
    for (var repetition = 0; repetition < 1000; repetition += 1) {
      final sample = <double>[];
      for (var index = 0; index < errorsByGroup.length; index += 1) {
        state = ((1664525 * state) + 1013904223) & 0xffffffff;
        sample.addAll(errorsByGroup[state % errorsByGroup.length]);
      }
      sample.sort();
      p95Values.add(sample[((sample.length - 1) * 0.95).ceil()]);
    }
    p95Values.sort();
    return p95Values[((p95Values.length - 1) * 0.95).ceil()];
  }

  static List<double> _doubleList(Object? value) =>
      (value! as List<Object?>).map((item) => (item! as num).toDouble()).toList();

  static List<num> _numericList(Object? value) => (value! as List<Object?>).map((item) => item! as num).toList();

  static List<List<double>> _knots(Object? value) => (value! as List<Object?>).map(_doubleList).toList();
}
