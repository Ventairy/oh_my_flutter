part of '../device_display_model.dart';

final class _DeviceDisplayModelAlgorithms {
  static const featureNames = <String>[
    'logDisplayAspectRatio',
    'logPhysicalShortSide',
    'logLogicalShortSide',
    'logDevicePixelRatio',
    'viewportCoverage',
    'maximumViewPaddingDiameterFraction',
    'naturalTopPaddingDiameterFraction',
    'naturalBottomPaddingDiameterFraction',
    'maximumGestureInsetDiameterFraction',
    'cutoutWidthFraction',
    'cutoutHeightFraction',
    'cutoutCountFraction',
    'devicePixelRatioMissing',
    'viewSizeMissing',
    'viewPaddingMissing',
    'systemGestureInsetsMissing',
    'displayCutoutMissing',
  ];

  List<double> features(Map<String, Object?> record) {
    final width = (record['physicalWidth']! as num).toDouble();
    final height = (record['physicalHeight']! as num).toDouble();
    final shortSide = math.min(width, height);
    final longSide = math.max(width, height);
    final isLandscape = width > height;
    final densityValue = (record['devicePixelRatio'] as num?)?.toDouble();
    final density = densityValue ?? 1;
    final viewWidthValue = (record['viewPhysicalWidth'] as num?)?.toDouble();
    final viewHeightValue = (record['viewPhysicalHeight'] as num?)?.toDouble();
    final viewWidth = viewWidthValue ?? width;
    final viewHeight = viewHeightValue ?? height;
    final paddingLeftValue = (record['viewPaddingLeftPhysical'] as num?)?.toDouble();
    final paddingTopValue = (record['viewPaddingTopPhysical'] as num?)?.toDouble();
    final paddingRightValue = (record['viewPaddingRightPhysical'] as num?)?.toDouble();
    final paddingBottomValue = (record['viewPaddingBottomPhysical'] as num?)?.toDouble();
    final gestureLeftValue = (record['systemGestureInsetLeftPhysical'] as num?)?.toDouble();
    final gestureTopValue = (record['systemGestureInsetTopPhysical'] as num?)?.toDouble();
    final gestureRightValue = (record['systemGestureInsetRightPhysical'] as num?)?.toDouble();
    final gestureBottomValue = (record['systemGestureInsetBottomPhysical'] as num?)?.toDouble();
    final cutoutWidthValue = (record['displayCutoutWidthPhysical'] as num?)?.toDouble();
    final cutoutHeightValue = (record['displayCutoutHeightPhysical'] as num?)?.toDouble();
    final cutoutCountValue = (record['displayCutoutCount'] as num?)?.toDouble();
    final paddingLeft = paddingLeftValue ?? 0;
    final paddingTop = paddingTopValue ?? 0;
    final paddingRight = paddingRightValue ?? 0;
    final paddingBottom = paddingBottomValue ?? 0;
    final gestureInsets = <double>[
      gestureTopValue ?? 0,
      gestureBottomValue ?? 0,
      gestureLeftValue ?? 0,
      gestureRightValue ?? 0,
    ];
    final allPadding = <double>[
      paddingTop,
      paddingBottom,
      paddingLeft,
      paddingRight,
    ];
    final leadingPadding = isLandscape ? paddingLeft : paddingTop;
    final trailingPadding = isLandscape ? paddingRight : paddingBottom;
    final isIos = record['platform'] == 'ios';
    final naturalTopPadding = isIos ? math.max(leadingPadding, trailingPadding) : leadingPadding;
    final naturalBottomPadding = isIos ? math.min(leadingPadding, trailingPadding) : trailingPadding;
    final naturalCutoutWidth = isLandscape ? cutoutHeightValue : cutoutWidthValue;
    final naturalCutoutHeight = isLandscape ? cutoutWidthValue : cutoutHeightValue;
    return <double>[
      math.log(longSide / shortSide),
      math.log(shortSide),
      math.log(shortSide / density),
      math.log(density),
      (viewWidth * viewHeight) / (width * height),
      2 * allPadding.reduce(math.max) / shortSide,
      2 * naturalTopPadding / shortSide,
      2 * naturalBottomPadding / shortSide,
      2 * gestureInsets.reduce(math.max) / shortSide,
      (naturalCutoutWidth ?? 0) / shortSide,
      (naturalCutoutHeight ?? 0) / shortSide,
      ((cutoutCountValue ?? 0) / 4).clamp(0, 1),
      _missingIndicator(densityValue == null),
      _missingIndicator(viewWidthValue == null || viewHeightValue == null),
      _missingIndicator(
        <double?>[
          paddingLeftValue,
          paddingTopValue,
          paddingRightValue,
          paddingBottomValue,
        ].any((value) => value == null),
      ),
      _missingIndicator(
        <double?>[
          gestureLeftValue,
          gestureTopValue,
          gestureRightValue,
          gestureBottomValue,
        ].any((value) => value == null),
      ),
      _missingIndicator(
        cutoutWidthValue == null || cutoutHeightValue == null || cutoutCountValue == null,
      ),
    ];
  }

