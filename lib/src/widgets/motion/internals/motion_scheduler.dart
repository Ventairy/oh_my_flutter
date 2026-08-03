part of '../motion.dart';

/// Shares one scheduler callback across every active motion.
class _MotionScheduler {
  _MotionScheduler._();

  static final _MotionScheduler instance = _MotionScheduler._();

  final FrameCallback _frameCallback = _handleFrame;
  _MotionAnimationGroup? _head;
  _MotionAnimationGroup? _cursor;
  int? _callbackId;
  int _forcedFrameCount = 0;

  void add(_MotionAnimationGroup group) {
    if (group._schedulerLinked) {
      return;
    }

    group
      .._schedulerLinked = true
      .._schedulerPrevious = null
      .._schedulerNext = _head;
    if (group.forceFrames) {
      _forcedFrameCount += 1;
    }
    _head?._schedulerPrevious = group;
    _head = group;
    _scheduleFrame();
  }

  void remove(_MotionAnimationGroup group) {
    if (!group._schedulerLinked) {
      return;
    }

    if (identical(_cursor, group)) {
      _cursor = group._schedulerNext;
    }
    final previous = group._schedulerPrevious;
    final next = group._schedulerNext;
    if (group.forceFrames) {
      _forcedFrameCount -= 1;
    }
    if (previous == null) {
      _head = next;
    } else {
      previous._schedulerNext = next;
    }
    next?._schedulerPrevious = previous;
    group
      .._schedulerLinked = false
      .._schedulerPrevious = null
      .._schedulerNext = null;

    if (_head == null && _callbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(_callbackId!);
      _callbackId = null;
    }
  }

  void updateForceFrames({required bool oldValue, required bool newValue}) {
    if (oldValue == newValue) {
      return;
    }
    _forcedFrameCount += newValue ? 1 : -1;
    if (newValue) {
      SchedulerBinding.instance.scheduleForcedFrame();
    }
  }

  void _scheduleFrame({bool rescheduling = false}) {
    if (_callbackId != null || _head == null) {
      return;
    }
    final binding = SchedulerBinding.instance;
    if (_forcedFrameCount > 0) {
      binding.scheduleForcedFrame();
    }
    _callbackId = binding.scheduleFrameCallback(
      _frameCallback,
      rescheduling: rescheduling,
      scheduleNewFrame: _forcedFrameCount == 0,
    );
  }

  static void _handleFrame(Duration timeStamp) {
    final scheduler = instance.._callbackId = null;
    var group = scheduler._head;
    while (group != null) {
      scheduler._cursor = group._schedulerNext;
      if (group._schedulerLinked) {
        try {
          group._tick(timeStamp);
        } catch (exception, stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: exception,
              stack: stack,
              library: 'oh_my_flutter motion scheduler',
              context: ErrorDescription('while advancing a Motion animation'),
            ),
          );
        }
      }
      group = scheduler._cursor;
    }
    scheduler
      .._cursor = null
      .._scheduleFrame(rescheduling: true);
  }
}
