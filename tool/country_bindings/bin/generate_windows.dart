import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ffigen/ffigen.dart';

Future<void> main(List<String> arguments) async {
  // The SDK header is pinned for reproducibility and stays in the local cache.
  final header = File('.dart_tool/country_bindings/icu.h');
  const checksum = 'b6bc444570b0f74b34c071c012fd85eba00d8f88d44e8dd1d1e1088e42ef3754';
  if (!header.existsSync()) {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(
        Uri.parse(
          'https://raw.githubusercontent.com/microsoft/win32metadata/'
          '29896383c51d9dd6a2ea0ec6304d095baca9418c/'
          'generation/WinSDK/RecompiledIdlHeaders/um/icu.h',
        ),
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Could not download the pinned ICU header: ${response.statusCode}');
      }
      final bytes = await response.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
      if (sha256.convert(bytes).toString() != checksum) throw StateError('ICU header checksum mismatch.');
      header.parent.createSync(recursive: true);
      header.writeAsBytesSync(bytes);
    } finally {
      client.close(force: true);
    }
  }
  if (sha256.convert(header.readAsBytesSync()).toString() != checksum) {
    throw StateError('Cached ICU header checksum mismatch; remove ${header.path} and regenerate.');
  }
  FfiGenerator(
    headers: Headers(
      entryPoints: [header.absolute.uri],
      include: (uri) => uri.pathSegments.last == 'icu.h',
      compilerOptions: [
        '-DNTDDI_VERSION=0x0A000004',
        '-DNTDDI_WIN10_RS3=0x0A000004',
        '-fno-short-enums',
        if (Platform.isMacOS) ...['-isysroot', macSdkPath],
      ],
    ),
    functions: Functions.includeSet({'uloc_getDisplayCountry'}),
    enums: Enums(
      include: (declaration) => declaration.originalName == 'UErrorCode',
      // The Windows SDK uses a signed 32-bit int for UErrorCode; the
      // compiler option above also fixes that width during generation.
      silenceWarning: true,
    ),
    output: Output(
      dartFile: arguments.isEmpty
          ? Platform.script.resolve('../../../lib/src/gen/country_names_windows.g.dart')
          : File(arguments.single).absolute.uri,
      style: const DynamicLibraryBindings(wrapperName: 'CountryNamesWindowsBindings'),
      commentType: const CommentType(CommentStyle.doxygen, CommentLength.brief),
      preamble:
          '// Generated from the Microsoft Windows SDK ICU header. Do not edit.\n'
          '// See tool/country_bindings/bin/generate_windows.dart for the pinned source.',
    ),
  ).generate();
}
