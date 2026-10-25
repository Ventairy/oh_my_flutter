import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks/hooks.dart';

import '../../hook/build.dart' as build_hook;

void main() {
  for (final target in [OS.linux, OS.windows]) {
    test('when native tracing is unsupported on $target, it should build without a native compiler', () async {
      final temporary = Directory.systemTemp.createTempSync('contour-build-test-');
      addTearDown(() => temporary.delete(recursive: true));
      final outputUri = temporary.uri.resolve('output.json');
      final builder = BuildInputBuilder()
        ..setupShared(
          packageName: 'oh_my_flutter',
          packageRoot: Directory.current.uri,
          outputFile: outputUri,
          outputDirectoryShared: temporary.uri.resolve('shared/'),
        )
        ..setupBuildInput();
      builder.config.setupBuild(linkingEnabled: true);
      CodeAssetExtension(
        targetArchitecture: Architecture.x64,
        targetOS: target,
        linkModePreference: LinkModePreference.dynamic,
      ).setupBuildInput(builder);
      final config = File.fromUri(temporary.uri.resolve('input.json'))
        ..writeAsStringSync(jsonEncode(builder.build().json));

      await build_hook.main(['--config=${config.path}']);
      final output = BuildOutput(
        jsonDecode(File.fromUri(outputUri).readAsStringSync()) as Map<String, Object?>,
      );

      expect(output.assets.encodedAssets, isEmpty);
    });
  }
}
