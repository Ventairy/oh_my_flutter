part of '../device_display_model.dart';

final class _DeviceDisplayModelCommand {
  Future<int> run(List<String> arguments) async {
    if (arguments.isEmpty || arguments.first == 'help') {
      _printUsage();
      return arguments.isEmpty ? 64 : 0;
    }
    final command = arguments.first;
    final options = arguments.skip(1).toList();
    try {
      return await switch (command) {
        'collect' => _collect(options),
        'train' => _train(options),
        'generate' => _generate(options),
        'validate' => _validate(options),
        'check' => _check(options),
        'check-publish-archive' => _checkPublishArchive(options),
        'check-collectors' => _checkCollectors(options),
        _ => _unknown(command),
      };
    } on FileSystemException catch (error) {
      stderr.writeln(error.message);
      return 1;
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      return 1;
    }
  }

  Future<int> _collect(List<String> arguments) async {
    final output = _option(arguments, '--output');
    final iosRecord = _option(arguments, '--ios-record');
    final iosDeviceApp = _option(arguments, '--ios-device-app');
    final corpus = await _DeviceDisplayModelCollector().collect(
      iosRecordPaths: [?iosRecord],
      iosDeviceAppPath: iosDeviceApp,
    );
    _writeOrPrint(DeviceDisplayModelEncoding.prettyJson(corpus), output);
    return 0;
  }

  Future<int> _train(List<String> arguments) async {
    final corpusPath = _requiredOption(arguments, '--corpus');
    final output = _option(arguments, '--output');
    final corpus = _readMap(corpusPath);
    final manifest = _DeviceDisplayModelTrainer().train(corpus);
    _writeOrPrint(DeviceDisplayModelEncoding.prettyJson(manifest), output);
    return 0;
  }

  Future<int> _generate(List<String> arguments) async {
    final manifestPath = _requiredOption(arguments, '--manifest');
    final output = _option(arguments, '--output');
    final source = _DeviceDisplayModelGenerator().generate(
      _readMap(manifestPath),
    );
    _writeOrPrint(source, output);
    return 0;
  }

  Future<int> _validate(List<String> arguments) async {
    final corpusPath = _requiredOption(arguments, '--corpus');
    final manifestPath = _requiredOption(arguments, '--manifest');
    final output = _option(arguments, '--output');
    final report = _DeviceDisplayModelValidator().report(
      _readMap(corpusPath),
      _readMap(manifestPath),
    );
    _writeOrPrint(report, output);
    return 0;
  }

  Future<int> _check(List<String> arguments) async {
    final corpus = _readMap(_requiredOption(arguments, '--corpus'));
    final manifestPath = _requiredOption(arguments, '--manifest');
    final artifactPath = _requiredOption(arguments, '--artifact');
    final reportPath = _option(arguments, '--report');
    final storedManifest = _readMap(manifestPath);
    final expectedManifest = _DeviceDisplayModelTrainer().train(corpus);
    final manifestMatches =
        DeviceDisplayModelEncoding.canonicalJson(
          storedManifest,
        ) ==
        DeviceDisplayModelEncoding.canonicalJson(expectedManifest);
    final artifactContents = File(artifactPath).readAsStringSync();
    final artifactMatches = artifactContents == _DeviceDisplayModelGenerator().generate(expectedManifest);
    final reportMatches =
        reportPath == null ||
        File(reportPath).readAsStringSync() == _DeviceDisplayModelValidator().report(corpus, expectedManifest);
    final collectorSources = _DeviceDisplayModelCollector().validateSourceManifests();
    final collectorSourcesFresh = collectorSources['iosCollectorSourceManifestFresh'] == true;
    final forbiddenShippingMaterial = RegExp(
      'manufacturer|deviceName|deviceIdentifier|deviceTypeIdentifier|modelIdentifier|hardwareModel|productModel|productDevice|serialNumber|udid|sourceObservationHash|familyGroupHash|generationGroupHash|oemGroupHash|maskCollisionGroupHash|runtimeGroupHash|validationGroup|sourceKind|sourceApiLevel|NSSelectorFromString|_displayCornerRadius|framebufferMask|corner.radius.collector|legacyDisplayCornerRadiusForScreen|effectiveRadiusForCorner|containerConcentricRadius',
      caseSensitive: false,
    ).hasMatch(artifactContents);
    stdout.writeln(
      DeviceDisplayModelEncoding.prettyJson(<String, Object?>{
        'manifestMatchesCorpus': manifestMatches,
        'artifactMatchesManifest': artifactMatches,
        'reportMatchesManifest': reportMatches,
        'shippingArtifactHasForbiddenCatalogMaterial': forbiddenShippingMaterial,
        'collectorSourceManifestsFresh': collectorSourcesFresh,
      }),
    );
    return manifestMatches && artifactMatches && reportMatches && !forbiddenShippingMaterial && collectorSourcesFresh
        ? 0
        : 1;
  }

