/// Configures deterministic behavior for Morph's own test suites.
///
/// This internal utility is not exported by `package:oh_my_flutter`.
abstract final class MorphTestConfiguration {
  /// Whether tests may prepare asynchronous retained text rasters.
  static bool rasterizationEnabled = true;
}
