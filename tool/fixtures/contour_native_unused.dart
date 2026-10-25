// Keeps a public OMF dependency in the app without using Contour.
import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(color: const Color(0xff204060).lighten(.1)),
    ),
  );
}
