# Device display estimator validation

This report contains only measurements produced by the committed corpus and deterministic tooling. Missing accuracy and split results are reported as n/a; they are never inferred.

- Corpus fingerprint: `fnv1a64:dcae258c599afa2e`
- Target: `2 * physicalRadius / shortestPhysicalDisplaySide`
- Runtime conversion: `logicalRadius = target * shortestLogicalDisplaySide / 2`

## Local corpus

- Total accepted labels: 34
- Android SDK skins enumerated: 56
- Android skin labels accepted: 2
- Android AVDs enumerated: 23
- Skin labels joined to an unambiguous AVD density: 2
- Connected Android devices enumerated: 1
- Connected Android emulators excluded from the physical-device path: 0
- Connected Android eligible physical devices: 1
- Connected Android API 31+ exact `WindowInsets` labels accepted: 1
- Connected Android positive legacy default-resource labels accepted: 0
- Connected Android collector source hash: `sha256:01609a9d1f87b1a175f96aa780443c62cd0e671f2617b67bd91e706836e8c2c3`
- Xcode simulator device types enumerated: 124
- Xcode iPhone/iPad device types: 86
- Xcode framebuffer masks audited: 63
- iOS exact labels accepted: 31
- Connected physical iPhones enumerated / eligible / attempted / accepted: 1 / 0 / 0 / 0
- Connected-iOS signed collector supplied: false; source hash `n/a`
- Android labels with exact runtime-equivalent view/inset/cutout fields: 1
- Records with anonymous mask grouping: 29
- iOS labels with explicit view size and four-edge safe-area evidence: 31
- iOS labels with four-edge system-gesture evidence: 0
- iOS labels with Flutter display-cutout evidence: 0

Accepted source counts:

- `android_api31_window_insets`: 1
- `android_sdk_skin_avd_join`: 2
- `ios26_public_uikit_concentric_corner`: 31

Framebuffer masks are used only to group possible leakage collisions and audit completeness. They are never radius labels. The 29 mask-grouped iOS records are unioned before every outer fold; 2 iOS records lack an automatic mask association, so mask leakage protection is partial.
The 31 committed iOS records are the canonical exact observations from the completed selected-runtime simulator pass. The inventory separately reports all Xcode device types, including types outside that selected iOS runtime.
All committed iOS rows include the current collector feature fields.
System-gesture evidence is missing for 31 iOS rows. The training schema retains that missingness rather than fabricating observed insets.
Flutter display-cutout evidence is unavailable for 31 iOS rows. Both training and runtime mark this iOS-only absence with the display-cutout missing indicator.

## Candidate comparison

### Android

| Alternative | Role | Selection eligible | Scoring pipeline | Status | Worst logical p95 UCB | Worst macro logical MAE | Logical max | Bytes | Ops |
|---|---|---|---|---|---:|---:|---:|---:|---:|
| `zero_baseline` | comparison baseline | false | `fold_local_raw_bounded_formula_v1` | executed | 33.142857 | 32.714286 | 33.142857 | 180 | 0 |
| `safe_inset_baseline` | comparison baseline | false | `fold_local_raw_bounded_formula_v1` | executed | 33.142857 | 23.914286 | 33.142857 | 192 | 2 |
| `platform_median_logical_radius` | comparison baseline | false | `fold_local_raw_bounded_formula_v1` | executed | 1.142857 | 1.047619 | 1.142857 | 260 | 6 |
| `shortest_side_formula` | comparison baseline | false | `fold_local_raw_bounded_formula_v1` | executed | 4.156250 | 2.282683 | 4.156250 | 284 | 2 |
| `robust_quadratic_regression` | structured candidate | true | `fold_local_distance_disagreement_gate_prior_v1` | executed | 1.142857 | 1.047619 | 1.142857 | 8288 | 492 |
| `spline_gam` | structured candidate | true | `fold_local_distance_disagreement_gate_prior_v1` | executed | 1.142857 | 1.047619 | 1.142857 | 8907 | 458 |
| `shallow_boosted_tree` | structured candidate | true | `fold_local_distance_disagreement_gate_prior_v1` | executed | 1.142857 | 1.047619 | 1.142857 | 8907 | 458 |
| `constrained_blend` | structured candidate | true | `fold_local_distance_disagreement_gate_prior_v1` | executed | 1.142857 | 1.047619 | 1.142857 | 9753 | 672 |

