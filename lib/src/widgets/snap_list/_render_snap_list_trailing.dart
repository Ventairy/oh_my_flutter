part of 'snap_list.dart';

class _RenderSnapListTrailing extends RenderProxyBox {
  _RenderSnapListTrailing(this.axis, this.extent, this.onExtentChanged);

  Axis axis;
  double extent;
  ValueChanged<double> onExtentChanged;
  double? _reportedExtent;

  void configure(Axis value, double viewportExtent, ValueChanged<double> callback) {
    onExtentChanged = callback;
    if (axis == value && extent == viewportExtent) return;
    axis = value;
    extent = viewportExtent;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(
      axis == Axis.vertical
          ? constraints.copyWith(minHeight: 0, maxHeight: extent)
          : constraints.copyWith(minWidth: 0, maxWidth: extent),
      parentUsesSize: true,
    );
    size = constraints.constrain(child!.size);
    final measured = axis == Axis.vertical ? size.height : size.width;
    if (measured != _reportedExtent) {
      _reportedExtent = measured;
      onExtentChanged(measured);
    }
  }
}
