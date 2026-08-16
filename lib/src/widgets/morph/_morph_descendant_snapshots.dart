part of 'morph.dart';

final class _MorphDescendantSnapshots {
  const _MorphDescendantSnapshots._();

  static final Expando<List<_MorphDescendantFlightRecord>> _records = Expando<List<_MorphDescendantFlightRecord>>(
    'oh_my_flutter.morph.descendants',
  );

  static void attach(
    MorphEndpoint<Object?> endpoint,
    List<_MorphDescendantFlightRecord> records,
  ) {
    if (records.isEmpty) return;
    _records[endpoint] = records;
  }

  static List<_MorphDescendantFlightRecord> of(
    MorphEndpoint<Object?> endpoint,
  ) {
    return _records[endpoint] ?? const [];
  }
}
