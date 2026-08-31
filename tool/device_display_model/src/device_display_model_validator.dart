part of '../device_display_model.dart';

final class _DeviceDisplayModelValidator {
  String report(
    Map<String, Object?> corpus,
    Map<String, Object?> manifest,
  ) {
    final inventory = corpus['inventory']! as Map<String, Object?>;
    final androidInventory = inventory['android']! as Map<String, Object?>;
    final appleInventory = inventory['apple']! as Map<String, Object?>;
    final records = (corpus['records']! as List<Object?>).map((value) => value! as Map<String, Object?>).toList();
    final platforms = manifest['platforms']! as Map<String, Object?>;
    final android = platforms['android']! as Map<String, Object?>;
    final ios = platforms['ios']! as Map<String, Object?>;
    final androidAccuracyGatePassed = _androidAccuracyGatePassed(android);
    final iosAccuracyGatePassed = _iosAccuracyGatePassed(ios);
    final maskGroupedRecords = records.where((record) => record['maskCollisionGroupHash'] != null).length;
    final iosRecords = records.where((record) => record['platform'] == 'ios').toList();
    final connectedIosRecordCount = iosRecords
        .where(
          (record) => record['sourceKind'] == 'ios26_connected_public_uikit_concentric_corner',
        )
        .length;
    final simulatorIosRecordCount = iosRecords.length - connectedIosRecordCount;
    final androidRecords = records.where((record) => record['platform'] == 'android').toList();
    final androidCompleteRuntimeFeatureCount = androidRecords
        .where(
          (record) => const <String>[
            'viewPhysicalWidth',
            'viewPhysicalHeight',
            'viewPaddingLeftPhysical',
            'viewPaddingTopPhysical',
            'viewPaddingRightPhysical',
            'viewPaddingBottomPhysical',
            'systemGestureInsetLeftPhysical',
            'systemGestureInsetTopPhysical',
            'systemGestureInsetRightPhysical',
            'systemGestureInsetBottomPhysical',
            'displayCutoutWidthPhysical',
            'displayCutoutHeightPhysical',
            'displayCutoutCount',
          ].every((key) => record[key] != null),
        )
        .length;
    final iosCompleteViewGeometryCount = iosRecords
        .where(
          (record) => const <String>[
            'viewPhysicalWidth',
            'viewPhysicalHeight',
            'viewPaddingLeftPhysical',
            'viewPaddingTopPhysical',
            'viewPaddingRightPhysical',
            'viewPaddingBottomPhysical',
          ].every((key) => record[key] != null),
        )
        .length;
    final iosCompleteGestureEvidenceCount = iosRecords
        .where(
          (record) => const <String>[
            'systemGestureInsetLeftPhysical',
            'systemGestureInsetTopPhysical',
            'systemGestureInsetRightPhysical',
            'systemGestureInsetBottomPhysical',
          ].every((key) => record[key] != null),
        )
        .length;
    final iosCompleteCutoutEvidenceCount = iosRecords
        .where(
          (record) => const <String>[
            'displayCutoutWidthPhysical',
            'displayCutoutHeightPhysical',
            'displayCutoutCount',
          ].every((key) => record[key] != null),
        )
        .length;
    final sourceCounts = <String, int>{};
    for (final record in records) {
      final source = record['sourceKind']! as String;
      sourceCounts[source] = (sourceCounts[source] ?? 0) + 1;
    }

    final buffer = StringBuffer()
      ..writeln('# Device display estimator validation')
      ..writeln()
      ..writeln(
        'This report contains only measurements produced by the committed '
        'corpus and deterministic tooling. Missing accuracy and split results '
        'are reported as n/a; they are never inferred.',
      )
      ..writeln()
      ..writeln('- Corpus fingerprint: `${manifest['corpusFingerprint']}`')
      ..writeln('- Target: `2 * physicalRadius / shortestPhysicalDisplaySide`')
      ..writeln(
        '- Runtime conversion: '
        '`logicalRadius = target * shortestLogicalDisplaySide / 2`',
      )
      ..writeln()
      ..writeln('## Local corpus')
      ..writeln()
      ..writeln('- Total accepted labels: ${records.length}')
      ..writeln('- Android SDK skins enumerated: ${androidInventory['skinCount']}')
      ..writeln(
        '- Android skin labels accepted: ${androidInventory['skinLabelCount']}',
      )
      ..writeln('- Android AVDs enumerated: ${androidInventory['avdCount']}')
      ..writeln(
        '- Skin labels joined to an unambiguous AVD density: '
        '${androidInventory['avdDensityJoinCount']}',
      )
      ..writeln(
        '- Connected Android devices enumerated: '
        '${androidInventory['connectedDeviceCount']}',
      )
      ..writeln(
        '- Connected Android emulators excluded from the physical-device path: '
        '${androidInventory['connectedEmulatorDeviceCount']}',
      )
      ..writeln(
        '- Connected Android eligible physical devices: '
        '${androidInventory['connectedEligibleDeviceCount']}',
      )
      ..writeln(
        '- Connected Android API 31+ exact `WindowInsets` labels accepted: '
        '${androidInventory['connectedExactLabelCount']}',
      )
      ..writeln(
        '- Connected Android positive legacy default-resource labels accepted: '
        '${androidInventory['connectedLegacyLabelCount']}',
      )
      ..writeln(
        '- Connected Android collector source hash: '
        '`${androidInventory['collectorSourceHash'] ?? 'n/a'}`',
      )
      ..writeln(
        '- Xcode simulator device types enumerated: '
        '${appleInventory['deviceTypeCount']}',
      )
      ..writeln(
        '- Xcode iPhone/iPad device types: '
        '${appleInventory['mobileDeviceTypeCount']}',
      )
      ..writeln(
        '- Xcode framebuffer masks audited: '
        '${appleInventory['framebufferMaskCount']}',
      )
      ..writeln(
        '- iOS exact labels accepted: ${appleInventory['exactLabelCount']}',
      )
      ..writeln(
        '- Connected physical iPhones enumerated / eligible / attempted / accepted: '
        '${appleInventory['connectedDeviceCount']} / '
        '${appleInventory['connectedEligibleDeviceCount']} / '
        '${appleInventory['connectedCollectorAttemptCount']} / '
        '${appleInventory['connectedLabelCount']}',
      )
      ..writeln(
        '- Connected-iOS signed collector supplied: '
        '${appleInventory['connectedCollectorAppSupplied']}; source hash '
        '`${appleInventory['connectedCollectorSourceHash'] ?? 'n/a'}`',
      )
      ..writeln(
        '- Android labels with exact runtime-equivalent view/inset/cutout fields: '
        '$androidCompleteRuntimeFeatureCount',
      )
      ..writeln('- Records with anonymous mask grouping: $maskGroupedRecords')
      ..writeln(
        '- iOS labels with explicit view size and four-edge safe-area evidence: '
        '$iosCompleteViewGeometryCount',
      )
      ..writeln(
        '- iOS labels with four-edge system-gesture evidence: '
        '$iosCompleteGestureEvidenceCount',
      )
      ..writeln(
        '- iOS labels with Flutter display-cutout evidence: '
        '$iosCompleteCutoutEvidenceCount',
      )
      ..writeln()
      ..writeln('Accepted source counts:')
      ..writeln();
    for (final source in sourceCounts.keys.toList()..sort()) {
      buffer.writeln('- `$source`: ${sourceCounts[source]}');
    }
    buffer
      ..writeln()
      ..writeln(
        'Framebuffer masks are used only to group possible leakage collisions '
        'and audit completeness. They are never radius labels. '
        '${maskGroupedRecords == 0
            ? 'Mask grouping is unavailable for this committed corpus.'
            : maskGroupedRecords == iosRecords.length
            ? 'Every committed iOS record is mask-grouped and unioned before each outer fold.'
            : 'The $maskGroupedRecords mask-grouped iOS records are unioned before every outer fold; ${iosRecords.length - maskGroupedRecords} iOS records lack an automatic mask association, so mask leakage protection is partial.'}',
      )
      ..writeln(
        iosRecords.isEmpty
            ? 'No iOS label is present in this corpus.'
            : connectedIosRecordCount == 0
            ? 'The $simulatorIosRecordCount committed iOS records are the '
                  'canonical exact observations from the completed '
                  'selected-runtime simulator pass. The inventory separately '
                  'reports all Xcode device types, including types outside '
                  'that selected iOS runtime.'
            : 'The committed iOS corpus contains '
                  '$simulatorIosRecordCount canonical simulator observations '
                  'and $connectedIosRecordCount public-API connected-device '
                  'observations. The inventory separately reports all Xcode '
                  'device types, including types outside the selected runtime.',
      )
      ..writeln(
        iosRecords.isEmpty
            ? 'iOS four-edge/view feature completeness is n/a.'
            : iosCompleteViewGeometryCount == iosRecords.length
            ? 'All committed iOS rows include the current collector feature fields.'
            : 'The committed iOS run predates four-edge/view feature capture for '
                  '${iosRecords.length - iosCompleteViewGeometryCount} rows; those '
                  'fields remain missing rather than being fabricated.',
      )
      ..writeln(
        iosRecords.isEmpty
            ? 'iOS system-gesture feature completeness is n/a.'
            : iosCompleteGestureEvidenceCount == iosRecords.length
            ? 'All committed iOS rows include four-edge system-gesture evidence.'
            : 'System-gesture evidence is missing for '
                  '${iosRecords.length - iosCompleteGestureEvidenceCount} iOS rows. '
                  'The training schema retains that missingness rather than '
                  'fabricating observed insets.',
      )
      ..writeln(
        iosRecords.isEmpty
            ? 'iOS Flutter display-cutout feature completeness is n/a.'
            : iosCompleteCutoutEvidenceCount == iosRecords.length
            ? 'All committed iOS rows include Flutter display-cutout evidence.'
            : 'Flutter display-cutout evidence is unavailable for '
                  '${iosRecords.length - iosCompleteCutoutEvidenceCount} iOS rows. '
                  'Both training and runtime mark this iOS-only absence with '
                  'the display-cutout missing indicator.',
      )
      ..writeln()
      ..writeln('## Candidate comparison')
      ..writeln();
    _writeCandidateTable(buffer, 'Android', android);
    _writeCandidateTable(buffer, 'iOS', ios);
    buffer
      ..writeln('## Standalone comparison baselines')
      ..writeln();
    _writeStandaloneComparatorTable(buffer, 'Android', android);
    _writeStandaloneComparatorTable(buffer, 'iOS', ios);
    buffer
      ..writeln(
        'Each report-only baseline row is its literal bounded formula. Each '
        'selection-eligible structured candidate row is a fold-local '
        'reconstruction of the deployed safety '
        'pipeline, including the rounded/square hurdle, a structurally '
        'different challenger, robust distance/disagreement support, and '
        'blending toward a training-only prior.',
      )
      ..writeln(
        'The four structured candidates are ranked by the '
        'worst available executed regime: '
        'deterministic group-bootstrap upper confidence bound of held-out '
        'logical-pixel p95 first, then group-macro logical-pixel MAE, '
        'logical-pixel maximum error, serialized generated-model bytes, '
        'inference operations, and fixed candidate order.',
      )
      ..writeln(
        'The separate baseline table expands the literal rows above: zero '
        "radius, Flutter 3.47.1 Cupertino sheet's `0.9 * raw top viewPadding` "
        'only when that logical radius exceeds 20 pixels, a group-weighted '
        'constant logical radius (including '
        'authoritative square labels), and a '
        'shortest-side formula `radius = k * shortestLogicalSide` fitted through '
        'constant normalized diameter. They use the same grouped regimes and '
        'metrics without the structured-model safety pipeline, but remain '
        'report-only benchmarks.',
      )
      ..writeln(
        'When the safe-inset formula is selected as the deployed iOS prior, '
        'runtime rotates its evidence with the display and uses the '
        'order-independent larger major-axis padding. The portrait top edge '
        'was that larger edge for every committed iOS observation, so this is '
        'numerically equivalent to the measured literal comparator on the '
        'current corpus while preserving 90/270-degree invariance.',
      )
      ..writeln(
        'All candidates are scored on the same DPR-known observations. The outer fold '
        'fits each literal baseline directly; structured alternatives fit the '
        'rounded-versus-square hurdle and positive-radius heads using training '
        'groups only, then score the complete gated/OOD prediction. Bare skin '
        'labels without a defensible density and matching AVD geometry are '
        'excluded because their logical phone form and logical-pixel error '
        'cannot be established without guessing.',
      )
      ..writeln(
        'Every source observation is fitted and scored from its own numeric '
        'geometry. Within each training fold, observation weights are '
        'normalized so every unioned leakage group contributes total weight '
        'one; inner blend folds keep entire leakage groups together.',
      )
      ..writeln(
        'The orientation-normalized feature schema uses log display aspect, '
        'log physical and logical short sides, log DPR, viewport coverage, '
        'normalized inset/cutout geometry, and explicit missing-evidence '
        'indicators. No device identity is a predictor.',
      )
      ..writeln()
      ..writeln('## Selected-model validation')
      ..writeln();
    _writePlatformValidation(buffer, 'Android', android);
    _writePlatformValidation(buffer, 'iOS', ios);
    buffer
      ..writeln('## Executed stress splits')
      ..writeln();
    _writeHoldouts(buffer, 'Android', android);
    _writeHoldouts(buffer, 'iOS', ios);
    buffer
      ..writeln('## OOD calibration and collision floor')
      ..writeln();
    _writeOod(buffer, 'Android', android);
    _writeOod(buffer, 'iOS', ios);
    buffer
      ..writeln('## Acceptance gates')
      ..writeln()
      ..writeln(
        '- Runtime safety: every valid estimate is deterministic, finite, and '
        'bounded to `[0, shortestLogicalDisplaySide / 2]`.',
      )
      ..writeln(
        '- Runtime privacy: generated shipping source must contain no '
        'manufacturer, device/model identifier, source record, provenance '
        'group, private selector, or catalog material.',
      )
      ..writeln(
        '- Reproducibility: corpus -> manifest -> Dart artifact -> this report '
        'must reproduce byte-for-byte.',
      )
      ..writeln(
        '- Calibrated Android accuracy claim: at least 20 independent leakage '
        'groups, at least 5 authoritative square groups, logical-pixel MAE <= '
        '4, p95 <= 8, and worst available executed-regime p95 UCB <= 10.',
      )
      ..writeln(
        '- Calibrated iOS accuracy claim: at least 12 independent exact-label '
        'families spanning at least 3 generations, logical-pixel MAE <= 4, '
        'p95 <= 8, and newest-generation p95 <= 10.',
      )
      ..writeln(
        '- Measured Android accuracy gate: '
        '${androidAccuracyGatePassed ? 'passed' : 'not satisfied'}.',
      )
      ..writeln(
        '- Measured iOS accuracy gate: '
        '${iosAccuracyGatePassed ? 'passed' : 'not satisfied'}.',
      )
      ..writeln()
      ..writeln(
        !androidAccuracyGatePassed && !iosAccuracyGatePassed
            ? "The committed corpus does not satisfy either platform's "
                  'calibrated-accuracy sample-size and stress-split gates. The '
                  'generated artifact is the best measured sparse-corpus '
                  'fallback; no calibrated accuracy claim is made.'
            : 'A passing measured gate does not expand the evidence beyond the '
                  'committed corpus; claims remain limited to the platform whose '
                  'gate passed.',
      )
      ..writeln()
      ..writeln('## Known limitations')
      ..writeln()
      ..writeln(
        '- Display radius is not identifiable from viewport geometry: '
        'different hardware can expose the same runtime features and use '
        'different physical radii. The reported collision lower bound '
        'quantifies only collisions present in this corpus.',
      )
      ..writeln(
        '- Android API 31+ exact `WindowInsets` radii, including authoritative '
        'all-zero square displays, are accepted on any display only when the '
        'native response matches the captured Flutter display/view geometry.',
      )
      ..writeln(
        "- Pre-31 legacy default radius resources are used only on Android's "
        'default display and scale against its current full-display size. '
        'Current AOSP per-display arrays require hidden physical display '
        'unique IDs; their presence rejects the ambiguous global scalar, so '
        'runtime never guesses that mapping.',
      )
      ..writeln(
        '- Android SDK skin `corner_radius` values describe emulator skin '
        'geometry. Connected API 31+ values are stronger labels.',
      )
      ..writeln(
        '- The committed Android corpus has $androidCompleteRuntimeFeatureCount '
        '${androidCompleteRuntimeFeatureCount == 1 ? 'label' : 'labels'} with '
        'the exact Flutter-equivalent view, padding, gesture, and '
        'cutout feature set. SDK-skin and positive legacy-resource rows retain '
        'those fields as missing; the report does not claim empirical '
        'calibration of unavailable features.',
      )
      ..writeln(
        '- Insets can describe bars, cutouts, and window state rather than the '
        'physical curve. Split-screen and desktop windowing therefore reduce '
        'feature support instead of being mistaken for new hardware.',
      )
      ..writeln(
        '- Android natural top/bottom pairs rotate to left/right pairs in '
        'landscape. Flutter geometry cannot distinguish a 180-degree rotation '
        'without asymmetric cutout position evidence; padding and gesture '
        'insets are not treated as a reliable direction sensor.',
      )
      ..writeln(
        '- Connected iOS collection always inventories local wired, booted, '
        'paired iPhones. Installing is explicit opt-in with a caller-supplied '
        'signed public-only app. Its source manifest, embedded source hash, '
        'signature, profile App ID, target provisioning, nonce, and payload are '
        'verified, but the supplied signed binary remains a trusted local input; '
        'the tooling never provisions or changes an Apple account.',
      )
      ..writeln(
        '- Tool-side corpus and provenance fingerprints use deterministic '
        '64-bit FNV for canonical records and SHA-256 source/group digests. No '
        '32-bit fingerprint can silently deduplicate or union observations.',
      )
      ..writeln(
        '- Unknown phone-shaped geometry always receives a bounded result; '
        'bounded does not mean physically accurate. Fold/hinge geometry is '
        'rejected by the estimator.',
      )
      ..writeln()
      ..writeln('## Primary references')
      ..writeln()
      ..writeln(
        '- [Flutter `MediaQueryData.displayCornerRadii`](https://api.flutter.dev/flutter/widgets/MediaQueryData/displayCornerRadii.html) '
        'defines exact logical-pixel radii when Flutter receives them.',
      )
      ..writeln(
        '- [Android rounded-corner insets](https://developer.android.com/develop/ui/views/layout/insets/rounded-corners) '
        'document API 31 `WindowInsets.getRoundedCorner`.',
      )
      ..writeln(
        '- [AOSP `RoundedCorners`](https://android.googlesource.com/platform/frameworks/base/+/15cb562bcd7427c4ec8565d2d022db4e6c252264/core/java/android/view/RoundedCorners.java) '
        'shows default resources and hidden display-unique-ID array mapping.',
      )
      ..writeln(
        '- [Apple `containerConcentricRadius`](https://developer.apple.com/documentation/uikit/uicornerradius-c.class/containerconcentricradius?language=objc) '
        'and [`UICornerConfiguration`](https://developer.apple.com/documentation/uikit/uicornerconfiguration-c.class) '
        'define the public iOS 26 collector probe.',
      )
      ..writeln(
        '- [GroupKFold](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.GroupKFold.html) '
        'documents the non-overlapping-group validation principle mirrored by '
        'the deterministic union-find folds.',
      )
      ..writeln(
        '- [Scikit-learn robust and elastic-net linear models](https://scikit-learn.org/stable/modules/linear_model.html) '
        'motivate the compact Huber/regularized polynomial candidate.',
      )
      ..writeln(
        '- [Scikit-learn spline transformers](https://scikit-learn.org/stable/modules/generated/sklearn.preprocessing.SplineTransformer.html) '
        'document spline basis and extrapolation behavior.',
      )
      ..writeln(
        '- [Scikit-learn gradient boosting](https://scikit-learn.org/stable/modules/ensemble.html) '
        'documents shallow-tree and shrinkage controls used by the tree candidate.',
      )
      ..writeln(
        '- [NIST bootstrap percentiles](https://www.itl.nist.gov/div898/handbook/eda/section3/eda334.htm) '
        'provide the percentile-bootstrap basis for the deterministic grouped '
        'upper-tail comparison.',
      );
    return buffer.toString();
  }

  void _writeCandidateTable(
    StringBuffer buffer,
    String label,
    Map<String, Object?> platform,
  ) {
    buffer
      ..writeln('### $label')
      ..writeln()
      ..writeln(
        '| Alternative | Role | Selection eligible | Scoring pipeline | Status | Worst logical p95 UCB | Worst macro logical MAE | Logical max | Bytes | Ops |',
      )
      ..writeln('|---|---|---|---|---|---:|---:|---:|---:|---:|');
    for (final value in platform['candidateScores']! as List<Object?>) {
      final score = value! as Map<String, Object?>;
      final role = score['role']! as String;
      if (score['eligible'] != true) {
        buffer.writeln(
          '| `${score['candidate']}` | $role | ${score['selectionEligible']} | n/a | ineligible: '
          '${score['ineligibilityReason']} | n/a | n/a | n/a | n/a | '
          '${score['inferenceOperationCount']} |',
        );
        continue;
      }
      buffer.writeln(
        '| `${score['candidate']}` | $role | ${score['selectionEligible']} | `${score['scoringPipeline']}` | executed | '
        '${_number(score['worstRegimeBootstrapUpperLogicalP95'])} | '
        '${_number(score['worstRegimeMacroLogicalPixelMae'])} | '
        '${_number(score['logicalPixelMaximumAbsoluteError'])} | '
        '${score['generatedModelBytes']} | '
        '${score['inferenceOperationCount']} |',
      );
    }
    buffer.writeln();
  }

  void _writeStandaloneComparatorTable(
    StringBuffer buffer,
    String label,
    Map<String, Object?> platform,
  ) {
    buffer
      ..writeln('### $label')
      ..writeln()
      ..writeln(
        '| Literal comparator | Logical MAE | Logical median | Logical p95 | Logical max | Within 2 / 4 / 8 px |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|');
    for (final value in platform['candidateScores']! as List<Object?>) {
      final score = value! as Map<String, Object?>;
      final standalone = score['standaloneComparator'] as Map<String, Object?>?;
      if (standalone == null) {
        continue;
      }
      final metrics = standalone['metrics']! as Map<String, Object?>;
      buffer.writeln(
        '| `${score['candidate']}` | '
        '${_number(metrics['logicalPixelMae'])} | '
        '${_number(metrics['logicalPixelMedianAbsoluteError'])} | '
        '${_number(metrics['logicalPixelP95AbsoluteError'])} | '
        '${_number(metrics['logicalPixelMaximumAbsoluteError'])} | '
        '${_percentage(metrics['withinTwoLogicalPixels'])} / '
        '${_percentage(metrics['withinFourLogicalPixels'])} / '
        '${_percentage(metrics['withinEightLogicalPixels'])} |',
      );
    }
    buffer.writeln();
  }

  void _writePlatformValidation(
    StringBuffer buffer,
    String label,
    Map<String, Object?> platform,
  ) {
    final validation = platform['validation'] as Map<String, Object?>?;
    final classification = platform['classification']! as Map<String, Object?>;
    final baselineScores =
        (platform['candidateScores']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .where(
              (score) => score['eligible'] == true && score['role'] == 'comparison baseline',
            )
            .toList()
          ..sort(_compareScores);
    final strongestBaseline = baselineScores.isEmpty ? null : baselineScores.first;
    final baselineMargin = validation == null || strongestBaseline == null
        ? null
        : (validation['worstRegimeBootstrapUpperLogicalP95']! as num).toDouble() -
              (strongestBaseline['worstRegimeBootstrapUpperLogicalP95']! as num).toDouble();
    final baselineMarginDescription = baselineMargin == null
        ? 'n/a.'
        : baselineMargin.abs() <= 0.000000001
        ? 'matches `${strongestBaseline!['candidate']}` at the primary '
              'p95-UCB criterion.'
        : baselineMargin < 0
        ? 'beats `${strongestBaseline!['candidate']}` by '
              '${_number(-baselineMargin)} logical px at the primary '
              'p95-UCB criterion.'
        : 'trails `${strongestBaseline!['candidate']}` by '
              '${_number(baselineMargin)} logical px at the primary '
              'p95-UCB criterion.';
    buffer
      ..writeln('### $label')
      ..writeln()
      ..writeln('- Selected: `${platform['selectedCandidate']}`')
      ..writeln('- Deployed pipeline: `${platform['predictionPipeline']}`')
      ..writeln(
        validation == null
            ? '- Selection rationale: sparse fallback; grouped logical-pixel '
                  'comparison of the measured alternatives was unavailable.'
            : '- Selection rationale: lowest deterministic lexicographic score '
                  'among the four executed structured candidates (worst-regime '
                  'p95 UCB '
                  '${_number(validation['worstRegimeBootstrapUpperLogicalP95'])}, '
                  'worst-regime macro MAE '
                  '${_number(validation['worstRegimeMacroLogicalPixelMae'])} '
                  'logical px).',
      )
      ..writeln(
        '- Selected pipeline versus strongest raw baseline: '
        '$baselineMarginDescription',
      )
      ..writeln(
        '- Structurally different challenger: '
        '`${platform['challengerCandidate'] ?? 'n/a'}`',
      )
      ..writeln('- Accepted labels: ${platform['labeledRecordCount']}')
      ..writeln(
        '- DPR-known logical-pixel scoring labels: '
        '${platform['logicalScoringRecordCount']}',
      )
      ..writeln('- Independent leakage groups: ${platform['validationGroupCount']}')
      ..writeln(
        platform['predictionPipeline'] == 'raw_bounded_formula_v1'
            ? '- Hurdle: measured but not applied by the selected literal baseline.'
            : '- Hurdle: `${classification['selectedCandidate']}`; rounded '
                  '${classification['roundedRecordCount']}, square '
                  '${classification['squareRecordCount']} records; rounded '
                  '${classification['roundedIndependentGroupCount']}, square '
                  '${classification['squareIndependentGroupCount']} independent groups; fitted '
                  '${classification['isFitted']}',
      )
      ..writeln('- Logical-pixel MAE: ${_number(validation?['logicalPixelMae'])}')
      ..writeln(
        '- Logical-pixel median absolute error: '
        '${_number(validation?['logicalPixelMedianAbsoluteError'])}',
      )
      ..writeln(
        '- Logical-pixel p95 absolute error: '
        '${_number(validation?['logicalPixelP95AbsoluteError'])}',
      )
      ..writeln(
        '- Logical-pixel maximum absolute error: '
        '${_number(validation?['logicalPixelMaximumAbsoluteError'])}',
      )
      ..writeln(
        '- Within 2 logical pixels: '
        '${_percentage(validation?['withinTwoLogicalPixels'])}',
      )
      ..writeln(
        '- Within 4 logical pixels: '
        '${_percentage(validation?['withinFourLogicalPixels'])}',
      )
      ..writeln(
        '- Within 8 logical pixels: '
        '${_percentage(validation?['withinEightLogicalPixels'])}',
      )
      ..writeln('- Normalized-diameter MAE: ${_number(validation?['diameterMae'])}')
      ..writeln(
        '- Normalized-diameter p95: '
        '${_number(validation?['diameterP95AbsoluteError'])}',
      )
      ..writeln();
  }

  void _writeHoldouts(
    StringBuffer buffer,
    String label,
    Map<String, Object?> platform,
  ) {
    buffer
      ..writeln('### $label')
      ..writeln();
    final holdouts = platform['holdouts']! as Map<String, Object?>;
    for (final key in holdouts.keys.toList()..sort()) {
      final result = holdouts[key]! as Map<String, Object?>;
      if (result['status'] != 'executed') {
        buffer.writeln(
          '- `$key`: unavailable (${result['reason']}; '
          '${result['groupCount']}/${result['minimumGroupCount']} metadata '
          'values; ${result['eligibleLeakageGroupCount']} eligible and '
          '${result['excludedLeakageGroupCount']} excluded leakage groups).',
        );
        continue;
      }
      final metrics = result['metrics']! as Map<String, Object?>;
      buffer.writeln(
        '- `$key`: executed; p95 UCB '
        '${_number(metrics['familyBootstrapUpperLogicalP95'])} logical px, '
        'macro MAE ${_number(metrics['macroLogicalPixelMae'])} logical px; '
        '${result['eligibleLeakageGroupCount']} eligible and '
        '${result['excludedLeakageGroupCount']} excluded leakage groups. '
        'Observations without target metadata participate in neither training '
        'nor scoring. A union group spanning missing or multiple values is held '
        'out as one unit, while only known observations matching the target '
        'value are scored.',
      );
    }
    buffer.writeln();
  }

  void _writeOod(
    StringBuffer buffer,
    String label,
    Map<String, Object?> platform,
  ) {
    final schema = platform['featureSchema'] as Map<String, Object?>?;
    final disagreement = platform['disagreement']! as Map<String, Object?>;
    final collision = platform['collisionLowerBound']! as Map<String, Object?>;
    final prior = platform['prior']! as Map<String, Object?>;
    final support = platform['support'] as Map<String, Object?>?;
    buffer
      ..writeln('### $label')
      ..writeln()
      ..writeln(
        '- Robust feature-distance support inner/outer: '
        '${_number(schema?['distanceInner'])} / '
        '${_number(schema?['distanceOuter'])}',
      )
      ..writeln(
        '- Challenger disagreement: ${disagreement['available'] == true ? 'calibrated at p50 ${_number(disagreement['logicalPixelP50'])} and p95 ${_number(disagreement['logicalPixelP95'])} logical px' : 'unavailable (${disagreement['reason']})'}',
      )
      ..writeln(
        '- Inner grouped-OOF robust prior: '
        '`${prior['candidate'] ?? prior['kind']}`; calibrated model blend '
        'weight ${_number(support?['modelBlendWeight'])}, distance transition '
        'scale ${_number(support?['distanceTransitionScale'])}, and '
        'disagreement transition scale '
        '${_number(support?['disagreementTransitionScale'])}.',
      )
      ..writeln(
        '- Observable collision groups: ${collision['collisionGroupCount']}; '
        'logical-pixel collision lower-bound MAE '
        '${_number(collision['logicalPixelMae'])} from '
        '${collision['logicalPixelObservationCount']} observations.',
      )
      ..writeln(
        platform['predictionPipeline'] == 'raw_bounded_formula_v1'
            ? '- OOD behavior: the selected bounded baseline is itself the '
                  'robust extrapolation prior. Distance and challenger blending '
                  'degenerate to that same formula and are not claimed as '
                  'calibrated for this selection.'
            : prior['kind'] == 'grouped_oof_selected_literal_baseline'
            ? '- OOD behavior: the structured prediction and rounded gate '
                  'blend toward the inner grouped-OOF selected literal prior as '
                  'feature support or structurally different challenger '
                  'agreement weakens. A zero calibrated model weight reduces '
                  'exactly to that bounded prior.'
            : '- OOD behavior: no fitted platform prior is available; the '
                  'bounded safe-inset fallback is used.',
      )
      ..writeln();
  }

  String _number(Object? value) => value is num ? value.toStringAsFixed(6) : 'n/a';

  String _percentage(Object? value) => value is num ? '${(100 * value).toStringAsFixed(1)}%' : 'n/a';

  int _compareScores(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    for (final key in const <String>[
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
    return (left['candidate']! as String).compareTo(
      right['candidate']! as String,
    );
  }

  bool _androidAccuracyGatePassed(Map<String, Object?> platform) {
    final validation = platform['validation'] as Map<String, Object?>?;
    final classification = platform['classification']! as Map<String, Object?>;
    return (platform['validationGroupCount']! as int) >= 20 &&
        (classification['squareIndependentGroupCount']! as int) >= 5 &&
        validation != null &&
        (validation['logicalPixelMae']! as num) <= 4 &&
        (validation['logicalPixelP95AbsoluteError']! as num) <= 8 &&
        (validation['worstRegimeBootstrapUpperLogicalP95']! as num) <= 10;
  }

  bool _iosAccuracyGatePassed(Map<String, Object?> platform) {
    final validation = platform['validation'] as Map<String, Object?>?;
    final holdouts = platform['holdouts']! as Map<String, Object?>;
    final generations = holdouts['leaveGenerationOut']! as Map<String, Object?>;
    final newest = holdouts['newestGeneration']! as Map<String, Object?>;
    final newestMetrics = newest['metrics'] as Map<String, Object?>?;
    return (platform['validationGroupCount']! as int) >= 12 &&
        (generations['groupCount']! as int) >= 3 &&
        generations['status'] == 'executed' &&
        newest['status'] == 'executed' &&
        validation != null &&
        newestMetrics != null &&
        (validation['logicalPixelMae']! as num) <= 4 &&
        (validation['logicalPixelP95AbsoluteError']! as num) <= 8 &&
        (newestMetrics['logicalPixelP95AbsoluteError']! as num) <= 10;
  }
}