### iOS

| Alternative | Role | Selection eligible | Scoring pipeline | Status | Worst logical p95 UCB | Worst macro logical MAE | Logical max | Bytes | Ops |
|---|---|---|---|---|---:|---:|---:|---:|---:|
| `zero_baseline` | comparison baseline | false | `fold_local_raw_bounded_formula_v1` | executed | 62.000000 | 47.330000 | 62.000000 | 138 | 0 |
| `safe_inset_baseline` | comparison baseline | false | `fold_local_raw_bounded_formula_v1` | executed | 11.030000 | 5.030000 | 11.030000 | 144 | 1 |
| `platform_median_logical_radius` | comparison baseline | false | `fold_local_raw_bounded_formula_v1` | executed | 53.330000 | 15.613442 | 53.330000 | 191 | 3 |
| `shortest_side_formula` | comparison baseline | false | `fold_local_raw_bounded_formula_v1` | executed | 46.726051 | 13.494934 | 46.726051 | 190 | 1 |
| `robust_quadratic_regression` | structured candidate | true | `fold_local_distance_disagreement_gate_prior_v1` | executed | 55.000000 | 6.224019 | 55.000000 | 7944 | 371 |
| `spline_gam` | structured candidate | true | `fold_local_distance_disagreement_gate_prior_v1` | executed | 11.099883 | 5.030000 | 11.099883 | 8767 | 414 |
| `shallow_boosted_tree` | structured candidate | true | `fold_local_distance_disagreement_gate_prior_v1` | executed | 11.030000 | 4.931593 | 11.030000 | 8767 | 414 |
| `constrained_blend` | structured candidate | true | `fold_local_distance_disagreement_gate_prior_v1` | executed | 11.030000 | 4.558003 | 11.030000 | 9331 | 521 |

## Standalone comparison baselines

### Android

| Literal comparator | Logical MAE | Logical median | Logical p95 | Logical max | Within 2 / 4 / 8 px |
|---|---:|---:|---:|---:|---:|
| `zero_baseline` | 32.714286 | 33.000000 | 33.142857 | 33.142857 | 0.0% / 0.0% / 0.0% |
| `safe_inset_baseline` | 23.914286 | 33.000000 | 33.142857 | 33.142857 | 0.0% / 0.0% / 33.3% |
| `platform_median_logical_radius` | 1.047619 | 1.000000 | 1.142857 | 1.142857 | 100.0% / 100.0% / 100.0% |
| `shortest_side_formula` | 2.282683 | 1.370370 | 4.156250 | 4.156250 | 66.7% / 66.7% / 100.0% |

### iOS

| Literal comparator | Logical MAE | Logical median | Logical p95 | Logical max | Within 2 / 4 / 8 px |
|---|---:|---:|---:|---:|---:|
| `zero_baseline` | 48.735484 | 53.330000 | 62.000000 | 62.000000 | 6.5% / 6.5% / 6.5% |
| `safe_inset_baseline` | 3.877419 | 1.900000 | 11.030000 | 11.030000 | 51.6% / 51.6% / 90.3% |
| `platform_median_logical_radius` | 8.974194 | 6.000000 | 53.330000 | 53.330000 | 35.5% / 35.5% / 58.1% |
| `shortest_side_formula` | 7.482340 | 2.726051 | 46.726051 | 46.726051 | 45.2% / 51.6% / 74.2% |