  Future<int> _checkPublishArchive(List<String> arguments) async {
    final packageRoot = Directory(
      _option(arguments, '--package-root') ?? Directory.current.path,
    ).absolute;
    final listingPath = _option(arguments, '--listing');
    int? publishDryRunExitCode;
    final listing = listingPath == null
        ? await () async {
            final result = await Process.run(
              'fvm',
              const <String>['flutter', 'pub', 'publish', '--dry-run'],
              workingDirectory: packageRoot.path,
            );
            publishDryRunExitCode = result.exitCode;
            return '${result.stdout}\n${result.stderr}';
          }()
        : File(listingPath).readAsStringSync();
    final publishedPaths = _publishedPaths(listing);
    final publishDryRunSucceeded = publishDryRunExitCode == null || publishDryRunExitCode == 0;
    final listingIsComplete = listing.contains('Total compressed archive size:') && publishedPaths.isNotEmpty;
    final excludedModelToolingIncluded = publishedPaths.any(
      (path) =>
          path == 'tool/device_display_model' ||
          path.startsWith('tool/device_display_model/') ||
          path == 'test/tool/device_display_model' ||
          path.startsWith('test/tool/device_display_model/'),
    );
    final forbiddenSourcePaths = <String>[];
    final forbiddenSourcePattern = RegExp(
      'NSSelectorFromString|_displayCornerRadius|effectiveRadiusForCorner|'
      r'containerConcentricRadius|corner\.radius\.collector|'
      'legacyDisplayCornerRadiusForScreen|device_display_model_collector|'
      'CornerRadiusCollectorActivity|OMF_DEVICE_DISPLAY_COLLECTOR_SOURCE_HASH|'
      'OMFDeviceDisplayCollectorAppDelegate|'
      'ios26_connected_public_uikit_concentric_corner',
      caseSensitive: false,
    );
    for (final path in publishedPaths) {
      final file = File('${packageRoot.path}/$path');
      if (file.existsSync() &&
          forbiddenSourcePattern.hasMatch(
            utf8.decode(file.readAsBytesSync(), allowMalformed: true),
          )) {
        forbiddenSourcePaths.add(path);
      }
    }
    forbiddenSourcePaths.sort();
    stdout.writeln(
      DeviceDisplayModelEncoding.prettyJson(<String, Object?>{
        'archiveListingComplete': listingIsComplete,
        'archiveFileCount': publishedPaths
            .where(
              (path) => FileSystemEntity.isFileSync(
                '${packageRoot.path}/$path',
              ),
            )
            .length,
        'publishDryRunExitCode': publishDryRunExitCode,
        'publishDryRunSucceeded': publishDryRunSucceeded,
        'archiveIncludesExcludedModelTooling': excludedModelToolingIncluded,
        'shippingSourceHasPrivateCollectorMaterial': forbiddenSourcePaths.isNotEmpty,
        'forbiddenShippingSourcePaths': forbiddenSourcePaths,
      }),
    );
    return publishDryRunSucceeded && listingIsComplete && !excludedModelToolingIncluded && forbiddenSourcePaths.isEmpty
        ? 0
        : 1;
  }

  Future<int> _checkCollectors(List<String> arguments) async {
    if (arguments.isNotEmpty) {
      throw const FormatException('check-collectors accepts no options.');
    }
    final result = await _DeviceDisplayModelCollector().validateTooling();
    stdout.writeln(DeviceDisplayModelEncoding.prettyJson(result));
    return result['androidCollectorBuiltAndLinted'] == true && result['iosCollectorSourceManifestFresh'] == true
        ? 0
        : 1;
  }

  List<String> _publishedPaths(String listing) {
    final paths = <String>[];
    final directories = <String>[];
    final treeLine = RegExp(
      r'^((?:(?:│   )|(?:    ))*)(?:├── |└── )(.+)$',
    );
    final sizeSuffix = RegExp(r' \((?:<)?\d+(?:\.\d+)? [KMGT]?B\)$');
    for (final line in const LineSplitter().convert(listing)) {
      final match = treeLine.firstMatch(line);
      if (match == null) {
        continue;
      }
      final depth = match.group(1)!.length ~/ 4;
      final listedName = match.group(2)!;
      final isFile = sizeSuffix.hasMatch(listedName);
      final name = listedName.replaceFirst(sizeSuffix, '');
      if (directories.length > depth) {
        directories.removeRange(depth, directories.length);
      }
      final path = <String>[...directories, name].join('/');
      paths.add(path);
      if (!isFile) {
        directories.add(name);
      }
    }
    return paths;
  }

  int _unknown(String command) {
    stderr.writeln('Unknown command: $command');
    _printUsage();
    return 64;
  }

  String? _option(List<String> arguments, String name) {
    final index = arguments.indexOf(name);
    if (index == -1) {
      return null;
    }
    if (index + 1 >= arguments.length) {
      throw FormatException('Missing value for $name.');
    }
    return arguments[index + 1];
  }

  String _requiredOption(List<String> arguments, String name) {
    final value = _option(arguments, name);
    if (value == null) {
      throw FormatException('Missing required option $name.');
    }
    return value;
  }

  Map<String, Object?> _readMap(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  void _writeOrPrint(String contents, String? path) {
    if (path == null) {
      stdout.writeln(contents);
      return;
    }
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents.endsWith('\n') ? contents : '$contents\n');
  }

  void _printUsage() {
    stdout.writeln('''
Usage:
  collect [--ios-record record.json] [--ios-device-app /absolute/Collector.app] [--output corpus.json]
  train --corpus corpus.json [--output model_manifest.json]
  generate --manifest model_manifest.json [--output model.g.dart]
  validate --corpus corpus.json --manifest model_manifest.json [--output report.md]
  check --corpus corpus.json --manifest model_manifest.json --artifact model.g.dart [--report report.md]
  check-collectors
  check-publish-archive [--package-root directory] [--listing dry-run-output.txt]''');
  }
}
