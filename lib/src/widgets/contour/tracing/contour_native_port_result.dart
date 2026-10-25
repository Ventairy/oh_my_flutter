import 'dart:typed_data';

/// Makes retired native geometry available without copying its coordinates.
final class ContourNativePortResult {
  /// Splits one copied native reply into views over its coordinate storage.
  factory({
    required int ticket,
    required int status,
    required Uint32List lengths,
    required Float64List values,
  }) {
    var offset = 0;
    final contours = <Float64List>[];
    for (final length in lengths) {
      final end = offset + length;
      if (end > values.length) {
        throw const FormatException(
          'Native contour lengths exceed the coordinate storage.',
        );
      }
      contours.add(Float64List.sublistView(values, offset, end));
      offset = end;
    }
    if (offset != values.length) {
      throw const FormatException(
        'Native contour lengths do not cover the coordinate storage.',
      );
    }
    return ContourNativePortResult._(
      ticket,
      status,
      List.unmodifiable(contours),
    );
  }

  const new _(this.ticket, this.status, this.contours);

  /// Identifies the admission that the consumer must acknowledge.
  final int ticket;

  /// Reports the native tracing outcome, with zero indicating success.
  final int status;

  /// Provides contour coordinate views backed by the VM-owned reply storage.
  final List<Float64List> contours;
}