Each report-only baseline row is its literal bounded formula. Each selection-eligible structured candidate row is a fold-local reconstruction of the deployed safety pipeline, including the rounded/square hurdle, a structurally different challenger, robust distance/disagreement support, and blending toward a training-only prior.
The four structured candidates are ranked by the worst available executed regime: deterministic group-bootstrap upper confidence bound of held-out logical-pixel p95 first, then group-macro logical-pixel MAE, logical-pixel maximum error, serialized generated-model bytes, inference operations, and fixed candidate order.
The separate baseline table expands the literal rows above: zero radius, Flutter 3.47.1 Cupertino sheet's `0.9 * raw top viewPadding` only when that logical radius exceeds 20 pixels, a group-weighted constant logical radius (including authoritative square labels), and a shortest-side formula `radius = k * shortestLogicalSide` fitted through constant normalized diameter. They use the same grouped regimes and metrics without the structured-model safety pipeline, but remain report-only benchmarks.
When the safe-inset formula is selected as the deployed iOS prior, runtime rotates its evidence with the display and uses the order-independent larger major-axis padding. The portrait top edge was that larger edge for every committed iOS observation, so this is numerically equivalent to the measured literal comparator on the current corpus while preserving 90/270-degree invariance.
All candidates are scored on the same DPR-known observations. The outer fold fits each literal baseline directly; structured alternatives fit the rounded-versus-square hurdle and positive-radius heads using training groups only, then score the complete gated/OOD prediction. Bare skin labels without a defensible density and matching AVD geometry are excluded because their logical phone form and logical-pixel error cannot be established without guessing.
Every source observation is fitted and scored from its own numeric geometry. Within each training fold, observation weights are normalized so every unioned leakage group contributes total weight one; inner blend folds keep entire leakage groups together.
The orientation-normalized feature schema uses log display aspect, log physical and logical short sides, log DPR, viewport coverage, normalized inset/cutout geometry, and explicit missing-evidence indicators. No device identity is a predictor.

## Selected-model validation

### Android

- Selected: `robust_quadratic_regression`
- Deployed pipeline: `distance_disagreement_gate_prior_v1`
- Selection rationale: lowest deterministic lexicographic score among the four executed structured candidates (worst-regime p95 UCB 1.142857, worst-regime macro MAE 1.047619 logical px).
- Selected pipeline versus strongest raw baseline: matches `platform_median_logical_radius` at the primary p95-UCB criterion.
- Structurally different challenger: `shallow_boosted_tree`
- Accepted labels: 3
- DPR-known logical-pixel scoring labels: 3
- Independent leakage groups: 3
- Hurdle: `laplace_smoothed_constant_hurdle`; rounded 3, square 0 records; rounded 3, square 0 independent groups; fitted false
- Logical-pixel MAE: 1.047619
- Logical-pixel median absolute error: 1.000000
- Logical-pixel p95 absolute error: 1.142857
- Logical-pixel maximum absolute error: 1.142857
- Within 2 logical pixels: 100.0%
- Within 4 logical pixels: 100.0%
- Within 8 logical pixels: 100.0%
- Normalized-diameter MAE: 0.005266
- Normalized-diameter p95: 0.005556

### iOS

- Selected: `constrained_blend`
- Deployed pipeline: `distance_disagreement_gate_prior_v1`
- Selection rationale: lowest deterministic lexicographic score among the four executed structured candidates (worst-regime p95 UCB 11.030000, worst-regime macro MAE 4.558003 logical px).
- Selected pipeline versus strongest raw baseline: matches `safe_inset_baseline` at the primary p95-UCB criterion.
- Structurally different challenger: `robust_quadratic_regression`
- Accepted labels: 31
- DPR-known logical-pixel scoring labels: 31
- Independent leakage groups: 11
- Hurdle: `quadratic_logistic_hurdle`; rounded 29, square 2 records; rounded 10, square 1 independent groups; fitted true
- Logical-pixel MAE: 3.748187
- Logical-pixel median absolute error: 3.818146
- Logical-pixel p95 absolute error: 8.380969
- Logical-pixel maximum absolute error: 11.030000
- Within 2 logical pixels: 22.6%
- Within 4 logical pixels: 74.2%
- Within 8 logical pixels: 90.3%
- Normalized-diameter MAE: 0.018538
- Normalized-diameter p95: 0.039163

