part of 'contour.dart';

/// Reads current MAIN submissions for focused rendering tests.
///
/// This internal observer cannot select a backend, prepare a source, or make
/// an unsubmitted result qualify. It is not exported by the package library.
@visibleForTesting
class ContourPresentationTestHarness {
  new _();

  /// Returns a receipt only for a current decoration actually emitted in MAIN.
  ///
  /// Identity hashes label validated source objects; they are not provenance.
  static ({
    int mainFrameNumber,
    int configurationSerial,
    int submissionSerial,
    int sourceRevision,
    int sourceIdentity,
    int carrierIdentity,
    bool liveForegroundSubmitted,
    bool knownBoxDirect,
  })?
  currentMainPresentation({required RenderObject renderObject, required int frameNumber}) {
    if (renderObject is! _RenderContour || !renderObject.attached) return null;
    final layer = renderObject._decorationLayer.layer;
    final capture = renderObject.child;
    if (layer == null || capture is! _RenderContourCapture || !layer._hasMainSubmission(frameNumber)) return null;
    if (layer._sourceRevision != renderObject._contentRevision || layer._picture == null) return null;
    RenderObject? view = renderObject;
    while (view != null && view is! RenderView) {
      view = view.parent;
    }
    if (view is! RenderView ||
        view.configuration.devicePixelRatio != renderObject._pixelRatio ||
        view.flutterView.devicePixelRatio != renderObject._pixelRatio) {
      return null;
    }
    final composite = renderObject._compositeBacking;
    if (composite.ready) {
      if (!layer._submittedForeground ||
          !composite.ready ||
          !composite.current(renderObject, capture) ||
          !identical(layer._sourceIdentity, composite.identity)) {
        return null;
      }
    } else {
      final declared = renderObject._declaredSource;
      if (!layer._submittedForeground ||
          declared == null ||
          !declared.isCurrent(capture) ||
          !identical(layer._sourceIdentity, renderObject._shape)) {
        return null;
      }
    }
    return (
      mainFrameNumber: frameNumber,
      configurationSerial: layer._configurationSerial,
      submissionSerial: layer._submissionSerial,
      sourceRevision: layer._sourceRevision,
      sourceIdentity: layer._sourceIdentity.hashCode,
      carrierIdentity: layer._picture.hashCode,
      liveForegroundSubmitted: layer._submittedForeground,
      knownBoxDirect: renderObject._declaredSource?.knownBox != null,
    );
  }

  /// Returns only the original source subtree of an emitted current carrier.
  ///
  /// This is a source-input witness, not proof that the source contains ink.
  /// Tests must inspect its original recordings separately; an empty source is
  /// a valid native composite and must not qualify an all-content endpoint.
  static ContainerLayer? currentSourceLayer({required RenderObject renderObject, required int frameNumber}) {
    final receipt = currentMainPresentation(renderObject: renderObject, frameNumber: frameNumber);
    if (receipt == null || renderObject is! _RenderContour || !renderObject._compositeBacking.ready) return null;
    final capture = renderObject.child;
    return capture is _RenderContourCapture ? capture.captureLayer : null;
  }
}
