import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:meta/meta.dart';

import '../contour_work_budget.dart';
import '../tracing/contour_native_port_session.dart';
import 'contour_composite_capture.dart';
import 'contour_composite_native_request.dart';
import 'contour_composite_result.dart';

part '_contour_composite_layout.dart';
part '_contour_composite_request.dart';

/// Prepares bounded decoration atlases using standard Flutter captures.
@internal
final class ContourCompositeSource implements ContourCompositeCapture {
  new _();

  /// Shares source capture and native admission in this isolate.
  static final _shared = ContourCompositeSource._();

  /// Installs an isolated public-API-only capture source in focused tests.
  @visibleForTesting
  static ContourCompositeCapture? testOverride;

  /// Returns the normal backend unless a focused test supplies its own source.
  static ContourCompositeCapture get shared => testOverride ?? _shared;

  /// Checks support without opening a native owner.
  @override
  bool get available => ContourNativePortSession.isSupported;

  static const _maximumBatch = 40;
  static const _maximumOwned = 80;
  static const int _maximumOwnedPixels = 8 * 1024 * 1024;
  static const int _maximumOutputBytes = 4 * 1024 * 1024 * 4;
  // Match the mask's three-percent visibility cutoff. Invisible font specks
  // must not trigger repeated captures of ever larger areas.
  static const _minimumVisibleAlpha = 8;
  final _pending = <_ContourCompositeRequest>[];
  int _owned = 0;
  int _ownedPixels = 0;
  bool _scheduled = false;
  bool _running = false;
  bool _gpuUnavailable = false;

  /// Retains the source immediately, then batches independently owned captures.
  @override
  Future<ContourCompositeResult?> capturePicture(
    ui.Picture source, {
    required int width,
    required int height,
    required double sourceRatio,
    required double outputRatio,
    required double amountOutputPx,
    required int contourArgb,
    required int shadowArgb,
    required double shadowSigmaOutputPx,
    required double shadowDxOutputPx,
    required double shadowDyOutputPx,
    required Future<void> cancelled,
  }) {
    final pixels = width * height;
    if (!available ||
        width < 1 ||
        height < 1 ||
        width > 2048 ||
        height > 2048 ||
        pixels > 262144 ||
        _owned >= _maximumOwned ||
        pixels > _maximumOwnedPixels - _ownedPixels) {
      return Future.value();
    }
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawPicture(source);
    _owned++;
    _ownedPixels += pixels;
    final request = _ContourCompositeRequest(
      picture: recorder.endRecording(),
      width: width,
      height: height,
      sourceRatio: sourceRatio,
      outputRatio: outputRatio,
      amount: amountOutputPx,
      color: contourArgb,
      shadow: shadowArgb,
      sigma: shadowSigmaOutputPx,
      dx: shadowDxOutputPx,
      dy: shadowDyOutputPx,
      onFinished: () {
        _owned--;
        _ownedPixels -= pixels;
      },
    );
    unawaited(
      cancelled.then<void>((_) {
        _pending.remove(request);
        request.cancel();
      }),
    );
    _pending.add(request);
    _schedule();
    return request.result.future;
  }

  void _schedule() {
    if (_scheduled || _running) return;
    _scheduled = true;
    scheduleMicrotask(
      () => scheduleMicrotask(() {
        _scheduled = false;
        unawaited(_flush());
      }),
    );
  }

  Future<void> _flush() async {
    if (_running) return;
    _running = true;
    try {
      while (_pending.isNotEmpty) {
        final jobs = _pending.take(_maximumBatch).toList();
        _pending.removeRange(0, jobs.length);
        await _process(jobs);
      }
    } finally {
      _running = false;
      if (_pending.isNotEmpty) _schedule();
    }
  }

