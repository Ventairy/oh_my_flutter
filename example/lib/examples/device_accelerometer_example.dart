import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Shows live acceleration and lets the user start and stop observation.
class DeviceAccelerometerExample extends StatefulWidget {
  /// Creates an accelerometer example with an optional test implementation.
  const new({super.key, this.accelerometer = const DeviceAccelerometer()});

  /// The accelerometer used by the example.
  final DeviceAccelerometer accelerometer;

  @override
  State<DeviceAccelerometerExample> createState() => _DeviceAccelerometerExampleState();
}

class _DeviceAccelerometerExampleState extends State<DeviceAccelerometerExample> {
  StreamSubscription<DeviceAccelerometerSample>? _subscription;
  DeviceAccelerometerSample? _sample;
  Duration? _startedAt;
  String? _error;
  bool _stopping = false;

  void _start() {
    if (_subscription != null || _stopping) return;
    setState(() {
      _error = null;
      _sample = null;
      _startedAt = null;
    });
    _subscription = widget.accelerometer.watch().listen(
      (sample) {
        if (!mounted) return;
        setState(() {
          _startedAt ??= sample.timestamp;
          _sample = sample;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = switch (error) {
            DeviceAccelerometerException(reason: DeviceAccelerometerExceptionReason.unsupportedPlatform) =>
              'Accelerometer is unsupported on this platform.',
            DeviceAccelerometerException(reason: DeviceAccelerometerExceptionReason.sensorUnavailable) =>
              'No accelerometer is available on this device.',
            DeviceAccelerometerException(reason: DeviceAccelerometerExceptionReason.permissionDenied) =>
              'System permissions prevented accelerometer access.',
            _ => 'Accelerometer access failed. Try again.',
          };
        });
      },
      onDone: () {
        if (mounted) setState(() => _subscription = null);
      },
    );
    setState(() {});
  }

  Future<void> _stop() async {
    setState(() => _stopping = true);
    try {
      await _subscription?.cancel();
    } on DeviceAccelerometerException {
      if (mounted) setState(() => _error = 'Accelerometer cleanup failed.');
    } finally {
      if (mounted) {
        setState(() {
          _subscription = null;
          _stopping = false;
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sample = _sample;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Observe acceleration including gravity. Readings use m/s² and device-fixed axes.'),
        const SizedBox(height: 8),
        if (_error case final error?)
          Text(error)
        else if (sample != null) ...[
          Text(
            'X ${sample.x.toStringAsFixed(2)} · Y ${sample.y.toStringAsFixed(2)} · Z ${sample.z.toStringAsFixed(2)} m/s²',
          ),
          Text('Sample time: ${(sample.timestamp - _startedAt!).inMilliseconds} ms'),
        ] else
          Text(_subscription == null ? 'Not observing.' : 'Waiting for a reading…'),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _stopping
              ? null
              : _subscription == null
              ? _start
              : _stop,
          child: Text(
            _stopping
                ? 'Stopping…'
                : _subscription == null
                ? 'Start accelerometer'
                : 'Stop accelerometer',
          ),
        ),
      ],
    );
  }
}
