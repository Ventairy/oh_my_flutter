import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:record_use/record_use.dart';

/// Builds the native contour tracer and its Dart API message bridge.
abstract final class ContourNativePortCLibrary {
  /// Connects the native library to its Dart binding asset.
  static const assetName = 'src/widgets/contour/tracing/contour_native_port_bindings.dart';

  /// Names the contour tracing code asset.
  static const libraryName = 'oh_my_flutter_contour_native_port';

  static const _sdkLibraryName = '${libraryName}_sdk_glue';
  static const _sdkAssetName = 'src/widgets/contour/tracing/contour_native_port_sdk_glue';

  static const _create = Method(
    'create',
    Class(
      'ContourNativePortSession',
      Library(
        'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session_io.dart',
      ),
    ),
  );

  /// Keeps the library when compiled code can create a native session.
  ///
  /// Missing reachability metadata conservatively retains the library.
  static bool isReachable(Recordings? recordedUses) {
    if (recordedUses == null) return true;
    return recordedUses.calls[_create]?.isNotEmpty ?? false;
  }

  /// Supports Android and macOS contour processing.
  static bool supports(OS target) => target == OS.android || target == OS.macOS;

  /// Compiles the SDK C glue separately and publishes the contour code asset.
  static Future<void> build({required BuildInput input, required BuildOutputBuilder output}) async {
    final target = input.config.code.targetOS;
    final linking = input.config.linkingEnabled;
    await CBuilder.library(
      name: _sdkLibraryName,
      assetName: linking ? _sdkAssetName : null,
      sources: const ['src/contour_native_port/sdk/include/dart_api_dl.c'],
      includes: const ['src/contour_native_port/sdk/include'],
      language: Language.c,
      std: 'c11',
    ).run(
      input: input,
      output: output,
      routing: linking ? [ToLinkHook(input.packageName)] : const [],
      linkModePreference: LinkModePreference.static,
    );
    if (linking) {
      // CBuilder's archiver replaces named members without removing old ones.
      // Start this owned archive clean when the C++ source list changes.
      final archive = File.fromUri(input.outputDirectory.resolve(target.staticlibFileName(libraryName)));
      if (archive.existsSync()) archive.deleteSync();
    }
    await _libraryFor(
      target,
      sdkDirectory: linking ? null : input.outputDirectory.toFilePath(),
    ).build(input: input, output: output);
  }

  /// Links both private archives into the single contour code asset.
  static Future<void> link({
    required LinkInput input,
    required LinkOutputBuilder output,
    required LinkerOptions linkerOptions,
  }) async {
    final target = input.config.code.targetOS;
    final library = libraryFor(target);
    await CLinker.library(
      name: libraryName,
      assetName: assetName,
      language: library.language,
      flags: const ['-x', 'none'],
      libraries: library.libraries,
      cppLinkStdLib: library.cppLinkStdLib,
    ).run(
      input: input,
      output: output,
      linkerOptions: linkerOptions,
      sources: [
        for (final asset in input.assets.code)
          if (asset.id == 'package:${input.packageName}/$assetName' ||
              asset.id == 'package:${input.packageName}/$_sdkAssetName')
            asset.file!.toFilePath(),
      ],
    );
  }

  /// Configures the owned C++ contour implementation.
  static CLibrary libraryFor(OS target) => _libraryFor(target);

  static CLibrary _libraryFor(OS target, {String? sdkDirectory}) => CLibrary(
    name: libraryName,
    assetName: assetName,
    sources: const [
      'src/contour_native_port/contour_native_port.cpp',
      'src/contour_native_port/composite/contour_cpu_batch.cpp',
      'src/contour_native_port/composite/portable/contour_generic_fused.cpp',
      'src/contour_native_port/composite/portable/deps/trace/contour_source_a8.cpp',
      'src/contour_native_port/composite/portable/deps/backing/contour_backing_raster.cpp',
      'src/contour_native_port/composite/portable/deps/backing/scanline.cpp',
      'src/contour_native_port/composite/portable/deps/backing/clipper2/src/clipper.engine.cpp',
      'src/contour_native_port/composite/portable/deps/backing/clipper2/src/clipper.offset.cpp',
      'src/contour_native_port/composite/portable/deps/compositor/contour_a8_compositor.cpp',
    ],
    includes: const [
      'src/contour_native_port/',
      'src/contour_native_port/composite/portable/deps/trace',
      'src/contour_native_port/composite/portable/deps/backing',
      'src/contour_native_port/composite/portable/deps/backing/clipper2/include',
      'src/contour_native_port/composite/portable/deps/compositor',
    ],
    defines: const {'Clipper2Lib': 'ContourPackageBackingClipper2Lib'},
    language: Language.cpp,
    std: 'c++17',
    // Keep archive inputs in linker mode while compiling C++ source files.
    flags: const ['-ffp-contract=off', '-fno-fast-math', '-x', 'none'],
    // The ARM32 C runtime does not provide floor/ceil; link libm explicitly.
    libraries: [if (sdkDirectory != null) _sdkLibraryName, if (target == OS.android) 'm'],
    libraryDirectories: [?sdkDirectory],
    cppLinkStdLib: target == OS.android ? 'c++_static' : null,
  );
}
