part of '../device_display_model.dart';

final class _DeviceDisplayModelGenerator {
  int modelPayloadByteCount(Map<String, Object?> payload) => utf8.encode(_dartLiteral(payload)).length;

  String generate(Map<String, Object?> manifest) {
    final platforms = manifest['platforms']! as Map<String, Object?>;
    final android = platforms['android']! as Map<String, Object?>;
    final ios = platforms['ios']! as Map<String, Object?>;
    final baseline = manifest['safeInsetBaseline']! as Map<String, Object?>;
    final androidHeads = android['headModels']! as Map<String, Object?>;
    final iosHeads = ios['headModels']! as Map<String, Object?>;
    final androidChallengers = android['challengerHeadModels'] as Map<String, Object?>?;
    final iosChallengers = ios['challengerHeadModels'] as Map<String, Object?>?;
    final androidPrior = android['prior']! as Map<String, Object?>;
    final iosPrior = ios['prior']! as Map<String, Object?>;
    final androidPriorHeads = androidPrior['headModels']! as Map<String, Object?>;
    final iosPriorHeads = iosPrior['headModels']! as Map<String, Object?>;
    final androidClassification = android['classification']! as Map<String, Object?>;
    final iosClassification = ios['classification']! as Map<String, Object?>;
    final androidDisagreement = android['disagreement']! as Map<String, Object?>;
    final iosDisagreement = ios['disagreement']! as Map<String, Object?>;
    final androidSupport = android['support'] as Map<String, Object?>?;
    final iosSupport = ios['support'] as Map<String, Object?>?;
    final iosUsesSafetyPipeline = ios['predictionPipeline'] == 'distance_disagreement_gate_prior_v1';
    final androidUsesSafetyPipeline = android['predictionPipeline'] == 'distance_disagreement_gate_prior_v1';
    final fingerprint = DeviceDisplayModelEncoding.fingerprint(manifest);

    final fallback = <String, Object?>{'kind': 'safe_inset'};
    final zero = <String, Object?>{'kind': 'zero'};
    final iosHead = iosHeads['common'] as Map<String, Object?>? ?? fallback;
    final androidTop = androidHeads['top'] as Map<String, Object?>? ?? fallback;
    final androidBottom = androidHeads['bottom'] as Map<String, Object?>? ?? fallback;
    final iosPriorHead = iosUsesSafetyPipeline ? (iosPriorHeads['common'] as Map<String, Object?>? ?? fallback) : zero;
    final androidTopPrior = androidUsesSafetyPipeline
        ? (androidPriorHeads['top'] as Map<String, Object?>? ?? fallback)
        : zero;
    final androidBottomPrior = androidUsesSafetyPipeline
        ? (androidPriorHeads['bottom'] as Map<String, Object?>? ?? fallback)
        : zero;
    final iosGate = iosUsesSafetyPipeline ? (iosClassification['commonGate'] as Map<String, Object?>? ?? zero) : zero;
    final androidTopGate = androidUsesSafetyPipeline
        ? (androidClassification['topGate'] as Map<String, Object?>? ?? zero)
        : zero;
    final androidBottomGate = androidUsesSafetyPipeline
        ? (androidClassification['bottomGate'] as Map<String, Object?>? ?? zero)
        : zero;
    final iosChallenger = iosUsesSafetyPipeline ? (iosChallengers?['common'] as Map<String, Object?>?) : null;
    final androidTopChallenger = androidUsesSafetyPipeline
        ? (androidChallengers?['top'] as Map<String, Object?>?)
        : null;
    final androidBottomChallenger = androidUsesSafetyPipeline
        ? (androidChallengers?['bottom'] as Map<String, Object?>?)
        : null;
    final iosFeatureSchema = iosUsesSafetyPipeline ? (ios['featureSchema'] as Map<String, Object?>?) : null;
    final androidFeatureSchema = androidUsesSafetyPipeline ? (android['featureSchema'] as Map<String, Object?>?) : null;

    final source =
        '''
// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: tool/device_display_model/model_manifest.json
// Fingerprint: $fingerprint

part of 'device_display_estimator.dart';

final class _DeviceDisplayEstimatorModel {
  static const safeInsetMultiplier = ${_doubleLiteral(baseline['multiplier']!)};
  static const iosCandidateKind = ${_dartLiteral(ios['selectedCandidate'])};
  static const androidCandidateKind = ${_dartLiteral(android['selectedCandidate'])};
  static const _iosUsesSafetyPipeline = $iosUsesSafetyPipeline;
  static const _androidUsesSafetyPipeline = $androidUsesSafetyPipeline;
  static const Map<String, Object?> _iosHead = ${_dartLiteral(iosHead)};
  static const Map<String, Object?> _androidTopHead = ${_dartLiteral(androidTop)};
  static const Map<String, Object?> _androidBottomHead = ${_dartLiteral(androidBottom)};
  static const _iosHasChallenger = ${iosChallenger != null};
  static const _androidTopHasChallenger = ${androidTopChallenger != null};
  static const _androidBottomHasChallenger = ${androidBottomChallenger != null};
  static const Map<String, Object?> _iosChallenger = ${_dartLiteral(iosChallenger ?? zero)};
  static const Map<String, Object?> _androidTopChallenger = ${_dartLiteral(androidTopChallenger ?? zero)};
  static const Map<String, Object?> _androidBottomChallenger = ${_dartLiteral(androidBottomChallenger ?? zero)};
  static const Map<String, Object?> _iosPrior = ${_dartLiteral(iosPriorHead)};
  static const Map<String, Object?> _androidTopPrior = ${_dartLiteral(androidTopPrior)};
  static const Map<String, Object?> _androidBottomPrior = ${_dartLiteral(androidBottomPrior)};
  static const Map<String, Object?> _iosGate = ${_dartLiteral(iosGate)};
  static const Map<String, Object?> _androidTopGate = ${_dartLiteral(androidTopGate)};
  static const Map<String, Object?> _androidBottomGate = ${_dartLiteral(androidBottomGate)};
  static const iosGateThreshold = ${_doubleLiteral(iosGate['threshold'] ?? 0.5)};
  static const androidTopGateThreshold = ${_doubleLiteral(androidTopGate['threshold'] ?? 0.5)};
  static const androidBottomGateThreshold = ${_doubleLiteral(androidBottomGate['threshold'] ?? 0.5)};
  static const iosModelBlendWeight = ${_doubleLiteral(iosSupport?['modelBlendWeight'] ?? 1)};
  static const androidModelBlendWeight = ${_doubleLiteral(androidSupport?['modelBlendWeight'] ?? 1)};
  static const iosDistanceTransitionScale = ${_doubleLiteral(iosSupport?['distanceTransitionScale'] ?? 1)};
  static const androidDistanceTransitionScale = ${_doubleLiteral(androidSupport?['distanceTransitionScale'] ?? 1)};
  static const iosDisagreementTransitionScale = ${_doubleLiteral(iosSupport?['disagreementTransitionScale'] ?? 1)};
  static const androidDisagreementTransitionScale = ${_doubleLiteral(androidSupport?['disagreementTransitionScale'] ?? 1)};
  static const _iosHasFeatureSchema = ${iosFeatureSchema != null};
  static const _androidHasFeatureSchema = ${androidFeatureSchema != null};
  static const Map<String, Object?> _iosFeatureSchema = ${_dartLiteral(iosFeatureSchema ?? const <String, Object?>{})};
  static const Map<String, Object?> _androidFeatureSchema = ${_dartLiteral(androidFeatureSchema ?? const <String, Object?>{})};
  static const iosDisagreementInnerLogicalPixels = ${_doubleLiteral(iosDisagreement['logicalPixelP50'] ?? 0)};
  static const iosDisagreementOuterLogicalPixels = ${_doubleLiteral(iosDisagreement['logicalPixelP95'] ?? 0)};
  static const androidDisagreementInnerLogicalPixels = ${_doubleLiteral(androidDisagreement['logicalPixelP50'] ?? 0)};
  static const androidDisagreementOuterLogicalPixels = ${_doubleLiteral(androidDisagreement['logicalPixelP95'] ?? 0)};

  static bool get hasCandidateKinds =>
      iosCandidateKind.isNotEmpty && androidCandidateKind.isNotEmpty;

  static double iosNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_iosHead, features, safeInsetDiameter);

  static double? iosChallengerNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => !_iosHasChallenger
      ? null
      : _predict(_iosChallenger, features, safeInsetDiameter);

  static double iosPriorNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_iosPrior, features, safeInsetDiameter);

  static double androidTopNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_androidTopHead, features, safeInsetDiameter);

  static double androidBottomNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_androidBottomHead, features, safeInsetDiameter);

  static double? androidTopChallengerNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => !_androidTopHasChallenger
      ? null
      : _predict(_androidTopChallenger, features, safeInsetDiameter);

  static double? androidBottomChallengerNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => !_androidBottomHasChallenger
      ? null
      : _predict(_androidBottomChallenger, features, safeInsetDiameter);

  static double androidTopPriorNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_androidTopPrior, features, safeInsetDiameter);

  static double androidBottomPriorNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_androidBottomPrior, features, safeInsetDiameter);

  static double iosRoundedProbability(List<double> features) =>
      _gateProbability(_iosGate, features);

  static double androidTopRoundedProbability(List<double> features) =>
      _gateProbability(_androidTopGate, features);

  static double androidBottomRoundedProbability(List<double> features) =>
      _gateProbability(_androidBottomGate, features);

  static double iosSupportWeight(List<double> features) =>
      _iosHasFeatureSchema
          ? _distanceSupportWeight(
              _iosFeatureSchema,
              features,
              iosDistanceTransitionScale,
            )
          : 0;

  static double androidSupportWeight(List<double> features) =>
      _androidHasFeatureSchema
          ? _distanceSupportWeight(
              _androidFeatureSchema,
              features,
              androidDistanceTransitionScale,
            )
          : 0;

  static double iosPipelineNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
    required double shortestLogicalSide,
  }) {
    final selected = iosNormalizedDiameter(
      features,
      safeInsetDiameter: safeInsetDiameter,
    );
    if (!_iosUsesSafetyPipeline) {
      return selected;
    }
    return _pipelineNormalizedDiameter(
      selectedDiameter: selected,
      challengerDiameter: iosChallengerNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      priorDiameter: iosPriorNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      roundedProbability: iosRoundedProbability(features),
      gateThreshold: iosGateThreshold,
      modelBlendWeight: iosModelBlendWeight,
      distanceSupport: iosSupportWeight(features),
      shortestLogicalSide: shortestLogicalSide,
      disagreementInnerLogicalPixels:
          iosDisagreementInnerLogicalPixels *
          iosDisagreementTransitionScale,
      disagreementOuterLogicalPixels:
          iosDisagreementOuterLogicalPixels *
          iosDisagreementTransitionScale,
    );
  }

  static double androidTopPipelineNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
    required double shortestLogicalSide,
  }) {
    final selected = androidTopNormalizedDiameter(
      features,
      safeInsetDiameter: safeInsetDiameter,
    );
    if (!_androidUsesSafetyPipeline) {
      return selected;
    }
    return _pipelineNormalizedDiameter(
      selectedDiameter: selected,
      challengerDiameter: androidTopChallengerNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      priorDiameter: androidTopPriorNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      roundedProbability: androidTopRoundedProbability(features),
      gateThreshold: androidTopGateThreshold,
      modelBlendWeight: androidModelBlendWeight,
      distanceSupport: androidSupportWeight(features),
      shortestLogicalSide: shortestLogicalSide,
      disagreementInnerLogicalPixels:
          androidDisagreementInnerLogicalPixels *
          androidDisagreementTransitionScale,
      disagreementOuterLogicalPixels:
          androidDisagreementOuterLogicalPixels *
          androidDisagreementTransitionScale,
    );
  }

  static double androidBottomPipelineNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
    required double shortestLogicalSide,
  }) {
    final selected = androidBottomNormalizedDiameter(
      features,
      safeInsetDiameter: safeInsetDiameter,
    );
    if (!_androidUsesSafetyPipeline) {
      return selected;
    }
    return _pipelineNormalizedDiameter(
      selectedDiameter: selected,
      challengerDiameter: androidBottomChallengerNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      priorDiameter: androidBottomPriorNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      roundedProbability: androidBottomRoundedProbability(features),
      gateThreshold: androidBottomGateThreshold,
      modelBlendWeight: androidModelBlendWeight,
      distanceSupport: androidSupportWeight(features),
      shortestLogicalSide: shortestLogicalSide,
      disagreementInnerLogicalPixels:
          androidDisagreementInnerLogicalPixels *
          androidDisagreementTransitionScale,
      disagreementOuterLogicalPixels:
          androidDisagreementOuterLogicalPixels *
          androidDisagreementTransitionScale,
    );
  }

  static double _pipelineNormalizedDiameter({
    required double selectedDiameter,
    required double? challengerDiameter,
    required double priorDiameter,
    required double roundedProbability,
    required double gateThreshold,
    required double modelBlendWeight,
    required double distanceSupport,
    required double shortestLogicalSide,
    required double disagreementInnerLogicalPixels,
    required double disagreementOuterLogicalPixels,
  }) {
    final support = modelBlendWeight *
        math.min(
          distanceSupport,
          disagreementWeight(
            selectedDiameter: selectedDiameter,
            challengerDiameter: challengerDiameter,
            shortestLogicalSide: shortestLogicalSide,
            innerLogicalPixels: disagreementInnerLogicalPixels,
            outerLogicalPixels: disagreementOuterLogicalPixels,
          ),
        );
    final blendedProbability =
        support * roundedProbability +
        (1 - support) * (priorDiameter > 0 ? 1 : 0);
    if (blendedProbability < gateThreshold) {
      return 0;
    }
    return (support * selectedDiameter + (1 - support) * priorDiameter)
        .clamp(0, 1);
  }

  static double disagreementWeight({
    required double selectedDiameter,
    required double? challengerDiameter,
    required double shortestLogicalSide,
    required double innerLogicalPixels,
    required double outerLogicalPixels,
  }) {
    if (challengerDiameter == null) {
      return 1;
    }
    final logicalSpread =
        (selectedDiameter - challengerDiameter).abs() * shortestLogicalSide / 2;
    if (logicalSpread <= innerLogicalPixels) {
      return 1;
    }
    final outer = math.max(outerLogicalPixels, innerLogicalPixels + 0.000001);
    if (logicalSpread >= outer) {
      return 0;
    }
    return (outer - logicalSpread) / (outer - innerLogicalPixels);
  }

  static double _predict(
    Map<String, Object?> model,
    List<double> features,
    double safeInsetDiameter,
  ) {
    final kind = model['kind']! as String;
    if (kind == 'zero') {
      return 0;
    }
    if (kind == 'safe_inset') {
      return safeInsetDiameter.clamp(0, 1);
    }
    if (kind == 'median') {
      return (model['intercept']! as num).toDouble().clamp(0, 1);
    }
    if (kind == 'shortest_side') {
      return (model['normalizedDiameter']! as num).toDouble().clamp(0, 1);
    }
    if (kind == 'logical_radius_median') {
      final logicalShortSide = math.exp(features[2]);
      return (2 * (model['logicalRadius']! as num).toDouble() /
              logicalShortSide)
          .clamp(0, 1);
    }
    final standardized = _standardize(model, features);
    if (kind == 'linear') {
      return _linearCombination(model, standardized).clamp(0, 1);
    }
    return _predictNormalized(model, standardized).clamp(0, 1);
  }

  static List<double> _standardize(
    Map<String, Object?> model,
    List<double> features,
  ) {
    final schema = model['featureSchema'] as Map<String, Object?>?;
    final centers = (model['featureCenters'] ?? schema?['medians'])!
        as List<Object?>;
    final scales = (model['featureScales'] ?? schema?['madScales'])!
        as List<Object?>;
    return <double>[
      for (var index = 0; index < features.length; index += 1)
        (features[index] - (centers[index]! as num).toDouble()) /
            (scales[index]! as num).toDouble(),
    ];
  }

  static double _predictNormalized(
    Map<String, Object?> model,
    List<double> features,
  ) => switch (model['kind']) {
        'robust_quadratic_regression' =>
          _linearCombination(model, <double>[
            ...features,
            for (final feature in features) feature * feature,
          ]),
        'spline_gam' => _linearCombination(
            model,
            _gamBasis(features, model['knots']! as List<Object?>),
          ),
        'shallow_boosted_tree' => _treeEnsemble(model, features),
        'constrained_blend' =>
          (model['weight']! as num).toDouble() *
                  _predictNormalized(
                    model['gam']! as Map<String, Object?>,
                    features,
                  ).clamp(0, 1) +
              (1 - (model['weight']! as num).toDouble()) *
                  _predictNormalized(
                    model['trees']! as Map<String, Object?>,
                    features,
                  ).clamp(0, 1),
        _ => throw StateError(
            'Unknown generated display-radius model kind: \${model['kind']}',
          ),
      };

  static double _linearCombination(
    Map<String, Object?> model,
    List<double> basis,
  ) {
    final coefficients = model['coefficients']! as List<Object?>;
    var result = (model['intercept']! as num).toDouble();
    for (var index = 0; index < basis.length; index += 1) {
      result += (coefficients[index]! as num).toDouble() * basis[index];
    }
    return result;
  }

  static List<double> _gamBasis(
    List<double> features,
    List<Object?> knots,
  ) {
    final result = <double>[];
    for (var feature = 0; feature < features.length; feature += 1) {
      final value = features[feature];
      result.add(value);
      final featureKnots = knots[feature]! as List<Object?>;
      if (featureKnots.length != 4) {
        continue;
      }
      final first = (featureKnots.first! as num).toDouble();
      final secondLast = (featureKnots[2]! as num).toDouble();
      final last = (featureKnots.last! as num).toDouble();
      final rangeSquared = (last - first) * (last - first);
      final tailDistance = last - secondLast;
      for (var knot = 0; knot < 2; knot += 1) {
        final current = (featureKnots[knot]! as num).toDouble();
        final currentCubic =
            math.pow(math.max(value - current, 0), 3).toDouble() /
                rangeSquared;
        final secondLastCubic =
            math.pow(math.max(value - secondLast, 0), 3).toDouble() /
                rangeSquared;
        final lastCubic =
            math.pow(math.max(value - last, 0), 3).toDouble() /
                rangeSquared;
        result.add(
          currentCubic -
              secondLastCubic * (last - current) / tailDistance +
              lastCubic * (secondLast - current) / tailDistance,
        );
      }
    }
    return result;
  }

  static double _treeEnsemble(
    Map<String, Object?> model,
    List<double> features,
  ) {
    var prediction = (model['bias']! as num).toDouble();
    final rate = (model['learningRate']! as num).toDouble();
    for (final tree in model['trees']! as List<Object?>) {
      prediction += rate * _tree(tree! as List<Object?>, features);
    }
    return prediction;
  }

  static double _tree(List<Object?> tree, List<double> features) {
    var node = 0;
    while (true) {
      final offset = node * 5;
      final feature = (tree[offset]! as num).toInt();
      if (feature == -1) {
        return (tree[offset + 4]! as num).toDouble();
      }
      node = features[feature] <= (tree[offset + 1]! as num).toDouble()
          ? (tree[offset + 2]! as num).toInt()
          : (tree[offset + 3]! as num).toInt();
    }
  }

  static double _gateProbability(
    Map<String, Object?> gate,
    List<double> features,
  ) {
    if (gate['fitted'] != true) {
      return (gate['priorProbability'] as num?)?.toDouble() ?? 1;
    }
    final standardized = _standardize(gate, features);
    final basis = <double>[
      ...standardized,
      for (final feature in standardized) feature * feature,
    ];
    final linear = (gate['intercept']! as num).toDouble() +
        _dot(gate['coefficients']! as List<Object?>, basis);
    if (linear >= 0) {
      return 1 / (1 + math.exp(-linear));
    }
    final exponential = math.exp(linear);
    return exponential / (1 + exponential);
  }

  static double _dot(List<Object?> coefficients, List<double> values) {
    var result = 0.0;
    for (var index = 0; index < values.length; index += 1) {
      result += (coefficients[index]! as num).toDouble() * values[index];
    }
    return result;
  }

  static double _distanceSupportWeight(
    Map<String, Object?> schema,
    List<double> features,
    double transitionScale,
  ) {
    final centers = schema['medians']! as List<Object?>;
    final scales = schema['madScales']! as List<Object?>;
    var squaredDistance = 0.0;
    for (var index = 0; index < features.length; index += 1) {
      final standardized =
          (features[index] - (centers[index]! as num).toDouble()) /
              (scales[index]! as num).toDouble();
      squaredDistance += standardized * standardized;
    }
    final distance = math.sqrt(squaredDistance / features.length);
    final inner =
        (schema['distanceInner']! as num).toDouble() * transitionScale;
    final outer = math.max(
      (schema['distanceOuter']! as num).toDouble() * transitionScale,
      inner + 0.000001,
    );
    if (distance <= inner) {
      return 1;
    }
    if (distance >= outer) {
      return 0;
    }
    return (outer - distance) / (outer - inner);
  }
}
''';
    return _format(source);
  }

