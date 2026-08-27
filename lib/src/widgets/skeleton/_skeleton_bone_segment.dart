part of 'skeleton.dart';

class _SkeletonBoneSegment {
  _SkeletonBoneSegment({required this.bounds});

  final Rect bounds;
  final _SkeletonBoneCommands commands = _SkeletonBoneCommands();

  PictureLayer? _pictureLayer;
  late final ContainerLayer _effectLayer;
  late final _SkeletonBoneSegmentMode _mode;
  Color? _recordedColor;

  void attachTo(
    ContainerLayer parent,
    Paint paint,
    SkeletonStyle style,
  ) {
    if (commands.isEmpty) return;

    final mode = _modeFor(style.effect);
    _mode = mode;
    final pictureLayer = PictureLayer(bounds);
    _pictureLayer = pictureLayer;
    switch (mode) {
      case _SkeletonBoneSegmentMode.staticPicture:
        _recordPicture(paint);
        parent.append(pictureLayer);
        commands.clear();
      case _SkeletonBoneSegmentMode.customAnimated:
        pictureLayer.willChangeHint = true;
        _recordPicture(paint);
        parent.append(pictureLayer);
      case _SkeletonBoneSegmentMode.fade:
        final opacityLayer = OpacityLayer();
        _effectLayer = opacityLayer;
        _recordSolidPicture(style.color);
        _updateOpacity(opacityLayer, paint);
        opacityLayer.append(pictureLayer);
        parent.append(opacityLayer);
        commands.clear();
      case _SkeletonBoneSegmentMode.shimmerMask:
        final shaderMaskLayer = ShaderMaskLayer()
          ..maskRect = bounds
          ..blendMode = BlendMode.srcIn
          ..shader = paint.shader;
        _effectLayer = shaderMaskLayer;
        _recordPicture(Paint()..color = const Color(0xFFFFFFFF));
        shaderMaskLayer.append(pictureLayer);
        parent.append(shaderMaskLayer);
        commands.clear();
    }
  }

  void update(Paint paint, SkeletonStyle style) {
    switch (_mode) {
      case _SkeletonBoneSegmentMode.staticPicture:
        return;
      case _SkeletonBoneSegmentMode.customAnimated:
        _recordPicture(paint);
      case _SkeletonBoneSegmentMode.fade:
        final opacityLayer = _effectLayer as OpacityLayer;
        if (_recordedColor != style.color) {
          _recordSolidPicture(style.color);
        }
        _updateOpacity(opacityLayer, paint);
      case _SkeletonBoneSegmentMode.shimmerMask:
        (_effectLayer as ShaderMaskLayer).shader = paint.shader;
    }
  }

  _SkeletonBoneSegmentMode _modeFor(SkeletonEffect? effect) {
    if (effect is SkeletonFadeEffect) return _SkeletonBoneSegmentMode.fade;
    if (effect is SkeletonShimmerEffect) {
      return _SkeletonBoneSegmentMode.shimmerMask;
    }
    if (effect is SkeletonAnimatedEffectBase) {
      return _SkeletonBoneSegmentMode.customAnimated;
    }
    return _SkeletonBoneSegmentMode.staticPicture;
  }

  void _recordSolidPicture(Color color) {
    _recordedColor = color;
    _recordPicture(Paint()..color = color.withValues(alpha: 1));
  }

  void _recordPicture(Paint paint) {
    final pictureLayer = _pictureLayer;
    if (pictureLayer == null) return;

    final recorder = RendererBinding.instance.createPictureRecorder();
    final canvas = RendererBinding.instance.createCanvas(recorder);
    commands.replay(canvas, paint);
    pictureLayer.picture = recorder.endRecording();
  }

  void _updateOpacity(OpacityLayer layer, Paint paint) {
    layer.alpha = ui.Color.getAlphaFromOpacity(paint.color.a);
  }
}