## Executed stress splits

### Android

- `leaveGenerationOut`: unavailable (Fewer than two anonymized generation groups were available.; 0/2 metadata values; 0 eligible and 3 excluded leakage groups).
- `leaveOemOut`: unavailable (Fewer than two anonymized OEM groups were available.; 1/2 metadata values; 1 eligible and 2 excluded leakage groups).
- `newestGeneration`: unavailable (Fewer than two distinct anonymous chronology ranks were available.; 0/2 metadata values; 0 eligible and 3 excluded leakage groups).

### iOS

- `leaveGenerationOut`: executed; p95 UCB 11.030000 logical px, macro MAE 4.558003 logical px; 11 eligible and 0 excluded leakage groups. Observations without target metadata participate in neither training nor scoring. A union group spanning missing or multiple values is held out as one unit, while only known observations matching the target value are scored.
- `leaveOemOut`: unavailable (Fewer than two anonymized OEM groups were available.; 1/2 metadata values; 11 eligible and 0 excluded leakage groups).
- `newestGeneration`: executed; p95 UCB 3.848595 logical px, macro MAE 3.848595 logical px; 11 eligible and 0 excluded leakage groups. Observations without target metadata participate in neither training nor scoring. A union group spanning missing or multiple values is held out as one unit, while only known observations matching the target value are scored.

## OOD calibration and collision floor

### Android

- Robust feature-distance support inner/outer: 0.798088 / 1.798088
- Challenger disagreement: calibrated at p50 0.213821 and p95 0.242100 logical px
- Inner grouped-OOF robust prior: `platform_median_logical_radius`; calibrated model blend weight 0.000000, distance transition scale 0.250000, and disagreement transition scale 0.250000.
- Observable collision groups: 0; logical-pixel collision lower-bound MAE n/a from 0 observations.
- OOD behavior: the structured prediction and rounded gate blend toward the inner grouped-OOF selected literal prior as feature support or structurally different challenger agreement weakens. A zero calibrated model weight reduces exactly to that bounded prior.

### iOS

- Robust feature-distance support inner/outer: 33.396384 / 34.396384
- Challenger disagreement: calibrated at p50 3.064858 and p95 153.003673 logical px
- Inner grouped-OOF robust prior: `safe_inset_baseline`; calibrated model blend weight 0.500000, distance transition scale 0.250000, and disagreement transition scale 1.000000.
- Observable collision groups: 8; logical-pixel collision lower-bound MAE 0.000000 from 54 observations.
- OOD behavior: the structured prediction and rounded gate blend toward the inner grouped-OOF selected literal prior as feature support or structurally different challenger agreement weakens. A zero calibrated model weight reduces exactly to that bounded prior.

## Acceptance gates

- Runtime safety: every valid estimate is deterministic, finite, and bounded to `[0, shortestLogicalDisplaySide / 2]`.
- Runtime privacy: generated shipping source must contain no manufacturer, device/model identifier, source record, provenance group, private selector, or catalog material.
- Reproducibility: corpus -> manifest -> Dart artifact -> this report must reproduce byte-for-byte.
- Calibrated Android accuracy claim: at least 20 independent leakage groups, at least 5 authoritative square groups, logical-pixel MAE <= 4, p95 <= 8, and worst available executed-regime p95 UCB <= 10.
- Calibrated iOS accuracy claim: at least 12 independent exact-label families spanning at least 3 generations, logical-pixel MAE <= 4, p95 <= 8, and newest-generation p95 <= 10.
- Measured Android accuracy gate: not satisfied.
- Measured iOS accuracy gate: not satisfied.

