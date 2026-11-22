part of '../../motion.dart';

class _MotionParticlePainter extends CustomPainter {
  new({
    required this.image,
    required this.applications,
    required List<Rect> fragments,
    required this.stagger,
    required this.blurFragments,
    required this.capturesBlurredSource,
    this.characterIndices,
    this.sourceRegions,
    this.paintOffset = Offset.zero,
  }) : _bounds = fragments,
       super(repaint: Listenable.merge(applications.map((application) => application.animation))) {
    _operations = List.generate(fragments.length, (_) => MotionEffectTransform._());
    updateOperations();
  }

  final List<Rect> _bounds;
  bool _prepared = false;

  void prepareGeometry() {
    if (_prepared) return;
    _prepared = true;
    final fragments = _bounds;
    final totalArea = fragments.fold<double>(0, (sum, bounds) => sum + bounds.width * bounds.height);
    var remainingParticles = _MotionDisintegrationParameters.maximumParticleCount;
    var firstParticle = 0;
    for (var index = 0; index < fragments.length; index++) {
      final bounds = fragments[index];
      final remainingFragments = fragments.length - index - 1;
      final areaShare =
          (_MotionDisintegrationParameters.maximumParticleCount * bounds.width * bounds.height / totalArea).floor();
      final particleBudget = math.max(1, math.min(remainingParticles - remainingFragments, areaShare));
      final fragment = _MotionParticleFragment(
        bounds: bounds,
        operations: _operations[index],
        budget: particleBudget,
        firstParticle: capturesBlurredSource ? 0 : firstParticle,
        sourceRegion: sourceRegions?[index] ?? bounds,
      );
      if (capturesBlurredSource) {
        _blurredSources.add(
          _MotionParticleBlurredSource(
            image: image,
            fragment: fragment,
            budget: particleBudget,
            isWidget: !blurFragments,
          ),
        );
      } else {
        for (final stage in fragment.stages.values) {
          stage.prepareParticles();
        }
        _fragments.add(fragment);
      }
      firstParticle += fragment.count;
      remainingParticles -= fragment.count;
    }
    if (capturesBlurredSource) return;
    transforms = Float32List(firstParticle * 4);
    colors = Int32List(firstParticle);
    sourceRects = Float32List(firstParticle * 4);
    for (final fragment in _fragments) {
      fragment.writeSourceRects(sourceRects);
    }
  }

  final ui.Image image;
  final List<_MotionApplication> applications;
  final Duration stagger;
  final Offset paintOffset;
  final List<Rect>? sourceRegions;
  final List<int>? characterIndices;
  final bool blurFragments;
  final bool capturesBlurredSource;
  final _blurredSources = <_MotionParticleBlurredSource>[];
  final _blur = _MotionBlur();
  final List<_MotionParticleFragment> _fragments = [];
  late final List<MotionEffectTransform> _operations;
  late final Float32List transforms;
  late final Float32List sourceRects;
  late final Int32List colors;
  final _paint = Paint();
  final _filteredPaint = Paint();

  MotionEffectTransform get singleOperations => _operations.single;

  void updateOperations() {
    for (var character = 0; character < _operations.length; character++) {
      final operations = _operations[character].._reset();
      for (final application in applications) {
        final effect = application.effect;
        final firstOperation = operations._operationCount;
        final animation = application.animation;
        var progress = animation.value;
        var loopPhase = animation is _MotionAnimation ? animation._rawValue : progress;
        if (effect is _TextMotionEffect) {
          final elapsed =
              progress * effect.duration.inMicroseconds -
              stagger.inMicroseconds * (characterIndices?[character] ?? character);
          final phase = elapsed / effect.effect.duration.inMicroseconds;
          if (effect.effect.playback.isOnce) {
            progress = effect.effect.curve.transform(phase.clamp(0.0, 1.0));
          } else {
            loopPhase = (phase % 1 + 1) % 1;
            progress = effect.effect.curve.transform(loopPhase);
          }
          effect.effect.apply(progress, operations);
        } else {
          effect.apply(progress, operations);
        }
        if (capturesBlurredSource && !effect.playback.isOnce) {
          for (var index = firstOperation + 1; index < operations._operationCount; index += 2) {
            operations._operations![index].loopPhase = loopPhase;
          }
        }
      }
      operations._finishOperations();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    updateOperations();
    prepareGeometry();
    if (capturesBlurredSource) {
      canvas
        ..save()
        ..translate(paintOffset.dx, paintOffset.dy);
      try {
        for (final source in _blurredSources) {
          source.paint(canvas);
        }
      } finally {
        canvas.restore();
      }
      return;
    }
    var usesBlur = false;
    for (final fragment in _fragments) {
      fragment.write(transforms, colors);
      usesBlur = usesBlur || (blurFragments && fragment.operations._blurSigma > 0);
    }
    canvas
      ..save()
      ..translate(paintOffset.dx, paintOffset.dy);
    if (usesBlur) {
      _paintFilteredFragments(canvas);
    } else {
      canvas.drawRawAtlas(image, transforms, sourceRects, colors, .srcIn, null, _paint);
    }
    canvas.restore();
  }

  void _paintFilteredFragments(Canvas canvas) {
    var firstFragment = 0;
    while (firstFragment < _fragments.length) {
      final fragment = _fragments[firstFragment];
      final sigma = fragment.operations._blurSigma;
      var endFragment = firstFragment + 1;
      while (endFragment < _fragments.length && _fragments[endFragment].operations._blurSigma == sigma) {
        endFragment++;
      }
      final end = endFragment == _fragments.length ? colors.length : _fragments[endFragment].firstParticle;
      final paint = sigma > 0 ? (_filteredPaint..imageFilter = _blur.filter(sigma)) : _paint;
      _MotionBlur.drawAtlasRange(
        canvas,
        image,
        transforms,
        sourceRects,
        colors,
        paint,
        start: fragment.firstParticle,
        end: end,
      );
      firstFragment = endFragment;
    }
  }

  void dispose() {
    for (final source in _blurredSources) {
      source.dispose();
    }
  }

  @override
  bool shouldRepaint(_MotionParticlePainter oldDelegate) =>
      oldDelegate.image != image || !listEquals(oldDelegate.applications, applications);
}
