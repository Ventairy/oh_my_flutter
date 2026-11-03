import 'package:flutter/animation.dart';

class RouteListenerProgressAnimation extends AnimationController {
  new({required super.vsync, super.value});

  int listenerCount = 0;

  @override
  void addListener(VoidCallback listener) {
    listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerCount--;
    super.removeListener(listener);
  }
}
