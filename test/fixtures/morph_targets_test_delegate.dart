import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class MorphTargetsTestDelegate extends MorphFlightDelegate<int> {
  const new({this.onCapture, this.onFlight});

  final VoidCallback? onCapture;
  final void Function(MorphFlight<int> flight)? onFlight;

  @override
  int properties(MorphEndpointContext endpoint) {
    onCapture?.call();
    return 1;
  }

  @override
  int lerpProperties(int source, int destination, MorphFlightProgress progress) => source;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<int> flight) {
    onFlight?.call(flight);
    return const ColoredBox(color: Color(0xFFFF0000));
  }
}
