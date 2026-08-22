import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Demonstrates automatic and manually managed foreground location access.
class DeviceLocationExample extends StatefulWidget {
  /// Creates the DeviceLocation example.
  const DeviceLocationExample({
    this.checkPermission,
    this.requestPermission,
    this.getCoordinates,
    this.openLocationSettings,
    super.key,
  });

  /// Overrides the permission-status operation for deterministic tests.
  final Future<DeviceLocationPermissionStatus> Function()? checkPermission;

  /// Overrides the permission-request operation for deterministic tests.
  final Future<DeviceLocationPermissionStatus> Function()? requestPermission;

  /// Overrides coordinate acquisition for deterministic tests.
  final Future<DeviceLocationCoordinates> Function({
    bool prompt,
  })?
  getCoordinates;

  /// Overrides settings navigation for deterministic tests.
  final Future<bool> Function()? openLocationSettings;

  @override
  State<DeviceLocationExample> createState() => _DeviceLocationExampleState();
}

class _DeviceLocationExampleState extends State<DeviceLocationExample> {
  static const _location = DeviceLocation();

  String _status = 'Choose a location operation.';
  bool _working = false;

  Future<void> _run(Future<String> Function() operation) async {
    if (_working) return;
    setState(() => _working = true);

    try {
      final status = await operation();
      if (!mounted) return;
      setState(() => _status = status);
    } on DeviceLocationException catch (error) {
      if (!mounted) return;
      setState(() => _status = _failureMessage(error.reason));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String> _checkPermission() async {
    final request = widget.checkPermission;
    late final DeviceLocationPermissionStatus permission;
    if (request == null) {
      permission = await _location.permissionStatus;
    } else {
      permission = await request();
    }
    return 'Permission: ${permission.name}';
  }

  Future<String> _requestPermission() async {
    final request = widget.requestPermission;
    late final DeviceLocationPermissionStatus permission;
    if (request == null) {
      permission = await _location.requestPermission();
    } else {
      permission = await request();
    }
    return 'Permission: ${permission.name}';
  }

  Future<String> _getCoordinates({required bool requestPermission}) async {
    final request = widget.getCoordinates;
    final coordinates = request == null
        ? await _location.getCurrentCoordinates(
            requestPermission: requestPermission,
          )
        : await request(prompt: requestPermission);
    return '${coordinates.latitude}, ${coordinates.longitude} '
        '(±${coordinates.accuracy} m)';
  }

  Future<String> _openSettings() async {
    final request = widget.openLocationSettings;
    late final bool opened;
    if (request == null) {
      opened = await _location.openLocationSettings();
    } else {
      opened = await request();
    }
    return opened ? 'Application settings opened.' : 'Settings did not open.';
  }

  String _failureMessage(DeviceLocationExceptionReason failure) {
    switch (failure) {
      case DeviceLocationExceptionReason.servicesDisabled:
        return 'Location services are disabled.';
      case DeviceLocationExceptionReason.permissionDenied:
        return 'Location permission was denied.';
      case DeviceLocationExceptionReason.permissionPermanentlyDenied:
        return 'Location access is blocked. Check system settings or policy.';
      case DeviceLocationExceptionReason.configurationMissing:
        return 'Location is not configured for this application.';
      case DeviceLocationExceptionReason.unsupportedPlatform:
        return 'Location is not supported on this device.';
      case DeviceLocationExceptionReason.operationUnavailable:
        return 'The location operation is unavailable.';
      case DeviceLocationExceptionReason.coordinatesUnavailable:
        return 'Current coordinates are unavailable.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton(
          onPressed: _working
              ? null
              : () => _run(
                  () => _getCoordinates(requestPermission: true),
                ),
          child: const Text('Use current location'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _working ? null : () => _run(_checkPermission),
              child: const Text('Check permission'),
            ),
            OutlinedButton(
              onPressed: _working ? null : () => _run(_requestPermission),
              child: const Text('Request permission'),
            ),
            OutlinedButton(
              onPressed: _working
                  ? null
                  : () => _run(
                      () => _getCoordinates(requestPermission: false),
                    ),
              child: const Text('Use without prompting'),
            ),
            OutlinedButton(
              onPressed: _working ? null : () => _run(_openSettings),
              child: const Text('Open app settings'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(_working ? 'Working…' : _status),
      ],
    );
  }
}
