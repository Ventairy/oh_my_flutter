import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../exceptions/device_accelerometer_exception.dart';
import '../../exceptions/device_accelerometer_exception_reason.dart';
import '../../gen/device_accelerometer/device_accelerometer.g.dart';
import 'device_accelerometer_platform.dart';
import 'device_accelerometer_sample.dart';

part '_device_accelerometer_coordinator.dart';
part '_device_accelerometer_listener.dart';

/// Reads acceleration through the package's native sensor API.
final class PigeonDeviceAccelerometerPlatform extends DeviceAccelerometerPlatform {
  /// Creates native accelerometer access without starting sampling.
  new() : _api = DeviceAccelerometerHostApi(), _samples = deviceAccelerometerSamples;

  /// Creates access backed by a test host and event source.
  @visibleForTesting
  new test({required this._api, required this._samples});

  final DeviceAccelerometerHostApi _api;
  final Stream<DeviceAccelerometerPlatformSample> Function() _samples;
  _DeviceAccelerometerCoordinator? _coordinator;

  @override
  Future<bool> get isAvailable async {
    try {
      return await _api.isAvailable();
    } on Object catch (error) {
      throw _exception(error);
    }
  }

  @override
  Stream<DeviceAccelerometerSample> watch({required Duration samplingInterval}) {
    return (_coordinator ??= _DeviceAccelerometerCoordinator(api: _api, samples: _samples)).watch(samplingInterval);
  }

  static DeviceAccelerometerException _exception(Object error) {
    if (error is DeviceAccelerometerException) return error;
    final reason = switch (error) {
      PlatformException(code: 'sensorUnavailable') => DeviceAccelerometerExceptionReason.sensorUnavailable,
      PlatformException(code: 'permissionDenied') => DeviceAccelerometerExceptionReason.permissionDenied,
      _ => DeviceAccelerometerExceptionReason.operationUnavailable,
    };
    return DeviceAccelerometerException(reason, cause: error);
  }
}