  double _missingIndicator(bool isMissing) => isMissing ? 1 : 0;

  Map<String, Object?> featureSchema(
    Iterable<Map<String, Object?>> groups,
  ) {
    final rows = groups.toList();
    final weights = rows.map(_rowWeight).toList();
    final medians = <double>[];
    final madScales = <double>[];
    for (var feature = 0; feature < featureNames.length; feature += 1) {
      final values = rows.map((row) => (row['features']! as List<double>)[feature]).toList();
      final median = _weightedQuantile(values, weights, 0.5);
      final deviations = values.map((value) => (value - median).abs()).toList();
      medians.add(median);
      final scaledMad = 1.4826 * _weightedQuantile(deviations, weights, 0.5);
      madScales.add(scaledMad < 1e-6 ? 1.0 : scaledMad);
    }
    final provisional = <String, Object?>{
      'names': featureNames,
      'medians': medians,
      'madScales': madScales,
      'missingDefaults': medians,
    };
    final distances = rows
        .map(
          (row) => featureDistance(
            row['features']! as List<double>,
            provisional,
          ),
        )
        .toList();
    final inner = distances.isEmpty ? 0.0 : _weightedQuantile(distances, weights, 0.95);
    final maximum = distances.isEmpty ? 0.0 : distances.reduce(math.max);
    return <String, Object?>{
      ...provisional,
      'distanceInner': inner,
      'distanceOuter': math.max(maximum, inner + 1),
    };
  }

  double featureDistance(
    List<double> features,
    Map<String, Object?> schema,
  ) {
    final medians = (schema['medians']! as List<Object?>).map((value) => (value! as num).toDouble()).toList();
    final scales = (schema['madScales']! as List<Object?>).map((value) => (value! as num).toDouble()).toList();
    var sum = 0.0;
    for (var index = 0; index < features.length; index += 1) {
      final standardized = (features[index] - medians[index]) / scales[index];
      sum += standardized * standardized;
    }
    return math.sqrt(sum / features.length);
  }

  Map<String, Object?> fitModel(
    String candidate,
    List<Map<String, Object?>> groups, {
    required String targetKey,
  }) {
    final schema = featureSchema(groups);
    return switch (candidate) {
      'zero_baseline' => <String, Object?>{
        'kind': 'zero',
      },
      'safe_inset_baseline' => <String, Object?>{
        'kind': 'safe_inset',
      },
      'platform_median_logical_radius' => _fitLogicalRadiusMedian(
        groups,
        targetKey: targetKey,
      ),
      'shortest_side_formula' => <String, Object?>{
        'kind': 'shortest_side',
        'normalizedDiameter': _weightedQuantile(
          groups.map((group) => group[targetKey]! as double).toList(),
          groups.map(_rowWeight).toList(),
          0.5,
        ),
      },
      'median_normalized_diameter' => <String, Object?>{
        'kind': 'median',
        'intercept': _weightedQuantile(
          groups.map((group) => group[targetKey]! as double).toList(),
          groups.map(_rowWeight).toList(),
          0.5,
        ),
      },
      'linear_aspect_regression' => _fitLinear(
        groups,
        targetKey: targetKey,
        schema: schema,
      ),
      'robust_quadratic_regression' => _fitQuadratic(
        groups,
        targetKey: targetKey,
        schema: schema,
      ),
      'spline_gam' => _fitGam(
        groups,
        targetKey: targetKey,
        schema: schema,
      ),
      'shallow_boosted_tree' => _fitTrees(
        groups,
        targetKey: targetKey,
        schema: schema,
      ),
      'constrained_blend' => _fitBlend(
        groups,
        targetKey: targetKey,
        schema: schema,
      ),
      _ => throw FormatException('Unknown model candidate: $candidate'),
    };
  }

