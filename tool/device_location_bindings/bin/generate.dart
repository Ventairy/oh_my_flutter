import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main(List<String> arguments) async {
  final repositoryRoot = Platform.script.resolve('../../../');
  final output = arguments.isEmpty
      ? repositoryRoot.resolve(
          'lib/src/device/device_location/apple_device_location/apple_device_location_native_bindings.g.dart',
        )
      : File(arguments.single).absolute.uri;
  final header = repositoryRoot.resolve('src/device_location/apple_device_location.h');
  const assetId =
      'package:oh_my_flutter/src/device/device_location/apple_device_location/apple_device_location_platform.dart';

  FfiGenerator(
    headers: Headers(
      entryPoints: [header],
      include: (uri) => uri.pathSegments.last == 'apple_device_location.h',
      compilerOptions: ['-I${repositoryRoot.resolve('src/device_location').toFilePath()}'],
    ),
    functions: Functions(
      include: (declaration) => {
        'omf_device_location_is_service_enabled',
        'omf_device_location_check_permission',
        'omf_device_location_request_permission',
        'omf_device_location_request_coordinates',
        'omf_device_location_request_address',
        'omf_device_location_allocate',
        'omf_device_location_free',
        'omf_device_location_open_settings',
      }.contains(declaration.originalName),
      recordUse: (_) => true,
    ),
    typedefs: Typedefs.includeSet({
      'OMFDeviceLocationValueCallback',
      'OMFDeviceLocationCoordinatesCallback',
      'OMFDeviceLocationAddressCallback',
      'OMFDeviceLocationFailure',
    }),
    output: Output(
      dartFile: output,
      style: const NativeExternalBindings(assetId: assetId),
      preamble:
          '// Generated from src/device_location/apple_device_location.h. Do not edit.\n'
          '// Run make generate-device-location-bindings to regenerate.',
    ),
  ).generate();
}
