/// Helps choose a fallback when a shared element cannot animate during navigation.
///
/// Status describes the latest navigation handled by a Morph navigator observer,
/// rather than local changes to an appearance.
enum MorphTagStatus {
  /// The observer has not evaluated any navigation yet.
  idle,

  /// Navigation has begun and Morph is resolving the appearances.
  pending,

  /// No usable flight was accepted. A normal navigation transition can be used.
  ///
  /// This also applies when animations are disabled. Honor reduced motion before
  /// selecting an animated fallback.
  unmatched,

  /// An accepted flight is active, including its final endpoint handoff.
  flying,

  /// The accepted flight reached the navigation destination and handed off.
  completed,

  /// An accepted flight ended without completing the requested navigation.
  ///
  /// Cancellation does not request a new fallback animation.
  cancelled,
}
