part of '../motion.dart';

class _RenderMotionParticleBlur extends RenderProxyBox {
  new(this._applications, {required this.preview}) {
    _updateBlur();
  }

  List<_MotionApplication> _applications;
  final bool preview;
  final _transform = MotionEffectTransform._();
  final _blur = _MotionBlur();
  double _sigma = 0;

  List<_MotionApplication> get applications => _applications;
  set applications(List<_MotionApplication> value) {
    if (listEquals(_applications, value)) return;
    if (attached) _unlisten();
    _applications = value;
    if (attached) _listen();
    _updateBlur();
  }

  @override
  bool get isRepaintBoundary => child != null && _sigma > 0;

  @override
  OffsetLayer updateCompositedLayer({required covariant ImageFilterLayer? oldLayer}) {
    return (oldLayer ?? ImageFilterLayer())..imageFilter = _blur.filter(_sigma);
  }

  @override
  Rect get paintBounds => (Offset.zero & size).inflate(_MotionBlur.outset(_sigma));

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen();
    _updateBlur();
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  void _listen() {
    for (final application in _applications) {
      application.animation.addListener(_updateBlur);
    }
  }

  void _unlisten() {
    for (final application in _applications) {
      application.animation.removeListener(_updateBlur);
    }
  }

  void _updateBlur() {
    _transform._reset();
    for (final application in _applications) {
      application.effect.apply(application.animation.value, _transform);
    }
    if (preview) _transform._finishOperations();
    final sigma = preview ? _transform._previewBlurSigma : _transform._blurSigma;
    if (_sigma == sigma) return;
    final wasRepaintBoundary = isRepaintBoundary;
    _sigma = sigma;
    if (wasRepaintBoundary != isRepaintBoundary) {
      markNeedsCompositingBitsUpdate();
      markNeedsPaint();
    } else if (isRepaintBoundary) {
      markNeedsCompositedLayerUpdate();
    }
  }
}
