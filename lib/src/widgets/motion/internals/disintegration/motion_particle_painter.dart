part of '../../motion.dart';

class _MotionParticlePainter extends CustomPainter {
  new({
    required this.image,
    required this.applications,
    required List<Rect> fragments,
    required this.stagger,
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
        firstParticle: firstParticle,
        sourceRegion: sourceRegions?[index] ?? bounds,
      );
      _fragments.add(fragment);
      firstParticle += fragment.count;
      remainingParticles -= fragment.count;
    }
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
  final List<_MotionParticleFragment> _fragments = [];
  late final List<MotionEffectTransform> _operations;
  late final Float32List transforms;
  late final Float32List sourceRects;
  late final Int32List colors;
  final _paint = Paint();

  MotionEffectTransform get singleOperations => _operations.single;

  void updateOperations() {
    for (var character = 0; character < _operations.length; character++) {
      final operations = _operations[character].._reset();
      for (final application in applications) {
        final effect = application.effect;
        var progress = application.animation.value;
        if (effect is _TextMotionEffect) {
          final elapsed = progress * effect.duration.inMicroseconds - stagger.inMicroseconds * character;
          progress = effect.effect.curve.transform(
            effect.effect.playback.isOnce
                ? (elapsed / effect.effect.duration.inMicroseconds).clamp(0.0, 1.0)
                : ((elapsed / effect.effect.duration.inMicroseconds) % 1 + 1) % 1,
          );
          effect.effect.apply(progress, operations);
        } else {
          effect.apply(progress, operations);
        }
      }
      operations._finishOperations();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    updateOperations();
    prepareGeometry();
    for (final fragment in _fragments) {
      fragment.write(transforms, colors);
    }
    canvas
      ..save()
      ..translate(paintOffset.dx, paintOffset.dy)
      ..drawRawAtlas(image, transforms, sourceRects, colors, .srcIn, null, _paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_MotionParticlePainter oldDelegate) =>
      oldDelegate.image != image || !listEquals(oldDelegate.applications, applications);
}