  String _format(String source) {
    final directory = Directory.systemTemp.createTempSync(
      'omf-device-display-generator-',
    );
    try {
      final file = File('${directory.path}/device_display_model.g.dart')..writeAsStringSync(source);
      final result = Process.runSync(
        Platform.resolvedExecutable,
        <String>[
          'format',
          '--page-width=120',
          '--trailing-commas=preserve',
          file.path,
        ],
      );
      if (result.exitCode != 0) {
        throw const FormatException(
          'Generated Dart source could not be formatted.',
        );
      }
      return file.readAsStringSync();
    } finally {
      directory.deleteSync(recursive: true);
    }
  }

  String _dartLiteral(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is bool) {
      return value.toString();
    }
    if (value is num) {
      return _doubleLiteral(value);
    }
    if (value is String) {
      return _quotedString(value);
    }
    if (value is List<Object?>) {
      return '<Object?>[${value.map(_dartLiteral).join(', ')}]';
    }
    if (value is Map<String, Object?>) {
      final keys = value.keys.toList()..sort();
      final entries = keys
          .map(
            (key) => '${_dartLiteral(key)}: ${_dartLiteral(value[key])}',
          )
          .join(', ');
      return '<String, Object?>{$entries}';
    }
    throw FormatException('Cannot emit ${value.runtimeType} in a model.');
  }

  String _quotedString(String value) {
    final buffer = StringBuffer()..writeCharCode(39);
    for (final codePoint in value.runes) {
      if (codePoint == 39 || codePoint == 92) {
        buffer
          ..writeCharCode(92)
          ..writeCharCode(codePoint);
        continue;
      }
      if (codePoint == 10 || codePoint == 13) {
        buffer
          ..writeCharCode(92)
          ..writeCharCode(codePoint == 10 ? 110 : 114);
        continue;
      }
      buffer.writeCharCode(codePoint);
    }
    buffer.writeCharCode(39);
    return buffer.toString();
  }

  String _doubleLiteral(Object value) {
    final number = (value as num).toDouble();
    if (!number.isFinite) {
      throw const FormatException('Generated model numbers must be finite.');
    }
    return number.toString();
  }
}
