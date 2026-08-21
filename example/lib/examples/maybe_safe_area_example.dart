import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows a compact control that avoids unsafe edges only when necessary.
class MaybeSafeAreaExample extends StatelessWidget {
  /// Creates the MaybeSafeArea example.
  const MaybeSafeAreaExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaybeSafeArea(
      child: Chip(label: Text('Safe at the edge')),
    );
  }
}
