part of 'morph.dart';

class _MorphDepartureBridge extends SingleChildRenderObjectWidget {
  const new({required this.coordinator, required super.child});

  final _MorphCoordinator coordinator;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMorphDepartureBridge(coordinator);
}
