part of '../device_display_model.dart';

/// Evaluates the complete offline display-radius safety pipeline.
///
/// This tool-only evaluator is kept numerically equivalent to the generated
/// runtime pipeline so deterministic fixtures can detect generation drift.
abstract final class DeviceDisplayModelPipeline {
  static final _algorithms = _DeviceDisplayModelAlgorithms();

  /// Returns a bounded normalized diameter for one serialized head pipeline.
  static double predict({
    required Map<String, Object?> selectedModel,
    required Map<String, Object?>? challengerModel,
    required Map<String, Object?> priorModel,
    required Map<String, Object?> gate,
    required Map<String, Object?> featureSchema,
    required Map<String, Object?> disagreement,
    required List<double> features,
    required double safeInsetDiameter,
    required double logicalRadiusScale,
    required double modelBlendWeight,
    required double distanceTransitionScale,
    required double disagreementTransitionScale,
  }) {
    final selected = _predictModel(
      selectedModel,
      features,
      safeInsetDiameter: safeInsetDiameter,
    );
    final challenger = disagreement['available'] == true && challengerModel != null
        ? _predictModel(
            challengerModel,
            features,
            safeInsetDiameter: safeInsetDiameter,
          )
        : null;
    final support =
        modelBlendWeight *
        math.min(
          _distanceSupportWeight(
            featureSchema,
            features,
            transitionScale: distanceTransitionScale,
          ),
          _disagreementSupportWeight(
            selected: selected,
            challenger: challenger,
            logicalRadiusScale: logicalRadiusScale,
            disagreement: disagreement,
            transitionScale: disagreementTransitionScale,
          ),
        );
    final prior = _predictModel(
      priorModel,
      features,
      safeInsetDiameter: safeInsetDiameter,
    );
    final roundedProbability = _blend(
      _algorithms.predictGate(gate, features),
      prior > 0 ? 1 : 0,
      support,
    );
    if (roundedProbability < (gate['threshold']! as num).toDouble()) {
      return 0;
    }
    return _blend(selected, prior, support).clamp(0, 1);
  }

  static double _predictModel(
    Map<String, Object?> model,
    List<double> features, {
    required double safeInsetDiameter,
  }) {
    if (const <String>{
      DeviceDisplayModelCandidateEngine.robustQuadratic,
      DeviceDisplayModelCandidateEngine.naturalSplineGam,
      DeviceDisplayModelCandidateEngine.shallowBoostedTrees,
      DeviceDisplayModelCandidateEngine.constrainedBlend,
    }.contains(model['kind'])) {
      return DeviceDisplayModelCandidateEngine.predict(
        model: model,
        features: features,
      );
    }
    return _algorithms.predictModel(
      model,
      features,
      safeInsetPrediction: safeInsetDiameter,
    );
  }

  static double _distanceSupportWeight(
    Map<String, Object?> schema,
    List<double> features, {
    required double transitionScale,
  }) {
    final distance = _algorithms.featureDistance(features, schema);
    final inner = (schema['distanceInner']! as num).toDouble() * transitionScale;
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

  static double _disagreementSupportWeight({
    required double selected,
    required double? challenger,
    required double logicalRadiusScale,
    required Map<String, Object?> disagreement,
    required double transitionScale,
  }) {
    if (challenger == null || disagreement['available'] != true) {
      return 1;
    }
    final spread = (selected - challenger).abs() * logicalRadiusScale;
    final inner = (disagreement['logicalPixelP50']! as num).toDouble() * transitionScale;
    final outer = math.max(
      (disagreement['logicalPixelP95']! as num).toDouble() * transitionScale,
      inner + 0.000001,
    );
    if (spread <= inner) {
      return 1;
    }
    if (spread >= outer) {
      return 0;
    }
    return (outer - spread) / (outer - inner);
  }

  static double _blend(
    double selected,
    double prior,
    double support,
  ) => support * selected + (1 - support) * prior;
}
