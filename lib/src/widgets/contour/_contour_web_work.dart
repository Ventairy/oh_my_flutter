part of 'contour.dart';

class _ContourWebWork {
  new trace({
    required this.id,
    required this.rgba,
    required this.width,
    required this.height,
    required this.ratio,
    this.nativeTrace = false,
    this.nativeTraceQuota = 0,
  }) : original = null,
       originalWidth = 0,
       originalHeight = 0,
       padding = 0,
       verification = false;

  new verification({
    required this.id,
    required this.rgba,
    required this.width,
    required this.height,
    required this.ratio,
    required this.original,
    required this.originalWidth,
    required this.originalHeight,
    required this.padding,
  }) : verification = true,
       nativeTrace = false,
       nativeTraceQuota = 0;

  final int id;
  Uint8List? rgba;
  final int width;
  final int height;
  final double ratio;
  Uint8List? original;
  final int originalWidth;
  final int originalHeight;
  final int padding;
  final bool verification;
  final bool nativeTrace;
  final int nativeTraceQuota;
  ContourNativePortSession? nativePortSession;
  int? nativePortTicket;
  Completer<void>? acknowledgement;
  bool active = false;
  bool cancelled = false;

  int get payloadBytes => (rgba?.lengthInBytes ?? 0) + (original?.lengthInBytes ?? 0);

  void clearPayload() {
    rgba = null;
    original = null;
  }
}
