// Release-build fixture proving that importing oh_my_flutter without using
// DeviceLocation leaves its native iOS framework out of the final application.
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  final background = const Color(0xFF204060).lighten(0.1);
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(color: background),
    ),
  );
}