The committed corpus does not satisfy either platform's calibrated-accuracy sample-size and stress-split gates. The generated artifact is the best measured sparse-corpus fallback; no calibrated accuracy claim is made.

## Known limitations

- Display radius is not identifiable from viewport geometry: different hardware can expose the same runtime features and use different physical radii. The reported collision lower bound quantifies only collisions present in this corpus.
- Android API 31+ exact `WindowInsets` radii, including authoritative all-zero square displays, are accepted on any display only when the native response matches the captured Flutter display/view geometry.
- Pre-31 legacy default radius resources are used only on Android's default display and scale against its current full-display size. Current AOSP per-display arrays require hidden physical display unique IDs; their presence rejects the ambiguous global scalar, so runtime never guesses that mapping.
- Android SDK skin `corner_radius` values describe emulator skin geometry. Connected API 31+ values are stronger labels.
- The committed Android corpus has 1 label with the exact Flutter-equivalent view, padding, gesture, and cutout feature set. SDK-skin and positive legacy-resource rows retain those fields as missing; the report does not claim empirical calibration of unavailable features.
- Insets can describe bars, cutouts, and window state rather than the physical curve. Split-screen and desktop windowing therefore reduce feature support instead of being mistaken for new hardware.
- Android natural top/bottom pairs rotate to left/right pairs in landscape. Flutter geometry cannot distinguish a 180-degree rotation without asymmetric cutout position evidence; padding and gesture insets are not treated as a reliable direction sensor.
- Connected iOS collection always inventories local wired, booted, paired iPhones. Installing is explicit opt-in with a caller-supplied signed public-only app. Its source manifest, embedded source hash, signature, profile App ID, target provisioning, nonce, and payload are verified, but the supplied signed binary remains a trusted local input; the tooling never provisions or changes an Apple account.
- Tool-side corpus and provenance fingerprints use deterministic 64-bit FNV for canonical records and SHA-256 source/group digests. No 32-bit fingerprint can silently deduplicate or union observations.
- Unknown phone-shaped geometry always receives a bounded result; bounded does not mean physically accurate. Fold/hinge geometry is rejected by the estimator.

## Primary references

- [Flutter `MediaQueryData.displayCornerRadii`](https://api.flutter.dev/flutter/widgets/MediaQueryData/displayCornerRadii.html) defines exact logical-pixel radii when Flutter receives them.
- [Android rounded-corner insets](https://developer.android.com/develop/ui/views/layout/insets/rounded-corners) document API 31 `WindowInsets.getRoundedCorner`.
- [AOSP `RoundedCorners`](https://android.googlesource.com/platform/frameworks/base/+/15cb562bcd7427c4ec8565d2d022db4e6c252264/core/java/android/view/RoundedCorners.java) shows default resources and hidden display-unique-ID array mapping.
- [Apple `containerConcentricRadius`](https://developer.apple.com/documentation/uikit/uicornerradius-c.class/containerconcentricradius?language=objc) and [`UICornerConfiguration`](https://developer.apple.com/documentation/uikit/uicornerconfiguration-c.class) define the public iOS 26 collector probe.
- [GroupKFold](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.GroupKFold.html) documents the non-overlapping-group validation principle mirrored by the deterministic union-find folds.
- [Scikit-learn robust and elastic-net linear models](https://scikit-learn.org/stable/modules/linear_model.html) motivate the compact Huber/regularized polynomial candidate.
- [Scikit-learn spline transformers](https://scikit-learn.org/stable/modules/generated/sklearn.preprocessing.SplineTransformer.html) document spline basis and extrapolation behavior.
- [Scikit-learn gradient boosting](https://scikit-learn.org/stable/modules/ensemble.html) documents shallow-tree and shrinkage controls used by the tree candidate.
- [NIST bootstrap percentiles](https://www.itl.nist.gov/div898/handbook/eda/section3/eda334.htm) provide the percentile-bootstrap basis for the deterministic grouped upper-tail comparison.
