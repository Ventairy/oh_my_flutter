part of 'contour.dart';

abstract class _ContourDecorationLayer extends ContainerLayer {
  new() {
    _removeCompositionCallback = addCompositionCallback((_) {
      if (_isMainComposition && _hasSubmittedConfiguration) {
        _mainFrame = WidgetsBinding.instance.platformDispatcher.frameData.frameNumber;
      }
    });
  }

  late bool Function() isCurrent;
  bool Function() canPresent = () => true;
  late final VoidCallback _removeCompositionCallback;
  int _configurationSerial = 0;
  int _submittedConfiguration = -1;
  int _submissionSerial = 0;
  int _mainFrame = -1;
  Object? _submittedOwner;
  bool _submittedForeground = false;
  bool _submittedDecoration = false;

  bool get _isMainComposition =>
      !_ContourSourcePreflight.observing &&
      SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks &&
      owner is RenderView &&
      RendererBinding.instance.renderViews.contains(owner);

  bool get _hasSubmittedConfiguration =>
      attached &&
      identical(owner, _submittedOwner) &&
      _submittedConfiguration == _configurationSerial &&
      _submittedDecoration;

  bool _hasMainSubmission(int frame) {
    if (frame < 0 || _mainFrame != frame || !_hasSubmittedConfiguration) return false;
    Layer? ancestor = parent;
    while (ancestor != null) {
      if (ancestor is _ContourDecorationLayer && !ancestor._hasMainSubmission(frame)) {
        return false;
      }
      ancestor = ancestor.parent;
    }
    return true;
  }

  void _invalidateSubmission() {
    _configurationSerial++;
    _submittedConfiguration = -1;
    _mainFrame = -1;
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    final isMain = _isMainComposition;
    if (isMain) {
      _submittedConfiguration = -1;
      _mainFrame = -1;
    }
    // Observe current source layers before deciding which visible result to emit.
    _ContourSourcePreflight.observe(() => addChildrenToScene(_ContourSourcePreflight.forScene(builder)));
    if (!canPresent()) return;
    final current = isCurrent();
    final decoration = current && addDecorationToScene(builder);
    addChildrenToScene(builder);
    // A ready source or a failed addPicture call cannot create this receipt.
    if (isMain && decoration) {
      _submittedConfiguration = _configurationSerial;
      _submittedOwner = owner;
      _submittedForeground = true;
      _submittedDecoration = true;
      _submissionSerial++;
    }
  }

  bool addDecorationToScene(ui.SceneBuilder builder);

  @override
  void dispose() {
    _removeCompositionCallback();
    super.dispose();
  }
}