  double predictModel(
    Map<String, Object?> model,
    List<double> features, {
    double safeInsetPrediction = 0,
  }) {
    final kind = model['kind']! as String;
    if (kind == 'zero') {
      return 0;
    }
    if (kind == 'safe_inset') {
      return safeInsetPrediction.clamp(0, 1);
    }
    if (kind == 'median') {
      return (model['intercept']! as num).toDouble().clamp(0, 1);
    }
    if (kind == 'shortest_side') {
      return (model['normalizedDiameter']! as num).toDouble().clamp(0, 1);
    }
    if (kind == 'logical_radius_median') {
      final logicalShortSide = math.exp(features[2]);
      return (2 * (model['logicalRadius']! as num).toDouble() / logicalShortSide).clamp(0, 1);
    }
    final schema = model['featureSchema']! as Map<String, Object?>;
    final standardized = _standardize(features, schema);
    final prediction = switch (kind) {
      'linear' => _linearPrediction(model, standardized),
      'quadratic' => _basisPrediction(
        model,
        _quadraticBasis(standardized),
      ),
      'gam' => _basisPrediction(
        model,
        _gamBasis(
          standardized,
          (model['knots']! as List<Object?>)
              .map(
                (value) => (value! as List<Object?>).map((knot) => (knot! as num).toDouble()).toList(),
              )
              .toList(),
        ),
      ),
      'trees' => _treesPrediction(model, standardized),
      'blend' => _blendPrediction(model, features),
      _ => throw FormatException('Unknown serialized model kind: $kind'),
    };
    return prediction.clamp(0, 1);
  }