  Future<void> _process(List<_ContourCompositeRequest> jobs) async {
    jobs.removeWhere((job) => job.cancelled);
    if (jobs.isEmpty) return;
    final layout = _ContourCompositeLayout.pack(jobs);
    // Flutter capture/decode storage and the native heap have independent
    // admission. Reserve three source and output planes until the atlas has
    // been decoded and retained by its per-owner pictures.
    final uiBytes = layout == null ? 0 : layout.width * layout.height * 12 + _maximumOutputBytes * 3 + 64 * 1024;
    if (layout == null || uiBytes > ContourWorkBudget.shared.maxBytes) {
      if (jobs.length > 1) {
        final middle = jobs.length ~/ 2;
        await _process(jobs.sublist(0, middle));
        await _process(jobs.sublist(middle));
      } else {
        jobs.single.finish(null);
      }
      return;
    }
    final cancelled = Completer<void>();
    void checkCancellation() {
      if (!cancelled.isCompleted && jobs.every((job) => job.cancelled)) cancelled.complete();
    }

    for (final job in jobs) {
      job.onCancelled = checkCancellation;
    }
    checkCancellation();
    final reservation = ContourWorkBudget.shared.request(bytes: uiBytes, owner: cancelled);
    unawaited(cancelled.future.then<void>((_) => reservation.cancel()));
    ContourWorkBudgetLease? lease;
    ui.Picture? atlas;
    ui.Image? sourceImage;
    ui.Image? outputImage;
    ContourNativePortSession? session;
    try {
      lease = await reservation.future;
      if (lease == null || cancelled.isCompleted) return;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final tiles = Float64List(jobs.length * 25);
      for (var index = 0; index < jobs.length; index++) {
        final job = jobs[index];
        final (x, y) = layout.offsets[index];
        canvas
          ..save()
          ..translate(x.toDouble(), y.toDouble())
          ..clipRect(ui.Rect.fromLTWH(0, 0, job.width.toDouble(), job.height.toDouble()), doAntiAlias: false);
        if (!job.cancelled) canvas.drawPicture(job.picture!);
        canvas.restore();
        final at = index * 25;
        tiles.setRange(at, at + 13, [
          x.toDouble(),
          y.toDouble(),
          job.width.toDouble(),
          job.height.toDouble(),
          job.sourceRatio,
          job.outputRatio,
          job.amount,
          job.color.toDouble(),
          if (job.shadow == 0) 0.0 else 1.0,
          job.sigma,
          job.dx,
          job.dy,
          job.shadow.toDouble(),
        ]);
      }
      atlas = recorder.endRecording();
      final sourceFuture = atlas.toImage(layout.width, layout.height);
      try {
        session = ContourNativePortSession.create();
      } catch (_) {
        // The capture has already started. Await its image so finally can
        // dispose it even when native initialization is unavailable.
      }
      sourceImage = await sourceFuture;
      if (cancelled.isCompleted) return;
      final data = await sourceImage.toByteData();
      sourceImage.dispose();
      sourceImage = null;
      atlas.dispose();
      atlas = null;
      if (data == null || cancelled.isCompleted || session == null) return;
      final output = await ContourCompositeNativeRequest.run(
        rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width: layout.width,
        height: layout.height,
        tiles: tiles,
        session: session,
        cancelled: cancelled.future,
      );
      if (output == null || cancelled.isCompleted) return;
      outputImage = await _decode(output.rgba, output.width, output.height);
      if (cancelled.isCompleted) return;
      for (var index = 0; index < jobs.length; index++) {
        final job = jobs[index];
        if (job.cancelled) continue;
        final at = index * 6;
        final p = output.placements;
        final scale = job.sourceRatio / job.outputRatio;
        final bounds = ui.Rect.fromLTWH(p[at + 4] * scale, p[at + 5] * scale, p[at + 2] * scale, p[at + 3] * scale);
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawImageRect(
          outputImage,
          ui.Rect.fromLTWH(p[at], p[at + 1], p[at + 2], p[at + 3]),
          bounds,
          ui.Paint()..filterQuality = ui.FilterQuality.low,
        );
        job.finish(
          ContourCompositeResult(
            picture: recorder.endRecording(),
            boundsPx: bounds,
            sourceTouchesBoundary: _touchesBoundary(
              data,
              atlasWidth: layout.width,
              offset: layout.offsets[index],
              request: job,
            ),
          ),
        );
      }
    } catch (_) {
      // Unsupported captures and bounded resource failures use the existing
      // contour renderer. They never publish an incomplete decoration.
    } finally {
      sourceImage?.dispose();
      atlas?.dispose();
      outputImage?.dispose();
      try {
        await session?.close();
      } finally {
        for (final job in jobs) {
          job
            ..onCancelled = null
            ..finish(null);
        }
        lease?.release();
      }
    }
  }

  bool _touchesBoundary(
    ByteData pixels, {
    required int atlasWidth,
    required (int, int) offset,
    required _ContourCompositeRequest request,
  }) {
    final (left, top) = offset;
    final stride = atlasWidth * 4;
    final first = (top * atlasWidth + left) * 4 + 3;
    final last = first + (request.height - 1) * stride;
    for (var x = 0; x < request.width; x++) {
      if (pixels.getUint8(first + x * 4) >= _minimumVisibleAlpha ||
          pixels.getUint8(last + x * 4) >= _minimumVisibleAlpha) {
        return true;
      }
    }
    final right = first + (request.width - 1) * 4;
    for (var y = 1; y < request.height - 1; y++) {
      if (pixels.getUint8(first + y * stride) >= _minimumVisibleAlpha ||
          pixels.getUint8(right + y * stride) >= _minimumVisibleAlpha) {
        return true;
      }
    }
    return false;
  }

  Future<ui.Image> _decode(Uint8List rgba, int width, int height) async {
    if (!_gpuUnavailable) {
      try {
        final texture = gpu.gpuContext.createTexture(
          gpu.StorageMode.devicePrivate,
          width,
          height,
          enableRenderTargetUsage: false,
        )..overwrite(ByteData.sublistView(rgba));
        return texture.asImage();
      } catch (_) {
        // GPU upload is optional. A standard app needs no renderer flag.
        _gpuUnavailable = true;
      }
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = ui.ImageDescriptor.raw(buffer, width: width, height: height, pixelFormat: ui.PixelFormat.rgba8888);
      codec = await descriptor.instantiateCodec();
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
