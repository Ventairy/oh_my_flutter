import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Schedules glyph shader preparation around frame work.
@internal
abstract final class MotionShaderPreparation {
  /// Runs a shader preparation phase when the scheduler can accept it.
  static void schedule(VoidCallback callback, {required bool waitForQuiet}) {
    if (!waitForQuiet) {
      _whenIdle(callback);
      return;
    }

    // A frame can look idle just before an interaction schedules its repaint.
    // Keep preparation off the raster queue while frames are still arriving.
    final scheduler = SchedulerBinding.instance;
    const grace = Duration(milliseconds: 150);
    _whenIdle(() {
      final wait = clock.stopwatch()..start();
      var lastFrame = Duration.zero;
      var pending = true;

      void recordFrame(Duration _) {
        if (!pending) return;
        lastFrame = wait.elapsed;
        scheduler.addPostFrameCallback(recordFrame);
      }

      void check() {
        if (!scheduler.framesEnabled || scheduler.hasScheduledFrame || scheduler.transientCallbackCount != 0) {
          scheduler.addPostFrameCallback((_) => Timer(grace, check));
          return;
        }
        final remaining = grace + lastFrame - wait.elapsed;
        if (remaining > Duration.zero) {
          Timer(remaining, check);
          return;
        }
        pending = false;
        callback();
      }

      scheduler.addPostFrameCallback(recordFrame);
      Timer(grace, check);
    });
  }

  static void _whenIdle(VoidCallback callback) {
    final scheduler = SchedulerBinding.instance;
    void afterFrame(Duration _) {
      if (scheduler.hasScheduledFrame || scheduler.transientCallbackCount != 0) {
        scheduler.addPostFrameCallback(afterFrame);
      } else {
        callback();
      }
    }

    // Retry once per rendered frame while busy. The scheduler's idle task
    // queue can repeatedly schedule timer events during active animation.
    if (scheduler.schedulerPhase == SchedulerPhase.idle ||
        scheduler.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      afterFrame(Duration.zero);
    } else {
      scheduler.addPostFrameCallback(afterFrame);
    }
  }
}
