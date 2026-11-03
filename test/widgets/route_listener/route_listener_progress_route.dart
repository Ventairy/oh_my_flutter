import 'package:flutter/material.dart';

class RouteListenerProgressRoute extends PageRouteBuilder<void> {
  new({required this.progress, required WidgetBuilder builder})
    : super(pageBuilder: (context, animation, secondaryAnimation) => builder(context));

  Animation<double> progress;

  @override
  Animation<double> get animation => progress;
}
