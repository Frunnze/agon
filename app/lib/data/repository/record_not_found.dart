final class RecordNotFound implements Exception {
  const RecordNotFound({required this.kind, required this.identifier});

  final String kind;
  final String identifier;

  @override
  String toString() => 'No $kind with id $identifier';
}

T findRecord<T>(
  Iterable<T> records, {
  required bool Function(T record) matches,
  required String kind,
  required String identifier,
}) {
  for (final T record in records) {
    if (matches(record)) {
      return record;
    }
  }
  throw RecordNotFound(kind: kind, identifier: identifier);
}
