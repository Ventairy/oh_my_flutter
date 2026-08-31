import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/device_display_model/device_display_model.dart';

void main() {
  final features = <List<double>>[
    for (var index = 0; index < 36; index += 1)
      <double>[
        index / 35,
        ((index * 7) % 36) / 35,
        ((index * 13) % 36) / 35,
      ],
  ];
  final weights = <double>[
    for (var index = 0; index < features.length; index += 1)
      if (index.isEven) 1 else 0.75,
  ];

  group('DeviceDisplayModelCandidateEngine', () {
    test(
      'when one grouped row is available, it should degrade every candidate '
      'to a finite deterministic prediction',
      () {
        final results = <Object?>[];
        for (final candidate in const <String>[
          DeviceDisplayModelCandidateEngine.robustQuadratic,
          DeviceDisplayModelCandidateEngine.naturalSplineGam,
          DeviceDisplayModelCandidateEngine.shallowBoostedTrees,
          DeviceDisplayModelCandidateEngine.constrainedBlend,
        ]) {
          final first = DeviceDisplayModelCandidateEngine.fit(
            candidate: candidate,
            features: const <List<double>>[
              <double>[2.1, 1, 0.08],
            ],
            targets: const <double>[0.16],
          );
          final second = DeviceDisplayModelCandidateEngine.fit(
            candidate: candidate,
            features: const <List<double>>[
              <double>[2.1, 1, 0.08],
            ],
            targets: const <double>[0.16],
          );
          results
            ..add(jsonEncode(first) == jsonEncode(second))
            ..add(
              DeviceDisplayModelCandidateEngine.predict(
                model: first,
                features: const <double>[2.1, 1, 0.08],
              ).isFinite,
            );
        }

        expect(results, List<bool>.filled(8, true));
      },
    );

    test(
      'when quadratic data is fitted twice, it should produce deterministic '
      'elastic-net predictions',
      () {
        final targets = <double>[
          for (final row in features) 0.08 + 0.18 * row[0] + 0.24 * row[1] * row[1],
        ];
        final first = DeviceDisplayModelCandidateEngine.fit(
          candidate: DeviceDisplayModelCandidateEngine.robustQuadratic,
          features: features,
          targets: targets,
          weights: weights,
        );
        final second = DeviceDisplayModelCandidateEngine.fit(
          candidate: DeviceDisplayModelCandidateEngine.robustQuadratic,
          features: features,
          targets: targets,
          weights: weights,
        );
        final low = DeviceDisplayModelCandidateEngine.predict(
          model: first,
          features: const <double>[0.1, 0.1, 0.1],
        );
        final high = DeviceDisplayModelCandidateEngine.predict(
          model: first,
          features: const <double>[0.9, 0.9, 0.1],
        );

        expect(
          <Object?>[
            jsonEncode(first),
            low.isFinite,
            high > low,
          ],
          <Object?>[
            jsonEncode(second),
            true,
            true,
          ],
        );
      },
    );

    test(
      'when curved data is fitted twice, it should produce deterministic '
      'natural-spline predictions',
      () {
        final targets = <double>[
          for (final row in features) 0.1 + 0.14 * row[0] + 0.18 * row[0] * row[0] * row[0],
        ];
        final first = DeviceDisplayModelCandidateEngine.fit(
          candidate: DeviceDisplayModelCandidateEngine.naturalSplineGam,
          features: features,
          targets: targets,
          weights: weights,
        );
        final second = DeviceDisplayModelCandidateEngine.fit(
          candidate: DeviceDisplayModelCandidateEngine.naturalSplineGam,
          features: features,
          targets: targets,
          weights: weights,
        );
        final inner = DeviceDisplayModelCandidateEngine.predict(
          model: first,
          features: const <double>[0.5, 0.5, 0.5],
        );
        final outer = DeviceDisplayModelCandidateEngine.predict(
          model: first,
          features: const <double>[1.1, 0.5, 0.5],
        );
        final fartherOuter = DeviceDisplayModelCandidateEngine.predict(
          model: first,
          features: const <double>[1.2, 0.5, 0.5],
        );
        final farthestOuter = DeviceDisplayModelCandidateEngine.predict(
          model: first,
          features: const <double>[1.3, 0.5, 0.5],
        );
        final outerSecondDifference = farthestOuter - 2 * fartherOuter + outer;

        expect(
          <Object?>[
            jsonEncode(first),
            inner.isFinite,
            outer.isFinite,
            inner != outer,
            outerSecondDifference.abs() < 1e-8,
          ],
          <Object?>[
            jsonEncode(second),
            true,
            true,
            true,
            true,
          ],
        );
      },
    );

    test(
      'when stepped data is fitted twice, it should produce deterministic '
      'depth-two boosted trees',
      () {
        final targets = <double>[
          for (final row in features)
            if (row[0] < 0.33) 0.08 else if (row[1] < 0.55) 0.24 else 0.42,
        ];
        final first = DeviceDisplayModelCandidateEngine.fit(
          candidate: DeviceDisplayModelCandidateEngine.shallowBoostedTrees,
          features: features,
          targets: targets,
          weights: weights,
        );
        final second = DeviceDisplayModelCandidateEngine.fit(
          candidate: DeviceDisplayModelCandidateEngine.shallowBoostedTrees,
          features: features,
          targets: targets,
          weights: weights,
        );
        final trees = first['trees']! as List<Object?>;
        final nodeCounts = trees.map((tree) => (tree! as List<Object?>).length ~/ 5).toList();
        final low = DeviceDisplayModelCandidateEngine.predict(
          model: first,
          features: const <double>[0.1, 0.1, 0.1],
        );
        final high = DeviceDisplayModelCandidateEngine.predict(
          model: first,
          features: const <double>[0.9, 0.9, 0.1],
        );

        expect(
          <Object?>[
            jsonEncode(first),
            nodeCounts.every((count) => count <= 7),
            high > low,
          ],
          <Object?>[
            jsonEncode(second),
            true,
            true,
          ],
        );
      },
    );

    test(
      'when noisy grouped data is fitted twice, it should select a '
      'deterministic out-of-fold constrained blend',
      () {
        final targets = <double>[
          for (var index = 0; index < features.length; index += 1) 0.3 + (((index * 17) % 11) - 5) * 0.04,
        ];
        final first = DeviceDisplayModelCandidateEngine.fit(
          candidate: DeviceDisplayModelCandidateEngine.constrainedBlend,
          features: features,
          targets: targets,
          weights: weights,
        );
        final second = DeviceDisplayModelCandidateEngine.fit(
          candidate: DeviceDisplayModelCandidateEngine.constrainedBlend,
          features: features,
          targets: targets,
          weights: weights,
        );
        final decoded = jsonDecode(jsonEncode(first)) as Map<String, Object?>;
        final blendWeight = (first['weight']! as num).toDouble();
        final gam = <String, Object?>{
          ...(first['gam']! as Map<String, Object?>),
          'featureCenters': first['featureCenters'],
          'featureScales': first['featureScales'],
        };
        final trees = <String, Object?>{
          ...(first['trees']! as Map<String, Object?>),
          'featureCenters': first['featureCenters'],
          'featureScales': first['featureScales'],
        };
        var inSampleWeight = 0.8;
        var inSampleLoss = double.infinity;
        for (var weightIndex = 0; weightIndex <= 12; weightIndex += 1) {
          final weight = 0.8 - 0.05 * weightIndex;
          var loss = 0.0;
          for (var row = 0; row < features.length; row += 1) {
            final gamPrediction = DeviceDisplayModelCandidateEngine.predict(
              model: gam,
              features: features[row],
            );
            final treePrediction = DeviceDisplayModelCandidateEngine.predict(
              model: trees,
              features: features[row],
            );
            final prediction = weight * gamPrediction + (1 - weight) * treePrediction;
            loss += weights[row] * (prediction - targets[row]).abs();
          }
          if (loss < inSampleLoss - 1e-12) {
            inSampleLoss = loss;
            inSampleWeight = weight;
          }
        }
        final prediction = DeviceDisplayModelCandidateEngine.predict(
          model: decoded,
          features: const <double>[0.7, 0.8, 0.2],
        );

        expect(
          <Object?>[
            jsonEncode(first),
            blendWeight >= 0.2 && blendWeight <= 0.8,
            blendWeight != inSampleWeight,
            prediction.isFinite,
            DeviceDisplayModelCandidateEngine.inferenceOperationCount(
                  decoded,
                ) >
                0,
          ],
          <Object?>[
            jsonEncode(second),
            true,
            true,
            true,
            true,
          ],
        );
      },
    );

    test(
      'when rows are duplicated within leakage groups, it should preserve grouped fitting and OOF selection',
      () {
        final groupedFeatures = features.take(12).toList();
        final groupedTargets = <double>[
          for (var index = 0; index < groupedFeatures.length; index += 1)
            0.1 + groupedFeatures[index][0] * 0.2 + (index.isEven ? 0.03 : -0.02),
        ];
        final groupIds = List<int>.generate(
          groupedFeatures.length,
          (index) => index,
        );
        final duplicatedFeatures = <List<double>>[
          for (final row in groupedFeatures) ...<List<double>>[row, row],
        ];
        final duplicatedTargets = <double>[
          for (final target in groupedTargets) ...<double>[target, target],
        ];
        final duplicatedGroupIds = <int>[
          for (final groupId in groupIds) ...<int>[groupId, groupId],
        ];
        final original = DeviceDisplayModelCandidateEngine.fit(
          candidate: DeviceDisplayModelCandidateEngine.constrainedBlend,
          features: groupedFeatures,
          targets: groupedTargets,
          groupIds: groupIds,
        );
        final duplicated = DeviceDisplayModelCandidateEngine.fit(
          candidate: DeviceDisplayModelCandidateEngine.constrainedBlend,
          features: duplicatedFeatures,
          targets: duplicatedTargets,
          weights: List<double>.filled(duplicatedFeatures.length, 0.5),
          groupIds: duplicatedGroupIds,
        );
        const probe = <double>[0.4, 0.6, 0.2];

        expect(
          <Object?>[
            original['weight'],
            DeviceDisplayModelCandidateEngine.predict(
              model: original,
              features: probe,
            ),
          ],
          <Object?>[
            duplicated['weight'],
            closeTo(
              DeviceDisplayModelCandidateEngine.predict(
                model: duplicated,
                features: probe,
              ),
              0.000001,
            ),
          ],
        );
      },
    );
  });
}