  Map<String, Object?> fitGate(
    List<Map<String, Object?>> groups, {
    String targetKey = 'roundedTarget',
  }) {
    if (groups.isEmpty) {
      return <String, Object?>{
        'kind': 'constant_logistic',
        'fitted': false,
        'priorProbability': 0.5,
        'threshold': 0.5,
        'intercept': 0.0,
        'coefficients': const <double>[],
      };
    }
    final weights = groups.map(_rowWeight).toList();
    final groupIds = <Object?>{
      for (var index = 0; index < groups.length; index += 1) groups[index]['fitGroupId'] ?? index,
    };
    final roundedGroupIds = <Object?>{
      for (var index = 0; index < groups.length; index += 1)
        if (groups[index][targetKey] == 1.0) groups[index]['fitGroupId'] ?? index,
    };
    final squareGroupIds = <Object?>{
      for (var index = 0; index < groups.length; index += 1)
        if (groups[index][targetKey] == 0.0) groups[index]['fitGroupId'] ?? index,
    };
    final totalWeight = weights.reduce((left, right) => left + right);
    var roundedWeight = 0.0;
    for (var index = 0; index < groups.length; index += 1) {
      roundedWeight += weights[index] * (groups[index][targetKey]! as double);
    }
    final prior = (roundedWeight + 1) / (totalWeight + 2);
    if (roundedGroupIds.isEmpty || squareGroupIds.isEmpty || groupIds.length < 2) {
      return <String, Object?>{
        'kind': 'constant_logistic',
        'fitted': false,
        'priorProbability': prior,
        'threshold': 0.5,
        'intercept': _logit(prior),
        'coefficients': const <double>[],
      };
    }
    final schema = featureSchema(groups);
    final rows = groups
        .map((group) => _quadraticBasis(_standardize(group['features']! as List<double>, schema)))
        .toList();
    var intercept = _logit(prior);
    final coefficients = List<double>.filled(rows.first.length, 0);
    const step = 0.02;
    const l1 = 0.0005;
    const l2 = 0.005;
    for (var iteration = 0; iteration < 600; iteration += 1) {
      var interceptGradient = 0.0;
      final gradients = List<double>.filled(coefficients.length, 0);
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
        final probability = _sigmoid(
          intercept + _dot(coefficients, rows[rowIndex]),
        );
        final residual = probability - (groups[rowIndex][targetKey]! as double);
        final weightedResidual = weights[rowIndex] * residual;
        interceptGradient += weightedResidual;
        for (var coefficient = 0; coefficient < coefficients.length; coefficient += 1) {
          gradients[coefficient] += weightedResidual * rows[rowIndex][coefficient];
        }
      }
      intercept -= step * interceptGradient / totalWeight;
      for (var coefficient = 0; coefficient < coefficients.length; coefficient += 1) {
        final gradient = gradients[coefficient] / totalWeight + l2 * coefficients[coefficient];
        coefficients[coefficient] = _softThreshold(
          coefficients[coefficient] - step * gradient,
          step * l1,
        );
      }
    }
    return <String, Object?>{
      'kind': 'quadratic_logistic',
      'fitted': true,
      'priorProbability': prior,
      'threshold': 0.5,
      'intercept': intercept,
      'coefficients': coefficients,
      'featureSchema': schema,
    };
  }

  double predictGate(
    Map<String, Object?> gate,
    List<double> features,
  ) {
    if (gate['fitted'] != true) {
      return (gate['priorProbability']! as num).toDouble();
    }
    final schema = gate['featureSchema']! as Map<String, Object?>;
    final basis = _quadraticBasis(_standardize(features, schema));
    final coefficients = (gate['coefficients']! as List<Object?>).map((value) => (value! as num).toDouble()).toList();
    return _sigmoid(
      (gate['intercept']! as num).toDouble() + _dot(coefficients, basis),
    );
  }

  int inferenceOperationCount(Map<String, Object?> model) {
    return switch (model['kind']) {
      'zero' => 0,
      'safe_inset' => 1,
      'median' => 1,
      'shortest_side' => 1,
      'logical_radius_median' => 3,
      'linear' => 2 * ((model['coefficients']! as List<Object?>).length),
      'quadratic' || 'gam' => 3 * ((model['coefficients']! as List<Object?>).length),
      'trees' => 8 * 6,
      'blend' =>
        inferenceOperationCount(model['gam']! as Map<String, Object?>) +
            inferenceOperationCount(model['trees']! as Map<String, Object?>) +
            3,
      _ => 1000000,
    };
  }

  Map<String, Object?> _fitLinear(
    List<Map<String, Object?>> groups, {
    required String targetKey,
    required Map<String, Object?> schema,
  }) {
    final rows = groups.map((group) => _standardize(group['features']! as List<double>, schema)).toList();
    final targets = groups.map((group) => group[targetKey]! as double).toList();
    final weights = groups.map(_rowWeight).toList();
    final x = rows.map((row) => row.first).toList();
    final totalWeight = weights.reduce((left, right) => left + right);
    var meanX = 0.0;
    var meanY = 0.0;
    for (var index = 0; index < x.length; index += 1) {
      meanX += weights[index] * x[index];
      meanY += weights[index] * targets[index];
    }
    meanX /= totalWeight;
    meanY /= totalWeight;
    var covariance = 0.0;
    var variance = 0.0;
    for (var index = 0; index < x.length; index += 1) {
      covariance += weights[index] * (x[index] - meanX) * (targets[index] - meanY);
      variance += weights[index] * (x[index] - meanX) * (x[index] - meanX);
    }
    final slope = variance == 0 ? 0.0 : covariance / variance;
    return <String, Object?>{
      'kind': 'linear',
      'intercept': meanY - slope * meanX,
      'coefficients': <double>[
        slope,
        ...List<double>.filled(featureNames.length - 1, 0),
      ],
      'featureSchema': schema,
    };
  }

  Map<String, Object?> _fitLogicalRadiusMedian(
    List<Map<String, Object?>> rows, {
    required String targetKey,
  }) {
    final logicalRows = rows
        .where(
          (row) => (row['logicalRadiusScale'] as double?)?.isFinite ?? false,
        )
        .toList();
    if (logicalRows.isEmpty) {
      return <String, Object?>{
        'kind': 'logical_radius_median',
        'logicalRadius': 0.0,
      };
    }
    final countsByGroup = <Object?, int>{};
    for (var index = 0; index < logicalRows.length; index += 1) {
      final group = logicalRows[index]['fitGroupId'] ?? index;
      countsByGroup.update(group, (count) => count + 1, ifAbsent: () => 1);
    }
    return <String, Object?>{
      'kind': 'logical_radius_median',
      'logicalRadius': _weightedQuantile(
        <double>[
          for (final row in logicalRows) (row[targetKey]! as double) * (row['logicalRadiusScale']! as double),
        ],
        <double>[
          for (var index = 0; index < logicalRows.length; index += 1)
            1 / (countsByGroup[logicalRows[index]['fitGroupId'] ?? index]!),
        ],
        0.5,
      ),
    };
  }

  Map<String, Object?> _fitQuadratic(
    List<Map<String, Object?>> groups, {
    required String targetKey,
    required Map<String, Object?> schema,
  }) {
    final rows = groups
        .map(
          (group) => _quadraticBasis(
            _standardize(group['features']! as List<double>, schema),
          ),
        )
        .toList();
    final fitted = _fitHuber(rows, groups, targetKey: targetKey, l1: 0.0005, l2: 0.005);
    return <String, Object?>{
      'kind': 'quadratic',
      ...fitted,
      'featureSchema': schema,
    };
  }

  Map<String, Object?> _fitGam(
    List<Map<String, Object?>> groups, {
    required String targetKey,
    required Map<String, Object?> schema,
  }) {
    final standardized = groups.map((group) => _standardize(group['features']! as List<double>, schema)).toList();
    final knots = <List<double>>[];
    for (var feature = 0; feature < featureNames.length; feature += 1) {
      final values = standardized.map((row) => row[feature]).toList()..sort();
      final featureKnots = <double>[
        _percentile(values, 0.05),
        _percentile(values, 0.35),
        _percentile(values, 0.65),
        _percentile(values, 0.95),
      ];
      knots.add(featureKnots.toSet().length == 4 ? featureKnots : const <double>[]);
    }
    final rows = standardized.map((row) => _gamBasis(row, knots)).toList();
    final fitted = _fitHuber(rows, groups, targetKey: targetKey, l1: 0, l2: 0.01);
    return <String, Object?>{
      'kind': 'gam',
      ...fitted,
      'knots': knots,
      'featureSchema': schema,
    };
  }

  Map<String, Object?> _fitTrees(
    List<Map<String, Object?>> groups, {
    required String targetKey,
    required Map<String, Object?> schema,
  }) {
    final rows = groups.map((group) => _standardize(group['features']! as List<double>, schema)).toList();
    final targets = groups.map((group) => group[targetKey]! as double).toList();
    final bias = _median(targets);
    final predictions = List<double>.filled(targets.length, bias);
    final trees = <Object?>[];
    const learningRate = 0.1;
    final delta = 1.345 * math.max(_medianAbsoluteDeviation(targets), 0.001);
    for (var round = 0; round < 8; round += 1) {
      final residuals = <double>[
        for (var index = 0; index < targets.length; index += 1)
          (targets[index] - predictions[index]).clamp(-delta, delta),
      ];
      final tree = _fitTree(
        rows,
        residuals,
        List<int>.generate(rows.length, (index) => index),
        depth: 0,
        minimumLeaf: math.max(3, (groups.length * 0.1).ceil()),
      );
      trees.add(tree);
      for (var index = 0; index < rows.length; index += 1) {
        predictions[index] += learningRate * _predictTree(tree, rows[index]);
      }
    }
    return <String, Object?>{
      'kind': 'trees',
      'bias': bias,
      'learningRate': learningRate,
      'trees': trees,
      'featureSchema': schema,
    };
  }

  Map<String, Object?> _fitBlend(
    List<Map<String, Object?>> groups, {
    required String targetKey,
    required Map<String, Object?> schema,
  }) {
    final errorsByWeight = <double, List<double>>{
      for (var step = 4; step <= 16; step += 1) step / 20: <double>[],
    };
    final foldCount = math.min(5, groups.length);
    for (var fold = 0; fold < foldCount; fold += 1) {
      final training = <Map<String, Object?>>[];
      final validation = <Map<String, Object?>>[];
      for (var index = 0; index < groups.length; index += 1) {
        (index % foldCount == fold ? validation : training).add(groups[index]);
      }
      final foldSchema = featureSchema(training);
      final gam = _fitGam(training, targetKey: targetKey, schema: foldSchema);
      final trees = _fitTrees(training, targetKey: targetKey, schema: foldSchema);
      for (final row in validation) {
        final features = row['features']! as List<double>;
        final target = row[targetKey]! as double;
        final scale = row['logicalRadiusScale']! as double;
        final gamPrediction = predictModel(gam, features);
        final treePrediction = predictModel(trees, features);
        for (final entry in errorsByWeight.entries) {
          final prediction = entry.key * gamPrediction + (1 - entry.key) * treePrediction;
          entry.value.add((prediction - target).abs() * scale);
        }
      }
    }
    var selectedWeight = 0.5;
    var selectedP95 = double.infinity;
    for (final entry in errorsByWeight.entries) {
      entry.value.sort();
      final p95 = entry.value.isEmpty ? double.infinity : _percentile(entry.value, 0.95);
      if (p95 < selectedP95) {
        selectedP95 = p95;
        selectedWeight = entry.key;
      }
    }
    return <String, Object?>{
      'kind': 'blend',
      'weight': selectedWeight,
      'gam': _fitGam(groups, targetKey: targetKey, schema: schema),
      'trees': _fitTrees(groups, targetKey: targetKey, schema: schema),
      'featureSchema': schema,
    };
  }

  Map<String, Object?> _fitHuber(
    List<List<double>> rows,
    List<Map<String, Object?>> groups, {
    required String targetKey,
    required double l1,
    required double l2,
  }) {
    final targets = groups.map((group) => group[targetKey]! as double).toList();
    var intercept = _median(targets);
    final coefficients = List<double>.filled(rows.first.length, 0);
    final delta = 1.345 * math.max(_medianAbsoluteDeviation(targets), 0.001);
    final step = 0.03 / math.sqrt(coefficients.length);
    for (var iteration = 0; iteration < 800; iteration += 1) {
      var interceptGradient = 0.0;
      final gradients = List<double>.filled(coefficients.length, 0);
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
        final residual = (intercept + _dot(coefficients, rows[rowIndex])) - targets[rowIndex];
        final influence = residual.clamp(-delta, delta);
        interceptGradient += influence;
        for (var coefficient = 0; coefficient < coefficients.length; coefficient += 1) {
          gradients[coefficient] += influence * rows[rowIndex][coefficient];
        }
      }
      intercept -= step * interceptGradient / rows.length;
      for (var coefficient = 0; coefficient < coefficients.length; coefficient += 1) {
        final gradient = gradients[coefficient] / rows.length + l2 * coefficients[coefficient];
        coefficients[coefficient] = _softThreshold(
          coefficients[coefficient] - step * gradient,
          step * l1,
        );
      }
    }
    return <String, Object?>{
      'intercept': intercept,
      'coefficients': coefficients,
    };
  }

  Map<String, Object?> _fitTree(
    List<List<double>> rows,
    List<double> residuals,
    List<int> indices, {
    required int depth,
    required int minimumLeaf,
  }) {
    final leafValue = indices.map((index) => residuals[index]).reduce((left, right) => left + right) / indices.length;
    if (depth == 2 || indices.length < minimumLeaf * 2) {
      return <String, Object?>{'feature': -1, 'value': leafValue};
    }
    var bestFeature = -1;
    var bestThreshold = 0.0;
    var bestLoss = double.infinity;
    for (var feature = 0; feature < featureNames.length; feature += 1) {
      final values = indices.map((index) => rows[index][feature]).toSet().toList()..sort();
      for (var valueIndex = 0; valueIndex + 1 < values.length; valueIndex += 1) {
        final threshold = (values[valueIndex] + values[valueIndex + 1]) / 2;
        final left = indices.where((index) => rows[index][feature] <= threshold).toList();
        final right = indices.where((index) => rows[index][feature] > threshold).toList();
        if (left.length < minimumLeaf || right.length < minimumLeaf) {
          continue;
        }
        final loss = _squaredResidualLoss(left, residuals) + _squaredResidualLoss(right, residuals);
        if (loss < bestLoss) {
          bestLoss = loss;
          bestFeature = feature;
          bestThreshold = threshold;
        }
      }
    }
    if (bestFeature == -1) {
      return <String, Object?>{'feature': -1, 'value': leafValue};
    }
    final left = indices.where((index) => rows[index][bestFeature] <= bestThreshold).toList();
    final right = indices.where((index) => rows[index][bestFeature] > bestThreshold).toList();
    return <String, Object?>{
      'feature': bestFeature,
      'threshold': bestThreshold,
      'left': _fitTree(
        rows,
        residuals,
        left,
        depth: depth + 1,
        minimumLeaf: minimumLeaf,
      ),
      'right': _fitTree(
        rows,
        residuals,
        right,
        depth: depth + 1,
        minimumLeaf: minimumLeaf,
      ),
    };
  }

  double _squaredResidualLoss(List<int> indices, List<double> residuals) {
    final mean = indices.map((index) => residuals[index]).reduce((left, right) => left + right) / indices.length;
    return indices
        .map((index) => math.pow(residuals[index] - mean, 2).toDouble())
        .reduce((left, right) => left + right);
  }

  double _predictTree(Map<String, Object?> node, List<double> features) {
    final feature = node['feature']! as int;
    if (feature == -1) {
      return (node['value']! as num).toDouble();
    }
    final child = features[feature] <= (node['threshold']! as num).toDouble() ? node['left'] : node['right'];
    return _predictTree(child! as Map<String, Object?>, features);
  }

  double _treesPrediction(Map<String, Object?> model, List<double> standardized) {
    var prediction = (model['bias']! as num).toDouble();
    final learningRate = (model['learningRate']! as num).toDouble();
    for (final value in model['trees']! as List<Object?>) {
      prediction += learningRate * _predictTree(value! as Map<String, Object?>, standardized);
    }
    return prediction;
  }

  double _blendPrediction(Map<String, Object?> model, List<double> features) {
    final weight = (model['weight']! as num).toDouble();
    return weight * predictModel(model['gam']! as Map<String, Object?>, features) +
        (1 - weight) * predictModel(model['trees']! as Map<String, Object?>, features);
  }

  List<double> _standardize(
    List<double> features,
    Map<String, Object?> schema,
  ) {
    final medians = (schema['medians']! as List<Object?>).map((value) => (value! as num).toDouble()).toList();
    final scales = (schema['madScales']! as List<Object?>).map((value) => (value! as num).toDouble()).toList();
    return <double>[
      for (var index = 0; index < features.length; index += 1) (features[index] - medians[index]) / scales[index],
    ];
  }

  List<double> _quadraticBasis(List<double> standardized) => <double>[
    ...standardized,
    ...standardized.map((value) => value * value),
  ];

  List<double> _gamBasis(
    List<double> standardized,
    List<List<double>> knots,
  ) {
    final basis = <double>[];
    for (var feature = 0; feature < standardized.length; feature += 1) {
      final value = standardized[feature];
      basis.add(value);
      final featureKnots = knots[feature];
      if (featureKnots.length != 4) {
        continue;
      }
      final denominator = featureKnots[3] - featureKnots[2];
      final conditioning = math.pow(featureKnots[3] - featureKnots[0], 2).toDouble();
      for (var knot = 0; knot < 2; knot += 1) {
        final first = math.pow(math.max(value - featureKnots[knot], 0), 3).toDouble();
        final penultimate = math.pow(math.max(value - featureKnots[2], 0), 3).toDouble();
        final last = math.pow(math.max(value - featureKnots[3], 0), 3).toDouble();
        basis.add(
          (first -
                  penultimate * (featureKnots[3] - featureKnots[knot]) / denominator +
                  last * (featureKnots[2] - featureKnots[knot]) / denominator) /
              conditioning,
        );
      }
    }
    return basis;
  }

  double _linearPrediction(Map<String, Object?> model, List<double> standardized) {
    final coefficients = (model['coefficients']! as List<Object?>).map((value) => (value! as num).toDouble()).toList();
    return (model['intercept']! as num).toDouble() + _dot(coefficients, standardized);
  }

  double _basisPrediction(Map<String, Object?> model, List<double> basis) {
    final coefficients = (model['coefficients']! as List<Object?>).map((value) => (value! as num).toDouble()).toList();
    return (model['intercept']! as num).toDouble() + _dot(coefficients, basis);
  }

  double _dot(List<double> left, List<double> right) {
    var result = 0.0;
    for (var index = 0; index < left.length; index += 1) {
      result += left[index] * right[index];
    }
    return result;
  }

  double _medianAbsoluteDeviation(List<double> values) {
    final median = _median(values);
    return _median(values.map((value) => (value - median).abs()).toList());
  }

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _rowWeight(Map<String, Object?> row) => (row['fitWeight'] as num?)?.toDouble() ?? 1;

  double _weightedQuantile(
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

  double _percentile(List<double> sortedValues, double percentile) =>
      sortedValues[((sortedValues.length - 1) * percentile).ceil()];

  double _softThreshold(double value, double threshold) {
    if (value > threshold) {
      return value - threshold;
    }
    if (value < -threshold) {
      return value + threshold;
    }
    return 0;
  }

  double _sigmoid(double value) {
    if (value >= 0) {
      return 1 / (1 + math.exp(-value));
    }
    final exponential = math.exp(value);
    return exponential / (1 + exponential);
  }

  double _logit(double probability) => math.log(probability / (1 - probability));
}
