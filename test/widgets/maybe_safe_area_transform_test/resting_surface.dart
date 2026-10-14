import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part '_render_resting_surface.dart';

class RestingSurface extends SingleChildRenderObjectWidget {
  const new({
    required this.translation,
    required super.child,
    this.useRestingGeometry = true,
    this.restingTranslation = .zero,
    super.key,
  });

  final Offset translation;
  final Offset restingTranslation;
  final bool useRestingGeometry;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderRestingSurface(
    translation: translation,
    useRestingGeometry: useRestingGeometry,
    restingTranslation: restingTranslation,
  );

  @override
  void updateRenderObject(BuildContext context, covariant RenderRestingSurface renderObject) => renderObject
    ..translation = translation
    ..restingTranslation = restingTranslation
    ..useRestingGeometry = useRestingGeometry;
}
