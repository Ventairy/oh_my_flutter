import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks/hooks.dart';

import '../../hook/link.dart' as link_hook;

void main() {
  test(
    'when an unreachable library is omitted, '
    'it should produce no assets or manual recording dependencies',
    () async {
      final temporary = Directory.systemTemp.createTempSync('contour-link-test-');
      addTearDown(() => temporary.delete(recursive: true));
      final recordings = File.fromUri(temporary.uri.resolve('recorded_uses.json'))..writeAsStringSync('{}');
      final outputUri = temporary.uri.resolve('output.json');
      final builder = LinkInputBuilder()
        ..setupShared(
          packageName: 'oh_my_flutter',
          packageRoot: Directory.current.uri,
          outputFile: outputUri,
          outputDirectoryShared: temporary.uri.resolve('shared/'),
        )
        ..setupLink(
          assets: const [],
          assetsFromLinking: const [],
          recordedUsesFile: recordings.uri,
        );
      CodeAssetExtension(
        targetArchitecture: Architecture.arm64,
        targetOS: OS.android,
        linkModePreference: LinkModePreference.dynamic,
        android: AndroidCodeConfig(targetNdkApi: 24),
      ).setupLinkInput(builder);
      final config = File.fromUri(temporary.uri.resolve('input.json'))
        ..writeAsStringSync(jsonEncode(builder.build().json));

      await link_hook.main(['--config=${config.path}']);
      final output = LinkOutput(
        jsonDecode(File.fromUri(outputUri).readAsStringSync()) as Map<String, Object?>,
      );

      expect((output.assets.encodedAssets.isEmpty, output.dependencies.isEmpty), (true, true));
    },
  );
}
