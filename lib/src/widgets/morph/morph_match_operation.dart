/// Distinguishes the changes that can bring matching appearances together.
///
/// Navigation values describe Navigator observer notifications, not the name
/// of the navigation method called. Compound updates report the operation
/// responsible for the destination becoming current.
enum MorphMatchOperation {
  /// An appearance changed within the same route or standalone overlay.
  local,

  /// A route was pushed above the previous top route.
  push,

  /// The top route was popped to reveal another route.
  pop,

  /// The top route was replaced, including through pushReplacement.
  replace,

  /// The top route was removed to reveal another route.
  remove,

  /// Observer notifications did not identify the top-route change.
  unknown,
}
